param([string]$UnityEditor = 'E:\Unity\Hub\Editor\6000.4.10f1\Editor\Unity.exe')
& "$PSScriptRoot/Build-AndroidApk.ps1" -Target Quest -UnityEditor $UnityEditor
