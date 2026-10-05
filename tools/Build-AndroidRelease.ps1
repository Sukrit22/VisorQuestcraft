param(
    [ValidateSet('Pico','Quest','Both')][string]$Target = 'Both',
    [string]$JavaHome = 'C:\Program Files\Java\jdk-17',
    [string]$AndroidSdk = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$Gradle = 'C:\Users\Sukrit22\.gradle\wrapper\dists\gradle-8.10.2-all\7iv73wktx1xtkvlq19urqw1wm\gradle-8.10.2\bin\gradle.bat',
    [switch]$Offline
)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
if (!(Test-Path -LiteralPath "$JavaHome/bin/java.exe")) { throw 'Set -JavaHome to Java 17.' }
if (!(Test-Path -LiteralPath $Gradle)) { throw 'Set -Gradle to Gradle 8.10.2 gradle.bat.' }
$previousJava = $env:JAVA_HOME
$previousSdk = $env:ANDROID_HOME
try {
    $env:JAVA_HOME = $JavaHome
    $env:ANDROID_HOME = $AndroidSdk
    & "$PSScriptRoot/Stage-PicoAssets.ps1" -Offline:$Offline
    & $Gradle -p "$workspace/sources/Pojlib" assembleRelease --console=plain
    if ($LASTEXITCODE -ne 0) { throw 'Pojlib compilation failed; no APK packaging attempted.' }
    $targets = if ($Target -eq 'Both') { @('Pico','Quest') } else { @($Target) }
    foreach ($headset in $targets) {
        & "$PSScriptRoot/Build-AndroidApk.ps1" -Target $headset
        & "$PSScriptRoot/Verify-AndroidApk.ps1" -Target $headset
    }
} finally {
    $env:JAVA_HOME = $previousJava
    $env:ANDROID_HOME = $previousSdk
}
