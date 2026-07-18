# Android Production Release Signing

This document explains how to produce a **real, production-signed** Android
App Bundle (`app-release.aab`) for Sallehly, using the
`Build Signed Android Release (AAB)` GitHub Actions workflow
(`.github/workflows/android-release-signed.yml`).

It is separate from the existing `Build Android` and
`Temporary Build Android APK (Release)` workflows, which intentionally
always fall back to **debug signing** and require no secrets — they exist
only to validate that the app builds, not to produce a distributable
release.

## 1. Generate a production keystore

Do this once, on your own machine, **never inside CI**:

```bash
keytool -genkey -v -keystore sallehly-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias sallehly
```

You'll be prompted for a store password, a key password, and your
name/organization details. `keytool` is bundled with the JDK.

**Back up `sallehly-release.jks` somewhere safe and durable (e.g. a password
manager or encrypted storage) immediately.** If you lose this file or its
passwords, you can never publish an update to the same app listing on
Google Play again — you'd have to publish under a new application ID.

## 2. Convert the keystore to Base64

GitHub Secrets only store text, so the keystore's binary content must be
Base64-encoded before it's pasted into a secret.

macOS / Linux:
```bash
base64 -i sallehly-release.jks -o sallehly-release.jks.base64
# or, if -i/-o aren't supported by your base64 build:
base64 -w 0 sallehly-release.jks > sallehly-release.jks.base64
```

Windows (PowerShell):
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("sallehly-release.jks")) | Out-File sallehly-release.jks.base64
```

Open `sallehly-release.jks.base64` and copy its entire contents (it will be
one long line, or wrapped depending on the tool — either is fine, the
workflow decodes it as-is).

## 3. Create the required GitHub Secrets

In the repository: **Settings → Secrets and variables → Actions → New
repository secret**. Create exactly these four secrets:

| Secret name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | The full contents of `sallehly-release.jks.base64` from step 2 |
| `ANDROID_KEYSTORE_PASSWORD` | The store password you set in step 1 |
| `ANDROID_KEY_ALIAS` | The alias you set in step 1 (e.g. `sallehly`) |
| `ANDROID_KEY_PASSWORD` | The key password you set in step 1 |

Once saved, secret values are never visible again in the GitHub UI — store
your own copy of the passwords securely before moving on.

## 4. Trigger the signed build

1. Go to the repo's **Actions** tab.
2. Select **Build Signed Android Release (AAB)** in the left sidebar.
3. Click **Run workflow**, choose the branch to build from, and confirm.

The workflow decodes the keystore into a runner-local temp file, generates
`android/key.properties` for that run only, builds
`flutter build appbundle --release`, uploads the result, and then deletes
both the decoded keystore and `key.properties` in a cleanup step that runs
even if the build fails.

If any of the four secrets is missing, the workflow fails immediately with
a clear error and does **not** fall back to debug signing.

## 5. Download the signed AAB

Open the workflow run (Actions tab → the run you triggered) and download
the **`sallehly-android-aab-signed`** artifact from the **Artifacts**
section at the bottom of the run summary page. It contains
`app-release.aab`, signed with your production key and ready to upload to
Google Play Console.

## Security notes

- **Never commit** `sallehly-release.jks` (or any `.jks`/`.keystore` file)
  or `android/key.properties` to git. Both are already excluded by
  `android/.gitignore`.
- `android/key.properties` is generated fresh by the workflow on the
  runner and deleted afterward — it never exists in the repository.
- Secret values referenced via `${{ secrets.* }}` are automatically masked
  by GitHub Actions if they ever appear in logs, but this workflow also
  never echoes them directly.
- Rotate the secrets (delete and re-add) if you ever suspect they were
  exposed. Rotating the keystore itself is not possible without losing the
  ability to update the existing Play Store listing — protect the
  `.jks` file and its passwords accordingly.
