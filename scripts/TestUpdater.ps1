# Update-HironCraft.ps1 against a local copy of the repository, packed the way
# GitHub packs a branch. Nothing is downloaded and nothing outside a temporary
# folder is touched.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projectRoot = Split-Path -Parent $PSScriptRoot
$updater = Join-Path $projectRoot 'Update-HironCraft.ps1'
$currentVersion = ((Get-Content -LiteralPath (Join-Path $projectRoot 'HironCraft.toc') |
    Where-Object { $_ -like '## Version:*' } | Select-Object -First 1) -replace '^## Version:\s*', '').Trim()

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('HironCraft-updater-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $testRoot | Out-Null

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "TestUpdater: $Message" }
}

# The updater in its own process, as the launcher runs it. Returns the exit code.
function Invoke-Updater([string[]]$Arguments) {
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $updater @Arguments 2>&1 | ForEach-Object { "$_" }
    $script:lastOutput = ($output -join "`n")
    return $LASTEXITCODE
}

# An installed copy as an old version leaves it, with something of the user's.
function New-Install([string]$Name, [string]$Version) {
    $addon = Join-Path (Join-Path $testRoot $Name) 'HironCraft'
    New-Item -ItemType Directory -Path (Join-Path $addon 'Customer') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $addon 'Old') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $addon 'HironCraft.toc') -Value @('## Interface: 120100', "## Version: $Version", 'Old\Gone.lua') -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $addon 'Customer\AnalyticsLog.lua') -Value '-- an old file' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $addon 'Old\Gone.lua') -Value '-- removed since' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $addon 'notes.txt') -Value 'mine' -Encoding ASCII
    return $addon
}

function Get-Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

