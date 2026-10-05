param([string]$JavaHome = 'C:\Program Files\Java\jdk-17', [string]$BackendJar)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$output = Join-Path $root 'build/bridge-discovery-tests'
New-Item -ItemType Directory -Force $output | Out-Null
$libs = Join-Path $root 'sources/Visor-0.5.0/libs'
$cp = "$output;$libs/atumvr-core-pico.jar;$libs/atumvr-api-pico.jar;$libs/lwjgl-openxr-quest-3.3.3.jar"
if ($BackendJar) { $cp = "$output;$BackendJar" }
foreach ($module in @('lwjgl','lwjgl-opengl','lwjgl-glfw')) {
    $lib = Get-ChildItem "$env:USERPROFILE/.gradle/caches/modules-2/files-2.1/org.lwjgl/$module/3.3.6" -Recurse -Filter "$module-3.3.6.jar" | Select-Object -First 1
    if (!$lib) { throw "Missing test dependency $module" }
    $cp += ";$($lib.FullName)"
}
& "$JavaHome/bin/javac.exe" --release 17 -cp $cp -d $output "$PSScriptRoot/BridgeDiscoveryTest.java"
if ($LASTEXITCODE -ne 0) { throw 'Bridge test compilation failed' }
$addon = Join-Path $root 'outputs/Visor-Android-Bridge-0.1.1.jar'
$services = Join-Path $output 'extra-provider/META-INF/services'
New-Item -ItemType Directory -Force $services | Out-Null
[IO.File]::WriteAllText((Join-Path $services 'me.phoenixra.atumvr.core.session.platform.AndroidXRBridge'), 'BridgeDiscoveryTest$ExtraBridge')
foreach ($mode in @('desktop','missing','single','duplicate')) {
    $classpath = $cp
    if ($mode -in @('single','duplicate')) { $classpath += ";$addon" }
    if ($mode -eq 'duplicate') { $classpath += ";$output/extra-provider" }
    & "$JavaHome/bin/java.exe" -cp $classpath BridgeDiscoveryTest $mode
    if ($LASTEXITCODE -ne 0) { throw "Bridge discovery test failed: $mode" }
}
