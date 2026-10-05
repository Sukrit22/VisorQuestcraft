param(
    [string]$JavaHome,
    [string]$Gradle
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'sources/Visor-0.6.0'
if (!$JavaHome) {
    $portable = Get-ChildItem (Join-Path $root 'build/java21-toolchain') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($portable) { $JavaHome = $portable.FullName } else { $JavaHome = $env:JAVA_HOME }
}
if (!$Gradle) {
    $portableGradle = Join-Path $root 'build/gradle-toolchain/gradle-9.7.1/bin/gradle.bat'
    $Gradle = if (Test-Path -LiteralPath $portableGradle) { $portableGradle } else { Join-Path $source 'gradlew.bat' }
}
if (!(Test-Path -LiteralPath "$JavaHome/bin/java.exe")) { throw 'Pass -JavaHome with a Java 21 JDK (the game target remains Java 17)' }
$previousJava = $env:JAVA_HOME
try {
    $env:JAVA_HOME = $JavaHome
    Push-Location $source
    try {
        & $Gradle ':visor-forge:1.20.1:buildAndCollect' ':visor-core:1.20.1:test' --configure-on-demand --max-workers=2 --console=plain
        if ($LASTEXITCODE -ne 0) { throw "Visor build failed: $LASTEXITCODE" }
    } finally { Pop-Location }
    $jar = Join-Path $source 'build/libs/Visor-0.6.0-alpha.2+mc1.20.1-forge.jar'
    $output = Join-Path $root 'outputs/Visor-0.6.0-alpha.2-android.1+mc1.20.1-forge.jar'
    Copy-Item -LiteralPath $jar -Destination $output
    & (Join-Path $PSScriptRoot 'Verify-VisorAndroid06.ps1') -Jar $output
} finally { $env:JAVA_HOME = $previousJava }
