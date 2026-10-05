# Android Visor build inputs

Edit `visor-downloads.json` to choose inputs for each maintained Android JAR. The default `url: null` uses the existing local Android builds without network access. Set `url` to a direct HTTPS JAR URL (including GitHub release assets), and set `sha256` to its independently verified 64-character SHA256. A remote URL without a pinned hash is rejected. Redirects are followed only over HTTPS. Mod metadata is never used to discover download URLs.

Run `tools/Stage-PicoAssets.ps1` after building local inputs or updating URLs. Remote inputs are cached by SHA256; cached bytes are checked again before use. Downloads have a 64 MiB size limit and a 120-second total timeout. `-Offline` explicitly uses each artifact's localPath instead, validates it, and enforces any supplied SHA256 pin.

Staging validates mod ID, loader, version, Android classes, and the 0.6 monolithic Android backend. It stages Forge 0.5, Fabric 0.5, Forge 0.6-alpha.2, and bridge 0.1.1 together with the prepared Forge runtime. Stock PC Visor JARs lack the required Android backend and are rejected.

Next rebuild Pojlib with `assembleRelease`, then run `tools/Build-AndroidApk.ps1 -Target Quest` or `-Target Pico`, and the corresponding verifier. APK packaging checks the manifest hash, staging receipt, and every JAR embedded in the AAR. Changing the manifest or restaging after building the AAR requires another Pojlib build; the packaging script rejects stale input instead of downloading after the AAR was built. APK verification checks the same receipt and artifact hashes, including the 0.6 JAR.
