# Dev tooling & service access

How to give a workstation (or an agent session) the tools and credentials to
inspect the services Navis runs on: **Supabase**, **Sentry**, **Novu** and
**Resend**. `deploy.md` covers shipping; this covers looking.

Written 2026-08-18 while setting this up on a Linux workstation with no root and
no Node, so every install here is a userland binary drop.

---

## 1. What an agent session can and cannot do

Worth stating plainly, because it is the thing that wastes the most time:

- **A browser tab you have open is invisible to the agent.** There is no browser
  tool, no screen access, and no way to borrow your session cookies. Opening the
  Supabase dashboard "for" the agent achieves nothing. `WebFetch` fails on any
  authenticated URL by design.
- **Therefore the agent cannot create tokens.** Every token below has to be
  minted by a human in a dashboard. Once it exists in the token file (§3), the
  agent can use it freely.
- Interactive logins (`supabase login`, which opens a browser) must be run by
  the human. In Claude Code, prefix with `!` so the output lands in the session:
  `! supabase login`. A Personal Access Token in the environment avoids the
  browser entirely, which is why §3 prefers it.

---

## 2. CLIs

No root and no npm on this box, so both CLIs are release binaries in
`~/.local/bin` (already on `PATH`). Re-run these to update.

```bash
mkdir -p ~/.local/bin

# Supabase CLI (2.115.0 at time of writing)
URL=$(curl -sS https://api.github.com/repos/supabase/cli/releases/latest \
  | grep -o 'https://[^"]*linux_amd64\.tar\.gz' | head -1)
curl -sSL "$URL" | tar xz -C /tmp supabase
install -m755 /tmp/supabase ~/.local/bin/supabase

# sentry-cli (3.6.2 at time of writing)
URL=$(curl -sS https://api.github.com/repos/getsentry/sentry-cli/releases/latest \
  | grep -o 'https://[^"]*sentry-cli-Linux-x86_64"' | tr -d '"' | head -1)
curl -sSL -o /tmp/sentry-cli "$URL"
install -m755 /tmp/sentry-cli ~/.local/bin/sentry-cli
```

**Novu and Resend need no CLI** — both are plain REST APIs, so `curl` is the
tool. Their CLIs exist but only wrap local development studios we do not use.

### Two environment limits to know before you fight them

- **`make db-start` / `db-reset` cannot work without a Docker daemon.** The
  Supabase CLI shells out to Docker for the local stack. This box has podman with
  its socket inactive and no docker-compat socket, so the local stack is simply
  unavailable. Fixable with `systemctl --user enable --now podman.socket` and
  `DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock`, but untested here.
- **No Flutter/Dart/Go toolchain on this box either**, so `flutter test`,
  `flutter analyze`, `dart format` and `go test` cannot run locally: CI is the
  first compiler that sees a change. Budget for a few red CI rounds on any large
  branch — see the format/analyzer ordering trap in §6.

---

## 3. The token file

Secrets live in one file **outside the repo**, never in it and never pasted into
a chat transcript:

```bash
mkdir -p ~/.config/navis
touch ~/.config/navis/tokens.env
chmod 600 ~/.config/navis/tokens.env
```

```bash
# ~/.config/navis/tokens.env
SUPABASE_ACCESS_TOKEN=sbp_...        # account-wide; see the warning below
SUPABASE_PROJECT_REF=...             # from the project URL
SUPABASE_DB_URL=postgresql://...     # only if direct SQL is needed
SENTRY_AUTH_TOKEN=sntrys_...
SENTRY_ORG=...
SENTRY_PROJECT=...
RESEND_API_KEY=re_...
NOVU_API_KEY_DEV=...
NOVU_API_KEY_PROD=...
```

Use it per command rather than exporting it into a long-lived shell:

```bash
set -a; . ~/.config/navis/tokens.env; set +a
```

> ⚠️ **A Supabase Personal Access Token cannot be scoped.** It grants management
> access to every project on the account, production included. And
> `SUPABASE_DB_URL` (or a `service_role` key) **bypasses RLS** — it reads and
> writes every user's rows, not just yours. That is sometimes exactly what is
> needed, but it is not a read-only credential, and a one-off SQL query run by a
> human in the dashboard is often the cheaper answer.

