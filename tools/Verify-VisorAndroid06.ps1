param([string]$Jar)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$Jar) { $Jar = Join-Path $root 'outputs/Visor-0.6.0-alpha.2-android.1+mc1.20.1-forge.jar' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($Jar)
try {
    $required = @(
        'META-INF/mods.toml',
        'org/vmstudio/visor/core/client/provider/openxr/QuestAndroidXRBridge.class',
        'org/vmstudio/visor/core/client/provider/openxr/QuestVLoader.class',
        'me/phoenixra/atumvr/core/session/platform/AndroidXRBridge.class',
        'me/phoenixra/atumvr/core/session/platform/XRPlatform$Android.class',
        'org/lwjgl/openxr/XrInstanceCreateInfoAndroidKHR.class',
        'org/lwjgl/openxr/XrGraphicsBindingOpenGLESAndroidKHR.class'
    )
    foreach ($name in $required) {
        if (!$zip.GetEntry($name)) { throw "Missing Android runtime entry: $name" }
    }
    $reader = [IO.StreamReader]::new($zip.GetEntry('META-INF/mods.toml').Open())
    try { $metadata = $reader.ReadToEnd() } finally { $reader.Dispose() }
    if ($metadata -notmatch 'version\s*=\s*"0\.6\.0-alpha\.2"') { throw 'Incorrect Visor version' }
    if ($metadata -notmatch 'versionRange\s*=\s*"\[1\.20,1\.20\.1\]"') { throw 'Incorrect Minecraft target' }
    if ($zip.Entries.FullName | Where-Object { $_ -match '\.(dll|dylib)$|(^|/)linux/.*\.so$' }) {
        throw 'Desktop native libraries accidentally bundled'
    }
    $classes = $zip.Entries | Where-Object { $_.FullName -like 'org/vmstudio/visor/*.class' }
    foreach ($entry in $classes) {
        $stream = $entry.Open()
        try {
            $header = [byte[]]::new(8)
            if ($stream.Read($header, 0, 8) -ne 8) { throw "Invalid class: $($entry.FullName)" }
            $major = [int]$header[6] * 256 + [int]$header[7]
            if ($major -gt 61) { throw "Requires newer than Java 17: $($entry.FullName) ($major)" }
        } finally { $stream.Dispose() }
    }
    Write-Output "PASS: Android bridge, real mod version, Minecraft target, no desktop natives, $($classes.Count) Java-17-compatible Visor classes."
} finally { $zip.Dispose() }
Get-FileHash -LiteralPath $Jar -Algorithm SHA256
