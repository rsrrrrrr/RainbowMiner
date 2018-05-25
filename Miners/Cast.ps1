﻿using module ..\Include.psm1

$Path = ".\Bin\CryptoNight-Cast\cast_xmr-vega.exe"
$Uri = "http://www.gandalph3000.com/download/cast_xmr-vega-win64_092.zip"

$Type = "AMD"
if (-not $Devices.$Type -or $Config.InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject]@{
    "cryptonightv7" = ""
    "cryptonight-lite" = ""
    "cryptonight-heavy" = "" 
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type      = $Type
        Path      = $Path
        Arguments = "--remoteaccess -S $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --forcecompute --fastjobswitch -G $((Get-GPUlist "AMD") -join ',')"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API       = "Cast"
        Port      = 7777
        URI       = $Uri
        DevFee    = 1.5
    }
}