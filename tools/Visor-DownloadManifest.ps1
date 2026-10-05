$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Get-VisorManifest($Workspace) {
    $path = Join-Path $Workspace 'build-targets/visor-downloads.json'
    $manifest = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 1) { throw 'Unsupported Visor download manifest schema' }
    $expected = @{ forge05='forge|0.5.0|mods/forge/Visor-0.5.0-android-forge.1.jar'; fabric05='fabric|0.5.0|mods/fabric/Visor-0.5.0-android-fabric.1.jar'; forge06='forge|0.6.0-alpha.2|mods/forge/Visor-0.6.0-alpha.2-android.1+mc1.20.1-forge.jar'; bridge='both|0.1.1|mods/android/Visor-Android-Bridge-0.1.1.jar' }
    $seen = @{}
    foreach ($item in $manifest.artifacts) {
        if ($seen.ContainsKey($item.id) -or !$expected.ContainsKey($item.id) -or "$($item.loader)|$($item.version)|$($item.asset)" -ne $expected[$item.id]) { throw "Invalid artifact definition: $($item.id)" }
        $seen[$item.id] = $true
        if ($item.sha256 -and $item.sha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid artifact SHA256' }
        if ($item.url) {
            $uri = [Uri]$item.url
            if (!$uri.IsAbsoluteUri -or $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Fragment) { throw 'Artifact URLs must be direct HTTPS URLs without credentials or fragments' }
            if ($item.sha256 -notmatch '^[a-fA-F0-9]{64}$') { throw "Remote artifact $($item.id) requires a pinned SHA256" }
        }
    }
    if ($seen.Count -ne $expected.Count) { throw 'Manifest must contain all four Android artifacts' }
    return $manifest
}
function Test-VisorArtifact($Path, $Item) {
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $required = if ($Item.id -eq 'bridge') { @('org/vmstudio/visor/android/QuestAndroidXRBridge.class','org/vmstudio/visor/android/QuestVLoader.class') } else { @('me/phoenixra/atumvr/core/session/platform/XRPlatform.class','org/lwjgl/openxr/XrGraphicsBindingOpenGLESAndroidKHR.class','org/lwjgl/openxr/XrInstanceCreateInfoAndroidKHR.class') }
        foreach ($entry in $required) { if (!$zip.GetEntry($entry)) { throw "Missing Android signature in $($Item.id): $entry" } }
        if ($Item.id -in @('forge05','fabric05')) {
            foreach ($entry in @('me/phoenixra/atumvr/core/session/platform/AndroidXRBridge.class','me/phoenixra/atumvr/core/session/platform/XRPlatform$Android.class')) {
                if (!$zip.GetEntry($entry)) { throw "Missing split Android backend signature: $entry" }
            }
            if ($zip.GetEntry('org/vmstudio/visor/core/client/provider/openxr/QuestAndroidXRBridge.class') -or $zip.GetEntry('org/vmstudio/visor/core/client/provider/openxr/QuestVLoader.class') -or $zip.GetEntry('org/vmstudio/visor/android/QuestVLoader.class')) { throw 'Visor 0.5 must use the split bridge, not own launcher bridge classes' }
        }
        $modId = if ($Item.id -eq 'bridge') { 'visor_android_bridge' } else { 'visor' }
        if ($Item.loader -in @('forge','both')) {
            $entry = $zip.GetEntry('META-INF/mods.toml'); if (!$entry) { throw 'Forge metadata missing' }
            $reader = [IO.StreamReader]::new($entry.Open()); try { $metadata = $reader.ReadToEnd() } finally { $reader.Dispose() }
            if ($metadata -notmatch ('(?m)^modId\s*=\s*"' + [regex]::Escape($modId) + '"\s*$') -or $metadata -notmatch ('(?m)^version\s*=\s*"' + [regex]::Escape($Item.version) + '"\s*$')) { throw "Incorrect Forge ID/version: $($Item.id)" }
        }
        if ($Item.loader -in @('fabric','both')) {
            $entry = $zip.GetEntry('fabric.mod.json'); if (!$entry) { throw 'Fabric metadata missing' }
            $reader = [IO.StreamReader]::new($entry.Open()); try { $metadata = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
            if ($metadata.id -ne $modId -or $metadata.version -ne $Item.version) { throw "Incorrect Fabric ID/version: $($Item.id)" }
            if ($Item.id -eq 'fabric05' -and !($zip.Entries.FullName -match 'META-INF/jars/fabric-api-')) { throw 'Full Fabric API bundle missing' }
        }
        if ($zip.Entries.FullName -match 'natives-(windows|linux)|\.(dll|dylib)$') { throw 'Desktop native libraries bundled' }
    } finally { $zip.Dispose() }
    if ($Item.id -eq 'forge06') { & (Join-Path $PSScriptRoot 'Verify-VisorAndroid06.ps1') -Jar $Path | Out-Null }
}
function Resolve-VisorArtifact($Workspace, $Item, [bool]$Offline) {
    if (!$Item.url -or $Offline) {
        $path = [IO.Path]::GetFullPath((Join-Path $Workspace $Item.localPath))
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Build local artifact first: $($Item.localPath)" }
    } else {
        $cache = Join-Path $Workspace 'downloads/visor'; New-Item -ItemType Directory -Force $cache | Out-Null
        $path = Join-Path $cache ($Item.sha256.ToLowerInvariant() + '.jar')
        if (!(Test-Path -LiteralPath $path)) {
            $partial = "$path.$([Guid]::NewGuid().ToString('N')).partial"
            try {
                # GitHub release assets redirect to their CDN; validate every hop before requesting it.
                $handler = [Net.Http.HttpClientHandler]::new(); $handler.AllowAutoRedirect = $false
                $client = [Net.Http.HttpClient]::new($handler)
                $timeout = [Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(120))
                try {
                    $uri = [Uri]$Item.url
                    for ($hop = 0; $hop -le 10; $hop++) {
                        if ($uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Fragment) { throw 'Unsafe artifact redirect' }
                        $response = $client.GetAsync($uri, [Net.Http.HttpCompletionOption]::ResponseHeadersRead, $timeout.Token).GetAwaiter().GetResult()
                        try {
                            if ([int]$response.StatusCode -in @(301,302,303,307,308)) {
                                if (!$response.Headers.Location -or $hop -eq 10) { throw 'Invalid or excessive artifact redirects' }
                                $uri = [Uri]::new($uri, $response.Headers.Location)
                                continue
                            }
                            $null = $response.EnsureSuccessStatusCode()
                            $maxBytes = 64MB
                            if ($response.Content.Headers.ContentLength -gt $maxBytes) { throw 'Artifact exceeds 64 MiB download limit' }
                            $stream = [IO.File]::Create($partial)
                            $body = $response.Content.ReadAsStreamAsync($timeout.Token).GetAwaiter().GetResult()
                            try {
                                $buffer = [byte[]]::new(65536); $total = 0L
                                while (($count = $body.ReadAsync($buffer, 0, $buffer.Length, $timeout.Token).GetAwaiter().GetResult()) -gt 0) {
                                    $total += $count
                                    if ($total -gt $maxBytes) { throw 'Artifact exceeds 64 MiB download limit' }
                                    $stream.Write($buffer, 0, $count)
                                }
                            } finally { $body.Dispose(); $stream.Dispose() }
                            break
                        } finally { $response.Dispose() }
                    }
                } finally { $timeout.Dispose(); $client.Dispose(); $handler.Dispose() }
                if ((Get-FileHash -LiteralPath $partial).Hash -ne $Item.sha256) { throw "Downloaded hash mismatch: $($Item.id)" }
                Move-Item -LiteralPath $partial -Destination $path
            } finally { if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial } }
        }
    }
    if ($Item.sha256 -and (Get-FileHash -LiteralPath $path).Hash -ne $Item.sha256) { throw "Artifact hash mismatch: $($Item.id)" }
    Test-VisorArtifact $path $Item
    return $path
}
function Assert-VisorArchive($Workspace, $ArchivePath) {
    $manifest = Get-VisorManifest $Workspace
    $assets = Join-Path $Workspace 'sources/Pojlib/src/main/assets'
    $receiptPath = Join-Path $assets 'visor-downloads.staged.json'
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    if ($receipt.manifestSHA256 -ne (Get-FileHash (Join-Path $Workspace 'build-targets/visor-downloads.json')).Hash) { throw 'Download manifest changed. Restage assets and rebuild Pojlib assembleRelease.' }
    if (@($receipt.artifacts).Count -ne @($manifest.artifacts).Count) { throw 'Incomplete staging receipt. Restage assets.' }
    foreach ($definition in $manifest.artifacts) {
        $records = @($receipt.artifacts | Where-Object { $_.id -eq $definition.id -and $_.asset -eq $definition.asset -and $_.sha256 -match '^[a-fA-F0-9]{64}$' })
        if ($records.Count -ne 1) { throw "Invalid staging receipt for $($definition.id)" }
        Test-VisorArtifact (Join-Path $assets $definition.asset) $definition
    }
    $zip = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        foreach ($item in $receipt.artifacts) {
            if ((Get-FileHash (Join-Path $assets $item.asset)).Hash -ne $item.sha256) { throw 'Staged artifact changed. Restage and rebuild Pojlib.' }
            $entry = $zip.GetEntry('assets/' + $item.asset); if (!$entry) { throw "Archive missing $($item.asset). Rebuild Pojlib." }
            $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
            try { $hash = [Convert]::ToHexString($sha.ComputeHash($stream)) } finally { $stream.Dispose(); $sha.Dispose() }
            if ($hash -ne $item.sha256) { throw "Stale archive artifact: $($item.asset). Rebuild Pojlib assembleRelease." }
        }
        $entry = $zip.GetEntry('assets/visor-downloads.staged.json'); if (!$entry) { throw 'Staging receipt missing. Restage and rebuild Pojlib.' }
        $reader = [IO.StreamReader]::new($entry.Open()); try { $embedded = $reader.ReadToEnd() } finally { $reader.Dispose() }
        if ($embedded -ne (Get-Content $receiptPath -Raw)) { throw 'Stale staging receipt. Rebuild Pojlib assembleRelease.' }
    } finally { $zip.Dispose() }
}
