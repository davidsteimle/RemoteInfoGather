<#
Partially taken from: https://docs.microsoft.com/en-us/windows-hardware/drivers/bringup/sample-powershell-script-to-query-smbios-locally
#>

$namespace = "root\CIMV2"

$ScriptBlock1 = {
  $obj1 = New-Object -Type PSObject | Select-Object SerialNumber, Manufacturer, UUID, BaseBoardProduct, ChassisTypes, Chassis, SystemFamily, SystemSKUNumber

  $obj1.SerialNumber = Get-WmiObject -class Win32_Bios -namespace $namespace | Select-Object -ExpandProperty SerialNumber
  $obj1.Manufacturer = Get-WmiObject -class Win32_Bios -namespace $namespace | Select-Object -ExpandProperty Manufacturer
  $obj1.UUID = Get-WmiObject Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID
  $obj1.BaseBoardProduct = Get-WmiObject Win32_BaseBoard | Select-Object -ExpandProperty Product
  $obj1.ChassisTypes = Get-WmiObject Win32_SystemEnclosure | Select-Object -ExpandProperty ChassisTypes
  $obj1.SystemFamily = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty SystemFamily
  $obj1.SystemSKUNumber = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty SystemSKUNumber
  
  $obj1
}

$ScriptBlock2 = {
  Get-WmiObject -class Win32_Bios -namespace $namespace
  Get-WmiObject Win32_ComputerSystemProduct
  Get-WmiObject Win32_BaseBoard
  Get-WmiObject Win32_SystemEnclosure
  Get-WmiObject Win32_ComputerSystem
}
