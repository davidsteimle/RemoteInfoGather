#region LetsStartSlow

    # On my local system, with no WinRM

    Invoke-Command -Scriptblock { 
        $wmi = gwmi win32_operatingsystem
        $wmi.ConvertToDateTime($wmi.LastBootUpTime) 
    }

    # On a remote system, with WinRM

    Invoke-Command -ComputerName YouComputer -Scriptblock { 
        $wmi = gwmi win32_operatingsystem
        $wmi.ConvertToDateTime($wmi.LastBootUpTime) 
    }

#endregion LetsStartSlow

#region TheRealPower

    $LastBootTime = Invoke-Command -Scriptblock { 
        $wmi = gwmi win32_operatingsystem
        $wmi.ConvertToDateTime($wmi.LastBootUpTime)
    }

    $LastBootTime | Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LastBootTime | Get-Date -Format s

#endregion TheRealPower

#region ScriptBlockVariable

    $MyScriptBlock = {
        $wmi = gwmi win32_operatingsystem
        $wmi.ConvertToDateTime($wmi.LastBootUpTime)
    }

    $LastBootTime = Invoke-Command -ScriptBlock $MyScriptBlock

    $LastBootTime | Get-Date -Format s

#endregion ScriptBlockVariable

#region MoreComplexScriptblocks

$ScriptBlock1 = {
    $namespace = "root\CIMV2"
    $obj1 = New-Object -Type PSObject | `
        Select-Object SerialNumber, Manufacturer, UUID, BaseBoardProduct, ChassisTypes, SystemFamily, SMBIOSAssetTag

    $obj1.SerialNumber = Get-WmiObject -class Win32_Bios -namespace $namespace | Select-Object -ExpandProperty SerialNumber
    $obj1.Manufacturer = Get-WmiObject -class Win32_Bios -namespace $namespace | Select-Object -ExpandProperty Manufacturer
    $obj1.UUID = Get-WmiObject Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID
    $obj1.BaseBoardProduct = Get-WmiObject Win32_BaseBoard | Select-Object -ExpandProperty Product
    $obj1.ChassisTypes = Get-WmiObject Win32_SystemEnclosure | Select-Object -ExpandProperty ChassisTypes
    $obj1.SystemFamily = $null
    $obj1.SMBIOSAssetTag = Get-WmiObject Win32_SystemEnclosure | Select-Object -ExpandProperty SMBIOSAssetTag
    
    $obj1
}

$MyQuery1 = Invoke-Command -ScriptBlock $ScriptBlock1

#endregion MoreComplexScriptblocks

#region HeresALittleTrick

$ChassisTypes = Invoke-RestMethod -Uri https://raw.githubusercontent.com/davidsteimle/RemoteInfoGather/master/ChassisTypes.json

$MyQuery1.SystemFamily = $ChassisTypes | Where-Object -Property Index -eq $MyQuery1.ChassisTypes | Select-Object -ExpandProperty Name

#endregion HeresALittleTrick

#region ScriptBlock2

$ScriptBlock2 = {
    $namespace = "root\CIMV2"
    Get-WmiObject -class Win32_Bios -namespace $namespace
    Get-WmiObject Win32_ComputerSystemProduct
    Get-WmiObject Win32_BaseBoard
    Get-WmiObject Win32_SystemEnclosure
    Get-WmiObject Win32_ComputerSystem | `
        Select-Object -Property Domain,Manufacturer,Model,Name,TotalPhysicalMemory `
        -ExcludeProperty PrimaryOwnerName
}

$MyQuery2 = Invoke-Command -ScriptBlock $ScriptBlock2

#endregion ScriptBlock2

#region ScriptBlock3

$MyData = New-Object System.Collections.Generic.List[psobject]

$ScriptBlock3 = {
    # Create an object with desired properties (named after our queries) 
    # and then populate the property with resultant objects
    $Response = New-Object -Type PSObject | `
        Select-Object ComputerName,SystemFamily,Win32_Bios,Win32_ComputerSystemProduct,Win32_BaseBoard,Win32_SystemEnclosure,Win32_ComputerSystem,PSVersionTable,LastReboot,CurrentKB
        $namespace = "root\CIMV2"
        $Response.Win32_Bios = $(Get-WmiObject -class Win32_Bios -namespace $namespace)
        $Response.Win32_ComputerSystemProduct = $(Get-WmiObject Win32_ComputerSystemProduct)
        $Response.Win32_BaseBoard = $(Get-WmiObject Win32_BaseBoard)
        $Response.Win32_SystemEnclosure = $(Get-WmiObject Win32_SystemEnclosure)
        $Response.Win32_ComputerSystem = $(Get-WmiObject Win32_ComputerSystem)
        $Response.PSVersionTable = $($PSVersionTable) # new
        $Response.LastReboot = $($wmi = gwmi win32_operatingsystem
            $wmi.ConvertToDateTime($wmi.LastBootUpTime)) # new
        $Response.CurrentKB = $(Get-Hotfix | Select-Object -Last 1) # new
        $Response.ComputerName = $Response.Win32_Bios.PSComputerName # new
        $Response.SystemFamily = $null #new
    $Response
}

