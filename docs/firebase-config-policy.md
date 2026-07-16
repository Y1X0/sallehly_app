# Firebase config policy: Android vs iOS

This project intentionally handles Firebase configuration differently per platform.

## Android — `android/app/google-services.json`

Committed directly to the repository, tracked in git.

Firebase's Android config file is not a secret credential — Google's own
documentation states it identifies the Firebase project only; it does not
grant access by itself. Access control is enforced server-side by Firebase
Security Rules / App Check, not by hiding this file. Keeping it in the repo
means any local Android build (`flutter build apk`, `flutter run`) works out
of the box with no extra setup.

## iOS — `ios/Runner/GoogleService-Info.plist`

**Not** committed (excluded via `.gitignore`). Generated at CI time in
`.github/workflows/ios-build.yml` from the `GOOGLE_SERVICE_INFO_PLIST`
GitHub Secret:

```
GitHub Secret (GOOGLE_SERVICE_INFO_PLIST)
        |
        v
GitHub Actions (ios-build.yml)
        |
        v
ios/Runner/GoogleService-Info.plist   (written at build time only)
```

Same underlying config sensitivity as Android's file — this isn't about the
plist being more secret. The reason for the split is that the iOS file was
added later, once the project already had this CI-secret pattern in place
for other iOS-specific values, and there was no reason to touch the
already-working, already-committed Android setup to make it consistent
retroactively.

**Practical consequence:** anyone building iOS locally (not through CI) must
obtain `GoogleService-Info.plist` from Firebase Console themselves and place
it at `ios/Runner/GoogleService-Info.plist` — it will not be present after a
fresh `git clone`.

## If you want to unify this later

Either commit `GoogleService-Info.plist` alongside the Android file (simpler,
matches Android's existing precedent), or move Android to the same
secret-injection pattern as iOS (more consistent with a "nothing but source
lives in the repo" policy). Both are legitimate; this file exists so the
current asymmetry is a documented decision, not an oversight.
