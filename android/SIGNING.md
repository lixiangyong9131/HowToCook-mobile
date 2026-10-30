# Android release signing (sideload)

## Root cause of in-app update failures (≤ v0.6.18)

`android/app/build.gradle.kts` signed **release** APKs with the **debug**
keystore (`signingConfigs.debug`). GitHub Actions runners each create their
own `~/.android/debug.keystore`, so every CI tag could produce a different
signing certificate.

Verified on published APKs:

| Tag     | Cert DN              | SHA-256 (prefix)     |
|---------|----------------------|----------------------|
| v0.6.17 | Android Debug        | `30832260affe2799…`  |
| v0.6.18 | Android Debug        | `da7e804a34739ddb…`  |

Android refuses upgrades when the signing cert changes
(`INSTALL_FAILED_UPDATE_INCOMPATIBLE`).

## Fix (v0.6.19+)

Stable project keystore (sideload / GitHub Releases, **not** Play App Signing):

- Keystore: `android/signing/howtocook-release.jks`
- Props: `android/signing/keystore.properties`
- Alias: `howtocook`

CI and local `flutter build apk --release` both use this file so updates
install over each other from v0.6.19 onward.

**One-time:** users on ≤ v0.6.18 must uninstall once, then install v0.6.19+.

This keystore is intentionally in-repo so sideload builds stay consistent.
Do not replace it without a migration note.