Minimum useful scopes, where scoping exists:

| Service | Token | Scope that suffices |
|---|---|---|
| Supabase | Personal Access Token | not scopeable (account-wide) |
| Sentry | Auth Token | `org:read`, `project:read`, `event:read` |
| Resend | API Key | **Full access** — a sending-only key cannot list deliveries |
| Novu | API Key | one per environment (Development / Production) |

---

## 4. Per-service recipes

### Supabase

```bash
supabase projects list
supabase link --project-ref "$SUPABASE_PROJECT_REF"

# Who exists, and on what plan. `profiles` has no row until an API call creates
# one (there is no auth trigger), and `GetOrCreate` then takes the column
# default, which is 'free'. So "no row" means Free.
psql "$SUPABASE_DB_URL" -c "
  select u.email, coalesce(p.plan, 'free (no row)') as plan
  from auth.users u left join profiles p on p.id = u.id
  order by u.created_at;"

# Grant a tier for testing (the PUT /me/plan switcher is dev-only, so this is
# the only route on production).
psql "$SUPABASE_DB_URL" -c "
  insert into profiles (id, plan)
  select id, 'pro' from auth.users where email = 'someone@example.com'
  on conflict (id) do update set plan = 'pro';"
```

`psql` is not installed here and needs root. Without it, the management API takes
SQL directly:

```bash
curl -sS -X POST \
  "https://api.supabase.com/v1/projects/$SUPABASE_PROJECT_REF/database/query" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"query":"select email from auth.users order by created_at"}'
```

The local seed user (`packages/supabase/seed.sql`) is `test@navis.app` /
`password123`, plan Free, with two boats and dated documents. Local stack only —
it does not exist in production.

### Sentry

```bash
sentry-cli --auth-token "$SENTRY_AUTH_TOKEN" info
sentry-cli issues list --org "$SENTRY_ORG" --project "$SENTRY_PROJECT"
```

Both the Go API and Flutter report here. Errors are tagged with `user_id`,
`boat_id`, app version and OS version, and PII is filtered before sending — so
searching by `user_id` is the way in, not by email.

### Novu

Five workflows, grouped by domain; the identifiers are the source of truth in
`apps/api/internal/service/notifier.go`, and the **workflow id doubles as the
notification category** for the preference toggles, so this list must match
`domain.NotificationCategory`:

```bash
curl -sS https://api.novu.co/v1/workflows \
  -H "Authorization: ApiKey $NOVU_API_KEY_PROD" \
  | jq -r '.data[] | "\(.workflowId)  steps=\([.steps[].template.type] | join(","))"'
```

Expect exactly: `regatta-updates`, `group-updates`, `boat-activity`,
`reminders`, `event-live` — each with a Push (FCM) step and an Email (Resend)
step. A workflow present in code but missing here means those notifications fail
silently at the provider boundary. Note the plan caps total workflows at 20,
which is why per-event names are Go aliases onto these five.

With no `NOVU_API_KEY` set, the provider no-ops *successfully* — the in-app feed
still fills from `FeedRecorder`, so "the bell works" is not evidence that push
or email went out.

### Resend

```bash
curl -sS "https://api.resend.com/emails?limit=20" \
  -H "Authorization: Bearer $RESEND_API_KEY" | jq '.data[] | {to, subject, last_event}'
```

Resend is wired as Novu's email channel, not called directly by our code, so a
missing email is usually a Novu-side problem (muted category, missing subscriber
email, workflow absent) rather than a Resend one. Sender:
`Navis <notifications@aerolume.app>`.

---

## 5. Credential rotation

If any of these leaks, rotate in the service dashboard first, then update
`~/.config/navis/tokens.env`. Nothing in the repo reads that file, so there is no
deploy to redo — the runtime secrets live in Railway env vars and the Flutter
`--dart-define`s (see `deploy.md`), which are a separate set.

---

## 6. CI ordering trap

The Flutter CI job runs, in order: `pub get` → `gen-l10n` → `build_runner` →
**format check** → **analyzer** → tests. Each step aborts the job, so a single
formatting slip hides every compile error behind it, and one analyzer info
(`--fatal-infos`) hides every test failure. On a large branch pushed without a
local toolchain, expect to peel these one layer at a time rather than in one
pass.
