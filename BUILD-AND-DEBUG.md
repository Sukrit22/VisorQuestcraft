# Reproducing the Visor 0.5.0 / Forge 1.20.1 Pico port

This is an experimental Android port for Pico 4 Ultra. Building an APK does not establish that Minecraft, rendering, or controller tracking works. The source directories in this workspace contain local changes; cloning the upstream projects without those changes will not reproduce this build. No changes have been published upstream.

## 1. Understand the components

The Unity launcher starts an Android Java launcher (Pojlib), which starts a separate embedded OpenJDK VM in the app process. That VM launches Minecraft and Forge. Visor uses AtumVR and the Android OpenXR bridge for VR rendering and input. Unity must stop its XR session before Minecraft creates its own.

Build order: AtumVR API/core -> Visor Forge JAR -> Pojlib AAR with bundled assets -> Unity ARM64 APK.

## 2. Use the recorded source baselines

| Directory | Baseline |
|---|---|
| sources/Visor | coah80/Visor, 32c80265594ae76f7f420cc69001c077a9283009 |
| sources/Visor-0.5.0 | VisorModStudio/Visor tag 0.5.0, 3d56cd0a |
| sources/AtumVR-upgrade | upstream AtumVR master f0aeed50acb5c83f5143a89aed5b8a0327b9935c, with Android integration adapted from coah80/AtumVR commit d04c166 |
| sources/Pojlib | coah80/Pojlib QuestCraft-6.0.0, 2b211783ff6bb3419ab1f519f17d4d8afa4ef957 |
| sources/QCXR-XR-Wrapper | coah80/QCXR-XR-Wrapper, c9d110bab8a24801351107a220802befbf43428c |

The workspace root repository, coah80/questcraft-visor-releases, is only a release index. The actual source projects are listed above. Visor-0.5.0 and AtumVR-upgrade are Git worktrees; retain their parent repositories when copying this workspace.

## 3. Install the build tools

- Java 17 for the host Gradle builds.
- Gradle 8.10.2 for the Visor, AtumVR, and Pojlib builds performed here.
- Android SDK 34 and NDK 26.1.10909125 for Pojlib (see its build.gradle).
- Unity 6000.4.10f1, matching ProjectSettings/ProjectVersion.txt, with Android Build Support, SDK/NDK, and OpenJDK. Unity 6000.6.3f1 was not used.
- Git, Git LFS, PowerShell 7, and ADB.

Unity's own Android build used its bundled Gradle 9.1.0/Android Gradle Plugin 9.0.0. That is separate from the Gradle version used to compile Pojlib.

## 4. Bring the Android bridge forward into AtumVR

Keep the newer AtumVR APIs required by Visor 0.5.0. Adapt the old fork's AndroidXRBridge/XRPlatform code rather than substituting the old AtumVR binaries wholesale. XRPlatform initializes the Android loader with the Java VM/activity pointers and provides the EGL/OpenGL ES graphics binding. XRInstance requests Android instance creation and OpenGL ES extensions and filters optional extensions by runtime support.

For Pico input, XRInputHandler suggests bindings for /interaction_profiles/bytedance/pico4_controller and /interaction_profiles/bytedance/pico4s_controller when XR_BD_controller_interaction is enabled. These profiles map to the existing Touch logical action layout. Unsupported input paths are filtered using the runtime's binding results. This requires headset validation; successful Java compilation is not proof of correct input.

Build :atumvr-api:jar and :atumvr-core:jar in sources/AtumVR-upgrade. Copy their outputs to sources/Visor-0.5.0/libs/atumvr-api-pico.jar and atumvr-core-pico.jar. Keep lwjgl-openxr-quest-3.3.3.jar from the Android fork.

## 5. Port and build the Visor Forge module

In sources/Visor-0.5.0, the Gradle dependencies point to the Android AtumVR JARs and custom LWJGL OpenXR classes. Forge bundles those classes instead of desktop OpenXR native libraries. QuestAndroidXRBridge and QuestVLoader connect to Pojlib's JNI bridge. Android disables the desktop mirror and uses a minimal mirror framebuffer.

