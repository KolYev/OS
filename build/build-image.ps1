param(
    [Parameter(Mandatory = $true)][string]$Stage1,
    [Parameter(Mandatory = $true)][string]$Stage2,
    [Parameter(Mandatory = $true)][string]$Kernel,
    [Parameter(Mandatory = $true)][string]$Output
)

$ErrorActionPreference = 'Stop'

$sectorSize = 512
$stage2Sectors = 64
$imageSize = 16MB
$maximumKernelSize = 448KB

$stage1Bytes = [System.IO.File]::ReadAllBytes($Stage1)
$stage2Bytes = [System.IO.File]::ReadAllBytes($Stage2)
$kernelBytes = [System.IO.File]::ReadAllBytes($Kernel)

if ($stage1Bytes.Length -ne $sectorSize) {
    throw "Stage1 must be exactly 512 bytes; actual size is $($stage1Bytes.Length)."
}
if ($stage1Bytes[510] -ne 0x55 -or $stage1Bytes[511] -ne 0xAA) {
    throw 'Stage1 does not end with the BIOS signature 55 AA.'
}
if ($stage2Bytes.Length -gt ($stage2Sectors * $sectorSize)) {
    throw "Stage2 exceeds its $($stage2Sectors * $sectorSize)-byte reserved area."
}
if ($kernelBytes.Length -eq 0 -or $kernelBytes.Length -gt $maximumKernelSize) {
    throw "Kernel size must be between 1 byte and $maximumKernelSize bytes; actual size is $($kernelBytes.Length)."
}

$marker = [System.Text.Encoding]::ASCII.GetBytes('KRNLSIZE')
$markerOffset = -1
for ($index = 0; $index -le $stage2Bytes.Length - $marker.Length; ++$index) {
    $matches = $true
    for ($markerIndex = 0; $markerIndex -lt $marker.Length; ++$markerIndex) {
        if ($stage2Bytes[$index + $markerIndex] -ne $marker[$markerIndex]) {
            $matches = $false
            break
        }
    }
    if ($matches) {
        if ($markerOffset -ne -1) {
            throw 'The KRNLSIZE marker occurs more than once in stage2.'
        }
        $markerOffset = $index
    }
}
if ($markerOffset -eq -1) {
    throw 'The KRNLSIZE marker was not found in stage2.'
}

$kernelSectors = [int][Math]::Ceiling($kernelBytes.Length / $sectorSize)
$sectorBytes = [BitConverter]::GetBytes($kernelSectors)
[Array]::Copy($sectorBytes, 0, $stage2Bytes, $markerOffset + $marker.Length, 4)

$outputDirectory = Split-Path -Parent $Output
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$stream = [System.IO.File]::Open($Output, [System.IO.FileMode]::Create, [System.IO.FileAccess]::ReadWrite)
try {
    $stream.SetLength($imageSize)
    $stream.Position = 0
    $stream.Write($stage1Bytes, 0, $stage1Bytes.Length)
    $stream.Position = $sectorSize
    $stream.Write($stage2Bytes, 0, $stage2Bytes.Length)
    $stream.Position = $sectorSize * (1 + $stage2Sectors)
    $stream.Write($kernelBytes, 0, $kernelBytes.Length)
}
finally {
    $stream.Dispose()
}

Write-Host "Image: $Output"
Write-Host "Kernel: $($kernelBytes.Length) bytes ($kernelSectors sectors)"
