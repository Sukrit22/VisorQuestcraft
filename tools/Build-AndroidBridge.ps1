param([string]$JavaHome = 'C:\Program Files\Java\jdk-17')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$project = Join-Path $root 'sources/Visor-Android-Bridge'
$classes = Join-Path $project ('build/classes-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $classes | Out-Null
$fml = Get-ChildItem "$env:USERPROFILE/.gradle/caches/modules-2/files-2.1/net.minecraftforge/javafmllanguage/1.20.1-47.4.0" -Recurse -Filter '*.jar' | Select-Object -First 1
if (!$fml) { throw 'Build Forge 1.20.1 first to obtain its compile-only Mod annotation' }
$core = Join-Path $root 'sources/Visor-0.5.0/libs/atumvr-core-pico.jar'
$sources = @(Get-ChildItem "$project/src/main/java" -Recurse -Filter '*.java' | ForEach-Object FullName)
& "$JavaHome/bin/javac.exe" --release 17 -cp "$core;$($fml.FullName)" -d $classes @sources
if ($LASTEXITCODE -ne 0) { throw 'Android bridge compilation failed' }
$jar = Join-Path $root 'outputs/Visor-Android-Bridge-0.1.1.jar'
& "$JavaHome/bin/jar.exe" --create --file $jar -C $classes . -C "$project/src/main/resources" .
if ($LASTEXITCODE -ne 0) { throw 'Android bridge packaging failed' }
Get-FileHash -LiteralPath $jar