Set version.properties to the intended release stage. Alpha.2 includes the Pico input changes; the first alpha.1 APK contained an earlier JAR. Run:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
# Set $gradle to your Gradle 8.10.2 gradle.bat.
Push-Location .\sources\Visor-0.5.0
& $gradle :visor-forge:build --console=plain
Pop-Location
```

The distributable is the remapped Forge JAR, not the -dev.jar.

## 6. Prepare Forge with its official installer

Run tools/Prepare-Forge.ps1. It downloads Forge 1.20.1-47.4.10, verifies installer SHA-1 66bfea9963bfa60d88bab6b2750e74a958392715, and runs the official client installer in prepared/forge/1.20.1-47.4.10. This executes Forge's processors on the PC and produces its patched client and supporting libraries. Copying only the Forge installer into Android is insufficient.

ForgeProfile.java validates the pinned profile and expands its library/classpath launch placeholders using the Android installation paths. Installer.installBundledForge copies the prepared runtime from APK assets on the device. The runtime directory is private to this app's external-files location.

## 7. Make installation loader-aware

InstanceHandler creates Forge metadata and uses Forge's BootstrapLauncher. MinecraftInstances adds Forge JVM/game arguments. Forge instances bypass the upstream Fabric/Vivecraft manifest. Installer.installVisor installs the app-managed Forge Visor JAR; alpha.2 retires the old app-managed alpha.1 filename after copying the replacement. ForgeMods rejects Vivecraft, duplicate Visor, and Fabric-only JARs. User configuration/world files are not deleted.

The mod manager filters individual mod searches by Minecraft version and loader. Forge modpack import remains unavailable in this prototype. Other mods still need Android, renderer, and memory compatibility testing.

Run tools/Test-ForgePort.ps1. Its 14 checks exercise profile parsing and mod preflight using small fixtures. They do not run Minecraft.

## 8. Stage assets and build Pojlib

Run tools/Stage-PicoAssets.ps1. It verifies required Android/Forge classes and version metadata in the Visor JAR, then copies the JAR and prepared Forge runtime into Pojlib assets.

```powershell
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
Push-Location .\sources\Pojlib
& $gradle assembleRelease --console=plain
Pop-Location
```

The AAR is sources/Pojlib/build/outputs/aar/Pojlib-release.aar. The Unity build helper copies it into Assets/Plugins/Android. Old generated bundle assets should not be carried into a new release unnecessarily.

## 9. Select the Pico OpenXR loader and Unity features

The fork's Pico feature declared a custom loader but omitted its binary. The restored ARM64 libopenxr_loader.so and importer metadata came from Pico-Developer/PICO-Unity-OpenXR-SDK commit 96efdded84cb6f6f03527effdd99f1930dee486b (release_1.3.0). Git blob hashes: 525fac1c6842f3caac91e11190bc3b132c6f18d3 and ed446e91339eefd8bb7d6e33b2274144ed7b81b1. Pojlib excludes its second loader from the AAR. libopenxr_pico.so is a separate Pico extension library, not a replacement for the loader.

QuestCraftPicoForgeBuild enables Pico Support, Pico OpenXR Features, and Pico 4/Ultra controller profiles; disables Meta/Oculus features; selects OpenGL ES 3; and builds ARM64. It uses a separate application ID, com.qcxr.qcxr.visor.forge.pico, and a development signing key. Thirty-six malformed inline assembly-name strings in Main.unity were quoted to repair scene parsing.

## 10. Build and inspect the APK

Run tools/Build-PicoApk.ps1, then tools/Verify-PicoApk.ps1. The verifier checks the signature, application ID/version, ARM64 components, and the bundled Visor/OpenXR binary hashes. Inspect unity-pico-build.log if Unity fails. The first IL2CPP build can take substantially longer than later builds.

Use a new version/versionCode for a delivered update, update the asset filenames consistently, and preserve the previous APK for comparison. This workspace's build helpers currently target alpha.2.

## 11. Diagnose the launch failure observed on Pico

ADB connected successfully on 2026-09-27. Android exit history and four hs_err reports showed SIGSEGV in libjli.so, JLI_Launch+0x2cc, before the Java VM initialized. The failed instance was named 1.20.1 and used Fabric; its saved classpath was null. A separate forge instance had a populated classpath.

The launcher was filling its launch/mod dropdowns from getQCSupportedVersions, so it displayed only 1.20.1 and hid the saved forge instance. Clicking Play could also create a default Fabric instance and immediately try to launch it before installation finished.

Alpha.2 changes UIHandler to populate launch/mod selectors from saved instance names and keeps the creator's version list separate. InstanceButton no longer implicitly creates Fabric on Play and blocks incomplete metadata. API.prelaunch and generateLaunchArgs add matching checks. The JNI launcher rejects null arguments before invoking libjli, and native argv allocation reserves a terminating null slot. Raw launch-argument logging was removed because it contains the account token.

This explains the observed invalid launch path. A successful corrected Forge launch still needs device verification; additional JVM/Forge/OpenXR problems may appear after this earlier failure is removed.

## 12. Retest without erasing user data

```powershell
& $adb devices -l
& $adb install -r .\outputs\QuestCraft-Forge-1.20.1-Visor-0.5.0-Pico-alpha.2.apk
& $adb shell am start -W -n com.qcxr.qcxr.visor.forge.pico/pojlib.UnityPlayerActivity
& $adb logcat -b crash -d -v threadtime
& $adb shell dumpsys activity exit-info com.qcxr.qcxr.visor.forge.pico
```

Wake the controllers and dismiss Pico's hand/controller dialog if it intercepts launch. Select the saved forge instance. Check first launch, both controller poses/buttons, stereo rendering, a local world, and a second launch. Check that no Vivecraft is installed. Only then add other Forge mods one at a time.

Crash reports and latestlog.txt live below /sdcard/Android/data/com.qcxr.qcxr.visor.forge.pico/files. Keep raw logs local: JVM launch data can contain account tokens. Redact before sharing. Do not use pm clear or uninstall to update this test build; install -r preserves app data.

## 13. Alpha.2 device launch corrections (27 September)

1. Pulled `latestlog.txt` and backed up `instances.json` with ADB. Forge's SecureJarHandler rejected the duplicate `lwjgl-glfw-classes.jar` path: Installer.installLibraries and InstanceHandler both appended it.
2. Deduplicated the saved Forge classpath in original order and added source normalization at creation and launch (including existing instances). Restarted the app without clearing data.
3. The next launch reached ModLauncher but failed with `Modules minecraft and client export package net.minecraft.data to module forge`.
4. Pojlib calls the vanilla download `client.jar`; the official Forge ignore list excludes a differently named vanilla jar. Added `client.jar` to the Forge bootstrap ignore list in source and in the device profile, retaining the original profile backup. Forge's transforming loader provides Minecraft.
5. Passed 16 local parser/mod preflight checks. The latest ignore-list correction still needs a headset launch; this does not establish game or VR compatibility. Both source corrections are pending inclusion in the next APK.

The headset's Forge mods directory already contains `Visor-0.5.0-pico-alpha.2.jar` (12,624,088 bytes). Extra Forge 1.20.1 mods and required dependencies can be placed in `/sdcard/Android/data/com.qcxr.qcxr.visor.forge.pico/files/instances/forge/mods/` using `adb push`. The launcher's Mods search filters by instance loader and version, but installing additional mods on this experimental port has not yet been device-tested. Desktop native dependencies may be incompatible with Android.

The loader dropdown is serialized with `m_Interactable: 0` in Main.unity. Default mods are disabled by InstanceManager for Forge because the upstream preset targets Fabric. This build targets only Minecraft 1.20.1. The reported simultaneous dropdown check marks remain a UI issue to investigate; the captured game log confirms Forge was launched.

## 14. Confirmed graphics crash and next diagnostic

The completed launch produced `crash-2026-09-27_03.56.12-client.txt`: Minecraft Window initialization threw `IllegalStateException: There is no OpenGL context current in the current thread` at GL.createCapabilities. This is later than the resolved module conflict. EGL errors 0x3009 and 0x3002 precede it. The simulation-distance warning is separate.

Backed up device config/fml.toml to logs/pico-fml-before.toml. Verified the bundled Forge ImmediateWindowHandler bytecode selects its DummyProvider when EARLY_WINDOW_CONTROL is false. Set only `earlyWindowControl = false` on the headset and restarted the launcher as a diagnostic for early-window interference. The next headset launch must establish whether this resolves context ownership; it is not yet a confirmed fix.

## 15. ADB config ownership correction

The first early-window-disabled test exited with code 1 before graphics initialization: NightConfig received AccessDeniedException saving fml.toml. ADB push created a shell-owned mode-0644 file, unlike the app-owned files nearby. Corrected fml.toml and the previously pushed instances.json to mode 0666 using adb shell chmod, verified the resulting modes, and confirmed earlyWindowControl remains false. These files contain configuration/instance metadata, not account credentials. Future device edits should preserve app ownership where possible; prefer app-side writes in the next build. The graphics diagnostic still requires another launch.

## 16. VR menu reached; recovery after disabling VR

User reported reaching the VR menu after the early-window and permission corrections. World gameplay is not yet verified. Selecting Disable VR saved `vrPlayMode: DISABLED` in config/Visor/settings.yml, making the VR menu inaccessible. Backed up the settings, stopped the app, changed only that value to ENABLED (the source default), ensured write permissions, pulled back to verify, and reopened the launcher. Preserve all calibration and other settings. Launch the Forge instance again to enter VR.

## 17. Launcher alpha.3 addon validation fix

The modded copy was blocked before Java launch: the alpha.2 preflight counted `modId="visor"` in dependency tables as extra Visor installations. ForgeMods now checks mod IDs only within [[mods]] sections, excluding [[dependencies.*]] entries. A regression fixture includes both Visor and Vivecraft dependency declarations; actual duplicate Visor mods and actual Vivecraft mods remain rejected. All 17 checks passed. Alpha.3 updates the launcher and includes the prior classpath fixes, while retaining the unchanged Visor alpha.2 JAR. Device installation and a modded launch remain to be verified.

Alpha.3 completion: Pojlib release and Unity Android builds succeeded; APK signature, ARM64-only packaging, Visor JAR hash and Pico loader hash verified. Installed with adb install -r successfully; device reports versionCode=3 and versionName=0.5.0-pico-alpha.3. Launcher reopened. Next validation is the user's forge - mods launch; mod compatibility is not yet established.

## 18. Exact Visor version and manual PC comparison instance

For dependency matching, version.properties now reports release version 0.5.0 (empty stage). The artifact filename and APK retain Pico experimental alpha.4 labels to distinguish this port from upstream. Android/Pico code changes remain intact.

Added optional instance metadata `manageBundledVisor`: absent/true installs and updates bundled Pico Visor; false validates the user's mod directory without injecting the bundle. Set false only for forge - pcvisor. Moved its injected alpha.2 JAR and disabled backup into visor-backup-alpha4 outside mods; its mods directory now contains only stock PC Visor. The alpha.4 launcher is required to honor this flag. This allows a comparison, not a guarantee stock PC Visor will work on Android.

Forge remains 47.4.10. To upgrade this port, prepare the target official Forge client installation (including installer processors) in a separate staging directory, update the pinned installer checksum and profile ID in Prepare-Forge.ps1, update ForgeProfile's version/profile checks, update staging and test paths, and package its complete libraries/profile into Pojlib before rebuilding the APK. Existing instances need matching forgeRoot and regenerated Forge classpath entries; changing only the version string is invalid. Keep the working instance/runtime as a rollback. TaCZ Addon currently requests at least 47.4.20 and below 48. No Forge upgrade was applied in this change.

## 19. Package Android yourself from PowerShell

Use Unity 6000.4.10f1 with Android Build Support, SDK/NDK and OpenJDK. Close this project's Unity Editor before starting the batch build. For packaging the current prepared sources/AAR:

```powershell
Set-Location 'E:\visor-compat\visor-0.5.0-questcraft'
.\tools\Build-PicoApk.ps1
.\tools\Verify-PicoApk.ps1
```

Build-PicoApk copies sources/Pojlib/build/outputs/aar/Pojlib-release.aar into the Unity project's Assets/Plugins/Android, checks project completeness and Unity version, then invokes Unity in batch mode with `-buildTarget Android -executeMethod QuestCraftPicoForgeBuild.BuildAndroid`. The build method selects the Pico OpenXR features, ARM64 build settings and package/version, then restores editor settings. It writes the APK to outputs. It does not install it. Do not substitute the older Meta/Quest build method.

If Java/native launcher code changed, first rebuild the AAR:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
$env:ANDROID_HOME = 'C:\Users\Sukrit22\AppData\Local\Android\Sdk'
$gradle = 'C:\Users\Sukrit22\.gradle\wrapper\dists\gradle-8.10.2-all\7iv73wktx1xtkvlq19urqw1wm\gradle-8.10.2\bin\gradle.bat'
& $gradle -p sources/Pojlib assembleRelease --console=plain
if ($LASTEXITCODE -ne 0) { throw 'Pojlib build failed' }
.\tools\Build-PicoApk.ps1
.\tools\Verify-PicoApk.ps1
```

