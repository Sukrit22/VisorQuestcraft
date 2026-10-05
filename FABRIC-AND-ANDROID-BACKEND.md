# Fabric support and upstream Android backend prototype (alpha.7)

## What changed

1. Added Fabric 1.20.1 instance creation to the launcher, pinned to Fabric Loader 0.16.14. Forge remains 47.4.20. The instance screen allows choosing either loader; the legacy default-mod pack is disabled.
2. Built Visor 0.5.0 for both loaders with the Android AtumVR/OpenXR dependencies. Fabric bundles Fabric API 0.92.3+1.20.1, including its networking and rendering modules.
3. Moved QuestCraft's Java/JNI handoff adapter into the separate `Visor-Android-Bridge-0.1.0.jar`. It supports both mod loaders and both headset targets. Existing JNI class names are retained because Pojlib exports those symbols.
4. Added Android bridge discovery to AtumVR through Java ServiceLoader. Desktop keeps its normal backend; Android reports missing or duplicate providers explicitly. Visor no longer directly constructs the QuestCraft adapter.
5. Updated launcher installation to stage the correct Visor and companion automatically. Recognized old managed Visor files move to the instance's `visor-backups` directory. Arbitrary duplicate Visor files trigger validation instead of being silently deleted.
6. Built separate Quest and Pico APKs using the same Java artifacts and target-specific Unity XR loaders.

This is an upstream-oriented local prototype, not compatibility with today's untouched stock Visor. The supplied Visor JARs still contain our Android AtumVR and LWJGL changes. Upstream needs to accept/release the backend hooks and Android dependencies before users can replace those with official Visor builds. No upstream PR or message has been sent.

## First test

1. Keep a backup of existing instances. Install the alpha.7 APK for your headset manually. The historical APK filenames/app IDs still contain `Forge`; both loaders are available.
2. Sign in, create a NEW Minecraft 1.20.1 instance, choose Fabric, and launch once. Let the launcher finish downloading its Android runtime and libraries.
3. Confirm the mods directory contains one Fabric Visor 0.5.0 JAR and one Android Bridge 0.1.0 JAR. Do not add Vivecraft or a Forge-only mod.
4. Test launcher controls, VR menu, world entry, both controllers, sleep/resume, and a second launch before adding other mods.
5. Add only Fabric 1.20.1 mods and their dependencies, a few at a time. Desktop native-code mods may not support Android. Do not copy an entire PC instance or its libraries/profile over the Android instance.
6. For multiplayer, use compatible Visor versions on both clients and matching server support. This change does not fix or alter the old prerelease network protocol.

The earlier Quest sign-in/button issue is not established as fixed by this release. If it prevents creation, capture full logcat from before launch through the failed action. Do not infer login status from an Alex skin alone.

## Custom Visor and rollback

`manageBundledVisor=false` in the instance configuration opts out of both managed Visor and companion installation for Fabric and Forge. The user then owns compatibility and file placement. This bridge declares Visor exactly 0.5.0; do not combine it with the older monolithic Android builds or the separate 0.6.0 experimental JAR. Use a separate test instance for those builds.

Old managed JAR backups live outside `mods`. Restoring a monolithic build also requires removing the new companion and new split Visor from `mods`, with managed installation disabled. Prefer retaining an untouched old instance/APK backup. Never copy authentication files to another player.

## Reproduce the build

Use PowerShell from `E:\visor-compat\visor-0.5.0-questcraft`, Java 17 and Gradle 8.10.2. Existing `sources/Visor-0.5.0/libs` includes Android binding inputs; the patches alone do not regenerate these binaries. Unity must be 6000.4.10f1 with Android support, with this project closed in the editor.

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
$env:ANDROID_HOME = 'C:\Users\Sukrit22\AppData\Local\Android\Sdk'
$gradle = 'C:\Users\Sukrit22\.gradle\wrapper\dists\gradle-8.10.2-all\7iv73wktx1xtkvlq19urqw1wm\gradle-8.10.2\bin\gradle.bat'
& $gradle -p sources/AtumVR-upgrade :atumvr-api:jar :atumvr-core:jar
# Stop on failure. Copy the freshly built API/core artifacts into Visor's local inputs.
Copy-Item 'sources/AtumVR-upgrade/atumvr-api/build/libs/atumvr-api-1.14.0beta-snapshot#14.jar' 'sources/Visor-0.5.0/libs/atumvr-api-pico.jar'
Copy-Item 'sources/AtumVR-upgrade/atumvr-core/build/libs/atumvr-core-1.14.0beta-snapshot#14.jar' 'sources/Visor-0.5.0/libs/atumvr-core-pico.jar'
& $gradle -p sources/Visor-0.5.0 :visor-fabric:build :visor-forge:build
# Stop on failure before staging anything.
.\tools\Build-AndroidBridge.ps1
.\tools\Test-AndroidBridge.ps1
.\tools\Test-ForgePort.ps1
.\tools\Verify-AndroidBackend.ps1
.\tools\Stage-PicoAssets.ps1
& $gradle -p sources/Pojlib assembleRelease
# Stop on failure. Build targets sequentially.
.\tools\Build-AndroidApk.ps1 -Target Quest
.\tools\Verify-AndroidApk.ps1 -Target Quest
.\tools\Build-AndroidApk.ps1 -Target Pico
.\tools\Verify-AndroidApk.ps1 -Target Pico
```

The scripts never install an APK. Java discovery/preflight and archive verification cannot prove Forge/Fabric classloader behavior, JNI handoff, GPU compatibility, or real controller behavior on a headset; those require the first-test sequence above.
