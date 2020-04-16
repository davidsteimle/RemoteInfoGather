$obj = New-Object -Type PSObject | Select-Object SerialNumber, Manufacturer, UUID, BaseBoardProduct, ChassisTypes, Chassis, SystemFamily, SystemSKUNumber

$obj.SerialNumber = Get-WmiObject -class Win32_Bios -namespace $namespace | Select-Object -ExpandProperty SerialNumber
$obj.Manufacturer = Get-WmiObject -class Win32_Bios -namespace $namespace | Select-Object -ExpandProperty Manufacturer
$obj.UUID = Get-WmiObject Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID
$obj.BaseBoardProduct = Get-WmiObject Win32_BaseBoard | Select-Object -ExpandProperty Product
$obj.ChassisTypes = Get-WmiObject Win32_SystemEnclosure | Select-Object -ExpandProperty ChassisTypes
$obj.Chassis = $ChassisTypes[[int]$obj.ChassisTypes]
$obj.SystemFamily = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty SystemFamily
$obj.SystemSKUNumber = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty SystemSKUNumber

Get-WmiObject -Class Win32_Bios
