param(
    [string]$JavaHome = 'C:\Program Files\Java\jdk-17'
)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$version = '1.20.1-47.4.20'
$root = Join-Path $workspace "prepared/forge/$version"
$downloads = Join-Path $workspace 'downloads'
$installer = Join-Path $downloads "forge-$version-installer.jar"
$java = Join-Path $JavaHome 'bin/java.exe'
if (!(Test-Path -LiteralPath $java)) { throw "Java 17 is required: $java" }
New-Item -ItemType Directory -Force $root,$downloads | Out-Null
$url = "https://maven.minecraftforge.net/net/minecraftforge/forge/$version/forge-$version-installer.jar"
# Published at https://files.minecraftforge.net/net/minecraftforge/forge/index_1.20.1.html
$sha1 = '237c5a17d941bfe793ff5780a4f330914d2c9f57'
if (!(Test-Path -LiteralPath $installer) -or (Get-FileHash -LiteralPath $installer -Algorithm SHA1).Hash -ne $sha1) {
    Invoke-WebRequest $url -OutFile $installer -TimeoutSec 300
}
if ((Get-FileHash -LiteralPath $installer -Algorithm SHA1).Hash -ne $sha1) { throw 'Installer checksum mismatch' }
# Dedicated staging directory: never use or change the user's desktop launcher profile.
$launcherProfile = Join-Path $root 'launcher_profiles.json'
if (!(Test-Path -LiteralPath $launcherProfile)) {
    '{"profiles":{}}' | Set-Content -LiteralPath $launcherProfile -Encoding utf8
}
& $java '-Djava.awt.headless=true' -jar $installer --installClient $root
if ($LASTEXITCODE -ne 0) { throw "Forge installer failed with exit code $LASTEXITCODE" }
$id = '1.20.1-forge-47.4.20'
$profilePath = Join-Path $root "versions/$id/$id.json"
if (!(Test-Path -LiteralPath $profilePath)) { throw 'Forge did not produce a client profile' }
$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
foreach ($library in $profile.libraries) {
    if ($library.name.StartsWith('org.lwjgl:')) { continue }
    $file = Join-Path $root ('libraries/' + $library.downloads.artifact.path)
    if (!(Test-Path -LiteralPath $file) -or (Get-Item -LiteralPath $file).Length -eq 0) {
        throw "Forge installation is incomplete: $file"
    }
}
$patched = Join-Path $root "libraries/net/minecraftforge/forge/$version/forge-$version-client.jar"
if (!(Test-Path -LiteralPath $patched)) { throw 'Forge client patch processor did not finish' }
Copy-Item -LiteralPath $profilePath -Destination (Join-Path $root 'profile.json')
Write-Host "Prepared Forge runtime: $root"
Write-Host 'This is runtime data for the experimental launcher, not an APK or a working Visor port.'

