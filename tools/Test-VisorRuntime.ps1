param([string]$JavaHome = 'C:\Program Files\Java\jdk-17')
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$gson = Get-ChildItem "$env:USERPROFILE/.gradle/caches/modules-2/files-2.1/com.google.code.gson/gson" -Recurse -Filter '*.jar' | Select-Object -First 1
if (!$gson) { throw 'A Gson jar is required in the local Gradle cache' }
$output = Join-Path $workspace 'build/visor-runtime-tests'
New-Item -ItemType Directory -Force $output | Out-Null
# The host harness isolates networking/ZIP policy from Android instance dependencies.
$stub = Join-Path $output 'MinecraftInstances.java'
Set-Content -LiteralPath $stub -Encoding ASCII -Value 'package pojlib.util.json; public class MinecraftInstances { public static class Instance { public String gameDir, modLoader, visorUrl, visorSha256; public String getModLoader(){ return modLoader; } } }'
$source = Join-Path $workspace 'sources/Pojlib/src/main/java/pojlib/install'
& "$JavaHome/bin/javac.exe" --release 8 -cp $gson.FullName -d $output "$source/VisorRuntime.java" "$source/CustomVisor.java" $stub "$PSScriptRoot/VisorRuntimeTest.java"
if ($LASTEXITCODE -ne 0) { throw 'Runtime test compilation failed' }
& "$JavaHome/bin/java.exe" -cp "$output;$($gson.FullName)" VisorRuntimeTest $workspace
if ($LASTEXITCODE -ne 0) { throw 'Runtime tests failed' }
