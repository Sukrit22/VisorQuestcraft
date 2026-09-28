# Release source and failed profile comparison

Checked the GitHub release API for coah80/questcraft-visor-releases v1.1.1. Its only uploaded asset is QuestCraft-VISOR-1.1.1.apk. The release tag points at e8494e4; the Git tree contains only README.md. GitHub's generated source ZIP/TAR therefore does not contain the application implementation. README links to coah80/Visor, Pojlib, QCXR-XR-Wrapper and AtumVR. Release notes identify QuestCraft 6.0.1 rc4 as the base; the Pojlib source branch is named QuestCraft-6.0.0, which alone is not proof of the exact upstream base commit.

Relevant inspected changes:
- Visor a0275017 adds QuestAndroidXRBridge/QuestVLoader and registers the Android bridge in XrProvider. It switches to Android-specific AtumVR/OpenXR libraries.
- AtumVR d04c166 adds XRPlatform/AndroidXRBridge and Android changes to instance creation, swapchains and system handling.
- Pojlib vloader.cpp exposes Visor JNI calls which forward to its Vivecraft Android bridge. setupAndroid sets gameReady and waits for launcherXRStopped.
- Unity InstanceButton stops XR subsystems and deinitializes its loader before setting launcherXRStopped.
- The current Pico port retains this handoff. A stock PC Visor JAR lacks it.

Device alpha.4 findings:
- forge - mods: vrPlayMode ENABLED; only reported mandatory dependency blocker is taczaddon requiring Forge [47.4.20,48), installed 47.4.10. Previous Visor exact-version blockers are gone.
- forge - pcvisor: log starts with Current VR Play Mode ENABLED, attempts initialization, gets xrCreateInstance ERROR_LIMIT_REACHED, then sets DISABLED. This was an automatic fallback, not user action. Missing launcher XR handoff in the stock PC path is a source-supported explanation, although the runtime error alone does not prove instance ownership.

No JARs or device settings changed during this inspection. A full historical diff against exact QuestCraft rc4 upstream commits remains separate from this targeted Android bridge comparison.
