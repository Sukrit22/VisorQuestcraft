# Learning to port QuestCraft and Visor to Minecraft 26.2

Written 2026-10-06 after inspecting this workspace and upstream sources. This is a learning and implementation guide, not a completed 26.2 port. No build or headset installation was performed for this guide. Commands for our existing 1.20.1 project reproduce its build procedure; commands for a new 26.2 checkout are starting points that still require porting and testing.

## 1. Start with the right expectations

Upstream Visor **0.6.0-alpha.3 already targets Minecraft 26.2**, with Fabric, Forge and NeoForge release artifacts. Our local `sources/Visor-0.6.0` is **0.6.0-alpha.2**, whose target list ends at 1.21.11. Start the new work from alpha.3 and bring our Android changes forward. Do not try to turn the old 1.20.1 JAR into a 26.2 JAR by editing its metadata. [Upstream target definitions](https://github.com/VisorModStudio/Visor/blob/0.6.0-alpha.3/stonecutter.properties.toml), [release](https://github.com/VisorModStudio/Visor/releases/tag/0.6.0-alpha.3).

Minecraft 26.2's official version JSON says `javaVersion.majorVersion = 25`. Its libraries use LWJGL 3.4.1. The Java runtime downloaded by our existing launcher comes from QuestCraft's latest JRE release; when checked for this guide, that release was `jre22-6.0.0` and listed `JRE-21.zip`, `JRE-22.zip` and `JRE.zip`, without a Java-25-labelled asset. This establishes a blocker in our current download path, not proof that nobody has built Android Java 25 elsewhere. [Minecraft metadata](https://piston-meta.mojang.com/v1/packages/c7868781b30aaf24be0dac894c94a34e5d6df10d/26.2.json), [QuestCraft runtime release](https://github.com/QuestCraftPlusPlus/android-openjdk-build-multiarch/releases/tag/jre22-6.0.0).

26.2 also has an experimental Vulkan renderer alongside OpenGL. Begin this port using the OpenGL backend because our current XR path supplies an EGL/OpenGL ES binding. Even that needs testing: translating Minecraft's desktop OpenGL calls to Android graphics is separate from making OpenXR work. [Minecraft release notes](https://www.minecraft.net/en-us/article/minecraft-java-edition-26-2), [Fabric's 26.2 developer notes](https://fabricmc.net/2026/06/15/262.html).

You have two projects to complete:

1. Make QuestCraft launch Minecraft 26.2 on Android with the correct runtime, libraries and loader.
2. Make Visor's 26.2 build use the headset's Android OpenXR environment.

Prove each separately before combining them. A mod compiling successfully does not prove the launcher can run its game version.

## 2. Vocabulary you will encounter

| Term | Meaning in this project |
|---|---|
| Source code | Human-readable Java, C++ and C# files you edit. |
| Compile | Convert source code to executable bytecode or machine code. |
| Gradle | The build system that downloads dependencies, compiles and packages the Java projects. |
| Gradle wrapper | A project's `gradlew.bat` and configuration; it chooses that project's Gradle version. |
| JDK | Java Development Kit on your PC: includes `java`, `javac`, `jar` and `javap`. |
| JRE/JVM | Runtime/virtual machine that executes Java. Minecraft runs in an embedded JVM on the headset. |
| JAR | Java archive. Visor and the companion bridge are Minecraft mod JARs. |
| AAR | Android library archive. Pojlib builds an AAR containing launcher code, native libraries and assets. |
| APK | Android application package. Unity packages the launcher and Pojlib into the installable APK. |
| Native library | Machine code in a `.so` file; must match Android and ARM64 on these headsets. |
| JNI | Java Native Interface: how Java calls our native C/C++ functions. |
| OpenXR | API for VR sessions, views, frame timing, tracking and controllers. |
| EGL | API for graphics displays, contexts and surfaces on Android. |
| OpenGL ES/GLES | Android's graphics API; related to desktop OpenGL but not identical. |
| LWJGL | Java bindings for graphics/native APIs, including OpenXR. |
| AtumVR | Java VR library used by Visor; we added Android platform support here. |
| Fabric Loader/Forge | Minecraft mod loaders. Each version needs a compatible loader and launch profile. |
| Fabric API | Mod API library; different from Fabric Loader. |
| Mixin | Mechanism for inserting mod behavior into Minecraft classes. Targets change between game versions. |
| Stonecutter | Visor's system for building shared source against several Minecraft versions. |
| Classpath | Ordered list of Java JARs used to load classes at runtime. |
| ABI | Binary interface: method signatures, native symbols and data layouts that components must agree on. |

You do not need to learn all Java and C++ before starting. First learn to reproduce a build, read its output, locate a named class, inspect a Git diff and identify which component owns a failure.

## 3. Understand the architecture

The runtime flow is:

```text
Unity launcher (C# UI and vendor XR setup)
    -> Pojlib (Android Java launcher)
        -> embedded Android OpenJDK JVM
            -> Minecraft + Fabric/Forge
                -> Visor
                    -> AtumVR
                        -> LWJGL OpenXR bindings
                            -> headset OpenXR runtime
```

The build flow is:

```text
Android AtumVR API/core JARs + compatible LWJGL bindings
    -> Android-adapted Visor mod JAR
        -> optional separate bridge mod JAR
            -> staged launcher assets + Pojlib AAR
                -> Unity Pico APK / Quest APK
```

An APK change is required when launcher Java/C#, native `.so` files, packaged assets or vendor XR settings change. A mod-only change can be tested by replacing the JAR in an unmanaged instance if the installed APK already supplies the required native interface and runtime. A new Java requirement or native ABI is not fixed by swapping Visor alone.

### The actual XR handover

Unity uses XR to display the launcher. Before Visor creates its own XR session, Unity must release that session:

1. Visor/AtumVR calls the Android bridge's `setupAndroid()`.
2. The bridge's Java adapter calls `QuestVLoader.setupAndroid()` through JNI.
3. `sources/Pojlib/src/main/jni/vloader.cpp` sets Pojlib's `API.gameReady` flag and waits for `API.launcherXRStopped` (currently with a roughly 10-second limit).
4. Unity's `Assets/Scripts/InstanceButton.cs` notices `gameReady`, fades the launcher, calls `StopSubsystems()` and `DeinitializeLoader()`, then sets `launcherXRStopped`.
5. The native call returns and AtumVR continues Android OpenXR initialization using the Android VM/activity and EGL handles.

That is why the handover needs cooperation from the APK and Java VR code. Setting a Visor configuration option to enable VR cannot implement this handshake.

Some C++ helper names still contain `vivecraft`. The Visor JNI entry points forward to those existing helpers. That is historical naming, not installation of the Vivecraft mod.

## 4. What Visor-Android-Bridge actually separates

**Yes: it is the separate companion for the launcher-specific Java/native connection we discussed. Its separation is partial.**

The current bridge lives in `sources/Visor-Android-Bridge`. Its responsibilities are:

- Provide the five native handles: EGL display, EGL context, EGL config, Android Java VM and Android activity.
- Invoke the native handover routine.
- Expose device model information through `QuestVLoader`.
- Register an implementation of AtumVR's `AndroidXRBridge` using `META-INF/services/...AndroidXRBridge`.
- Declare itself as a loader-visible mod using Fabric and Forge metadata.

It does **not** provide the embedded Java runtime, Unity XR shutdown code, the native `libvloader.so`, Android graphics translation, the complete Android AtumVR backend or a complete Minecraft-version port.

| Our existing path | How it obtains the bridge | What you install |
|---|---|---|
| Modified Visor 0.5.0 / Minecraft 1.20.1 | Patched AtumVR discovers the companion through Java `ServiceLoader`. | Modified Visor plus bridge 0.1.1. |
| Modified Visor 0.6.0-alpha.2 / Minecraft 1.20.1 Forge | Visor's `XrProvider` directly registers bridge classes embedded inside that Visor JAR. | That modified Visor JAR; not the 0.5 companion. |
| Planned 0.6.0-alpha.3 / Minecraft 26.2 | Choose and implement one approach while porting. | Not available from this guide. |

The current companion's metadata requires **Visor exactly 0.5.0 and Minecraft 1.20.1**. Its build helper also compiles against the old AtumVR and Forge annotation. It is not a universal addon that can be dropped beside every stock Visor version.

The inspected alpha.3 upstream AtumVR core archive does not include our `AndroidXRBridge`/`XRPlatform` service infrastructure. Installing our current companion next to that upstream release would not supply the missing consumer of that service.

### What else is changed in our modified Visor?

For the inspected local 0.6 alpha.2 build:

1. **AtumVR dependencies are replaced with our Android-adapted API/core.** They implement Android loader/instance initialization, EGL/GLES session binding and GLES swapchain-image handling.
2. **Android OpenXR Java bindings are bundled.** Forge's build uses our custom `lwjgl-openxr-quest-3.3.3.jar` instead of desktop OpenXR packaging.
3. **Visor registers the embedded bridge on Android.** See `XrProvider.java`.
4. **The desktop mirror is skipped on Android.** See `VisorScene.java`.
5. **The mirror render target is reduced to 1 x 1 on Android.** See `RenderTargetMain.java`. This does not reduce the headset eye images to 1 x 1.
6. **Pico controller profiles are handled in our AtumVR backend**, with optional runtime extension checks. Quest uses the existing Touch action path; test it separately on Quest.

Our launcher also has independent changes for Forge preparation, Fabric selection, managed/unmanaged/custom Visor, diagnostics and UI/account behavior. Those are APK features, not all edits to the Visor mod.

The cleaner long-term split is: vendor-neutral Android XR behavior in AtumVR, Minecraft-specific adaptation in Visor, launcher connection in the companion, and native/Unity implementation in the APK. Stock upstream Visor can use that arrangement only after the required backend hooks and packaging support exist upstream or are otherwise supplied compatibly.

## 5. Orient yourself in the workspace

Open `E:\visor-compat\visor-0.5.0-questcraft` in your editor. The outer release-index repository is not the source of every component; `sources` contains separate repositories/worktrees.

| Location | Open it when changing... |
|---|---|
| `sources/QCXR-XR-Wrapper` | Unity launcher screens, XR vendor settings, APK build methods. |
| `sources/Pojlib` | Android installation, instance records, Java runtime selection, launch arguments and JNI. |
| `sources/AtumVR-upgrade` | Our older Android backend, controller bindings and service interface. |
| `sources/Visor-0.5.0` | Current split 0.5 Android port. |
| `sources/Visor-0.6.0` | Current monolithic alpha.2 port, useful as a patch reference. |
| `sources/Visor-Android-Bridge` | Current separate Java adapter and metadata. |
| `build-targets/android.json` | Current APK release and vendor targets; still Minecraft 1.20.1. |
| `build-targets/visor-downloads.json` | Current fixed artifact slots, local paths/URLs and hashes. |
| `tools` | Build, staging, preparation, migration and archive checks. |
| `outputs` | Distributable APKs and selected JARs. |
| `user-logs` | Captured headset diagnostics. |

Start reading these files in this order:

1. `Pojlib/src/main/java/pojlib/API.java`: what Unity can ask the launcher to do.
2. `Pojlib/src/main/java/pojlib/InstanceHandler.java`: how a profile becomes an instance.
3. `Pojlib/src/main/java/pojlib/install/Installer.java`: downloads and installs its files.
4. `Pojlib/src/main/java/pojlib/util/JREUtils.java`: the actual JVM runtime paths and arguments.
5. Unity `Assets/Scripts/InstanceButton.cs`: handover.
6. `Pojlib/src/main/jni/vloader.cpp`: JNI/native half.
7. AtumVR `session/platform/XRPlatform.java`: Android OpenXR half.
8. Visor's `XrProvider`, `VisorScene` and `RenderTargetMain`.

Use search instead of reading every source file:

```powershell
Set-Location 'E:\visor-compat\visor-0.5.0-questcraft'
rg -n '1\.20\.1|launcherXRStopped|gameReady' sources/Pojlib/src/main/java
rg -n 'StopSubsystems|DeinitializeLoader' sources/QCXR-XR-Wrapper/Assets/Scripts
git -C sources/Visor-0.6.0 status --short
git -C sources/Visor-0.6.0 diff --ignore-space-at-eol
git -C sources/AtumVR-upgrade diff --ignore-space-at-eol
```

`git diff` shows tracked changes. `git status` also shows untracked bridge source files and local libraries; those are necessary inputs too. A patch made from `git diff` alone does not preserve them. Some directories are worktrees: copying their `.git` file alone does not make a standalone repository.

## 6. Keep the Java environments separate

| Environment | Existing 1.20.1 work | New 26.2 work |
|---|---|---|
| PC JDK running Pojlib's Android build | JDK 17 / Gradle 8.10.2 in our scripts. | Keep this initially unless launcher tooling itself needs an upgrade. |
| PC JDK running Visor's Gradle | Existing alpha.2 uses a Java-21 daemon. | Configure the new checkout explicitly; use Java 25 for the modern Fabric build path. |
| Compiler target for Visor classes | Java 17 for Minecraft 1.20.1. | Upstream's 26.2 target selects Java 25. |
| Embedded headset JVM | Our Android runtime download currently supplies Java 21/22 variants. | Must support Java 25 and Android ARM64. |
| Unity Android build tools | Unity 6000.4.10f1 with its own bundled Java/Gradle. | Keep Unity's project-matched tools initially. |

Changing Windows `JAVA_HOME` changes a host process. It does not update the headset's embedded JVM. A Windows JDK cannot be copied to the headset. A normal Linux ARM64 JDK also generally expects a different C library/runtime environment from Android; architecture alone is insufficient.

Gradle's daemon criteria can override `JAVA_HOME`. Alpha.3 currently includes `gradle/gradle-daemon-jvm.properties` with `toolchainVersion=21`; check both launcher and daemon JVMs with `gradlew --version`. For the new experimental checkout, use the supported `updateDaemonJvm --jvm-version=25` task if needed and verify again. [Gradle daemon documentation](https://docs.gradle.org/current/userguide/gradle_daemon.html), [upstream daemon criteria](https://github.com/VisorModStudio/Visor/blob/0.6.0-alpha.3/gradle/gradle-daemon-jvm.properties).

## 7. First exercise: reproduce the existing build

Do this before modifying version support. It proves your PC environment and teaches the packaging chain. These commands are for **our current 1.20.1 sources**.

Install or locate Git, PowerShell 7, JDK 17, Gradle 8.10.2, Android SDK/NDK matching Pojlib, and Unity **6000.4.10f1** with Android Build Support. Use the existing staged libraries/assets initially. The native build specifies SDK 34 and NDK 26.1.10909125.

Close this Unity project in the editor before the batch build. The existing script refuses other Unity versions.

```powershell
Set-Location 'E:\visor-compat\visor-0.5.0-questcraft'
$gradle8 = 'C:\Users\Sukrit22\.gradle\wrapper\dists\gradle-8.10.2-all\7iv73wktx1xtkvlq19urqw1wm\gradle-8.10.2\bin\gradle.bat'
Test-Path $gradle8
& 'C:\Program Files\Java\jdk-17\bin\java.exe' -version
```

Change the Gradle path if your installation differs. Then build **one headset target**:

```powershell
.\tools\Build-AndroidRelease.ps1 -Target Pico -Gradle $gradle8
```

For Quest use `-Target Quest`; for both use `-Target Both`. The combined helper stages and validates the existing artifact manifest, compiles `Pojlib-release.aar`, invokes Unity and runs APK verification. If it says the prepared Forge runtime is missing, read and run the current `tools/Prepare-Forge.ps1`, then retry. Do not use an older document's Forge pin; current `android.json` selects 1.20.1-47.4.20.

This helper packages existing Visor inputs; it does not rebuild AtumVR and Visor from source. To learn the current 0.6 mod build separately:

```powershell
.\tools\Build-VisorAndroid06.ps1
```

That script uses the portable Java/Gradle tools if present and builds **Forge 1.20.1, alpha.2**. It copies and verifies `outputs/Visor-0.6.0-alpha.2-android.1+mc1.20.1-forge.jar`. It is not a 26.2 builder.

To learn the older AtumVR build:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
& $gradle8 -p sources/AtumVR-upgrade ':atumvr-api:jar' ':atumvr-core:jar' --console=plain
if ($LASTEXITCODE -ne 0) { throw 'AtumVR build failed' }
```

Inspect `atumvr-api/build/libs` and `atumvr-core/build/libs`. The old build's version properties currently produce snapshot #14 names. Those are patch-reference artifacts for the old port, not proof of compatibility with alpha.3's snapshot #26.

For the **existing 0.5 companion only**, `tools/Build-AndroidBridge.ps1` runs `javac --release 17` with the patched AtumVR interface and a Forge compile-only annotation, then packages classes plus resources. `tools/Test-AndroidBridge.ps1` and `tools/Verify-AndroidBackend.ps1` exercise the current split arrangement. Their version assumptions need updating for a future bridge.

When a command fails, stop that stage. In PowerShell, a native program's nonzero exit status does not always stop subsequent commands automatically; check `$LASTEXITCODE` before copying or packaging its output.

**Success criterion:** you get a freshly built, verified current APK and can explain where its Visor JAR, AAR and native libraries came from. You install it yourself.

## 8. Second exercise: build upstream 26.2 Visor on the PC

Use a **new checkout**. Keep the working Android alpha.2 tree as a reference. Example commands below create a separate experimental source folder when you run them:

```powershell
Set-Location 'E:\visor-compat\visor-0.5.0-questcraft'
git clone --branch 0.6.0-alpha.3 --single-branch https://github.com/VisorModStudio/Visor.git sources/Visor-0.6.0-mc26.2
if ($LASTEXITCODE -ne 0) { throw 'Clone failed' }
git -C sources/Visor-0.6.0-mc26.2 switch -c android-mc26.2
git -C sources/Visor-0.6.0-mc26.2 rev-parse HEAD
```

Record the commit printed by the last command. A tag pins the starting point; your new branch records the port's changes.

Install a Windows JDK 25. Set its actual location here; this path is an example, not an installation performed by this guide:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-25'
& "$env:JAVA_HOME\bin\java.exe" -version
Set-Location 'E:\visor-compat\visor-0.5.0-questcraft\sources\Visor-0.6.0-mc26.2'
.\gradlew.bat --version
```

If the new project's daemon is still Java 21, configure it deliberately:

```powershell
.\gradlew.bat updateDaemonJvm --jvm-version=25
if ($LASTEXITCODE -ne 0) { throw 'Daemon configuration failed' }
.\gradlew.bat --stop
.\gradlew.bat --version
```

If configuration fails before that task runs, inspect the daemon criteria file and configure the experimental checkout to use your installed Java 25; do not change every project's Java settings. The wrapper in alpha.3 selects Gradle 9.7.1, so use that wrapper rather than our old Pojlib Gradle.

Discover the tasks first:

```powershell
.\gradlew.bat tasks --all --console=plain > tasks-26.2.txt
Select-String -Path tasks-26.2.txt -Pattern '26.2|buildAndCollect'
```

Upstream's inspected Stonecutter configuration creates these versioned tasks:

```powershell
# Choose one loader initially. These are upstream tasks, before Android edits.
.\gradlew.bat ':visor-fabric:26.2:buildAndCollect' --max-workers=2 --console=plain
if ($LASTEXITCODE -ne 0) { throw 'Fabric build failed' }

# Alternative for a Forge-specific port:
.\gradlew.bat ':visor-forge:26.2:buildAndCollect' --max-workers=2 --console=plain
if ($LASTEXITCODE -ne 0) { throw 'Forge build failed' }
```

The upstream aggregate `build-26.2` builds the available loaders/checks for that target; selecting one loader gives a smaller first experiment. Do not edit the generated `stonecutter.active` comment blindly. Use the versioned tasks or the project's generated version-switch task when editing version-conditional source.

Collected artifacts go to root `build/libs`. The runtime mod filename has `+mc26.2-fabric.jar` or `+mc26.2-forge.jar`. **Do not install the `-api.jar` as the runtime mod.** Test the unmodified upstream mod in a clean PC instance of that same Minecraft/loader version. A PC test isolates upstream game-version problems from your Android changes.

Minecraft became unobfuscated starting with 26.1, so the older Fabric remapping procedure is not applicable unchanged. Alpha.3 already selects Architectury's no-remap Loom path for these targets. Keep its build logic intact rather than transplanting alpha.2's whole build file. [Fabric migration notes](https://fabricmc.net/2026/03/14/261.html), [Visor's version-aware build logic](https://github.com/VisorModStudio/Visor/blob/0.6.0-alpha.3/buildSrc/src/main/groovy/visor.minecraft.gradle).

**Success criterion:** upstream Visor for 26.2 builds and starts on PC before any Android port changes. This guide has not run that build.

## 9. Add Minecraft 26.2 to the launcher

### 9.1 A version dropdown is the last visible part of support

Our current backend is intentionally restricted to 1.20.1. These restrictions prevent installing combinations we have not supported. Replace them with explicit supported-target definitions once each new target has a working runtime.

| File | Current restriction or assumption to address |
|---|---|
| `Pojlib/.../API.java` | `getSupportedVersions()` returns only 1.20.1; Fabric loader change API also checks it. |
| `Pojlib/.../InstanceHandler.java` | Fabric and Forge creation reject other Minecraft versions. |
| `Pojlib/.../install/FabricLoaderProfile.java` | Profile fetch/validation is restricted to 1.20.1. |
| `Pojlib/.../install/Installer.java` | One JRE path/download and managed mods restricted to 1.20.1. |
| `Pojlib/.../install/VersionInfo.java` | Current model does not expose Mojang's `javaVersion` field. |
| `Pojlib/.../util/JREUtils.java` | Native launch paths, `JAVA_HOME`, `java.home` and library paths point to `runtimes/JRE`. |
| `Pojlib/.../install/ForgeProfile.java` | Pinned old Forge schema/main class; rejects conditional libraries/arguments. |
| `Pojlib/.../install/VisorRuntime.java` | Fixed JAR names; 0.6 is currently Forge-only. |
| `Pojlib/.../install/CustomVisor.java` | Old MC/version/architecture validators. |
| Unity `Assets/Scripts/InstanceManager.cs` | Creation UI rejects a selected version other than 1.20.1. |
| `Pojlib/supportedVersions.json` | Older list; merely editing this file will not override the Java API and other guards. |
| `build-targets` and staging/verifier tools | Fixed artifact set and 1.20.1 prepared Forge runtime. |

Do not globally replace `1.20.1` with `26.2`: that would also change working targets and checks that should remain version-specific.

### 9.2 Model each supported combination

A useful design is to describe a supported combination with:

```text
Minecraft version
loader type + loader version
required Java major + Android runtime identifier
renderer/native-library set
Visor artifact + bridge mode + compatibility identifier
download locations + integrity hashes
experimental/validated status for Pico and Quest
```

This is a suggested design, not a schema our current launcher already implements. Pass the chosen target through UI -> instance creation -> installer -> JVM launch. Keep old instance records readable; a missing new field should resolve to the old target's defaults, not silently upgrade worlds or mods.

Treat Minecraft's version identifier as an exact string from Mojang's manifest. `26.2` is valid despite having two numeric components. Do not assume every version is `1.x.y`, and do not compare strings lexicographically to select Java requirements. Use `javaVersion` metadata or an explicit target table.

### 9.3 Supply and prove Android Java 25

This is native runtime work, not a Minecraft-mod setting:

1. Find a maintained Android/Bionic ARM64 Java 25 build, or port the Android OpenJDK build project. Begin at [QuestCraft's runtime source](https://github.com/QuestCraftPlusPlus/android-openjdk-build-multiarch). Its current Java-21/22 work is a reference, not a ready-made Java-25 build recipe.
2. Inspect its source revision, build scripts, Android patches, architecture and native dependencies. If building yourself, follow that project's host/container requirements; compiling Visor with a Windows JDK does not build Android OpenJDK.
3. Validate the runtime's `release` metadata and native libraries, then actually start its JVM in the launcher and log `java.version`, `java.vendor`, `os.arch` and `Runtime.version()`.
4. Exercise Pojlib's native invocation and AWT/graphics helpers. Loading `libjvm.so` alone is insufficient.
5. Add a versioned runtime directory such as `runtimes/java-25` alongside the existing runtime. This path is a design example. Change installation and **every** launch/library-path reference consistently.
6. Fail before launching if the selected runtime cannot execute the target game. File-existence checks alone do not validate its Java version.

Java 25 class files have major version 69; Java 22 supports up to 66 and Java 17 up to 61. An `UnsupportedClassVersionError` is a runtime mismatch. Increasing RAM or editing the mod metadata cannot fix it.

**Gate:** stop the 26.2 Android experiment here until an Android Java-25-capable runtime actually starts.

### 9.4 Install vanilla 26.2 correctly

Fetch Mojang's official manifest and selected version JSON. Preserve its client/assets/libraries URLs and verify their hashes. Our `MinecraftMeta` currently finds versions by exact ID, but the `VersionInfo` model and installer need review for modern argument/library rules.

Audit the final classpath. Desktop native classifiers cannot be executed on Android. Yet removing all new LWJGL libraries is not correct either: 26.2 uses Java bindings/native components beyond our old 1.20.1 library set. Supply compatible Android replacements for required modules and honor the game profile's arguments/rules.

Launch a fresh test instance with **no Visor and no extra mods**, using the OpenGL backend. For development this may need a deliberate launcher test path because managed VR instances install Visor automatically. Unmanaged mode means the launcher does not manage Visor; it is not a promise that vanilla 26.2 already works.

**Success criterion:** Minecraft 26.2 renders its menu and a small world on Android. If it fails before that, fix the runtime/graphics/launch layer before adding VR.

### 9.5 Add one mod loader

Fabric is my suggested first experiment because our launcher already fetches Fabric launch profiles dynamically. This reduces prepared-Forge-runtime work; it does not prove Fabric will be more compatible with the headset.

Alpha.3's 26.2 target pins Fabric Loader 0.19.5, Fabric API 0.161.0, Forge 65.1.3 and LWJGL 3.4.1. Use a consistent set from the chosen upstream tag rather than mixing the earlier 1.20.1 defaults. These are that tag's pins, not claims about the newest release of each dependency. [Target configuration](https://github.com/VisorModStudio/Visor/blob/0.6.0-alpha.3/stonecutter.properties.toml).

For Fabric:

1. Generalize the profile fetch to the selected Minecraft version and loader.
2. Validate that the returned profile matches **both** selections.
3. Download/check its required libraries and preserve its launch class/arguments.
4. Update the API for changing Fabric Loader on existing instances.
5. Keep old instances' selected loader version; use a per-target default for new instances.
6. Start an empty Fabric 26.2 instance before adding Visor.

For Forge:

1. Prepare the official **26.2 Forge** client installation on the PC.
2. Inspect its generated version JSON and processor outputs.
3. Generalize `Prepare-Forge.ps1`, asset layout and `ForgeProfile.java` for that exact profile/schema. Existing restrictions on rules and main classes need explicit review.
4. Stage the complete required runtime and hashes, not just a renamed old Forge JAR.
5. Preserve library ordering and expand placeholders to Android paths.
6. Start an empty Forge 26.2 instance before adding Visor.

Forge 47.4.20 belongs to Minecraft 1.20.1. It is not a loader choice for Minecraft 26.2. Treat Forge as a separate integration milestone even if Fabric already works.

## 10. Port Visor's Android support to the new source

### 10.1 Use compatible AtumVR source, not our old binary wholesale

Alpha.3 bundles AtumVR snapshot #26. Our Android backend is older. Locate the corresponding upstream AtumVR source revision/version before applying the Android patches. [AtumVR source](https://github.com/Phoenix-Ra/AtumVR).

Use the old port as a semantic reference:

- `session/platform/AndroidXRBridge.java`: launcher-supplied interface.
- `session/platform/XRPlatform.java`: desktop/Android platform selection, Android loader initialization, activity/VM chain and EGL/GLES binding.
- `session/XRInstance.java`: extension selection and Android instance/session setup.
- `session/XRSwapChain.java`: check platform-specific image handling and allocation.
- `input/XRInputHandler.java` and API interaction profile enum: optional Pico bindings.

Compare new method signatures, frame lifecycle and resource ownership. Bring the *behavior* forward into the new API. Replacing snapshot #26 with the older Android JAR may compile partly and still produce `NoSuchMethodError` or incorrect lifecycle behavior.

Build the new Android API/core and point the new Visor checkout's local dependency configuration to them. The old AtumVR module tasks illustrate the build shape, but inspect the matching revision's tasks/toolchain before running it. Assign a distinct artifact identifier/version so desktop and Android JARs cannot be confused.

### 10.2 Choose bridge architecture deliberately

For fastest initial debugging, an embedded bridge is a smaller migration: adapt the existing alpha.2 `QuestAndroidXRBridge`/`QuestVLoader` and explicit registration to the new backend.

For the separation you requested, carry forward the `ServiceLoader` interface/discovery into the new backend and publish a matching companion:

1. Backend defines the interface and discovers exactly one provider on Android.
2. Companion implements it in **`org.vmstudio.visor.android`**.
3. Companion contains the correct service registration and loader metadata.
4. Visor no longer embeds another provider or directly constructs its old bridge.
5. APK retains native JNI exports matching the companion's package/class/method signatures.
6. Define and check an explicit bridge/backend compatibility version.

Keep launcher bridge classes out of Visor's existing package tree. We previously corrected a Forge module split-package conflict by moving the companion to its own package. Do not shade another copy of AtumVR or LWJGL into the companion.

The new companion needs metadata for the actual Visor/game target, plus an updated build procedure. Merely broadening its version range hides compatibility failures; it does not establish compatibility.

### 10.3 Port the mirror changes to the current renderer

Locate the equivalents of `VisorScene.java` and `RenderTargetMain.java` in alpha.3's 26.2 path. Keep the Android condition around desktop-only mirror rendering. Apply the small mirror-target optimization where that target still exists and has the same purpose.

Minecraft's render interfaces and Visor's version-specific code have changed. Read the new frame/render path before copying a framebuffer patch. Preserve both stereo eye targets, depth images, frame submission and UI rendering. Do not make every render target 1 x 1.

Use Stonecutter conditions or the existing version-specific layout when an edit is valid only for certain Minecraft versions. Keep vendor selection separate from game-version selection.

### 10.4 Update LWJGL/OpenXR packaging

Our old binding JAR is 3.3.3; the new game uses 3.4.1. Do not assume the old replacement can stand in for the new API/native set. Inspect required Android extension classes/functions, their JNI/native implementation and their compatible library versions.

The upstream Fabric module currently includes desktop OpenXR Java/native artifacts. The old Android adaptation changed Forge packaging only. For a new Fabric port, adapt **Fabric packaging too**, retaining its current no-remap/nested-JAR pipeline. Review Forge separately rather than copying Fabric's packaging configuration into it.

The final package needs:

- One coherent set of required LWJGL Java classes and compatible Android native implementations.
- Android OpenXR loader initialization/instance creation and GLES graphics binding classes.
- No desktop Windows/Linux native artifacts selected for the Android runtime path.
- The intended vendor loader from the APK, without a conflicting second process-wide loader.
- No duplicate Visor, AtumVR, LWJGL or bridge providers on the runtime classpath.

The LWJGL desktop dependency alone does not generate every Android extension binding or a working headset native library. Inspect upstream binding generation/native source and the fork's inputs if regeneration is needed. This is an engineering stage with ABI validation, not just a Gradle dependency rename.

### 10.5 Build and inspect the Android JAR

After completing those edits in the new checkout, use its versioned build task again. A successful Java build is only the first check.

```powershell
.\gradlew.bat ':visor-fabric:26.2:buildAndCollect' --max-workers=2 --console=plain
if ($LASTEXITCODE -ne 0) { throw 'Android Visor build failed' }
```

Inspect the **collected runtime artifact**, including nested dependency JARs:

```powershell
$jar26 = '.\build\libs\Visor-0.6.0-alpha.3+mc26.2-fabric.jar'
& "$env:JAVA_HOME\bin\jar.exe" tf $jar26 > jar-contents-26.2.txt
Select-String jar-contents-26.2.txt -Pattern 'Android|openxr|META-INF/jars|fabric.mod.json'
Get-FileHash -LiteralPath $jar26 -Algorithm SHA256
```

Listing the outer JAR alone may not show classes packaged inside nested dependencies. Inspect those too. Validate metadata/version, Android backend classes, bridge architecture, native artifacts, required APIs and the absence of unwanted desktop natives. Java-25-targeted classes should report major version 69 when inspected with `javap -verbose`; libraries may legitimately target an older Java version.

Our existing `Verify-VisorAndroid06.ps1` checks alpha.2/1.20.1/Java-17 assumptions. Write or adapt verification for the new target; do not disable its failures and assume the archive is sound.

## 11. Integrate artifacts into the launcher and package Android

For early development, choose a supported **unmanaged** 26.2 test instance once launcher support exists. Put your correctly matched modified Visor and, for the split design, its matching bridge into `mods`. This isolates mod iteration from bundled-asset updates. An existing alpha.13 APK cannot create a supported 26.2 target just because you add the JAR manually.

For managed installation:

1. Extend the artifact manifest/installer to distinguish Minecraft version, loader, Visor version and bridge mode. Current manifest slots are fixed to the old targets.
2. Validate metadata against the selected instance instead of exact old strings.
3. Stage the new assets only after archive validation passes.
4. Retire old **managed** JARs safely when changing the selected runtime; preserve user mods/config/worlds.
5. Support custom URLs only when their artifact passes the same target/architecture checks. URL support is a delivery method, not Android compatibility.
6. Update the APK verifier to check both old and new runtime/asset sets and native exports.

The packaging sequence remains:

```text
modified AtumVR -> modified Visor -> matching companion if split
-> validate/stage assets -> Pojlib assembleRelease
-> Unity target build -> APK verification -> manual installation
```

Build Pojlib with its configured host JDK/Gradle, not whichever JDK was last used for Visor:

```powershell
# After target-aware staging has been implemented and validated:
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
& $gradle8 -p sources/Pojlib assembleRelease --console=plain
if ($LASTEXITCODE -ne 0) { throw 'Pojlib build failed' }
```

The current `Build-AndroidRelease.ps1` and verification helpers are useful packaging references, but they still stage the fixed 1.20.1 artifact set. Update their target assumptions before using them to claim a 26.2 release.

Unity's CLI shape is:

```powershell
# Example invocation after your target configuration/build methods are ready.
$unityEditor = 'E:\Unity\Hub\Editor\6000.4.10f1\Editor\Unity.exe'
& $unityEditor -batchmode -nographics -quit `
  -projectPath 'E:\visor-compat\visor-0.5.0-questcraft\sources\QCXR-XR-Wrapper' `
  -buildTarget Android `
  -executeMethod QuestCraftAndroidBuild.BuildPico `
  -logFile 'E:\visor-compat\visor-0.5.0-questcraft\unity-pico-26.2-build.log'
```

Use the wrapper scripts for the normal build because they copy/check the AAR, validate inputs, lock shared staging and check output freshness. The direct CLI is shown so you understand what the wrapper invokes; it is not a replacement for staging.

Pico and Quest use the same launcher/game/Android backend source, with vendor XR feature/loader selection during packaging. Build them sequentially when they share staged project files. Shared failures get a shared fix; Pico controller-profile/loader changes stay behind Pico/runtime capability checks; Quest-specific features stay in the Quest target. Validate both after a shared graphics/handover change.

## 12. Test in increasing complexity

| Gate | Evidence needed before advancing |
|---|---|
| Existing baseline | Current sources build and package with known toolchains. |
| Upstream PC | Unmodified Visor 26.2 starts with matching desktop loader. |
| Android JVM | Actual in-app Java version meets 25; native helpers load. |
| Android vanilla | 26.2 menu and small world render without VR/mods. |
| Android loader | Empty Fabric/Forge target starts with correct profile. |
| XR handover | Unity releases XR before Visor creates its instance/session. |
| VR menu | Stereo menu and headset tracking work without extra mods. |
| VR world/input | Small world, both controllers, movement, buttons and frame pacing work. |
| Lifecycle | Pause/resume, headset sleep and normal exit behave correctly. |
| Both vendors | Pico and Quest runtime/input paths tested independently. |
| Modpack/network | Add mods one at a time; then test multiplayer with compatible endpoints. |

Use a fresh test world/instance. Do not use an existing modpack as the first proof of a new runtime and renderer. Keep the working APK/instance available for comparison.

Record PC source commits, toolchain versions, final JAR/APK hashes, headset model/OS, Java version, loader version, renderer and exact reproduction steps. An APK filename alone cannot establish which staged JAR it contains.

## 13. Read failures by their owning layer

| First meaningful error | Investigate |
|---|---|
| `UnsupportedClassVersionError`, version 69 | Headset JVM too old or incorrect compiler target. |
| `UnsatisfiedLinkError` / missing JNI symbol | Native `.so` packaging, class/package name and JNI signature mismatch. |
| ELF wrong architecture / missing native dependency | Android ARM64/Bionic compatibility and native dependency search paths. |
| `NoSuchMethodError` in AtumVR/LWJGL | Dependency ABI mismatch or duplicate old JARs. |
| No Android bridge / multiple bridge providers | Missing service registration, classloader discovery or duplicate providers. |
| Forge split-package/module error | Companion sharing Visor's package or duplicate libraries. |
| Mixin target/injection failure | Minecraft-version mismatch, obsolete method target or wrong packaged build pipeline. |
| `xrCreateInstance` resource/session limit | Unity XR release sequence and selected runtime/loader. |
| XR graphics binding/session error | EGL handles, GLES requirements, graphics context ownership and thread. |
| OpenGL missing function/shader/FBO error | Android graphics translation and 26.2 renderer requirements. |
| OpenGL out of memory / native abort | GPU/native memory, settings and native crash trace; not just Java heap. |
| `java exit code: 1` | Earlier exception in the same launch. Exit code is the outcome, not the cause. |

Capture a complete launch. If ADB is available:

```powershell
adb logcat -c
# Launch manually on the headset and reproduce once.
adb logcat -d -v threadtime > headset-26.2-logcat.txt
```

Also export the launcher's diagnostic bundle and the instance's Minecraft `latest.log`. Full logcat retains native/runtime context that Unity-only filters can omit. Check the timestamps match the latest attempt.

## 14. A practical learning order

1. Rebuild one current APK. Learn what each output contains.
2. Read and trace the handover flags through Java, JNI and Unity.
3. Build stock alpha.3 for 26.2 on PC using its versioned task.
4. Resolve Android Java 25 and vanilla 26.2 graphics before VR.
5. Generalize one loader/version path and prove an empty instance.
6. Port the Android backend to the matching AtumVR revision.
7. Bring forward Visor's Android registration, mirror and packaging changes.
8. Choose embedded bridge first or implement the separate companion deliberately.
9. Test unmanaged VR artifacts, then add managed/custom delivery.
10. Package/test both headset targets and document their actual results.

At the end of each stage, write down what you proved and the next unanswered question. This prevents a successful compile, a visible launcher or a configuration flag from being mistaken for working Minecraft VR.

## Source references and existing local documents

- [Visor alpha.3 source/release](https://github.com/VisorModStudio/Visor/releases/tag/0.6.0-alpha.3)
- [Visor target/dependency configuration](https://github.com/VisorModStudio/Visor/blob/0.6.0-alpha.3/stonecutter.properties.toml)
- [Version-aware Visor build conventions](https://github.com/VisorModStudio/Visor/blob/0.6.0-alpha.3/buildSrc/src/main/groovy/visor.minecraft.gradle)
- [Minecraft 26.2 release notes](https://www.minecraft.net/en-us/article/minecraft-java-edition-26-2)
- [Official 26.2 client metadata](https://piston-meta.mojang.com/v1/packages/c7868781b30aaf24be0dac894c94a34e5d6df10d/26.2.json)
- [Fabric 26.1 migration notes](https://fabricmc.net/2026/03/14/261.html)
- [Fabric 26.2 developer notes](https://fabricmc.net/2026/06/15/262.html)
- [AtumVR source](https://github.com/Phoenix-Ra/AtumVR)
- [QuestCraft Android OpenJDK source](https://github.com/QuestCraftPlusPlus/android-openjdk-build-multiarch)
- [Gradle daemon/toolchain configuration](https://docs.gradle.org/current/userguide/gradle_daemon.html)
- Local `FABRIC-AND-ANDROID-BACKEND.md`: current 0.5 split-backend procedure.
- Local `VISOR-0.6-ANDROID.md`: current alpha.2 Forge/1.20.1 adaptation.
- Local `HEADSET-BUILDS.md` and `FABRIC-LOADER-ALPHA13.md`: vendor packaging and current launcher behavior.
- Local `BUILD-AND-DEBUG.md`: historical first-port walkthrough; some release pins and packaging details predate the current split/backend and alpha.13 setup.
