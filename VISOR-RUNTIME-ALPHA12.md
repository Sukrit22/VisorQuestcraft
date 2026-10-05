# Visor runtime choices — alpha.12

Both headset APKs built and passed packaging verification. Host checks passed: 23 runtime/download-policy checks, 19 actual installer migration checks, eight manifest tests, and 25 Forge/Fabric preflight checks. Unity's runtime selector geometry and policy checks passed. On 2026-10-04 the user reported that both Forge and Fabric launch into Visor with this build; this does not establish 0.6 or every custom URL/modpack as working.

## Player workflow

Create a Minecraft 1.20.1 instance and choose its loader, then its Visor runtime:

- **Visor 0.5 (managed):** the default for Forge and Fabric. The launcher installs the Android core and its companion bridge.
- **Visor 0.6 (experimental, Forge):** bundles the Android adaptation of 0.6.0 Alpha 2. This build includes its bridge inside the core JAR, so the separate 0.5 companion must not remain active. Fabric 0.6 is not offered by this port.
- **Manual install (unmanaged):** the launcher does not install or replace Visor. Finish creating the instance, then place the appropriate Android-adapted Visor and any required companion in that instance's `mods` folder. Keep exactly one Visor core and use mods for the selected loader. Do not copy a PC instance registry or runtime/classpath over the Android installation.
- **Custom Android JAR URL:** paste a direct HTTPS download link for a supported Android Visor JAR matching the selected loader. An optional SHA-256 can be supplied. Download and validation take place before launch. A stock PC JAR is not made Android-compatible by downloading it through this feature.

For an existing instance, open its information page and use **Visor runtime** to change the selection. Saving applies the managed runtime at the next launch. Unmanaged mode leaves existing files in place; remove or move old Visor/companion files yourself when replacing them manually.

Prefer a separate test instance for 0.6. Addons requiring Visor 0.5 can reject or break on 0.6. Changing the runtime selection does not convert addons or prove their compatibility. Preserve worlds and personal settings before testing a new runtime.

## Maintainer workflow

The APK can bundle JARs from local builds or from direct HTTPS links in `build-targets/visor-downloads.json`. Remote entries require a pinned SHA-256. See `build-targets/VISOR-DOWNLOADS.md` for the fields and cache behavior. No release was uploaded to GitHub by this task.

1. Build the Android JARs locally, or publish the intended JARs yourself and put their direct URLs and hashes in the manifest.
2. Run `tools/Stage-PicoAssets.ps1` to resolve and validate the artifacts and stage the Forge runtime. The legacy script name applies to both headset targets.
3. Set Java 17 and the Android SDK, then run Gradle 8.10.2 `-p sources/Pojlib assembleRelease --console=plain`.
4. Build and verify Pico and Quest sequentially with `tools/Build-AndroidApk.ps1 -Target Pico` / `tools/Verify-AndroidApk.ps1 -Target Pico`, then the corresponding Quest commands.
5. Install the matching APK manually and test both loaders and runtime choices on the intended headset. Packaging verification checks the staged artifact receipt against the AAR/APK to reject stale bundles.

Alternatively, `tools/Build-AndroidRelease.ps1 -Target Both` runs staging, Pojlib compilation and both sequential APK builds/verifiers. It accepts Java/SDK/Gradle path overrides and `-Offline` for local inputs.

## Quest 3S report supplied on 2026-10-03

`user-logs/latest-fromDangel.log` is a Forge 47.4.20 / Minecraft 1.20.1 log from instance `tst`. It ends at mod discovery (`Found 2 dependencies adding them to mods collection`). It contains no fatal exception, Java exit code, APK version, or Fabric attempt. The settings-correction and Forge-library `mods.toml` warnings in this fragment do not establish the cause of failure.

For alpha.10, the known Forge bridge conflict is a candidate, but this fragment does not confirm it. Ask the tester to use Save / Share Logs immediately after each failed attempt and label the reports Forge or Fabric, with the APK version. One tester's successful Fabric report does not establish that every Quest device or instance works.
