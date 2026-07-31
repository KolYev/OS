param(
    [switch]$InstallVirtualBox
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$toolsDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$uasmDirectory = Join-Path $toolsDirectory 'uasm'
$uasmPath = Join-Path $uasmDirectory 'uasm64.exe'
$uasmUrl = 'https://www.terraspace.co.uk/uasm257_x64.zip'

if (-not (Test-Path $uasmPath)) {
    New-Item -ItemType Directory -Force -Path $uasmDirectory | Out-Null
    $archivePath = Join-Path ([System.IO.Path]::GetTempPath()) 'uasm257_x64.zip'

    Write-Host 'Downloading UASM 2.57...'
    Invoke-WebRequest -Uri $uasmUrl -OutFile $archivePath
    Expand-Archive -Path $archivePath -DestinationPath $uasmDirectory -Force
    Remove-Item $archivePath -Force
}

if (-not (Test-Path $uasmPath)) {
    throw "UASM was downloaded, but $uasmPath was not found."
}

Write-Host "UASM: $uasmPath"

$vboxManage = Get-Command VBoxManage.exe -ErrorAction SilentlyContinue
if (-not $vboxManage) {
    $registry = Get-ItemProperty 'HKLM:\SOFTWARE\Oracle\VirtualBox' -ErrorAction SilentlyContinue
    if ($registry.InstallDir) {
        $candidate = Join-Path $registry.InstallDir 'VBoxManage.exe'
        if (Test-Path $candidate) {
            $vboxManage = Get-Item $candidate
        }
    }
}
if (-not $vboxManage) {
    $programDirectories = @($env:ProgramW6432, $env:ProgramFiles) | Where-Object { $_ }
    foreach ($programDirectory in $programDirectories) {
        $candidate = Join-Path $programDirectory 'Oracle\VirtualBox\VBoxManage.exe'
        if (Test-Path $candidate) {
            $vboxManage = Get-Item $candidate
            break
        }
    }
}

if (-not $vboxManage -and $InstallVirtualBox) {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw 'VirtualBox is missing and winget.exe is unavailable. Install VirtualBox from https://www.virtualbox.org/wiki/Downloads.'
    }

    Write-Host 'Installing Oracle VirtualBox (an elevation prompt may appear)...'
    & $winget.Source install --exact --id Oracle.VirtualBox --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "winget failed with exit code $LASTEXITCODE."
    }
}
elseif (-not $vboxManage) {
    Write-Warning 'VirtualBox is not installed. Re-run with -InstallVirtualBox when you are ready to install it.'
}
else {
    $vboxPath = if ($vboxManage.Source) { $vboxManage.Source } else { $vboxManage.FullName }
    Write-Host "VirtualBox: $vboxPath"
}