If Visor source changed, build `:visor-forge:build` in sources/Visor-0.5.0 with the same Gradle/Java 17, then run tools/Stage-PicoAssets.ps1 before rebuilding Pojlib. The staging script reads the reported 0.5.0 JAR but preserves a Pico build label on the bundled filename. For each new distributed APK increment the Android versionCode and coordinate output names in QuestCraftPicoForgeBuild.cs, Build-PicoApk.ps1 and Verify-PicoApk.ps1.

Watch progress from another PowerShell window:

```powershell
Get-Content 'E:\visor-compat\visor-0.5.0-questcraft\unity-pico-build.log' -Tail 30 -Wait
```

Ctrl+C here stops watching the log, not the separate build. Keep the original build terminal open until completion. For an interactive Unity build, open sources/QCXR-XR-Wrapper in the matching Editor; the current custom build method is CLI-driven and does not yet expose a menu item. Prefer the supplied script so the required Pico feature selection is applied consistently.

User preference: deliver verified APKs for manual installation; do not automatically install future updates.

Alpha.4 packaging completed successfully. APK signature, ARM64 packaging and bundled Visor/Pico loader hashes passed verification. Not installed, per user request. The existing alpha.3 app does not honor manageBundledVisor; install alpha.4 before launching forge - pcvisor or alpha.3 will inject the duplicate again.

