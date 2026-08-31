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
    Get-ChildItem -LiteralPath $projectRoot -Force |
        Where-Object { $_.Name -notin @(".git", ".build", "dist", "scripts") } |
        Copy-Item -Destination $stagingAddon -Recurse -Force

    $archive = Join-Path $OutputDirectory ("HironCraft-" + $version + ".zip")
    Compress-Archive -LiteralPath $stagingAddon -DestinationPath $archive -Force
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
