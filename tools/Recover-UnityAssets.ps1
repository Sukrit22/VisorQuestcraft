$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $workspace 'sources/QCXR-XR-Wrapper'
$tree = Get-Content "$workspace/downloads/wrapper-tree.json" -Raw | ConvertFrom-Json
$missing = @($tree.tree | Where-Object {
    $_.type -eq 'blob' -and $_.path -match '^(Assets|Packages|ProjectSettings)/' -and
    !(Test-Path -LiteralPath (Join-Path $destination $_.path)) -and
    $_.path -ne 'Assets/Plugins/Android/Pojlib-release.aar'
})
$results = $missing | ForEach-Object -ThrottleLimit 16 -Parallel {
    $item = $_
    $target = Join-Path $using:destination $item.path
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    $url = 'https://raw.githubusercontent.com/coah80/QCXR-XR-Wrapper/c9d110bab8a24801351107a220802befbf43428c/' + (($item.path.Split('/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
    try {
        & curl.exe --http1.1 --silent --show-error --fail --retry 2 --connect-timeout 20 --max-time 3600 --speed-limit 1024 --speed-time 90 $url -o "$target.partial"
        if ($LASTEXITCODE -ne 0) { throw "Download exit $LASTEXITCODE" }
        $bytes = [IO.File]::ReadAllBytes("$target.partial")
        $prefix = [Text.Encoding]::UTF8.GetBytes("blob $($bytes.Length)`0")
        $sha = [Security.Cryptography.SHA1]::Create()
        $hash = [Convert]::ToHexString($sha.ComputeHash($prefix + $bytes)).ToLowerInvariant()
        $sha.Dispose()
        if ($hash -ne $item.sha) { throw 'Git blob checksum mismatch' }
        Move-Item -LiteralPath "$target.partial" -Destination $target
        [pscustomobject]@{path=$item.path;ok=$true;error=''}
    } catch { [pscustomobject]@{path=$item.path;ok=$false;error=$_.Exception.Message} }
}
$results | ConvertTo-Json | Set-Content "$workspace/downloads/wrapper-recovery-results.json"
$failed = @($results | Where-Object {!$_.ok})
Write-Host "Recovered $($results.Count - $failed.Count) files; $($failed.Count) failed."
if ($failed.Count) { $failed | Format-List; throw 'Some Unity assets could not be recovered. Rerun to retry missing files.' }
