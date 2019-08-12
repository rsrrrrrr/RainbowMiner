﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 1.0

$PoolCoins_Request = [PSCustomObject]@{}
try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://minermore.com/api/currencies" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us") #,"eu","hk")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Pool_CoinSymbol = $_;$Pool_Currency = if ($PoolCoins_Request.$Pool_CoinSymbol.symbol) {$PoolCoins_Request.$Pool_CoinSymbol.symbol} else {$Pool_CoinSymbol};$Pool_User = $Wallets.$Pool_Currency;($PoolCoins_Request.$_.hashrate -gt 0 -or $AllowZero) -and $Pool_User -or $InfoOnly} | ForEach-Object {

    $Pool_Host = "minermore.com"

    $Pool_Port = $PoolCoins_Request.$Pool_CoinSymbol.port
    $Pool_Algorithm = $PoolCoins_Request.$Pool_CoinSymbol.algo

    if ($Pool_Algorithm -eq "equihash") {
        $Pool_Algorithm = Switch ($Pool_CoinSymbol) {
            "SAFE" {"Equihash24x7"}
            "VDL"  {"Equihash24x7"}
            "XSG"  {"Equihash24x5"}
            "YEC"  {"Equihash24x7"}
            default {"Equihash24x7"}
        }
    }
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_Coin = $PoolCoins_Request.$Pool_CoinSymbol.name

    if ($Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Currency")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    $Pool_TSL = (Get-UnixTimestamp)-$PoolCoins_Request.$Pool_CoinSymbol.timesincelast

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate -BlockRate $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks" -Quiet
    }

    foreach($Pool_Region in $Pool_Regions) {
        foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin
                CoinSymbol    = $Pool_CoinSymbol
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$(if ($Pool_Region -eq "us") {"pool"} else {$Pool_Region}).$($Pool_Host)"
                Port          = $Pool_Port
                User          = "$($Pool_User).{workername:$Worker}"
                Pass          = "x{diff:,d=`$difficulty}"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $PoolCoins_Request.$Pool_CoinSymbol.workers
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
                TSL           = $Pool_TSL
                WTM           = $true
            }
        }
    }
}
