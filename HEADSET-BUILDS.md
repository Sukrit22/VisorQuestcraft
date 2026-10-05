# Shared Android port, separate headset packages

Current release: alpha.13 adds [per-instance Fabric Loader selection](FABRIC-LOADER-ALPHA13.md). Alpha.12 added [managed/manual/custom Visor selection](VISOR-RUNTIME-ALPHA12.md). Alpha.11 fixed the [Forge bridge package conflict](PICO-FORGE-BRIDGE-ALPHA11.md). Alpha.10 fixed [Quest launcher runtime dependency packaging](QUEST-STARTUP-ALPHA10.md). Alpha.9 added [local diagnostics save/share](LOCAL-DIAGNOSTICS-ALPHA9.md). Alpha.8 added [launcher login and Demo-mode fixes](LAUNCHER-LOGIN-ALPHA8.md) on top of alpha.7 Fabric/Forge and Android backend support.

## Decision

Hardware baseline (user report, 2026-10-03): Pico alpha.5 worked. Our Quest build is not yet confirmed working on hardware; Coah's Quest build reportedly works sometimes. Build/package checks below do not replace these hardware results.

On 2026-10-04 the user reported Forge and Fabric launching into Visor with alpha.12. The new alpha.13 Fabric Loader migration and modded gameplay require separate headset validation. New Fabric instances default to Loader 0.17.2; older instances preserve their installed version until explicitly changed.

Maintain one Visor source tree, one AtumVR source tree, one Pojlib source tree and one Unity project. Do not maintain long-lived Pico and Quest source branches or duplicate the app. Android is the OS on both; the headset runtimes, Unity XR features and native loaders differ.

Alpha.7 supports Forge 47.4.20 and Fabric Loader 0.16.14 on Minecraft 1.20.1. Both headset APKs share the same loader-specific Visor 0.5.0 Android JARs, Android Bridge 0.1.0 companion and Pojlib AAR. Pico interaction bindings remain capability-gated. See [Fabric and backend workflow](FABRIC-AND-ANDROID-BACKEND.md) for the upstream prototype, migration and reproducible build steps.

Alpha.11 upgrades the shared companion to 0.1.1 and the native bridge together. Shared changes affect both targets. Headset profile changes are intended to affect only their target, but dependency/plugin filtering can cross that boundary: alpha.10 fixed a shared Gson dependency previously supplied accidentally by the Pico SDK. Verify both APKs after changes to shared packaging and run both hardware smoke tests before calling a release working.

## Ownership

| Problem | Edit | Validation |
|---|---|---|
| Forge install/version migration, mod validation, JVM arguments, graphics handoff | sources/Pojlib | Java checks; package both; runtime tests on both |
| Visor pose/network/rendering bug | sources/Visor-0.5.0 | common tests and two-headset runtime checks |
| Shared Android OpenXR or EGL behavior | sources/AtumVR-upgrade and Pojlib native bridge | both runtimes |
| Pico-specific Unity support/controller features | Assets/Editor/Headsets/PicoBuildProfile.cs | Pico build and hardware |
| Quest-specific Unity support/controller features | Assets/Editor/Headsets/QuestBuildProfile.cs | Quest build and hardware |
| Target identity/release version | build-targets/android.json | target APK manifest/version verification |
| Packaging, native plugin exclusion, restoration | Assets/Editor/QuestCraftAndroidBuild.cs | both builds in sequence; loader/manifest checks |

Runtime vendor fixes should be capability-gated in the shared runtime where possible (for example XR_BD_controller_interaction). Do not branch general gameplay/networking on a headset name. If a workaround needs vendor detection, keep the predicate and workaround together and record the device/runtime evidence.

## Targets

- Pico: com.qcxr.qcxr.visor.forge.pico; Pico OpenXR feature and loader; Pico 4/Ultra controller profiles.
- Quest: com.qcxr.qcxr.visor.forge.quest; Unity Meta Quest Support, Unity's default Android OpenXR loader, Oculus Touch and Touch Plus profiles. First hardware validation target is Quest 3. Hand-tracking-only play is not promised by this initial target.

