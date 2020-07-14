$Systems = @"
Name,User,Ping,WinRM,155,160
Laptop0,Joan Jett
Laptop1,Rob Halford
Laptop2,Joan Baez
Laptop3,David Lee Roth
Laptop4,David Bowie
Laptop5,Dolly Parton
Laptop6,Madonna
Laptop7,Nina Simone
Laptop8,Olivia Newton-John
Laptop9,Ella Fitzgerald
"@ | ConvertFrom-Csv

$ScriptBlock = {
    $MyResult = @{
        Five = $null
        Six = $null
    }
    if(Get-AppxPackage -Name "751d2504-0855-4568-a90d-fe4a4413cd97" -AllUsers){
        $MyResult.Five = $True
    }
    if(Get-AppxPackage -Name "a77af31f-f4b1-4e50-94b5-bebb0dd47cf3" -AllUsers){
        $MyResult.Six = $True
    }
    $MyResult
}

foreach($System in $Systems){
    $TestBlock = {
        try{
            Test-Connection $System.Name -Count 1 -ErrorAction Stop
            $True
        } catch {
            $False
        }
    }
    $TestRun = Invoke-Command -ScriptBlock $TestBlock
    if($TestRun){
        $System.Ping = $True
        try{
            $Result = Invoke-Command -ComputerName $System.Name -ScriptBlock $ScriptBlock -ErrorAction Stop
            $System.WinRM = $True
        } catch {
            $System.WinRM = $False
        }
        $System.155 = $Result.Five
        $System.160 = $Result.Six
    } else {
        $System.Ping = $False
    }
}
