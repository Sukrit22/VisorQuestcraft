param([ValidateSet('Pico','Quest')][string]$Target = 'Quest', [string]$UnityEditor = 'E:\Unity\Hub\Editor\6000.4.10f1\Editor\Unity.exe')
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Force (Join-Path $workspace 'build') | Out-Null
$buildLock = [IO.File]::Open((Join-Path $workspace 'build/android-packaging.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
$started = [DateTime]::UtcNow
$config = Get-Content (Join-Path $workspace 'build-targets/android.json') -Raw | ConvertFrom-Json
$profile = $config.targets | Where-Object name -eq $Target
$project = Join-Path $workspace 'sources/QCXR-XR-Wrapper'
if (!(Test-Path -LiteralPath $UnityEditor)) { throw "Unity not found: $UnityEditor" }
$projectVersion = Get-Content "$project/ProjectSettings/ProjectVersion.txt" -Raw
if ($projectVersion -notmatch 'm_EditorVersion: 6000.4.10f1') { throw 'Unexpected Unity project version' }
if ((Get-Item -LiteralPath $UnityEditor).VersionInfo.ProductVersion -notlike '6000.4.10f1*') { throw 'Use Unity 6000.4.10f1 for this project' }
$tree = Get-Content "$workspace/downloads/wrapper-tree.json" -Raw | ConvertFrom-Json
$missing = @($tree.tree | Where-Object {
    $_.type -eq 'blob' -and $_.path -match '^(Assets|Packages|ProjectSettings)/' -and
    !(Test-Path -LiteralPath (Join-Path $project $_.path))
})
if ($missing.Count) { throw "Unity checkout is incomplete: $($missing.Count) files missing. Run Recover-UnityAssets.ps1." }
$partials = @(Get-ChildItem "$project/Assets" -Recurse -Filter '*.partial')
if ($partials.Count) { throw 'Incomplete download files are still present in Assets.' }
$aar = Join-Path $workspace 'sources/Pojlib/build/outputs/aar/Pojlib-release.aar'
if (!(Test-Path -LiteralPath $aar)) { throw 'Build Pojlib assembleRelease first.' }
. "$PSScriptRoot/Visor-DownloadManifest.ps1"
Assert-VisorArchive $workspace $aar
Copy-Item -LiteralPath $aar -Destination "$project/Assets/Plugins/Android/Pojlib-release.aar"
$log = Join-Path $workspace ("unity-" + $Target.ToLowerInvariant() + "-build.log")
$arguments = @('-batchmode', '-nographics', '-quit', '-projectPath', ('"' + $project + '"'), '-buildTarget', 'Android', '-executeMethod', $profile.method, '-logFile', ('"' + $log + '"'))
$process = Start-Process -FilePath $UnityEditor -ArgumentList $arguments -WindowStyle Hidden -PassThru
Write-Host "Unity build started, process $($process.Id). Log: $log"
$process.WaitForExit()
if ($process.ExitCode -ne 0) { throw "Unity failed with exit code $($process.ExitCode). See $log" }
$apk = Join-Path $workspace ("outputs/QuestCraft-Forge-" + $config.minecraft + "-Visor-0.5.0-" + $Target + "-" + $config.release + ".apk")
if (!(Test-Path -LiteralPath $apk)) { throw 'Unity exited without producing the expected APK.' }
if ((Get-Item -LiteralPath $apk).LastWriteTimeUtc -lt $started) { throw "APK is stale" }
$evidence = Get-Content "$apk.build.json" -Raw | ConvertFrom-Json
$evidence | Add-Member -NotePropertyName pojlibSHA256 -NotePropertyValue (Get-FileHash $aar).Hash -Force
$evidence | Add-Member -NotePropertyName configSHA256 -NotePropertyValue (Get-FileHash "$workspace/build-targets/android.json").Hash -Force
$evidence | ConvertTo-Json -Depth 10 | Set-Content "$apk.build.json" -Encoding utf8NoBOM
Get-Item -LiteralPath $apk | Select-Object FullName,Length,LastWriteTime
Get-FileHash -LiteralPath $apk -Algorithm SHA256





} finally { $buildLock.Dispose() }
