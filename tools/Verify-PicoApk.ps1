$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$apk = Join-Path $workspace 'outputs/QuestCraft-Forge-1.20.1-Visor-0.5.0-Pico-alpha.5.apk'
$buildTools = 'E:\Unity\Hub\Editor\6000.4.10f1\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\build-tools\36.0.0'
$env:JAVA_HOME = 'E:\Unity\Hub\Editor\6000.4.10f1\Editor\Data\PlaybackEngines\AndroidPlayer\OpenJDK'
& "$buildTools/apksigner.bat" verify --verbose $apk
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
$badging = & "$buildTools/aapt2.exe" dump badging $apk
if ($LASTEXITCODE -ne 0) { throw 'Cannot read APK metadata' }
if (($badging -join "`n") -notmatch "package: name='com.qcxr.qcxr.visor.forge.pico'") { throw 'Wrong Android application ID' }
if (($badging -join "`n") -notmatch "versionName='0.5.0-pico-alpha.5'") { throw 'Wrong Android application version' }
$badging | Where-Object { $_ -match '^(package:|sdkVersion:|targetSdkVersion:|native-code:|launchable-activity:)' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($apk)
try {
    foreach ($name in @('assets/mods/forge/Visor-0.5.0-pico-alpha.4.jar', 'assets/forge/1.20.1-47.4.20/profile.json',
        'lib/arm64-v8a/libopenxr_loader.so', 'lib/arm64-v8a/libopenxr_pico.so', 'lib/arm64-v8a/libvloader.so',
        'lib/arm64-v8a/libUnityOpenXR.so', 'lib/arm64-v8a/libil2cpp.so')) {
        if (!$archive.GetEntry($name)) { throw "Missing APK component: $name" }
    }
    $abis = @($archive.Entries.FullName | Where-Object {$_ -match '^lib/([^/]+)/'} | ForEach-Object { ($_ -split '/')[1] } | Sort-Object -Unique)
    if ($abis.Count -ne 1 -or $abis[0] -ne 'arm64-v8a') { throw "Unexpected APK architectures: $abis" }
    if (@($archive.Entries | Where-Object FullName -like 'assets/forge/1.20.1-47.4.10/*').Count) { throw 'Old Forge runtime still bundled' }
    $profileReader = [IO.StreamReader]::new($archive.GetEntry('assets/forge/1.20.1-47.4.20/profile.json').Open())
    try { $profile = $profileReader.ReadToEnd() | ConvertFrom-Json } finally { $profileReader.Dispose() }
    if ($profile.id -ne '1.20.1-forge-47.4.20' -or $profile.arguments.game -notcontains '47.4.20') { throw 'Wrong Forge profile version' }
    $checks = @{
        'assets/mods/forge/Visor-0.5.0-pico-alpha.4.jar' = "$workspace/sources/Visor-0.5.0/visor-forge/build/libs/Visor-0.5.0+mc1.20.1-forge.jar"
        'lib/arm64-v8a/libopenxr_loader.so' = "$workspace/downloads/pico-1.3-openxr-loader.so"
    }
    $runtime = Join-Path $workspace 'prepared/forge/1.20.1-47.4.20'
    $checks['assets/forge/1.20.1-47.4.20/profile.json'] = Join-Path $runtime 'profile.json'
    foreach ($library in (Get-ChildItem "$runtime/libraries" -File -Recurse)) {
        $relative = [IO.Path]::GetRelativePath($runtime, $library.FullName).Replace('\','/')
        $checks["assets/forge/1.20.1-47.4.20/$relative"] = $library.FullName
    }
    foreach ($name in $checks.Keys) {
        $stream = $archive.GetEntry($name).Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [Convert]::ToHexString($sha.ComputeHash($stream)) }
        finally { $stream.Dispose(); $sha.Dispose() }
        if ($hash -ne (Get-FileHash -LiteralPath $checks[$name] -Algorithm SHA256).Hash) { throw "APK component hash mismatch: $name" }
        Write-Host "Verified $name"
    }
} finally { $archive.Dispose() }
Get-FileHash -LiteralPath $apk -Algorithm SHA256
Write-Host 'APK packaging checks passed. Headset runtime validation is still required.'




