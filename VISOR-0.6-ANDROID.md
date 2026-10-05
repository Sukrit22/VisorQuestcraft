# Visor 0.6.0 Alpha 2 Android port

## Result

Built and package-verified: `outputs/Visor-0.6.0-alpha.2-android.1+mc1.20.1-forge.jar` (12,734,174 bytes).

SHA256: `D1A562EB67DD331104770E79C0707469F40E1C33A6A85BF3AB2E1042862B4B5E`.

Forge build, mixin-config check and access-widener validation passed. All 17 upstream shader tests passed. Archive verification confirmed the Android bridge and GLES classes, the real mod version and Minecraft target, absence of desktop native libraries, and 1,392 Visor classes compatible with Java 17. Build warnings included dependency/mixin mapping and deprecated API warnings; these checks cannot establish runtime mixin/rendering compatibility.

No headset installation or runtime test was performed for this JAR. Test in a separate instance before using a modpack or existing world. Logs: `visor-0.6-android-build.log` and `visor-0.6-android-verification.log`.

## Scope

Minecraft 1.20.1 / Forge, for the existing Quest and Pico alpha.6 APKs. This port uses upstream tag `0.6.0-alpha.2`, commit `1b4387b511d96c421da6bfd27e0cb138722773c0`, in `sources/Visor-0.6.0`. The working 0.5.0 checkout and bundled APK assets are preserved.

The upstream release is https://github.com/VisorModStudio/Visor/releases/tag/0.6.0-alpha.2 . Use the Android-adapted mod, not the stock PC JAR or an API-only JAR. The mod reports its real version, `0.6.0-alpha.2`; the Android revision belongs in the filename.

## What changed

1. Register `QuestAndroidXRBridge` on Android, forwarding the existing `QuestVLoader` JNI calls. Pojlib's native method names are unchanged. Unity must release its XR session before Visor starts one.
2. Bundle our existing Android AtumVR API/core and Android LWJGL OpenXR binding. Upstream 0.5.0 and 0.6.0-alpha.2 ship identical AtumVR snapshot-23 binaries; the Android replacements are the same libraries used by our working 0.5.0 port.
3. Carry forward Android EGL/GLES support, Android instance creation and optional Pico input bindings through those AtumVR libraries. Quest uses the shared Touch controller path. Their historical `pico` library filenames do not make them Pico-only.
4. Skip the desktop mirror on Android and allocate its unused texture at 1x1, adapting the patch to the new Minecraft rendering abstraction.
5. Use the Android OpenXR JAR in Forge packaging and omit desktop OpenXR native libraries. Keep the upstream Vulkan Java API for linkage; Android selects GLES.

No launcher JNI changes or Unity rebuild are required by these changes. Runtime success still requires headset testing. The APK continues to bundle 0.5.0 for ordinary instances.

## First run on the new Quest APK

An empty instance list is expected for a fresh install: Quest and Pico use different application IDs and private data directories. Create a Forge 1.20.1 instance using the launcher, wait for installation to finish, then select that instance and launch it. Forge creation forces Fabric default mods off and uses bundled Forge 47.4.20. Alpha.6 seeds `config/fml.toml` with `earlyWindowControl = false` when the file does not exist.

First establish that the bundled 0.5.0 reaches the VR menu/world on Quest. Reaching the Unity launcher alone does not validate Minecraft's XR handoff.

## Manual JAR test on either headset

1. Create a separate Forge 1.20.1 instance named `visor06test` in the launcher. Finish installing it. Avoid reusing the modded world/profile for the first test.
2. Fully close the launcher before changing files. Back up `instances.json` and this instance's `mods` and `config` directories.
3. In `files/instances.json`, find the object with `"instanceName": "visor06test"`. Add `"manageBundledVisor": false` in that object, with valid JSON commas. Preserve every other field. This is a Boolean, not the string `"false"`. An absent value causes the launcher to reinstall bundled 0.5.0.
4. In that object's `gameDir` directory, move all existing Visor mod JARs outside `mods`, then put the new Android 0.6 JAR in `mods`. Keep exactly one actual Visor mod. Do not install its `-api.jar` as another mod.
5. Start with no addons. Existing Visor Desktop / Visor-TaCZ versions that require exactly 0.5.0 can prevent Forge from starting. Use updated addons only when their compatibility is established; changing a declared dependency is not a compatibility fix.
6. Confirm `config/fml.toml` contains `earlyWindowControl = false`. If an existing Visor configuration disabled VR, edit `config/Visor/settings.yml` to `vrPlayMode: ENABLED` while the app is closed, or start with a fresh backed-up configuration.
7. Relaunch this instance. Check its `logs/latest.log` for version `0.6.0-alpha.2`, OpenXR initialization, and any error. Confirm the VR menu, both controllers, a new world, and a subsequent relaunch in the headset.

Quest files are under `/sdcard/Android/data/com.qcxr.qcxr.visor.forge.quest/files`; Pico files are under `/sdcard/Android/data/com.qcxr.qcxr.visor.forge.pico/files`. Use the registered `gameDir`, not a guessed folder name. ADB-pushed configuration files must remain writable by the app; shell-owned 0644 files caused AccessDenied in earlier tests. Do not copy `instances.json` between packages because its paths are absolute.

Rollback: close the app, remove the test JAR from `mods`, restore the old JAR/configuration, and restore the backed-up registration or re-enable `manageBundledVisor`. Keep the working 0.5.0 instance untouched.

## Rebuild

Use JDK 21 to run upstream's Gradle 9.7.1 build (required by its daemon configuration). Keep JDK 17 installed for the Minecraft 1.20.1 compilation toolchain; the resulting game bytecode remains Java 17:

```powershell
Set-Location E:\visor-compat\visor-0.5.0-questcraft
.\tools\Build-VisorAndroid06.ps1
```

The script builds only Forge 1.20.1, runs its packaging/mixin checks plus the core tests, then copies and verifies the resulting mod at `outputs/Visor-0.6.0-alpha.2-android.1+mc1.20.1-forge.jar`. It does not stage APK assets or install anything on a headset. It uses the portable tools under `build/java21-toolchain` and `build/gradle-toolchain` when present, otherwise JAVA_HOME and the upstream wrapper. You may pass `-JavaHome` and `-Gradle` explicitly.

The portable build used Temurin 21.0.12.1+1 (download SHA256 `f9d6e191ab098c0d416e7d588a24420a8621cd2f4720dab2459b8b7b2d2d8b4e`) and Gradle 9.7.1 (download SHA256 `acd53f1edaf02f1a8ff99879f8a34b302661a057d9b063ae9e35b552f804d20a`). Both downloads were compared with their publishers' checksums before extraction. JDK 17 is installed at `C:\Program Files\Java\jdk-17` and was used by the compilation toolchain.

To repeat archive checks without rebuilding:

```powershell
.\tools\Verify-VisorAndroid06.ps1
```
