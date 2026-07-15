#!/usr/bin/env bash
# Runs the E2E suite on an iOS simulator against the local stack.
# Usage: TARGET=smoke_test.dart ./scripts/e2e.sh   (or suite_test.dart)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${TARGET:-smoke_test.dart}"

# The flutter wrapper may be permission-locked on this machine; the tools
# snapshot works regardless (see docs: flutter toolchain workaround).
FLUTTER_ROOT_DIR="${FLUTTER_ROOT:-/opt/homebrew/share/flutter}"
if command -v flutter >/dev/null 2>&1 && flutter --version >/dev/null 2>&1; then
  FLUTTER_TEST=(flutter test)
else
  FLUTTER_TEST=(env "FLUTTER_ROOT=$FLUTTER_ROOT_DIR" FLUTTER_ALREADY_LOCKED=true \
    "$FLUTTER_ROOT_DIR/bin/cache/dart-sdk/bin/dart" \
    "$FLUTTER_ROOT_DIR/bin/cache/flutter_tools.snapshot" \
    --no-version-check test)
fi

# 1. Local stack up? (Go API + Supabase auth)
if ! curl -sf http://127.0.0.1:8080/healthz >/dev/null; then
  echo "e2e: Go API not up — run 'make dev' first" >&2
  exit 1
fi
if ! curl -sf http://127.0.0.1:54321/auth/v1/health >/dev/null; then
  echo "e2e: Supabase local not up — run 'make dev' first" >&2
  exit 1
fi

# 2. Simulator: reuse a booted iPhone or boot the newest available one.
UDID=$(xcrun simctl list devices booted -j |
  jq -r '[.devices[][] | select(.name | test("iPhone"))][0].udid // empty')
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl list devices available -j |
    jq -r '[.devices[][] | select(.name | test("^iPhone")) ] | last | .udid // empty')
  [ -z "$UDID" ] && { echo "e2e: no iPhone simulator available" >&2; exit 1; }
  xcrun simctl boot "$UDID"
  open -a Simulator
  sleep 5
fi
echo "e2e: running integration_test/$TARGET on simulator $UDID"

# 3. Run against localhost (simulator shares the host network).
cleanup() { "$REPO_ROOT/scripts/e2e_cleanup.sh" || true; }
trap cleanup EXIT

cd "$REPO_ROOT/apps/mobile"
"${FLUTTER_TEST[@]}" "integration_test/$TARGET" -d "$UDID" --timeout none \
  --dart-define=API_URL=http://127.0.0.1:8080 \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321
