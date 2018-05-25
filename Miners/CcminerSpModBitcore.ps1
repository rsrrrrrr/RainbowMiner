﻿using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-SpModBitcore\ccminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-ccminerbitcore/ccminerbitcore_spmod_1.0.7z"

$Type = "NVIDIA"
if (-not $Devices.$Type -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    "bitcore"  = "" #Bitcore
}

$Default_Profile = 2
$Profiles = [PSCustomObject]@{
    "x16r" = 4
    "x16s" = 4
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$DeviceIDsAll = (Get-GPUlist $Type) -join ','

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type = $Type
        Path = $Path
        Arguments = "-r 0 -d $($DeviceIDsAll) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
        MSIAprofile = if ( $Profiles.$_ ) { $Profiles.$_ } else { $Default_Profile }
    }
}