Distinct app IDs isolate data. Installing Quest alpha.6 will NOT automatically migrate data from the earlier Pico APK someone sideloaded onto a Quest. Keep old app data until manually migrated and verified. Do not blindly copy instances.json between packages: it contains absolute application paths.

The build method filters opposite-vendor manifest entries and disables all Pico native/platform/enterprise plugins for Quest. It restores feature flags, plugin compatibility, manifest bytes and player settings in finally. The CLI takes an exclusive build lock; run targets sequentially in this Unity project. A hard process kill can bypass finally; inspect/recover editor settings before building after interruption.

## Build and verify

Use Unity 6000.4.10f1. Close the project in the editor for CLI builds. Starting in E:\visor-compat\visor-0.5.0-questcraft:

```powershell
.\tools\Build-AndroidApk.ps1 -Target Quest
.\tools\Verify-AndroidApk.ps1 -Target Quest
.\tools\Build-AndroidApk.ps1 -Target Pico
.\tools\Verify-AndroidApk.ps1 -Target Pico
```

Existing Build-PicoApk/Verify-PicoApk scripts delegate to the shared tools; Quest wrappers are provided too. For the editor UI, open sources/QCXR-XR-Wrapper and use QuestCraft > Build > Quest APK or Pico APK. Rebuild/copy Pojlib-release.aar first when launcher Java/native code changes; the CLI copies it automatically. Visor/AtumVR changes require rebuilding their JARs and running Stage-PicoAssets.ps1 (legacy script name) before Pojlib.

The target config controls both C# packaging and PowerShell verification. Each successful build writes .apk.build.json with feature selection; CLI adds shared AAR and config SHA256 hashes. Verification checks app ID/version, ARM64, target manifest, XR features, actual loader hash, shared Visor/Forge file hashes, and absence of opposite-vendor native libraries. It never installs the APK.

## Bug workflow

1. Record APK target/version, headset model/OS/runtime, instance mod list, actions and logs.
2. Classify from evidence: shared, Pico-specific, Quest-specific, or unknown. Unknown is not automatically vendor-specific.
3. Make one common source fix or a narrowly scoped target/runtime fix. Add an explanatory comment for vendor workarounds.
4. For shared changes, build both APKs from the same shared artifacts. For vendor changes, also package-check the other target for contamination; hardware retesting scope depends on what changed.
5. Test launcher/permissions/controllers, initial install, Unity-to-Minecraft XR handoff, menu/world, graphics reload, sleep/resume and second launch. Multiplayer pose tests require client and server logs.
6. Keep build verification separate from device validation. A compiled Quest APK is experimental until tested on Quest hardware.

## First Quest test

Install the Quest-labelled APK yourself. Start with controllers awake, default automatic RAM, no extra mods and a fresh Forge instance. Verify launcher before Minecraft. Fresh Forge instances now seed earlyWindowControl=false, the shared graphics-context workaround already validated on Pico. Existing fml.toml is preserved.

If black screen occurs, record full logcat locally and app memory before force-closing; do not infer microphone permission or RAM is the cause from video timing. Redact tokens/account information before sharing logs. The correct package for log/memory commands is com.qcxr.qcxr.visor.forge.quest. No runtime testing on a connected Pico can validate Quest behavior.

## Alpha.6 implementation notes

The release configuration is build-targets/android.json. Shared packaging is Assets/Editor/QuestCraftAndroidBuild.cs; target controller/features are in Assets/Editor/Headsets. QuestCraftManifestPolicy runs after SDK manifest callbacks (including Pico Platform's unconditional metadata insertion), strips opposite-vendor entries and declares Quest 3 (`eureka`) explicitly. The first Quest build was rejected by this validation before delivery; the corrected build passed.

Quest alpha.6 was built and package-verified on 30 September 2026: signature, ARM64, Quest app ID/version, Meta Quest feature selection, no Pico native libraries/metadata, Unity default Android OpenXR loader hash, and 74 shared Visor/Forge file hashes. A matching Pico build is also produced to validate switching targets from the same workspace. Hardware validation is separate and remains pending for Quest 3. The initial target intentionally does not advertise other Quest models as tested/supported.
