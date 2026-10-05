# Quest launcher startup failure — alpha.10

## Evidence from the tester

Both supplied `visor-diagnostics-20261002-*.txt` files identify Quest 3S, Android 14/API34, and our alpha.9 APK. They record `JNI initialized: False`, Demo false, and Instances enabled. The first startup exception is `NoClassDefFoundError: com/google/gson/GsonBuilder`, from `GsonUtils` -> `InstanceHandler.load` -> `API.loadAll` -> `JNIStorage.Start`. Later button clicks enter `InstanceManager.CreateInstanceArray`, which throws because initialization never produced an instance list. The full logcat confirms the same missing class.

This explains the blank account label and button press animation without page navigation. Demo mode and controller input were not the cause of this recorded failure. DNS failures are also present in the later session; they may affect authentication after startup is repaired, but do not cause the missing packaged Java class.

## Comparison with Coah 1.1.1

Downloaded `QuestCraft-VISOR-1.1.1.apk` from the v1.1.1 release and matched the GitHub asset SHA256:
`1e3b17a0f303b2da675066883975dcc156851610e3c4a4d5e2d31318220064c4`.

Real DEX class-definition inspection (not searching descriptor strings) found:

| Class | Coah 1.1.1 | Our Pico alpha.9 | Our Quest alpha.9 |
|---|---|---|---|
| Gson / GsonBuilder / TypeToken | present | present | missing |
| AndroidX core MathUtils | missing | missing | missing |
| Commons Math Vector3D | missing | missing | missing |

MathUtils is used by Pojlib's gamepad code. Commons Math is declared by Pojlib but has no direct source import found; its absence is dependency-parity evidence, not the cause of this startup failure. No Coah headset logs were supplied, so the exact tester baseline remains reported as probably 1.1.1.

The checked-out Coah Unity Gradle template does not declare Gson. The Pico SDK supplies `gson-2.10.1.jar`; our Quest-target packaging excludes Pico plugins and therefore removed the accidental source of Gson. A copied local AAR does not supply Maven transitive-dependency metadata. This was our Quest packaging integration gap.

## Fix

1. Explicitly declare the launcher dependencies in Unity `mainTemplate.gradle`: Gson 2.12.1, AndroidX core/annotations, JetBrains annotations, Commons Math; align Commons IO to 2.13.0 and MSAL4J to 1.17.2 with Pojlib. Android provides org.json, and Unity provides its own player classes.
2. Exclude the Pico SDK's duplicate gson JAR in both targets, while preserving Pico's vendor libraries on Pico. Restore importer settings after packaging.
3. Extend APK verification with `tools/verify_launcher_classes.py`, checking 10 actual class definitions in root APK DEX files. This reproduces the failure on the old Quest APK and prevents shipping another APK missing those dependencies. These checks target the current unminified builds; future shrinking requires revisiting unused-class checks.
4. Show an initialization error when Instances is clicked before JNI/instance data are ready instead of throwing another null-reference exception.
5. Build both targets as alpha.10. No Visor JAR or authentication protocol changes are required for this fix. Existing local Save/Share diagnostics remain available.

## Reproduce / test

From the workspace, run `python tools/verify_launcher_classes.py <APK>` for comparison. Build with Unity 6000.4.10f1 using `tools/Build-AndroidApk.ps1 -Target Quest`, followed by `tools/Verify-AndroidApk.ps1 -Target Quest`; repeat sequentially for Pico. Verification now requires Python 3 and includes the new DEX check.

On the Quest 3S: install alpha.10 over alpha.9, reopen the launcher, confirm account text and Instances work, and then test Microsoft login. Export diagnostics if it fails. Successful builds/DEX checks do not establish live sign-in or headset VR operation. Do not clear app data or reinstall Minecraft as a remedy for this packaging fault.

Final verification: both alpha.10 APKs built successfully and passed all 10 launcher class-definition checks plus the existing 76 asset, signature, manifest, architecture and headset-loader checks. Pico build evidence confirms the vendor gson JAR was excluded. Quest update signing certificate matches alpha.9. Hardware retesting remains outstanding.
