param(
    [string]$Image = (Join-Path $PSScriptRoot 'build\Debug\os.img'),
    [string]$VmName = 'OS-Dev',
    [switch]$Headless
)

$ErrorActionPreference = 'Stop'
$Image = [System.IO.Path]::GetFullPath($Image)

if (-not (Test-Path $Image)) {
    throw "Disk image not found: $Image. Build the x64 project first."
}

$vboxManage = Get-Command VBoxManage.exe -ErrorAction SilentlyContinue
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
if (-not $vboxManage) {
    throw 'VBoxManage.exe was not found. Run tools\bootstrap.ps1 -InstallVirtualBox.'
}
$vbox = if ($vboxManage.Source) { $vboxManage.Source } else { $vboxManage.FullName }

function Invoke-VBox {
    & $vbox @args
    if ($LASTEXITCODE -ne 0) {
        throw "VBoxManage failed with exit code ${LASTEXITCODE}: $($args -join ' ')"
    }
}

$ErrorActionPreference = 'SilentlyContinue'
& $vbox showvminfo $VmName *> $null
$vmExists = $LASTEXITCODE -eq 0
$ErrorActionPreference = 'Stop'
if (-not $vmExists) {
    Invoke-VBox createvm --name $VmName --ostype Other_64 --register
}

$machineInfo = & $vbox showvminfo $VmName --machinereadable
if ($LASTEXITCODE -ne 0) {
    throw "Could not query VirtualBox VM '$VmName'."
}

$stateLine = $machineInfo | Where-Object { $_ -match '^VMState=' }
if ($stateLine -and $stateLine -notmatch '"poweroff"|"aborted"|"saved"') {
    Invoke-VBox controlvm $VmName poweroff
    Start-Sleep -Milliseconds 750
}
if ($stateLine -match '"saved"') {
    Invoke-VBox discardstate $VmName
}

$serialLog = Join-Path (Split-Path -Parent $Image) 'serial.log'
if (Test-Path $serialLog) {
    Remove-Item $serialLog -Force
}
Invoke-VBox modifyvm $VmName --memory 128 --cpus 1 --firmware bios --chipset piix3 `
    --ioapic on --boot1 disk --boot2 none --boot3 none --boot4 none `
    --uart1 0x3F8 4 --uartmode1 file $serialLog

$hasIdeController = $machineInfo | Where-Object { $_ -match '^storagecontrollername\d+="IDE"$' }
if (-not $hasIdeController) {
    Invoke-VBox storagectl $VmName --name IDE --add ide --controller PIIX4
}

$ErrorActionPreference = 'SilentlyContinue'
& $vbox storageattach $VmName --storagectl IDE --port 0 --device 0 --type hdd --medium none *> $null
$ErrorActionPreference = 'Stop'

$virtualDisk = [System.IO.Path]::ChangeExtension($Image, '.vdi')
if (Test-Path $virtualDisk) {
    $ErrorActionPreference = 'SilentlyContinue'
    & $vbox closemedium disk $virtualDisk --delete *> $null
    $ErrorActionPreference = 'Stop'
    if (Test-Path $virtualDisk) {
        Remove-Item $virtualDisk -Force
    }
}

Invoke-VBox convertfromraw $Image $virtualDisk --format VDI --variant Fixed
Invoke-VBox storageattach $VmName --storagectl IDE --port 0 --device 0 --type hdd --medium $virtualDisk

$startType = if ($Headless) { 'headless' } else { 'gui' }
Invoke-VBox startvm $VmName --type $startType
Write-Host "Started '$VmName' with $Image"
Write-Host "Serial log: $serialLog"
