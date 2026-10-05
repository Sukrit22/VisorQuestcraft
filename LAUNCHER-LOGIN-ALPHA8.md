# Launcher login and Demo-mode fixes — alpha.8

## Origin and purpose

Minecraft's demo is Mojang's limited trial. QuestCraft's Pojlib account flow marks an account as demo when no Minecraft Java profile is found; the launch arguments then include `--demo`. This is not a Visor/Pico feature. The same disabled-instance-button branch is present in upstream QuestCraft's UIHandler, so it was inherited by Coah's fork. We have not attributed the original commit to a specific individual.

References:
- https://www.minecraft.net/en-us/free-trial
- https://github.com/QuestCraftPlusPlus/QCXR-XR-Wrapper/blob/master/Assets/Scripts/UIHandler.cs
- https://github.com/QuestCraftPlusPlus/Pojlib/blob/QuestCraft-6.0.0/src/main/java/pojlib/account/Msa.java

## Changes, in order

1. Changed `UIHandler.UILoginCheck`: instance creation, selection and mods management no longer depend on authentication or demo status. Play still requires a successfully loaded account. Game-running state keeps management and account switching disabled.
2. Reworked `LoginHandler`: wait for JNI/config initialization, parse accounts without triggering login, start one attempt, and poll explicit backend state. Removed the previous double login and comparison of AndroidJavaObject wrappers. Handle empty account lists, account selection, logout and persistence without losing settings changed during sign-in.
3. Added the always-visible login status panel, `Sign in / retry` and `Copy sign-in text` actions. Microsoft device-code instructions include the URL/code; copying copies only the displayed text. Status graphics do not intercept controller raycasts. The layout still needs in-headset review.
4. Moved cached-account checks, token refresh and interactive login off the Unity UI thread. Prevent overlapping attempts; publish explicit connecting/waiting/ready/error states. Device-code waiting is bounded at ten minutes and failed attempts can be retried. Account service errors are shown without raw authentication responses or tokens.
5. Changed the Minecraft profile check: HTTP 404 retains the existing no-profile/demo behavior; 401, 403, throttling and server errors fail login instead of silently classifying the player as demo. Added connect/read timeouts to the account HTTP requests and the connection probe.
6. Kept Minecraft's `--demo` argument and normal ownership/authentication flow unchanged. A cached demo account remains demo until the user chooses Sign in again; this intentionally permits rechecking an account previously misclassified by a service error.
7. Incremented the shared release config to alpha.8 and built both Quest and Pico targets with Unity 6000.4.10f1. Visor/bridge versions and Fabric/Forge support are unchanged from alpha.7.

## Verification

- Unity editor scene regression checks: authenticated and demo access, signed-out management without Play, pending-login restrictions, running-game restrictions, status raycast behavior, both action buttons, null account lists and parsing without login.
- `tools/Test-LoginProfile.ps1` exercises the actual compiled profile-check method with mocked HTTPS responses: 200, 404, 401, 403, 429, 500, 503. No real Microsoft account or credentials are used.
- Pojlib release compilation and both Unity APK builds; per-target signature, architecture, manifest, XR loader and 76 bundled runtime-file checks.
- Actual Microsoft sign-in, headset UI layout/copy behavior and the remote Quest user's failure are not verified by these local checks.

## Tester steps

1. Install the alpha.8 APK for the correct headset; do not uninstall or clear data first.
2. Report the status (connecting, Demo mode, signed in, or the error text); omit any active device code. Instance creation should work even before sign-in completes.
3. If it says Demo mode despite owning Java Edition, select `Sign in / retry`, then complete the displayed Microsoft URL/code on your own phone or PC. Do not send the live code to another person.
4. Confirm the status becomes `Signed in as ...`, create/select a Fabric or Forge 1.20.1 instance, and launch. Demo accounts remain limited to Minecraft demo behavior.
5. If sign-in fails, report the visible error text. A short video of the status and failed action is useful even when ADB logs are unavailable.

## Rebuild

From `E:\visor-compat\visor-0.5.0-questcraft`, use Java 17 and Gradle 8.10.2 to run `assembleRelease` in `sources/Pojlib`; stop if it fails. Run `tools/Test-LoginProfile.ps1`. With the Unity project closed, run Unity in batch mode with `-projectPath sources/QCXR-XR-Wrapper -executeMethod VerifyLauncherLogin.Run -quit -logFile unity-login-tests.log`; check for `PASS launcher login regression checks`.

Then run `tools/Build-AndroidApk.ps1 -Target Quest` and `tools/Verify-AndroidApk.ps1 -Target Quest`, followed sequentially by the same two commands with `-Target Pico`. See HEADSET-BUILDS.md for full Unity paths and packaging details. APKs are delivered for manual installation; these tools do not install them.