$passed = $false
try {
    # The repository as GitHub serves a branch: one folder holding everything tracked.
    $staging = Join-Path $testRoot 'staging\hironcraft-main'
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    Get-ChildItem -LiteralPath $projectRoot -Force |
        Where-Object { $_.Name -notin @('.git', 'dist', '.build') } |
        Copy-Item -Destination $staging -Recurse -Force
    $zipPath = Join-Path $testRoot 'hironcraft-main.zip'
    $zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $stagingRoot = (Join-Path $testRoot 'staging') + [IO.Path]::DirectorySeparatorChar
        foreach ($file in Get-ChildItem -LiteralPath $staging -File -Recurse -Force) {
            $name = $file.FullName.Substring($stagingRoot.Length).Replace('\', '/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $name) | Out-Null
        }
    }
    finally { $zip.Dispose() }

    # An older install is brought to the current version.
    $addon = New-Install 'old' '0.0.1'
    Assert ((Invoke-Updater @('-Source', $zipPath, '-AddonPath', $addon)) -eq 0) "update failed: $lastOutput"
    Assert ($lastOutput -match [regex]::Escape("0.0.1 -> $currentVersion")) "no summary: $lastOutput"
    $toc = Get-Content -LiteralPath (Join-Path $addon 'HironCraft.toc')
    Assert (($toc -join "`n") -match [regex]::Escape("## Version: $currentVersion")) 'the version was not updated'
    foreach ($line in $toc) {
        $entry = $line.Trim()
        if ($entry -and -not $entry.StartsWith('#')) {
            Assert (Test-Path -LiteralPath (Join-Path $addon $entry)) "a listed file is missing: $entry"
        }
    }
    Assert ((Get-Hash (Join-Path $addon 'Customer\AnalyticsLog.lua')) -eq (Get-Hash (Join-Path $projectRoot 'Customer\AnalyticsLog.lua'))) 'an old file was not replaced'
    foreach ($name in @('Update-HironCraft.ps1', 'Update-HironCraft.cmd', 'README.md', 'Media\WhisperAlert.ogg')) {
        Assert ((Get-Hash (Join-Path $addon $name)) -eq (Get-Hash (Join-Path $projectRoot $name))) "not installed intact: $name"
    }
    foreach ($name in @('scripts', 'AGENTS.md', 'artwork', '.gitignore', 'dist')) {
        Assert (-not (Test-Path -LiteralPath (Join-Path $addon $name))) "a development entry was installed: $name"
    }
    # The same files a release archive holds, nothing less.
    $expected = @(Get-ChildItem -LiteralPath $staging -File -Recurse -Force | Where-Object {
            ($_.FullName.Substring($staging.Length + 1) -split '[\\/]')[0] -notin
                @('.gitignore', '.gitattributes', '.github', '.idea', '.vscode', 'AGENTS.md', 'artwork', 'scripts')
        }).Count
    $actual = @(Get-ChildItem -LiteralPath $addon -File -Recurse -Force).Count
    Assert ($actual -eq $expected + 2) "installed $actual files, expected $expected and the two left from before"
    Assert ((Get-Content -LiteralPath (Join-Path $addon 'notes.txt')) -eq 'mine') 'a file of the user was touched'
    Assert (Test-Path -LiteralPath (Join-Path $addon 'Old\Gone.lua')) 'an old file was removed without -Clean'

    # The same version again: nothing is copied.
    Set-Content -LiteralPath (Join-Path $addon 'Bootstrap.lua') -Value '-- edited' -Encoding ASCII
    Assert ((Invoke-Updater @('-Source', $zipPath, '-AddonPath', $addon)) -eq 0) "second run failed: $lastOutput"
    Assert ($lastOutput -match 'up to date') "no up-to-date message: $lastOutput"
    Assert ((Get-Content -LiteralPath (Join-Path $addon 'Bootstrap.lua')) -eq '-- edited') 'an up-to-date install was rewritten'

    # -Force reinstalls, -Clean removes what the new version does not have.
    Assert ((Invoke-Updater @('-Source', $zipPath, '-AddonPath', $addon, '-Force', '-Clean')) -eq 0) "forced run failed: $lastOutput"
    Assert ((Get-Hash (Join-Path $addon 'Bootstrap.lua')) -eq (Get-Hash (Join-Path $projectRoot 'Bootstrap.lua'))) '-Force did not reinstall'
    Assert (-not (Test-Path -LiteralPath (Join-Path $addon 'Old\Gone.lua'))) '-Clean left an old file'
    Assert ($lastOutput -match '2 old removed') "no removal count: $lastOutput"

    # A newer install is not downgraded.
    $newer = New-Install 'newer' '9.9.9'
    Assert ((Invoke-Updater @('-Source', $zipPath, '-AddonPath', $newer)) -eq 0) "newer install: $lastOutput"
    Assert ((Get-Content -LiteralPath (Join-Path $newer 'Customer\AnalyticsLog.lua')) -eq '-- an old file') 'a newer install was downgraded'

    # A folder works as a source too.
    $fromFolder = New-Install 'folder' '0.0.1'
    Assert ((Invoke-Updater @('-Source', $staging, '-AddonPath', $fromFolder)) -eq 0) "folder source failed: $lastOutput"
    Assert (Test-Path -LiteralPath (Join-Path $fromFolder 'Customer\AnalyticsProfiles.lua')) 'nothing installed from a folder'

    # A git checkout is never overwritten.
    $checkout = New-Install 'checkout' '0.0.1'
    New-Item -ItemType Directory -Path (Join-Path $checkout '.git') | Out-Null
    Assert ((Invoke-Updater @('-Source', $zipPath, '-AddonPath', $checkout)) -eq 1) 'a git checkout was updated'
    Assert ($lastOutput -match 'git pull') "no explanation: $lastOutput"
    Assert ((Get-Content -LiteralPath (Join-Path $checkout 'Customer\AnalyticsLog.lua')) -eq '-- an old file') 'a git checkout was touched'

    # An incomplete download changes nothing.
    $broken = Join-Path $testRoot 'broken\hironcraft-main'
    New-Item -ItemType Directory -Path $broken -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $broken 'HironCraft.toc') -Value @('## Version: 9.0.0', 'Missing\File.lua') -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $broken 'Bootstrap.lua') -Value '-- half a download' -Encoding ASCII
    $victim = New-Install 'victim' '0.0.1'
    Assert ((Invoke-Updater @('-Source', (Split-Path -Parent $broken), '-AddonPath', $victim)) -eq 1) 'an incomplete download was installed'
    Assert ($lastOutput -match 'incomplete') "no explanation: $lastOutput"
    Assert (-not (Test-Path -LiteralPath (Join-Path $victim 'Bootstrap.lua'))) 'an incomplete download wrote files'
    Assert (((Get-Content -LiteralPath (Join-Path $victim 'HironCraft.toc')) -join "`n") -match '0\.0\.1') 'the version changed'

    # Not an addon folder, and a source that is not HironCraft.
    $empty = Join-Path $testRoot 'empty'
    New-Item -ItemType Directory -Path $empty | Out-Null
    Assert ((Invoke-Updater @('-Source', $zipPath, '-AddonPath', $empty)) -eq 1) 'a folder without the addon was accepted'
    Assert ((Invoke-Updater @('-Source', $empty, '-AddonPath', $victim)) -eq 1) 'an empty source was accepted'
    Assert ((Invoke-Updater @('-Source', (Join-Path $testRoot 'nowhere.zip'), '-AddonPath', $victim)) -eq 1) 'a missing source was accepted'

    # Nothing of the updater's is left in the temporary folder.
    $leftovers = @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Directory -Filter 'HironCraft-update-*')
    Assert ($leftovers.Count -eq 0) "temporary folders were left: $($leftovers.Count)"

    # The launcher is one line, so it survives being replaced while it runs.
    $launcher = @(Get-Content -LiteralPath (Join-Path $projectRoot 'Update-HironCraft.cmd'))
    Assert ($launcher.Count -eq 1 -and $launcher[0] -match 'Update-HironCraft\.ps1' -and $launcher[0] -match '& pause$') 'the launcher changed shape'
    # Windows PowerShell 5.1 reads a script without a BOM as ANSI: ASCII only.
    $bytes = [IO.File]::ReadAllBytes($updater)
    Assert (@($bytes | Where-Object { $_ -gt 127 }).Count -eq 0) 'the updater has non-ASCII characters'

    $passed = $true
    Write-Output 'Updater passed (update, intact files, up to date, force, clean, no downgrade, folder source, git checkout, incomplete download, bad folders, cleanup).'
}
finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolved).StartsWith('HironCraft-updater-test-')) {
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not $passed) { exit 1 }
}
# The updater's last (expected) failure must not become this test's exit code.
exit 0
