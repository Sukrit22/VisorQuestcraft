param()
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$lock = Get-Content "$workspace/source-lock.json" -Raw | ConvertFrom-Json
function Invoke-SourceGit([string[]]$Arguments) {
    & git @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'Source Git operation failed. Existing checkout preserved; inspect the output above.' }
}
New-Item -ItemType Directory -Force "$workspace/sources","$workspace/downloads" | Out-Null
foreach ($component in $lock.components) {
    $directory = Join-Path "$workspace/sources" $component.directory
    if (!(Test-Path -LiteralPath $directory)) {
        Invoke-SourceGit @('clone','--filter=blob:none','--no-checkout','--origin','upstream',$component.repository,$directory)
        Invoke-SourceGit @('-C',$directory,'checkout','--detach',$component.commit)
    }
    $head = & git -C $directory rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $head -ne $component.commit) { throw "Unexpected base in $directory. Use a fresh checkout or update source-lock.json deliberately." }
    $patch = Join-Path $workspace $component.patch
    & git -C $directory apply --reverse --check $patch 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "$($component.directory): source patch already applied"; continue }
    Invoke-SourceGit @('-C',$directory,'apply','--check',$patch)
    Invoke-SourceGit @('-C',$directory,'apply',$patch)
}
$bridge = "$workspace/sources/Visor-Android-Bridge"
if (!(Test-Path -LiteralPath $bridge)) {
    Copy-Item -LiteralPath "$workspace/bridge-source" -Destination $bridge -Recurse
} else { Write-Host 'Existing companion source preserved. Update it explicitly from bridge-source if needed.' }
# The inherited Android OpenXR binding is a pinned input from Coah's fork.
$bindingCheckout = "$workspace/sources/Visor"
if (!(Test-Path -LiteralPath $bindingCheckout)) {
    Invoke-SourceGit @('clone','--filter=blob:none','--no-checkout','--origin','upstream',$lock.androidBindings.repository,$bindingCheckout)
    Invoke-SourceGit @('-C',$bindingCheckout,'checkout','--detach',$lock.androidBindings.commit)
}
$bindingHead = & git -C $bindingCheckout rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $bindingHead -ne $lock.androidBindings.commit) { throw 'Unexpected Coah binding source revision.' }
foreach ($visor in @('Visor-0.5.0','Visor-0.6.0')) {
    New-Item -ItemType Directory -Force "$workspace/sources/$visor/libs" | Out-Null
    $target = "$workspace/sources/$visor/libs/lwjgl-openxr-quest-3.3.3.jar"
    if (!(Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath (Join-Path $bindingCheckout $lock.androidBindings.path) -Destination $target }
}
# Existing packaging/recovery tools use this source inventory, not GitHub API discovery.
$treeLines = & git -C "$workspace/sources/QCXR-XR-Wrapper" ls-tree -r --full-tree HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot create Unity source inventory.' }
$entries = @($treeLines | ForEach-Object {
    if ($_ -match '^\d+ (\w+) ([0-9a-f]+)\t(.+)$') {
        [ordered]@{type=$Matches[1];sha=$Matches[2];path=$Matches[3].Trim('"')}
    }
})
@{tree=$entries} | ConvertTo-Json -Depth 5 | Set-Content "$workspace/downloads/wrapper-tree.json" -Encoding utf8NoBOM
Write-Host 'Source restored. Build AtumVR dependencies, Visor cores and companion before staging and packaging; see SOURCE-WORKFLOW.md.'
