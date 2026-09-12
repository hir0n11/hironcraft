param(
    [Parameter(Mandatory = $true)]
    [string]$Archive
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archivePath = (Resolve-Path -LiteralPath $Archive).Path
$projectRoot = Split-Path -Parent $PSScriptRoot
$manifest = @{}
$zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    foreach ($entry in $zip.Entries) {
        $name = $entry.FullName
        if ($name -notmatch '^HironCraft/[^\\:]+$' -or
            $name -match '(^|/)\.{1,2}(/|$)' -or $name.Contains('//') -or
            $name.EndsWith('/') -or $manifest.ContainsKey($name)) {
            throw "Invalid or duplicate release file path: $name"
        }
        if ($entry.ExternalAttributes -ne 32) { throw "Unexpected ZIP attributes: $name" }
        $stream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $stream.Dispose(); $sha.Dispose() }
        $sourceFile = Join-Path $projectRoot $name.Substring('HironCraft/'.Length)
        if ((Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash -ne $hash) {
            throw "Archive bytes differ from source: $name"
        }
        $manifest[$name] = $hash
    }
}
finally { $zip.Dispose() }
foreach ($required in @('HironCraft/HironCraft.toc', 'HironCraft/Bindings.xml',
    'HironCraft/ProfitHub/Shop/Core/RecipeShopping.lua')) {
    if (-not $manifest.ContainsKey($required)) { throw "Missing release file: $required" }
}

# Exercise the same compressed-folder handler as Explorer, not only .NET's
# extractor. Keep failed output for diagnosis; clean up only this unique test dir.
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('HironCraft-zip-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$passed = $false
try {
    $shell = New-Object -ComObject Shell.Application
    $zipFolder = $shell.NameSpace($archivePath)
    $destination = $shell.NameSpace($testRoot)
    if (-not $zipFolder -or -not $destination) { throw 'Explorer could not open the ZIP or test directory' }
    $addonFolder = $zipFolder.ParseName('HironCraft')
    if (-not $addonFolder -or -not $addonFolder.IsFolder) { throw 'Explorer cannot see the HironCraft folder' }
    $destination.CopyHere($addonFolder, 1556) # Silent, no confirmation/error dialogs.
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        $copied = @(Get-ChildItem -LiteralPath $testRoot -File -Recurse)
        $complete = $copied.Count -eq $manifest.Count
        if ($complete) {
            foreach ($name in $manifest.Keys) {
                $path = Join-Path $testRoot $name
                try {
                    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $manifest[$name]) {
                        $complete = $false
                        break
                    }
                }
                catch { $complete = $false; break }
            }
        }
        if (-not $complete) { Start-Sleep -Milliseconds 200 }
    } while (-not $complete -and [DateTime]::UtcNow -lt $deadline)
    if (-not $complete) { throw "Explorer extraction failed or incomplete; inspect $testRoot" }
    $passed = $true
    Write-Output "ZIP paths, attributes, source hashes and Explorer extraction passed ($($manifest.Count) files)."
}
finally {
    if ($passed) {
        $resolved = [IO.Path]::GetFullPath($testRoot)
        $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
        if ($resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $resolved).StartsWith('HironCraft-zip-test-')) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
