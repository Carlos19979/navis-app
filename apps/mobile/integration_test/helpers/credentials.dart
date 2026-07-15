/// Per-run E2E identity. One user per process run; the smoke/suite deletes it
/// through the UI and `scripts/e2e_cleanup.sh` sweeps any leftovers.
library;

final String e2eEmail =
    'e2e+${DateTime.now().millisecondsSinceEpoch}@navis.local';
const String e2ePassword = 'NavisE2e!2026';
