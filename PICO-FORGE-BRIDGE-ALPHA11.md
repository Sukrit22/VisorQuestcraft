# Pico Forge launch failure — alpha.11

## Observed failure

Read-only ADB capture on 2026-10-03 found Pico alpha.10 installed. The latest launch of the managed `new` Forge 1.20.1/47.4.20 instance ended with Java exit code 1 during ModLauncher module-layer creation:

`Modules visor and visor_android_bridge export package org.vmstudio.visor.core.client.provider.openxr to module minecraft`

The instance contained split Visor 0.5.0 and Android Bridge 0.1.0. The game had not reached Minecraft rendering or OpenXR initialization. This is a package-ownership bug in our companion extraction, separate from the Quest alpha.9 missing-Gson launcher bug. No user mod or graphics-setting change is needed to address this exception.

The earlier saved diagnostic identifies alpha.9, but its attached instance/crash logs include older September 27 sessions. Those older flite/VR errors do not establish the cause of the latest launch. The current launch reports Java 22; runtime selection was not changed in this fix.

## Fix

1. Moved companion `QuestAndroidXRBridge` and `QuestVLoader` into the companion-owned `org.vmstudio.visor.android` package and updated the ServiceLoader provider declaration. Version is now Android Bridge 0.1.1.
2. Added seven new JNI exports for that package in Pojlib's vloader.cpp, forwarding the existing implementation. Retained all seven legacy Visor exports for the old monolithic Android builds, including our separate 0.6 experiment.
3. The managed installer copies Bridge 0.1.1 and moves the exact old managed `Visor-Android-Bridge-0.1.0.jar` into `visor-backups`. It also does this if 0.1.1 is already copied, making retry safe. Custom `manageBundledVisor=false` profiles still opt out.
4. Build-AndroidBridge uses a fresh compiler-output directory per build so removed-package classes cannot survive in a new JAR.
5. Added module-resolution regression coverage using package sets from the actual JARs. The old 0.1.0 reproduces the reported conflict; 0.1.1 resolves successfully. This is module-resolution coverage, not a full Forge or headset run.
6. APK verification checks all fourteen new/legacy JNI exports in the packaged ARM64 native library, in addition to launcher class definitions and existing package/asset checks.

## Installation and retest

Install the alpha.11 APK for your headset manually over the current app. Reopen and launch the managed Forge instance. The bridge migration happens during managed prelaunch; no manual JSON edit or removal is needed. Do not copy Bridge 0.1.1 into an older APK: its new JNI names require the updated native library.

If a custom profile opts out of managed installation, it is not automatically migrated. Keep its intended runtime arrangement; monolithic 0.6 should not have the separate 0.5 companion installed.

No app data was cleared, no mod files on the headset were changed, and no APK was installed during diagnosis. Save/Share fresh diagnostics after retesting if launch still fails.

## Rebuild

From the workspace with Java 17 / Gradle 8.10.2:

1. Run `tools/Build-AndroidBridge.ps1`, `tools/Test-AndroidBridge.ps1`, `tools/Verify-AndroidBackend.ps1`, and `tools/Test-ForgePort.ps1`.
2. Run `tools/Stage-PicoAssets.ps1`; then build Pojlib `assembleRelease` to compile the added JNI exports.
3. Build and verify Pico, then Quest, sequentially with `tools/Build-AndroidApk.ps1` and `tools/Verify-AndroidApk.ps1`.
4. Preserve previous artifacts for rollback. Outputs and hashes are recorded in `outputs/alpha11-artifacts.json`.

Verification requires Java 17, Python 3 and the existing Android NDK 26.1 llvm-nm path. Existing Visor core JARs are unchanged; this fix updates the companion and launcher native library.

## Verification results (2026-10-03)

Both alpha.11 APKs built successfully in Unity 6000.4.10f1. Each passed checks for ten launcher runtime class definitions, 76 shared runtime files, target loader/features/manifest, ARM64 architecture, APK signature and all fourteen new/legacy JNI exports. Bridge discovery tests and the 25 Forge/Fabric preflight checks passed; module-resolution coverage reproduced the old conflict and accepted the new bridge.

These are build and packaging results. Neither alpha.11 APK has been tested on a headset yet. The user confirms Pico alpha.5 worked; our Quest build remains hardware-unconfirmed, while Coah's reportedly works sometimes. Shared bridge/runtime changes require regression testing on both targets, even when discovered while investigating only one headset.