## 20. Forge 47.4.20 / launcher alpha.5

1. Downloaded the official Forge 1.20.1-47.4.20 installer and checked its published SHA1: 237c5a17d941bfe793ff5780a4f330914d2c9f57.
2. Updated Prepare-Forge.ps1 and ran its client installer processors in prepared/forge/1.20.1-47.4.20. The installer reported success and the prepared patched client/profile checks passed.
3. Updated ForgeProfile's supported version/profile ID, staging paths and parser fixtures. Visor remains mod version 0.5.0 with the unchanged Pico alpha.4 artifact.
4. Added prelaunch upgradeBundledForge: install/validate the new bundled runtime, preserve non-Forge classpath entries, replace libraries under the old Forge root, update forgeRoot/mainClass, and back up instances.json before first migration. Existing runtime data and instance worlds/mods/config are retained. Each profile migrates when launched.
5. Passed 20 checks including migration removal of old libraries, preservation of unrelated paths and addition of the new classpath. Archived old APK asset directory outside assets to avoid bundling two Forge runtimes.
6. Rebuilt Pojlib and packaged launcher alpha.5 (versionCode 5). APK verification additionally checks the exact Forge profile version and every bundled runtime file against the prepared installation.

User workflow after receiving the verified APK: install as an update without uninstalling/clearing data, launch forge - mods, and inspect latest.log for Forge 47.4.20. The existing taczaddon minimum version requirement should then be satisfied; other Android/VR mod compatibility issues may still appear. PC Visor's missing Android XR handoff is unaffected by this Forge upgrade. Do not automatically install the APK: user installs manually.

