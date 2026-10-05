param([string]$JavaHome = 'C:\Program Files\Java\jdk-17', [switch]$Live)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$classes = Join-Path $workspace 'sources/Pojlib/build/intermediates/javac/release/classes'
if (!(Test-Path "$classes/pojlib/install/FabricLoaderProfile.class")) { throw 'Compile Pojlib release Java first' }
$gson = Get-ChildItem "$env:USERPROFILE/.gradle/caches/modules-2/files-2.1/com.google.code.gson/gson" -Recurse -Filter '*.jar' | Select-Object -First 1
$android = "$env:LOCALAPPDATA/Android/Sdk/platforms/android-34/android.jar"
$output = Join-Path $workspace 'build/fabric-loader-tests'
New-Item -ItemType Directory -Force $output | Out-Null
$cp = "$classes;$($gson.FullName);$android"
& "$JavaHome/bin/javac.exe" --release 8 -cp $cp -d $output "$PSScriptRoot/FabricLoaderProfileTest.java"
if ($LASTEXITCODE -ne 0) { throw 'Fabric Loader test compilation failed' }
if ($Live) { & "$JavaHome/bin/java.exe" -cp "$output;$cp" pojlib.install.FabricLoaderProfileTest $workspace --live }
else { & "$JavaHome/bin/java.exe" -cp "$output;$cp" pojlib.install.FabricLoaderProfileTest $workspace }
if ($LASTEXITCODE -ne 0) { throw 'Fabric Loader tests failed' }
