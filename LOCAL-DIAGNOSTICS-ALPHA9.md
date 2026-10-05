# Local diagnostics — alpha.9

## Instructions for testers (no ADB)

1. Install the alpha.9 APK for your headset over the existing build.
2. Reproduce the problem (for example, press Instances or Sign in).
3. Press **Save / Share Logs**. The crash dialog's **save / share** action does the same thing.
4. Choose an installed sharing app and your intended recipient. Opening the chooser does not send anything by itself.
5. If sharing is unavailable, open the headset's file manager and look under **Downloads / Visor Diagnostics**. Send the newest `visor-diagnostics-*.txt` file when a suitable app or file transfer is available.

If neither Downloads nor sharing is available on that device, the launcher reports the app-local saved path. A short headset video of the status/error remains useful. Do not clear app data before retrieving that local copy.

## What changed

- Replaced the Coah upload in `LogUploader.cs` with a user-requested local text report.
- Replaced the older mclo.gs upload in `LoadLog.cs` as well; retained its serialized Unity method name to preserve scene wiring.
- Added `DiagnosticsExporter.java` to Pojlib. On Android 10+ it publishes a text file through MediaStore Downloads, then opens ACTION_SEND with temporary read permission on the content URI. No FileProvider or broad storage permission is needed.
- The report includes app version, headset model/OS, initialization/login state, recent Unity output, and selected Java/game/crash logs. Account files, launcher.conf, instances.json and sign-in instructions are excluded.
- Credential-related lines (tokens, authorization headers, device codes, passwords, custom environment values) are filtered before saving. This is best-effort filtering, not complete anonymization: player/server names and chat can remain. Review the file before sharing.
- The Unity log uses a bounded recent buffer; selected disk logs use size/file-count limits. A storage-read failure does not prevent the in-memory Unity report from being generated. Downloads/export/share failures leave the local saved copy and show its location.
- Both main and crash-dialog buttons now describe saving/sharing. There is no upload server in this workflow.

## Verification

12 diagnostics checks cover credential redaction, preservation of useful neighboring errors, partial-line truncation and report generation before launcher initialization. The 12 launcher/login regression checks also passed. Pojlib compiled and both Unity target APKs passed signature/manifest/architecture/XR-loader and 76 bundled-runtime-file checks. Inspection of both packaged DEX/IL2CPP metadata confirmed the exporter/UI and absence of the two old upload endpoints.

Two focused subagent reviews were used (gpt-6-sol and gpt-6.1-sol). Review fixes included guarding nullable UI state, handling inaccessible log directories, filtering custom environment values and checking MediaStore publication success. The final review found no blocking issue; it noted that the inherited startup crash-timestamp scan can still throw on inaccessible/disappearing directories, although report collection itself is guarded.

Not yet tested on a physical Quest/Pico: MediaStore visibility in the vendor file manager, available share apps, headset layout, and successful recipient delivery. No logs were sent during development, and no APK was installed automatically.

## Build steps

1. Build Pojlib `assembleRelease` using Java 17 / Gradle 8.10.2.
2. With the Unity project closed, run Unity 6000.4.10f1 in batch mode using `-projectPath sources/QCXR-XR-Wrapper -executeMethod VerifyDiagnostics.Run -quit -logFile unity-diagnostics-tests.log`. Confirm both PASS lines.
3. Run `tools/Build-AndroidApk.ps1 -Target Quest`, then `tools/Verify-AndroidApk.ps1 -Target Quest`.
4. Repeat sequentially with `-Target Pico`. The targets share one Unity project and must not build concurrently.
5. Outputs and checksums are in `outputs`, with `alpha9-artifacts.json` recording APK hashes.

Fabric/Forge 1.20.1, Visor and Android Bridge versions are unchanged from alpha.8. The historic APK filename still contains Forge even though both loaders are supported.
