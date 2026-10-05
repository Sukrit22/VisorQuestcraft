$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName System.IO.Compression.FileSystem
function HashEntry($zip, $name) {
    $entry = $zip.GetEntry($name)
    if (!$entry) { throw "Missing $name" }
    $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
    try { [Convert]::ToHexString($sha.ComputeHash($stream)) } finally { $stream.Dispose(); $sha.Dispose() }
}
$core = [IO.Compression.ZipFile]::OpenRead("$root/sources/Visor-0.5.0/libs/atumvr-core-pico.jar")
try {
    $holder = 'me/phoenixra/atumvr/core/session/platform/XRPlatform$Holder.class'
    [void](HashEntry $core $holder)
    foreach ($loader in @('fabric','forge')) {
        $zip = [IO.Compression.ZipFile]::OpenRead("$root/sources/Visor-0.5.0/visor-$loader/build/libs/Visor-0.5.0+mc1.20.1-$loader.jar")
        try {
            # Remapping rewrites constant-pool indexes, so raw class hashes are not stable.
            $jar = "$root/sources/Visor-0.5.0/visor-$loader/build/libs/Visor-0.5.0+mc1.20.1-$loader.jar"
            $bytecode = & 'C:/Program Files/Java/jdk-17/bin/javap.exe' -classpath $jar -c -p 'me.phoenixra.atumvr.core.session.platform.XRPlatform$Holder'
            if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect bundled backend' }
            foreach ($marker in @('discoverAndroidBridge', 'java/util/ServiceLoader.load', 'Multiple Android XR bridges installed', 'No Android XR bridge installed', 'XRPlatform.setAndroidBridge')) {
                if (!(($bytecode -join "`n").Contains($marker))) { throw "Missing backend behavior: $marker" }
            }
            foreach ($name in @('QuestAndroidXRBridge','QuestVLoader')) {
                if ($zip.GetEntry("org/vmstudio/visor/core/client/provider/openxr/$name.class")) { throw 'Launcher bridge still embedded in Visor' }
            }
            [void](HashEntry $zip 'org/lwjgl/openxr/XrGraphicsBindingOpenGLESAndroidKHR.class')
            if ($loader -eq 'fabric') {
                $api = $zip.Entries | Where-Object FullName -match '^META-INF/jars/fabric-api-.*\.jar$' | Select-Object -First 1
                if (!$api) { throw 'Fabric API missing' }
                $memory = [IO.MemoryStream]::new(); $stream = $api.Open()
                try { $stream.CopyTo($memory); $memory.Position = 0; $nested = [IO.Compression.ZipArchive]::new($memory, [IO.Compression.ZipArchiveMode]::Read)
                    try { foreach ($module in @('fabric-networking-api-v1','fabric-rendering-v1','fabric-resource-loader-v0')) {
                        if (!($nested.Entries.FullName -match $module)) { throw "Fabric API module missing: $module" }
                    } } finally { $nested.Dispose() }
                } finally { $stream.Dispose(); $memory.Dispose() }
            }
            Write-Output "PASS ${loader}: backend SPI, Android bindings, bridge extracted, required libraries present"
        } finally { $zip.Dispose() }
    }
} finally { $core.Dispose() }
$bridge = [IO.Compression.ZipFile]::OpenRead("$root/outputs/Visor-Android-Bridge-0.1.1.jar")
try {
    foreach ($name in @('QuestAndroidXRBridge','QuestVLoader')) { [void](HashEntry $bridge "org/vmstudio/visor/android/$name.class") }
    foreach ($name in @('fabric.mod.json','META-INF/mods.toml','META-INF/services/me.phoenixra.atumvr.core.session.platform.AndroidXRBridge')) { [void](HashEntry $bridge $name) }
    if ($bridge.Entries.FullName -match '^(me/phoenixra/atumvr|org/lwjgl)/') { throw 'Companion must not duplicate AtumVR/LWJGL classes' }
    Write-Output 'PASS companion: Forge/Fabric metadata and service registration; no duplicate runtime libraries'
} finally { $bridge.Dispose() }
$moduleTests = Join-Path $root 'build/bridge-module-tests'
New-Item -ItemType Directory -Force $moduleTests | Out-Null
& 'C:/Program Files/Java/jdk-17/bin/javac.exe' -d $moduleTests "$PSScriptRoot/BridgeModuleTest.java"
if ($LASTEXITCODE -ne 0) { throw 'Module test compilation failed' }
& 'C:/Program Files/Java/jdk-17/bin/java.exe' -cp $moduleTests BridgeModuleTest "$root/outputs/Visor-0.5.0-android-forge.1+mc1.20.1.jar" "$root/outputs/Visor-Android-Bridge-0.1.1.jar"
if ($LASTEXITCODE -ne 0) { throw 'Visor/bridge module package conflict' }
