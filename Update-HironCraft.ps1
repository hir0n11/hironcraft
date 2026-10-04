<#
.SYNOPSIS
    Updates the HironCraft addon in this folder from GitHub.
.DESCRIPTION
    Double-click Update-HironCraft.cmd, or run this script from PowerShell.
    It compares the installed version (HironCraft.toc) with the one on GitHub,
    downloads the newer one and copies it over the installed files. Settings
    are kept in the game's WTF folder and are not touched. Restart the game
    afterwards.
.PARAMETER Force
    Install even when the installed version is the same or newer.
.PARAMETER Clean
    Also delete files in the addon folder that are not part of the new version.
.PARAMETER Source
    A .zip or a folder to install from instead of GitHub.
.PARAMETER AddonPath
    The HironCraft addon folder; by default the folder this script is in.
#>
param(
    [switch]$Force,
    [switch]$Clean,
    [string]$Source = '',
    [string]$AddonPath = $PSScriptRoot,
    [string]$Repository = 'hir0n11/hironcraft',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Not part of an installed addon: the list scripts\Build.ps1 leaves out.
$developmentEntries = @('.git', '.gitignore', '.gitattributes', '.github', '.build', '.idea', '.vscode',
    'AGENTS.md', 'artwork', 'dist', 'scripts')

function Get-TocVersion([string]$TocPath) {
    $line = Get-Content -LiteralPath $TocPath | Where-Object { $_ -like '## Version:*' } | Select-Object -First 1
    if (-not $line) { return '' }
    return ($line -replace '^## Version:\s*', '').Trim()
}

# -1, 0 or 1: 0.4.9 is older than 0.4.10.
function Compare-Version([string]$Left, [string]$Right) {
    $a = @([regex]::Matches($Left, '\d+') | ForEach-Object { [int]$_.Value })
    $b = @([regex]::Matches($Right, '\d+') | ForEach-Object { [int]$_.Value })
    for ($index = 0; $index -lt [Math]::Max($a.Count, $b.Count); $index++) {
        $x = 0; if ($index -lt $a.Count) { $x = $a[$index] }
        $y = 0; if ($index -lt $b.Count) { $y = $b[$index] }
        if ($x -lt $y) { return -1 }
        if ($x -gt $y) { return 1 }
    }
    return 0
}

function Test-DevelopmentEntry([string]$Relative) {
    return $developmentEntries -contains ($Relative -split '[\\/]')[0]
}

$exitCode = 0
$temporary = $null
try {
    if (-not (Test-Path -LiteralPath $AddonPath -PathType Container)) { throw "The folder $AddonPath does not exist." }
    $addon = (Resolve-Path -LiteralPath $AddonPath).Path
    $toc = Join-Path $addon 'HironCraft.toc'
    if (-not (Test-Path -LiteralPath $toc)) {
        throw "HironCraft.toc was not found in $addon. Run this from the HironCraft addon folder."
    }
    if (Test-Path -LiteralPath (Join-Path $addon '.git')) {
        throw 'This folder is a git checkout. Update it with git pull.'
    }
    $installed = Get-TocVersion $toc
    Write-Host "Installed: HironCraft $installed"

    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('HironCraft-update-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $temporary | Out-Null

    $upToDate = $false
    if (-not $Source) {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $remoteToc = Join-Path $temporary 'remote.toc'
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$Repository/$Branch/HironCraft.toc" `
            -OutFile $remoteToc -UseBasicParsing
        $available = Get-TocVersion $remoteToc
        if (-not $available) { throw 'Could not read the version on GitHub.' }
        Write-Host "On GitHub: HironCraft $available"
        if (-not $Force -and (Compare-Version $available $installed) -le 0) {
            $upToDate = $true
        }
        else {
            $Source = Join-Path $temporary 'download.zip'
            Write-Host 'Downloading...'
            Invoke-WebRequest -Uri "https://github.com/$Repository/archive/refs/heads/$Branch.zip" `
                -OutFile $Source -UseBasicParsing
        }
    }

    if (-not $upToDate) {
        if (-not (Test-Path -LiteralPath $Source)) { throw "$Source does not exist." }
        if (Test-Path -LiteralPath $Source -PathType Container) {
            $tree = (Resolve-Path -LiteralPath $Source).Path
        }
        else {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $tree = Join-Path $temporary 'unpacked'
            [IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path -LiteralPath $Source).Path, $tree)
        }
        # GitHub puts everything into one folder named after the repository and branch.
        if (-not (Test-Path -LiteralPath (Join-Path $tree 'HironCraft.toc'))) {
            $inner = @(Get-ChildItem -LiteralPath $tree -Directory |
                Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'HironCraft.toc') })
            if ($inner.Count -ne 1) { throw 'The download does not contain HironCraft.' }
            $tree = $inner[0].FullName
        }

        # Nothing is touched unless the new version is complete.
        $newToc = Join-Path $tree 'HironCraft.toc'
        $version = Get-TocVersion $newToc
        if (-not $version) { throw 'The download has no version.' }
        foreach ($line in Get-Content -LiteralPath $newToc) {
            $entry = $line.Trim()
            if ($entry -and -not $entry.StartsWith('#') -and -not (Test-Path -LiteralPath (Join-Path $tree $entry))) {
                throw "The download is incomplete: $entry is missing."
            }
        }
        if (-not $Force -and (Compare-Version $version $installed) -le 0) { $upToDate = $true }
    }

    if ($upToDate) {
        Write-Host 'HironCraft is up to date.' -ForegroundColor Green
    }
    else {
        $prefix = $tree.TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
        $files = @(Get-ChildItem -LiteralPath $tree -File -Recurse -Force |
            Where-Object { -not (Test-DevelopmentEntry $_.FullName.Substring($prefix.Length)) })
        # The .toc goes last: an interrupted update still reports the old version and is done again.
        $ordered = @($files | Where-Object { $_.FullName.Substring($prefix.Length) -ne 'HironCraft.toc' }) +
            @($files | Where-Object { $_.FullName.Substring($prefix.Length) -eq 'HironCraft.toc' })
        $installedFiles = @{}
        $failed = @()
        foreach ($file in $ordered) {
            $relative = $file.FullName.Substring($prefix.Length)
            $installedFiles[$relative.ToLowerInvariant()] = $true
            if ($relative -eq 'HironCraft.toc' -and $failed.Count -gt 0) { break }
            $target = Join-Path $addon $relative
            try {
                $directory = Split-Path -Parent $target
                if (-not (Test-Path -LiteralPath $directory)) {
                    New-Item -ItemType Directory -Path $directory -Force | Out-Null
                }
                [IO.File]::Copy($file.FullName, $target, $true)
            }
            catch {
                $failed += $relative
            }
        }
        if ($failed.Count -gt 0) {
            throw ("Could not write $($failed.Count) file(s), for example $($failed[0]). " +
                'Close the game and run the update again.')
        }

        $removed = 0
        if ($Clean) {
            $addonPrefix = $addon.TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
            foreach ($file in @(Get-ChildItem -LiteralPath $addon -File -Recurse -Force)) {
                $relative = $file.FullName.Substring($addonPrefix.Length)
                if (-not (Test-DevelopmentEntry $relative) -and -not $installedFiles.ContainsKey($relative.ToLowerInvariant())) {
                    Remove-Item -LiteralPath $file.FullName -Force
                    $removed++
                }
            }
        }

        $summary = "HironCraft updated: $installed -> $version ($($ordered.Count) files"
        if ($removed -gt 0) { $summary += ", $removed old removed" }
        Write-Host ($summary + ').') -ForegroundColor Green
        if (Get-Process -Name 'Wow', 'WowT', 'WowB' -ErrorAction SilentlyContinue) {
            Write-Host 'World of Warcraft is running: restart the game to load the new version.' -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host ('HironCraft update failed: ' + $_.Exception.Message) -ForegroundColor Red
    $exitCode = 1
}
finally {
    if ($temporary -and (Test-Path -LiteralPath $temporary)) {
        $resolved = [IO.Path]::GetFullPath($temporary)
        $systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolved.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $resolved).StartsWith('HironCraft-update-')) {
            Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
exit $exitCode
