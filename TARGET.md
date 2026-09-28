# Visor 0.5.0 Forge on Pico 4 Ultra — experimental port

Target: Minecraft 1.20.1, Forge 47.4.10, Visor 0.5.0-pico-alpha.1, Pico 4 Ultra standalone.

## Current status

- Upstream Visor 0.5.0 ported to the fork's Android OpenXR bridge and built as a Forge JAR.
- AtumVR upgraded and built with Android OpenGL ES integration.
- Pojlib implements a prepared Forge installation, Forge launch arguments, bundled Visor installation, and loader-aware mod handling.
- Forge instances bypass the upstream Fabric/Vivecraft mod manifest. Preflight rejects Vivecraft, duplicate Visor, and Fabric-only JARs.
- Unity launcher offers Forge by default and filters individual mod searches by loader. Forge modpack import is intentionally unavailable in this prototype.
- Pojlib ARM64 release AAR built successfully, with the Forge runtime and new Visor embedded.
- Fourteen Forge parser/mod preflight checks pass. These are host-side checks, not Minecraft or headset runtime tests.
- Unity 6000.4.10f1 and Android support verified; batch-mode licence probe passed.
- Alpha.1 APK built and was installed on Pico. Device logs revealed a null-classpath crash in the accidentally selected incomplete Fabric instance and a launcher dropdown bug that hid saved Forge instances. Alpha.2 fixes those paths and is being built; successful Minecraft/VR operation is not yet verified. See BUILD-AND-DEBUG.md for the complete procedure.

## Sources

The workspace root is coah80/questcraft-visor-releases, a release index.

- sources/Visor: coah80/Visor Android fork baseline 32c80265594ae76f7f420cc69001c077a9283009.
- sources/Visor-0.5.0: worktree based on VisorModStudio/Visor tag 0.5.0 (3d56cd0a), branch codex/visor-0.5.0-android.
- sources/AtumVR-upgrade: upstream AtumVR master f0aeed50acb5c83f5143a89aed5b8a0327b9935c with the Android bridge adapted from coah80/AtumVR.
- sources/Pojlib: coah80/Pojlib QuestCraft-6.0.0, baseline 2b211783ff6bb3419ab1f519f17d4d8afa4ef957.
- sources/QCXR-XR-Wrapper: coah80/QCXR-XR-Wrapper, baseline c9d110bab8a24801351107a220802befbf43428c.

## Build inputs and tools

Use Java 17 and Unity 6000.4.10f1. The other installed Unity version is not used.

1. Build the upgraded AtumVR API/core JARs and copy them to Visor-0.5.0/libs as atumvr-api-pico.jar and atumvr-core-pico.jar.
2. Build Visor-0.5.0 with :visor-forge:build.
3. Run tools/Prepare-Forge.ps1. This runs the official pinned Forge installer in an isolated directory, including its client patch processors.
4. Run tools/Test-ForgePort.ps1 and tools/Stage-PicoAssets.ps1.
5. Build sources/Pojlib with assembleRelease, then copy build/outputs/aar/Pojlib-release.aar into sources/QCXR-XR-Wrapper/Assets/Plugins/Android/.
6. Build the Unity project for Android using QuestCraftPicoForgeBuild.BuildAndroid.

The intended APK uses application ID com.qcxr.qcxr.visor.forge.pico and a development signing key. It is an experimental separate app. The Pico build helper enables Pico support and Pico 4/Ultra controller profiles and selects OpenGL ES 3.

## Device validation still required

Test Microsoft login, creation of a new Forge 1.20.1 instance, first launch, Visor activation, stereo rendering, both controllers, a local world, and a second launch. Confirm that only Visor remains installed and no Vivecraft appears. Add other Forge 1.20.1 mods only after the base game works; Android native libraries, graphics assumptions, and headset memory can prevent otherwise valid desktop mods from working.

Build logs are at the workspace root. The existing visor-compat-tacz project is separate and is not modified by this port.

## Pico-specific build corrections

The fork omitted the loader declared by its Pico feature. Restored Runtime/Android/arm64/libopenxr_loader.so and its importer metadata from Pico-Developer/PICO-Unity-OpenXR-SDK commit 96efdded84cb6f6f03527effdd99f1930dee486b (release_1.3.0). The Git blob hashes are 525fac1c6842f3caac91e11190bc3b132c6f18d3 and ed446e91339eefd8bb7d6e33b2274144ed7b81b1. Pojlib excludes its second OpenXR loader from its AAR so the process uses the loader selected by Unity's Pico feature.

Quoted 36 malformed inline assembly-name strings in the upstream Main.unity scene so Unity can parse its text callbacks. Added XR_BD_controller_interaction to the Android extension requests and Pico 4/pico4s binding suggestions, using the existing Touch logical action layout. Unsupported capacitive inputs are filtered by runtime binding validation. Device testing must verify these controls.

Use tools/Build-PicoApk.ps1 for the Unity build and tools/Verify-PicoApk.ps1 for signature and packaged-component verification.
