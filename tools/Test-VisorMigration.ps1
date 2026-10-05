param([string]$JavaHome = 'C:\Program Files\Java\jdk-17')
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$classes = Join-Path $workspace 'sources/Pojlib/build/intermediates/javac/release/classes'
if (!(Test-Path "$classes/pojlib/install/Installer.class")) { throw 'Compile Pojlib release Java first' }
$gson = Get-ChildItem "$env:USERPROFILE/.gradle/caches/modules-2/files-2.1/com.google.code.gson/gson" -Recurse -Filter '*.jar' | Select-Object -First 1
$io = Get-ChildItem "$env:USERPROFILE/.gradle/caches/modules-2/files-2.1/commons-io/commons-io" -Recurse -Filter '*.jar' | Select-Object -First 1
$android = "$env:LOCALAPPDATA/Android/Sdk/platforms/android-34/android.jar"
$output = Join-Path $workspace 'build/visor-migration-tests'
New-Item -ItemType Directory -Force $output | Out-Null
# Only Android asset I/O is faked. Installer, FileUtil, Instance and validators are compiled production classes.
Set-Content "$output/Context.java" -Encoding ASCII 'package android.content; public class Context { protected android.content.res.AssetManager assets; public android.content.res.AssetManager getAssets(){return assets;} }'
Set-Content "$output/Activity.java" -Encoding ASCII 'package android.app; public class Activity extends android.content.Context { public Activity(java.io.File root){assets=new android.content.res.AssetManager(root);} }'
Set-Content "$output/AssetManager.java" -Encoding ASCII 'package android.content.res; public class AssetManager { private final java.io.File root; public AssetManager(java.io.File root){this.root=root;} public java.io.InputStream open(String path) throws java.io.IOException {return new java.io.FileInputStream(new java.io.File(root,path));} }'
$cp = "$classes;$($gson.FullName);$($io.FullName);$android"
& "$JavaHome/bin/javac.exe" --release 8 -cp $cp -d $output "$output/Context.java" "$output/Activity.java" "$output/AssetManager.java" "$PSScriptRoot/VisorMigrationTest.java"
if ($LASTEXITCODE -ne 0) { throw 'Migration test compilation failed' }
& "$JavaHome/bin/java.exe" -cp "$output;$cp" VisorMigrationTest $workspace
if ($LASTEXITCODE -ne 0) { throw 'Migration tests failed' }
