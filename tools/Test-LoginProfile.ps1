$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$output = Join-Path $root 'build/login-profile-tests'
New-Item -ItemType Directory -Force "$output/stubs/android/util" | Out-Null
# Only Android's map implementation is substituted; exercise the actual compiled Msa method.
[IO.File]::WriteAllText("$output/stubs/android/util/ArrayMap.java", 'package android.util; public class ArrayMap<K,V> extends java.util.HashMap<K,V> {}')
$cp = "$output;$root/sources/Pojlib/build/intermediates/javac/release/classes"
foreach ($dependency in @('org.json/json/20220924','com.google.code.gson/gson/2.12.1','commons-io/commons-io/2.13.0')) {
    $jar = Get-ChildItem "$env:USERPROFILE/.gradle/caches/modules-2/files-2.1/$dependency" -Recurse -Filter '*.jar' | Select-Object -First 1
    if (!$jar) { throw "Missing $dependency" }
    $cp += ";$($jar.FullName)"
}
 $cp += ";$env:LOCALAPPDATA/Android/Sdk/platforms/android-34/android.jar"
$java = 'C:/Program Files/Java/jdk-17/bin'
& "$java/javac.exe" -cp $cp -d $output "$output/stubs/android/util/ArrayMap.java" "$PSScriptRoot/AuthProfileTest.java"
if ($LASTEXITCODE -ne 0) { throw 'Profile test compilation failed' }
& "$java/java.exe" -cp $cp AuthProfileTest
if ($LASTEXITCODE -ne 0) { throw 'Profile regression failed' }
