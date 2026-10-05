param([ValidateSet('Pico','Quest')][string]$Target = 'Quest')
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$config = Get-Content "$workspace/build-targets/android.json" -Raw | ConvertFrom-Json
$targetProfile = $config.targets | Where-Object name -eq $Target
$apk = Join-Path $workspace "outputs/QuestCraft-Forge-$($config.minecraft)-Visor-0.5.0-$Target-$($config.release).apk"
. "$PSScriptRoot/Visor-DownloadManifest.ps1"
Assert-VisorArchive $workspace $apk
& python "$PSScriptRoot/verify_launcher_classes.py" $apk
if ($LASTEXITCODE -ne 0) { throw 'Launcher runtime dependencies missing from APK DEX' }
$buildTools = 'E:\Unity\Hub\Editor\6000.4.10f1\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\build-tools\36.0.0'
$env:JAVA_HOME = 'E:\Unity\Hub\Editor\6000.4.10f1\Editor\Data\PlaybackEngines\AndroidPlayer\OpenJDK'
& "$buildTools/apksigner.bat" verify --verbose $apk
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
$badging = (& "$buildTools/aapt2.exe" dump badging $apk) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Cannot read APK metadata' }
if (!$badging.Contains("package: name='$($targetProfile.applicationId)'")) { throw 'Wrong application ID' }
if (!$badging.Contains("versionCode='$($config.versionCode)'")) { throw 'Wrong version code' }
if (!$badging.Contains("versionName='0.5.0-$($Target.ToLowerInvariant())-$($config.release)'")) { throw 'Wrong application version' }
$manifest = (& "$buildTools/aapt2.exe" dump xmltree $apk --file AndroidManifest.xml) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Cannot decode manifest' }
if ($Target -eq 'Quest') {
    if ($manifest -match 'pvr\.|com\.picovr\.') { throw 'Pico metadata leaked into Quest manifest' }
    if ($manifest -notmatch 'com\.oculus\.intent\.category\.VR') { throw 'Quest VR category missing' }
    if ($manifest -notmatch 'com\.oculus\.supportedDevices') { throw 'Quest supported devices missing' }
} else {
    if ($manifest -notmatch 'pvr\.app\.type') { throw 'Pico VR metadata missing' }
    if ($manifest -match 'com\.oculus\.') { throw 'Quest metadata leaked into Pico manifest' }
}
$evidence = Get-Content "$apk.build.json" -Raw | ConvertFrom-Json
if ($evidence.target -ne $Target -or $evidence.applicationId -ne $targetProfile.applicationId) { throw 'Build profile evidence mismatch' }
if ($Target -eq 'Quest') {
    if ($evidence.enabledFeatures -match 'PICO') { throw 'Pico XR feature enabled in Quest build' }
    if (!($evidence.enabledFeatures -match '\.MetaQuestFeature$')) { throw 'Meta Quest Support not enabled' }
} elseif ($evidence.enabledFeatures -match 'MetaQuest|Oculus') { throw 'Meta feature enabled in Pico build' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
function EntryHash($zip, $name) {
    $entry = $zip.GetEntry($name)
    if (!$entry) { throw "Missing archive entry: $name" }
    $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
    try { [Convert]::ToHexString($sha.ComputeHash($stream)) } finally { $stream.Dispose(); $sha.Dispose() }
}
$archive = [IO.Compression.ZipFile]::OpenRead($apk)
try {
    foreach ($name in @('lib/arm64-v8a/libopenxr_loader.so','lib/arm64-v8a/libvloader.so','lib/arm64-v8a/libUnityOpenXR.so','lib/arm64-v8a/libil2cpp.so')) {
        if (!$archive.GetEntry($name)) { throw "Missing component: $name" }
    }
    $abis = @($archive.Entries.FullName | Where-Object {$_ -match '^lib/([^/]+)/'} | ForEach-Object { ($_ -split '/')[1] } | Sort-Object -Unique)
    if ($abis.Count -ne 1 -or $abis[0] -ne 'arm64-v8a') { throw "Unexpected architectures: $abis" }
    if ($Target -eq 'Quest') {
        if ($archive.Entries.FullName -match '^lib/.*(openxr_pico|pxrplatform|PXR).*\.so$') { throw 'Pico native library leaked into Quest APK' }
        $package = Get-ChildItem "$workspace/sources/QCXR-XR-Wrapper/Library/PackageCache" -Directory -Filter 'com.unity.xr.openxr@*' | Select-Object -First 1
        $loaderAar = [IO.Compression.ZipFile]::OpenRead("$($package.FullName)/RuntimeLoaders/android/openxr_loader.aar")
        try { $loaderHash = EntryHash $loaderAar 'jni/arm64-v8a/libopenxr_loader.so' } finally { $loaderAar.Dispose() }
    } else {
        if (!$archive.GetEntry('lib/arm64-v8a/libopenxr_pico.so')) { throw 'Pico bridge missing' }
        $loaderHash = (Get-FileHash "$workspace/downloads/pico-1.3-openxr-loader.so").Hash
    }
    if ((EntryHash $archive 'lib/arm64-v8a/libopenxr_loader.so') -ne $loaderHash) { throw 'Wrong target OpenXR loader' }
    $checks = @{}
    foreach ($item in (Get-VisorManifest $workspace).artifacts) {
        $checks['assets/' + $item.asset] = Join-Path "$workspace/sources/Pojlib/src/main/assets" $item.asset
    }
    $runtime = Join-Path $workspace "prepared/forge/$($config.forge)"
    $checks["assets/forge/$($config.forge)/profile.json"] = "$runtime/profile.json"
    foreach ($library in (Get-ChildItem "$runtime/libraries" -File -Recurse)) {
        $relative = [IO.Path]::GetRelativePath($runtime, $library.FullName).Replace('\','/')
        $checks["assets/forge/$($config.forge)/$relative"] = $library.FullName
    }
    if (@($archive.Entries | Where-Object { $_.FullName.StartsWith('assets/forge/') -and !$_.FullName.StartsWith("assets/forge/$($config.forge)/") -and $_.Length -gt 0 }).Count) { throw 'Other Forge runtime bundled' }
    foreach ($name in $checks.Keys) {
        if ((EntryHash $archive $name) -ne (Get-FileHash -LiteralPath $checks[$name]).Hash) { throw "Component mismatch: $name" }
    }
    Write-Host "Verified $($checks.Count) shared Visor/Forge files and $Target loader, features, manifest, signature and architecture."
} finally { $archive.Dispose() }
# A relocated Java native method needs an exported matching JNI symbol in this APK.
$nativeCheck = Join-Path $workspace "build/verify-$Target-vloader.so"
$archive = [IO.Compression.ZipFile]::OpenRead($apk)
try { [IO.Compression.ZipFileExtensions]::ExtractToFile($archive.GetEntry('lib/arm64-v8a/libvloader.so'), $nativeCheck, $true) }
finally { $archive.Dispose() }
$nm = "$env:LOCALAPPDATA/Android/Sdk/ndk/26.1.10909125/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-nm.exe"
$symbols = (& $nm --dynamic --defined-only $nativeCheck) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect JNI exports' }
foreach ($package in @('android', 'core_client_provider_openxr')) {
    foreach ($method in @('getEGLDisplay','getEGLContext','getEGLConfig','getDalvikVM','getDalvikActivity','setupAndroid','getDeviceModel')) {
        if (!$symbols.Contains("Java_org_vmstudio_visor_${package}_QuestVLoader_$method")) { throw "Missing bridge JNI export: $package $method" }
    }
}
Write-Host 'Verified new and legacy Visor JNI entry points.'
Get-FileHash -LiteralPath $apk -Algorithm SHA256
Write-Host 'Packaging verified. Headset runtime testing is still required.'