$MyQuery3 = Invoke-Command -ScriptBlock $ScriptBlock3

$ChassisTypes = Invoke-RestMethod -Uri https://raw.githubusercontent.com/davidsteimle/RemoteInfoGather/master/ChassisTypes.json

$MyQuery3.SystemFamily = $ChassisTypes | Where-Object -Property Index -eq $($MyQuery3.Win32_SystemEnclosure.ChassisTypes) | Select-Object -ExpandProperty Name

$MyData.Add($MyQuery3)

#endregion ScriptBlock3

#region ASimpleLoop

$Systems = @"
ComputerName,Count
Laptop1,1
Laptop2,1
Laptop5,1
Laptop9,1
"@ | ConvertFrom-Csv

$Results = New-Object "System.Collections.Generic.List[PSObject]"

$Systems.ForEach({
    $Results.Add($(Invoke-Command -ComputerName $PSItem.ComputerName -ScriptBlock $ScriptBlock3))
})

#endregion ASimpleLoop

#region DataForTheBoss

$BossData = New-Object System.Collections.Generic.List[psobject]

foreach($Item in $MyData){
    $SelectData = New-Object -Type PSObject | `
        Select-Object ComputerName, LastReboot, SerialNumber, Manufacturer, UUID, BaseBoardProduct, ChassisTypes, SystemFamily, SMBIOSAssetTag,BIOSVersion
    $SelectData.ComputerName = $Item.ComputerName
    $SelectData.LastReboot = $Item.LastReboot
    $SelectData.SerialNumber = $Item.Win32_Bios.SerialNumber
    $SelectData.Manufacturer = $Item.Win32_Bios.Manufacturer
    $SelectData.UUID = $Item.Win32_ComputerSystemProduct.UUID
    $SelectData.BaseBoardProduct = $Item.Win32_BaseBoard.Product
    $SelectData.ChassisTypes = $([int32]$($Item.Win32_SystemEnclosure.ChassisTypes))
    $SelectData.SystemFamily = $Item.SystemFamily
    $SelectData.SMBIOSAssetTag = $Item.Win32_SystemEnclosure.SMBIOSAssetTag
    $SelectData.BIOSVersion = $Item.Win32_BIOS.Version
    $BossData.Add($SelectData)
}

#endregion DataForTheBoss

#region MoreDataForTheBoss

$BossData = New-Object System.Collections.Generic.List[psobject]

foreach($Item in $MyData){
    $SelectData = New-Object -Type PSObject | `
        Select-Object ComputerName, LastReboot, SerialNumber, Manufacturer, UUID, BaseBoardProduct, ChassisTypes, SystemFamily, SMBIOSAssetTag, SecurityStatus
    $SelectData.ComputerName = $Item.ComputerName
    $SelectData.LastReboot = $Item.LastReboot
    $SelectData.SerialNumber = $Item.Win32_Bios.SerialNumber
    $SelectData.Manufacturer = $Item.Win32_Bios.Manufacturer
    $SelectData.UUID = $Item.Win32_ComputerSystemProduct.UUID
    $SelectData.BaseBoardProduct = $Item.Win32_BaseBoard.Product
    $SelectData.ChassisTypes = $([int32]$($Item.Win32_SystemEnclosure.ChassisTypes))
    # $SelectData.ChassisTypes = $($Item.Win32_SystemEnclosure.ChassisTypes)
    $SelectData.SystemFamily = $Item.SystemFamily
    $SelectData.SMBIOSAssetTag = $Item.Win32_SystemEnclosure.SMBIOSAssetTag
    $SelectData.SecurityStatus = $Item.Win32_SystemEnclosure.SecurityStatus
    $BossData.Add($SelectData)
}

#endregion MoreDataForTheBoss
