param(
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) "dist")
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$tocPath = Join-Path $projectRoot "HironCraft.toc"
$versionLine = Get-Content -LiteralPath $tocPath | Where-Object { $_ -like "## Version:*" } | Select-Object -First 1
$version = ($versionLine -replace "^## Version:\s*", "").Trim()
if (-not $version) {
    throw "Version is missing from HironCraft.toc"
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("HironCraft-build-" + [guid]::NewGuid().ToString("N"))
$stagingAddon = Join-Path $temporaryRoot "HironCraft"
New-Item -ItemType Directory -Path $stagingAddon -Force | Out-Null

try {
    $excludedRootEntries = @(
        ".git",
        ".gitignore",
        ".gitattributes",
        ".github",
        ".build",
        ".idea",
        ".vscode",
        "AGENTS.md",
        "artwork",
        "dist",
        "scripts"
    )

    Get-ChildItem -LiteralPath $projectRoot -Force |
        Where-Object { $_.Name -notin $excludedRootEntries } |
        Copy-Item -Destination $stagingAddon -Recurse -Force

    $repositoryArtifacts = Get-ChildItem -LiteralPath $stagingAddon -Force -Recurse |
        Where-Object {
            $_.Name -in @(".git", ".gitignore", ".gitattributes") -or
            $_.FullName -match '[\\/]\.github([\\/]|$)'
        } |
        Select-Object -First 1
    if ($repositoryArtifacts) {
        throw "Repository artifact leaked into release: $($repositoryArtifacts.FullName)"
    }

    # Windows PowerShell's Compress-Archive writes backslashes into ZIP entry
    # names. Use the ZIP-standard separator explicitly, including when built
    # with Windows PowerShell 5.1, for Explorer drag-and-drop compatibility.
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $temporaryArchive = Join-Path $temporaryRoot 'release.zip'
    $zip = [IO.Compression.ZipFile]::Open($temporaryArchive, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $prefix = $stagingAddon.TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
        foreach ($file in (Get-ChildItem -LiteralPath $stagingAddon -File -Recurse | Sort-Object FullName)) {
            $relative = $file.FullName.Substring($prefix.Length).Replace('\', '/')
            $entryName = 'HironCraft/' + $relative
            $entry = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $file.FullName, $entryName, [IO.Compression.CompressionLevel]::Optimal)
            $entry.ExternalAttributes = 32 # Normal Windows archive file; no inherited attributes.
        }
    }
    finally {
        $zip.Dispose()
    }

    $archive = Join-Path $OutputDirectory ("HironCraft-" + $version + ".zip")
    Copy-Item -LiteralPath $temporaryArchive -Destination $archive -Force
    Write-Output $archive
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath($temporaryRoot)
    $systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedTemp).StartsWith("HironCraft-build-")) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
