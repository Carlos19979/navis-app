#!/usr/bin/env bash
# Deletes leftover E2E users (e2e+*@navis.local) from the LOCAL Supabase via
# the auth admin API. Safety net for crashed runs; the suite normally deletes
# its own user through the UI. Local-only: the service_role key is the
# standard Supabase local demo JWT.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTH_URL="http://127.0.0.1:54321/auth/v1"

# Prefer the key reported by the running local stack; fall back to env var,
# then to the standard Supabase local demo service_role JWT.
SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
if [ -z "$SERVICE_ROLE_KEY" ] && command -v supabase >/dev/null 2>&1; then
  SERVICE_ROLE_KEY=$(cd "$REPO_ROOT/packages/supabase" &&
    supabase status -o env 2>/dev/null |
    sed -n 's/^SERVICE_ROLE_KEY="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' | head -1) || true
fi
SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU}"

if ! curl -sf "$AUTH_URL/health" >/dev/null; then
  echo "e2e_cleanup: Supabase local not up — nothing to clean"
  exit 0
fi

deleted=0
for page in 1 2 3; do
  ids=$(curl -sf "$AUTH_URL/admin/users?page=$page&per_page=100" \
    -H "apikey: $SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" |
    jq -r '.users[] | select(.email | test("^e2e\\+.*@navis\\.local$")) | .id')
  [ -z "$ids" ] && break
  while IFS= read -r id; do
    curl -sf -X DELETE "$AUTH_URL/admin/users/$id" \
      -H "apikey: $SERVICE_ROLE_KEY" \
      -H "Authorization: Bearer $SERVICE_ROLE_KEY" >/dev/null && deleted=$((deleted + 1))
  done <<<"$ids"
done

echo "e2e_cleanup: removed $deleted leftover e2e user(s)"
