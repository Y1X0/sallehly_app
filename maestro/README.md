# QA Automation — Maestro E2E Suite

Foundation for cloud-run, human-like end-to-end testing of the Sallehly app.
This is the **scripted, deterministic tier** of the QA strategy: fixed flows
that run on every CI trigger against a fresh emulator, a freshly-built debug
APK, and a freshly-booted, empty local backend (not staging, not production).

## Structure

```
maestro/
  README.md              this file
  smoke/                  smallest possible flows — one per critical path
    login_and_verify_home.yaml
  scripts/                small Node/bash helpers used only by CI, not app code
    read-otp.js           reads a pending registration's OTP straight out of
                           the test backend's SQLite file (same technique the
                           backend's own Playwright suite uses — see
                           sallehly/tests/*.spec.js's getPendingOtp helper)
```

More role-specific flow folders (`customer/`, `technician/`, `admin/`) will be
added incrementally — this first slice is intentionally just the smoke test.

## How a CI run works

See `.github/workflows/qa-e2e.yml` in this repo. Summary:

1. Checks out this repo (`sallehly_app`) and the backend repo (`sallehly`)
   side by side.
2. Boots the **real, unmodified** backend (`node server.js`) with
   `NODE_ENV=test`, a throwaway `DATA_DIR`, and a dummy `JWT_SECRET` — the
   exact same pattern used throughout this session's live diagnostics and
   the backend's own Playwright config. No staging server, no shared
   account contention, a clean DB every run.
3. Seeds one deterministic test customer account via the real HTTP API
   (register → read OTP from the SQLite file directly → verify-otp), so the
   smoke test has real, working credentials to log in with.
4. Builds a **debug** APK with
   `--dart-define=API_BASE_URL=http://10.0.2.2:<port>` — `10.0.2.2` is the
   Android emulator's fixed alias for the CI runner's own localhost, so the
   app on the emulator talks to the backend booted in the same job. This
   requires zero app code changes: `AppConfig.baseUrl`
   (`lib/config/app_config.dart`) already reads `API_BASE_URL` from
   `--dart-define`, exactly for this purpose.
5. Boots a GitHub-hosted Android emulator (`reactivecircus/android-emulator-runner`,
   KVM-accelerated on Linux runners — no macOS runner needed, keeps this on
   the free/cheap tier) and runs the Maestro flows against it.
6. Uploads the Maestro report + screenshots as a workflow artifact.

## Running a flow locally (optional, for authoring new flows)

```bash
# 1. Install Maestro CLI: https://maestro.mobile.dev
curl -Ls "https://get.maestro.mobile.dev" | bash

# 2. Have a booted backend + a running emulator/device with the debug APK
#    installed (built with --dart-define=API_BASE_URL pointing at that
#    backend), then:
maestro test maestro/smoke/login_and_verify_home.yaml \
  -e QA_EMAIL=qa-customer@sallehly.test \
  -e QA_PASSWORD='TestPass123!'
```

## What this first slice deliberately does NOT include yet

- Technician/admin flows.
- Image or voice-message upload flows (camera/mic simulation needs a
  separate, slightly more involved setup — pushing seed media into the
  emulator rather than driving a real camera/mic).
- Push-notification testing (needs a Google-API emulator image with Play
  Services, not the bare AOSP image used here).
- Automatic triggering on every push — the workflow is `workflow_dispatch`
  only for now, until the suite has enough coverage to be trusted as a gate.

These are the next slices, not omissions.
