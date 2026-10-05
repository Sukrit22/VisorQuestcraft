param([switch]$Offline)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot/Visor-DownloadManifest.ps1"
$config = Get-Content "$workspace/build-targets/android.json" -Raw | ConvertFrom-Json
$manifest = Get-VisorManifest $workspace
$runtime = Join-Path $workspace "prepared/forge/$($config.forge)"
if (!(Test-Path "$runtime/profile.json")) { throw 'Run Prepare-Forge.ps1 first.' }
$assets = Join-Path $workspace 'sources/Pojlib/src/main/assets'
# Resolve and validate everything before changing staged assets.
$resolved = @($manifest.artifacts | ForEach-Object {
    $path = Resolve-VisorArtifact $workspace $_ $Offline.IsPresent
    [pscustomobject]@{ item=$_; path=$path; hash=(Get-FileHash -LiteralPath $path).Hash }
})
$receipt = [ordered]@{ schemaVersion=1; manifestSHA256=(Get-FileHash "$workspace/build-targets/visor-downloads.json").Hash; artifacts=@() }
foreach ($artifact in $resolved) {
    $destination = Join-Path $assets $artifact.item.asset
    New-Item -ItemType Directory -Force (Split-Path $destination -Parent) | Out-Null
    Copy-Item -LiteralPath $artifact.path -Destination $destination -Force
    $receipt.artifacts += [ordered]@{ id=$artifact.item.id; asset=$artifact.item.asset; sha256=$artifact.hash }
}
New-Item -ItemType Directory -Force "$assets/forge/$($config.forge)" | Out-Null
Copy-Item -LiteralPath "$runtime/profile.json" -Destination "$assets/forge/$($config.forge)/profile.json" -Force
Copy-Item -LiteralPath "$runtime/libraries" -Destination "$assets/forge/$($config.forge)" -Recurse -Force
$receipt | ConvertTo-Json -Depth 10 | Set-Content "$assets/visor-downloads.staged.json" -Encoding utf8NoBOM
Write-Host 'Staged four validated Android artifacts, download receipt, and prepared Forge runtime. Rebuild Pojlib assembleRelease before packaging the APK.'
