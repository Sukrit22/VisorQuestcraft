$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Visor-DownloadManifest.ps1"
$root = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('visor-manifest-tests-' + [Guid]::NewGuid().ToString('N'))
$passed = 0
function Expect-Failure([string]$Name, [scriptblock]$Action, [string]$Pattern) {
    try { & $Action } catch {
        if ($_.Exception.Message -notmatch $Pattern) { throw "Wrong failure for ${Name}: $_" }
        $script:passed++; Write-Host "PASS: $Name"; return
    }
    throw "Expected failure: $Name"
}
try {
    New-Item -ItemType Directory -Force "$testRoot/build-targets" | Out-Null
    $manifestPath = "$testRoot/build-targets/visor-downloads.json"
    Copy-Item "$root/build-targets/visor-downloads.json" $manifestPath
    $manifest = Get-VisorManifest $testRoot
    $manifest.artifacts[0].url = 'http://example.invalid/mod.jar'
    $manifest.artifacts[0].sha256 = 'a' * 64
    $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath
    Expect-Failure 'HTTP URL rejected' { Get-VisorManifest $testRoot } 'direct HTTPS'
    $manifest.artifacts[0].url = 'https://example.invalid/mod.jar'; $manifest.artifacts[0].sha256 = $null
    $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath
    Expect-Failure 'Remote URL without pin rejected' { Get-VisorManifest $testRoot } 'requires a pinned'
    $manifest.artifacts[0].sha256 = 'invalid'
    $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath
    Expect-Failure 'Malformed hash rejected' { Get-VisorManifest $testRoot } 'Invalid artifact SHA256'
    Copy-Item "$root/build-targets/visor-downloads.json" $manifestPath -Force
    $manifest = Get-VisorManifest $testRoot
    $forge = $manifest.artifacts[0]; $fabric = $manifest.artifacts[1]
    Expect-Failure 'Fabric JAR rejected for Forge slot' { Test-VisorArtifact (Join-Path $root $fabric.localPath) $forge } 'Forge metadata missing'
    Copy-Item (Join-Path $root $forge.localPath) "$testRoot/local.jar"
    $forge.localPath = 'local.jar'; $forge.url = 'https://example.invalid/mod.jar'; $forge.sha256 = '0' * 64
    Expect-Failure 'Offline fallback enforces pin' { Resolve-VisorArtifact $testRoot $forge $true } 'Artifact hash mismatch'
    $assets = "$testRoot/sources/Pojlib/src/main/assets"
    New-Item -ItemType Directory -Force $assets | Out-Null
    $receiptPath = "$assets/visor-downloads.staged.json"
    @{ schemaVersion=1; manifestSHA256=('0'*64); artifacts=@() } | ConvertTo-Json | Set-Content $receiptPath
    Expect-Failure 'Changed manifest rejected before archive read' { Assert-VisorArchive $testRoot "$testRoot/fake.aar" } 'manifest changed'
    $manifest = Get-VisorManifest $testRoot
    $receipt = [ordered]@{ schemaVersion=1; manifestSHA256=(Get-FileHash $manifestPath).Hash; artifacts=@() }
    foreach ($item in $manifest.artifacts) {
        $path = Join-Path $assets $item.asset
        New-Item -ItemType Directory -Force (Split-Path $path -Parent) | Out-Null
        Copy-Item (Join-Path $root $item.localPath) $path
        $receipt.artifacts += @{ id=$item.id; asset=$item.asset; sha256=(Get-FileHash $path).Hash }
    }
    $receipt | ConvertTo-Json -Depth 10 | Set-Content $receiptPath
    $zip = [IO.Compression.ZipFile]::Open("$testRoot/fake.aar", [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in (Get-ChildItem $assets -File -Recurse)) {
            $name = 'assets/' + [IO.Path]::GetRelativePath($assets, $file.FullName).Replace('\','/')
            $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $name, [IO.Compression.CompressionLevel]::NoCompression)
        }
    } finally { $zip.Dispose() }
    Assert-VisorArchive $testRoot "$testRoot/fake.aar"
    $passed++; Write-Host 'PASS: matching archive accepted'
    Add-Content $receiptPath ' '
    Expect-Failure 'Stale embedded receipt rejected' { Assert-VisorArchive $testRoot "$testRoot/fake.aar" } 'Stale staging receipt'
    Write-Host "PASS: $passed isolated manifest tests"
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if ((Split-Path $resolved -Parent) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') -or (Split-Path $resolved -Leaf) -notlike 'visor-manifest-tests-*') { throw 'Unsafe test cleanup path' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
