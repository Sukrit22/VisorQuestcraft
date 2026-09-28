param([string]$JavaHome = 'C:\Program Files\Java\jdk-17')
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$gson = Get-ChildItem "$env:USERPROFILE/.gradle/caches/modules-2/files-2.1/com.google.code.gson/gson" -Recurse -Filter '*.jar' | Select-Object -First 1
if (!$gson) { throw 'A Gson jar is required in the local Gradle cache' }
$output = Join-Path $workspace 'build/forge-tests'
New-Item -ItemType Directory -Force $output | Out-Null
$source = Join-Path $workspace 'sources/Pojlib/src/main/java/pojlib/install'
& "$JavaHome/bin/javac.exe" --release 8 -cp $gson.FullName -d $output "$source/ForgeProfile.java" "$source/ForgeMods.java" "$PSScriptRoot/ForgePortTest.java"
if ($LASTEXITCODE -ne 0) { throw 'Forge test compilation failed' }
& "$JavaHome/bin/java.exe" -cp "$output;$($gson.FullName)" ForgePortTest "$workspace/downloads/forge-1.20.1-47.4.20-installer.jar"
if ($LASTEXITCODE -ne 0) { throw 'Forge port tests failed' }

