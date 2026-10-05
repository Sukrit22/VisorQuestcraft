# Upstream review package

Status: local prototype; not submitted or accepted upstream.

- `atumvr-android-backend.patch`: against AtumVR commit `f0aeed50acb5c83f5143a89aed5b8a0327b9935c`. Includes the Android platform abstraction, EGL/GLES/OpenXR setup, optional Pico controller profile handling, and ServiceLoader discovery. Review/split these concerns before submission.
- `visor-0.5-android-packaging.patch`: against Visor tag 0.5.0, commit `3d56cd0a75c0e1ba5e73e3b10d64165b1b3e0bef`. Android rendering/mirror and dependency packaging changes; removes the need for a hardcoded QuestCraft adapter in Visor.
- Companion source is published in `../bridge-source` and restored into `../sources/Visor-Android-Bridge`, built by `../tools/Build-AndroidBridge.ps1`. The adapter classes originated in the existing Visor port; its license is retained. Bridge 0.1.1 uses its own package to avoid the Forge split-package conflict; Pojlib exports both new and legacy JNI names.

Apply patches with `git apply` in checkouts at the stated bases. They exclude generated/local dependency JARs. The local workspace provides those build inputs; a distributable upstream solution must publish reproducible Android-capable dependencies rather than referencing local `*-pico.jar` files.

These are historical review patches. The complete current port patches and pinned revisions are in `../source-patches` and `../source-lock.json`; use `../SOURCE-WORKFLOW.md` for restoration and development.

## Proposed ownership

AtumVR owns platform-neutral discovery and Android OpenXR/EGL/GLES lifecycle. The companion supplies launcher-specific VM/activity/EGL handles and requests Unity XR shutdown through Pojlib. Visor owns gameplay, pose networking, rendering decisions and normal mod-loader integration. Unity target profiles own Quest/Pico loader selection. Common Android fixes apply to both targets; vendor fixes stay capability-gated or inside a target profile.

Desktop must not initialize the Android provider. Android accepts exactly one provider and fails clearly when none or multiple are installed. SPI discovery is lazy to avoid mod initialization-order assumptions. Real Fabric and Forge classloader discovery still needs device verification.

## Review requirements before an upstream release

- Agree on a stable backend API and versioning contract; current companion explicitly targets Visor 0.5.0.
- Publish Android LWJGL bindings and AtumVR artifacts from reproducible sources, with provenance/license review.
- Test desktop Windows/Linux regressions and Android Quest/Pico lifecycle (startup, graphics reload, sleep/resume, second launch).
- Improve the inherited handoff timeout: Pojlib's current wait is bounded but does not robustly propagate failure when Unity has not stopped XR. Compilation does not establish safe recovery.
- Test loader-specific service discovery and networking with matching client/server versions. No pose packet changes were made here.

See `../FABRIC-AND-ANDROID-BACKEND.md` for installation, migration, build steps and current limits.
