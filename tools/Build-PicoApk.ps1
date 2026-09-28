param([string]$UnityEditor = 'E:\Unity\Hub\Editor\6000.4.10f1\Editor\Unity.exe')
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
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
Copy-Item -LiteralPath $aar -Destination "$project/Assets/Plugins/Android/Pojlib-release.aar"
$log = Join-Path $workspace 'unity-pico-build.log'
$arguments = @('-batchmode', '-nographics', '-quit', '-projectPath', ('"' + $project + '"'), '-buildTarget', 'Android', '-executeMethod', 'QuestCraftPicoForgeBuild.BuildAndroid', '-logFile', ('"' + $log + '"'))
$process = Start-Process -FilePath $UnityEditor -ArgumentList $arguments -WindowStyle Hidden -PassThru
Write-Host "Unity build started, process $($process.Id). Log: $log"
$process.WaitForExit()
if ($process.ExitCode -ne 0) { throw "Unity failed with exit code $($process.ExitCode). See $log" }
$apk = Join-Path $workspace 'outputs/QuestCraft-Forge-1.20.1-Visor-0.5.0-Pico-alpha.5.apk'
if (!(Test-Path -LiteralPath $apk)) { throw 'Unity exited without producing the expected APK.' }
Get-Item -LiteralPath $apk | Select-Object FullName,Length,LastWriteTime
Get-FileHash -LiteralPath $apk -Algorithm SHA256



