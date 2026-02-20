<#
.SYNOPSIS
    Remove all build artefacts from the workspace.
#>

[CmdletBinding()]
param(
    [switch]$WhatIf
)

$Root = Resolve-Path "$PSScriptRoot\.."

Write-Host "`nCleaning build artefacts under: $Root" -ForegroundColor Yellow
Write-Host ""

# Folders to delete entirely
$FoldersToRemove = @(
    'Package\Win32',
    'Package\Win64',
    'Package\__history',
    'Package\__recovery',
    'Src\**\__history',
    'Src\**\__recovery',
    'Tests\**\Win32',
    'Tests\**\Win64'
)

# File extensions to delete recursively
$ExtensionsToRemove = @(
    '*.dcu',
    '*.dcp',
    '*.bpl',
    '*.exe',
    '*.dll',
    '*.map',
    '*.drc',
    '*.stat'
)

$Removed = 0

foreach ($RelPath in $FoldersToRemove) {
    $Matches = Get-ChildItem -Path $Root -Filter ($RelPath.Split('\')[-1]) -Recurse -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -like "*$($RelPath.Replace('**\','').Replace('\','*'))*" }
    foreach ($Item in $Matches) {
        Write-Host "  [DIR ] $($Item.FullName)" -ForegroundColor Gray
        if (-not $WhatIf) { Remove-Item $Item.FullName -Recurse -Force -ErrorAction SilentlyContinue }
        $Removed++
    }
}

foreach ($Ext in $ExtensionsToRemove) {
    $Files = Get-ChildItem -Path $Root -Filter $Ext -Recurse -File -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -notlike '*\.git\*' }
    foreach ($File in $Files) {
        Write-Host "  [FILE] $($File.FullName)" -ForegroundColor Gray
        if (-not $WhatIf) { Remove-Item $File.FullName -Force -ErrorAction SilentlyContinue }
        $Removed++
    }
}

if ($WhatIf) {
    Write-Host "`n  [DRY RUN] $Removed item(s) would be removed.`n" -ForegroundColor Cyan
} else {
    Write-Host "`n  [OK] $Removed item(s) removed.`n" -ForegroundColor Green
}