To reproduce from the prepared source changes:

```powershell
Set-Location 'E:\visor-compat\visor-0.5.0-questcraft'
.\tools\Prepare-Forge.ps1
.\tools\Test-ForgePort.ps1
.\tools\Stage-PicoAssets.ps1
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
$env:ANDROID_HOME = 'C:\Users\Sukrit22\AppData\Local\Android\Sdk'
& 'C:\Users\Sukrit22\.gradle\wrapper\dists\gradle-8.10.2-all\7iv73wktx1xtkvlq19urqw1wm\gradle-8.10.2\bin\gradle.bat' -p sources/Pojlib assembleRelease --console=plain
if ($LASTEXITCODE -ne 0) { throw 'Pojlib build failed' }
.\tools\Build-PicoApk.ps1
.\tools\Verify-PicoApk.ps1
```

Alpha.5 verification completed: APK signature valid, versionCode 5, ARM64-only; 73 Forge runtime/profile files match prepared hashes, no old 47.4.10 APK assets remain, and Visor/OpenXR loader hashes match. SHA256: 80E1CB7FA64D0F3C8B3348678142C5C11D01452E0241113EE0D750BB7985B463. Not installed; runtime migration and modded launch await the user's manual update/test.

## 21. Graphics settings recovery

Alpha.5 device log confirms Forge 47.4.20 and the modded world running. Changing graphics was followed by GL error 1285 (GL_OUT_OF_MEMORY) reported before depth overlay rendering. This location is where the GL error was detected, not proof of which allocation caused it. The process remained alive at about 4.0 GiB PSS; world-save completion was logged before recovery.

Backed up forge - mods/options.txt and Visor/settings.yml locally under logs/graphics-*. Stopped the stuck app, changed only graphicsMode 1->0 (Fast), renderDistance 9->4, simulationDistance 9->5 and mipmapLevels 4->0, verified the settings readback hash and writable mode, and reopened the launcher. VR remained ENABLED. User must relaunch the instance to validate recovery. No mods, worlds or calibration settings were removed.
