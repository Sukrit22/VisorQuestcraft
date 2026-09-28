$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$visor = Get-ChildItem "$workspace/sources/Visor-0.5.0/visor-forge/build/libs" -Filter 'Visor-0.5.0+mc1.20.1-forge.jar' | Select-Object -First 1
if (!$visor) { throw 'Build the Visor 0.5.0 Pico Forge jar before staging assets.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($visor.FullName)
try {
    foreach ($entry in @('META-INF/mods.toml','org/vmstudio/visor/core/client/provider/openxr/QuestAndroidXRBridge.class','me/phoenixra/atumvr/core/session/platform/XRPlatform.class','org/lwjgl/openxr/XrGraphicsBindingOpenGLESAndroidKHR.class')) {
        if (!$archive.GetEntry($entry)) { throw "Missing Android/Forge component: $entry" }
    }
    $reader = [IO.StreamReader]::new($archive.GetEntry('META-INF/mods.toml').Open())
    $metadata = $reader.ReadToEnd()
    $reader.Dispose()
    if ($metadata -notmatch '(?m)^version\s*=\s*"0\.5\.0"\s*$') { throw 'Unexpected Visor version in Forge metadata' }
} finally { $archive.Dispose() }
$runtime = "$workspace/prepared/forge/1.20.1-47.4.20"
if (!(Test-Path "$runtime/profile.json")) { throw 'Run Prepare-Forge.ps1 first.' }
$assets = "$workspace/sources/Pojlib/src/main/assets"
New-Item -ItemType Directory -Force "$assets/mods/forge","$assets/forge/1.20.1-47.4.20" | Out-Null
Copy-Item -LiteralPath $visor.FullName -Destination "$assets/mods/forge/Visor-0.5.0-pico-alpha.4.jar"
Copy-Item -LiteralPath "$runtime/profile.json" -Destination "$assets/forge/1.20.1-47.4.20/profile.json"
Copy-Item -LiteralPath "$runtime/libraries" -Destination "$assets/forge/1.20.1-47.4.20" -Recurse -Force
Write-Host 'Staged the verified Android Forge Visor jar and prepared Forge runtime in Pojlib assets.'


