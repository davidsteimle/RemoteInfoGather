# Remote Information Gathering with Powershell

Sometimes you have a need to get information from systems in your Enterprise. While there are many tools to do this, you might not have access to them, or they do not behave as desired. Tanium, for example, out of the box can be rather poor about how it handles registry queries. PowerShell, however, can do a lot with them. Alternately, you may have access to the systems in the Production environment, but not the Production deployment tools (such as SCCM) to use for reporting.

What is a scripter supposed to do?

## WinRM

If WinRM is enabled in your Enterprise it is a simple matter to run commands remotely. You could ``Enter-PsSession`` and run the desired commands and queries, or better yet, let ``Invoke-Command`` do it for you.

### Basic Use

At its most basic, ``Invoke-Command`` accepts a scriptblock and runs it. The benefit here is that the scriptblock may be run, via WinRM, on a remote system.

A simple example might be:

```powershell
Invoke-Command -ComputerName DavesLaptop -Scriptblock { 
  $wmi = gwmi win32_operatingsystem
  $wmi.ConvertToDateTime($wmi.LastBootUpTime) 
}
```

The scriptlock above will use a WMI call to determine the last time the system booted, and convert it to a human-readable ``datetime`` value.

The power comes in when we assign that example to a variable.

```powershell
$LastBootTime = Invoke-Command -ComputerName DavesLaptop -Scriptblock { 
  $wmi = gwmi win32_operatingsystem
  $wmi.ConvertToDateTime($wmi.LastBootUpTime)
}
```

Now, our last boot time is in the variable ``$LastBootTime`` and can be used elsewhere, or reformatted to suit our needs.

```powershell
$LastBootTime | Get-Date -Format "yyyy-MM-dd HH:mm:ss"
```

An alternative to the scriptblock as we have stated it above, is to create it as a variable as well. This is quite useful for complex scriptblocks.

```powershell
$MyScriptBlock = {
  $wmi = gwmi win32_operatingsystem
  $wmi.ConvertToDateTime($wmi.LastBootUpTime)
}

$LastBootTime = Invoke-Command -ComputerName DavesLaptop -ScriptBlock $MyScriptBlock
```

### Getting Multiple Responses

Let's gather some information about a system. 

> Partially taken from [Sample PowerShell script to query SMBIOS locally](https://docs.microsoft.com/en-us/windows-hardware/drivers/bringup/sample-powershell-script-to-query-smbios-locally), which has a cool tip on lookup tables for chasis type, which is out of my scope here. Worth looking at.

```powershell
$ScriptBlock1 = {
    $namespace = "root\CIMV2"
    $obj1 = New-Object -Type PSObject | `
        Select-Object SerialNumber, Manufacturer, UUID, BaseBoardProduct, ChassisTypes, SystemFamily, SystemSKUNumber

    $obj1.SerialNumber = Get-WmiObject -class Win32_Bios -namespace $namespace | `
        Select-Object -ExpandProperty SerialNumber
    $obj1.Manufacturer = Get-WmiObject -class Win32_Bios -namespace $namespace | `
        Select-Object -ExpandProperty Manufacturer
    $obj1.UUID = Get-WmiObject Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID
    $obj1.BaseBoardProduct = Get-WmiObject Win32_BaseBoard | Select-Object -ExpandProperty Product
    $obj1.ChassisTypes = Get-WmiObject Win32_SystemEnclosure | Select-Object -ExpandProperty ChassisTypes
    $obj1.SystemFamily = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty SystemFamily
    $obj1.SystemSKUNumber = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty SystemSKUNumber
    
    $obj1
}

$MyQuery = Invoke-Command -ComputerName DavesLaptop -ScriptBlock $ScriptBlock1
```

Which returns:

```

```

That's kind of pretty, right? However, we are making seven WMI calls to five WMI objects. What if we do this instead?

```powershell
$ScriptBlock2 = {
    $namespace = "root\CIMV2"
    Get-WmiObject -class Win32_Bios -namespace $namespace
    Get-WmiObject Win32_ComputerSystemProduct
    Get-WmiObject Win32_BaseBoard
    Get-WmiObject Win32_SystemEnclosure
    Get-WmiObject Win32_ComputerSystem
}

$MyQuery = Invoke-Command -ComputerName DavesLaptop -ScriptBlock $ScriptBlock2
```
Which returns:

```

```

There are, obviously, several differences here. First, we are getting a lot more information from ``$ScriptBlock2``. Second, ``$ScriptBlock2`` is not as pretty, or usable as ``$ScriptBlock1``.

Just for fun, I ran both scriptblocks 10, 100, and 1000 times with ``Measure-Command`` againsta a single (remote) system:

```
PS> Measure-Command {
    $i = 1
    while($i -le 10){
        Invoke-Command -ComputerName DavesLaptop -ScriptBlock $ScriptBlock1
        $i++
    }
} | Select-Object -Property TotalSeconds

TotalSeconds
------------
  17.6947685

PS> Measure-Command {
    $i = 1
    while($i -le 10){
        Invoke-Command -ComputerName DavesLaptop -ScriptBlock $ScriptBlock2
        $i++
    }
} | Select-Object -Property TotalSeconds

TotalSeconds
------------
  16.3201402
```

So, a bit over a second. Big deal.

Here are my results:

|                  | 1         | 10         | 100         | 1000         |
| :--------------- | --------: | ---------: | ----------: | -----------: |
| ScriptBlock1     | 1.7913257 | 17.6947685 | 164.6030548 | 1645.5537250 |
| ScriptBlock2     | 1.7223594 | 16.3201402 | 160.6308040 | 1595.7965102 |
| Rough Difference | 0.06 secs | 1.37 secs  | 3.97 secs   | 49.75 secs   |

So, the compact, seven item query does not take _too_ much longer, though you can certainly see how the time would escalate if you performed many more queries.

There is the hidden time factor though...

## Scenario

So, the Boss emails you and says:

> Steimle: scan the field for SerialNumber, Manufacturer, UUID, BaseBoardProduct, ChassisTypes, SystemFamily, SystemSKUNumber. Why are you still reading this? Go, man, go!

Sweet! Those are the items I am getting with ``$ScriptBlock1``. My Enterprise has 50,000 machines. Based on my timing above, this should maybe take a while, but it's easy!

_Starts script, goes to lunch. Waits a bit... Done!_

So, I wrap my results up in a CSV, because managers love CSV files, and off it goes.

Incoming email:

> Steimle: I don't see BIOS version in these numbers. Get me the BIOS version ASAP!

_For the record, none of my current bosses talk to me this way._

Well, I still have ``$ScriptBlock2``, and it runs a little faster...

Reply to boss:

> I'll have that for you in the morning, your benevolence.

_Starts script, sweats a bit. Goes home. New data in the AM. All done._

Or am I...?

## Going a Bit Deeper

So, while ``$ScriptBlock2`` gives us more information, it does not come back to us in a useful manner. Go ahead and run it on your system now. I'll wait...

```powershell
$ScriptBlock2 = {
    $namespace = "root\CIMV2"
    Get-WmiObject -class Win32_Bios -namespace $namespace
    Get-WmiObject Win32_ComputerSystemProduct
    Get-WmiObject Win32_BaseBoard
    Get-WmiObject Win32_SystemEnclosure
    Get-WmiObject Win32_ComputerSystem
}

$MyQuery = Invoke-Command -ScriptBlock $ScriptBlock2

$MyQuery
```

Your ``$MyQuery`` is a mess, right? Well, you ain't seen nothing yet. Try this:

```powershell
$MyQuery | Select-Object -Property *
```

What we need is a way to make that information come back to me in a logical, and useful form. Let's rebuild ``$ScriptBlock2`` as ``$ScriptBlock3``, but add some other data we can play with:

```powershell
$ScriptBlock3 = {
    $namespace = "root\CIMV2"
    $Response = @{
        "Win32_Bios" = $(Get-WmiObject -class Win32_Bios -namespace $namespace)
        "Win32_ComputerSystemProduct" = $(Get-WmiObject Win32_ComputerSystemProduct)
        "Win32_BaseBoard" = $(Get-WmiObject Win32_BaseBoard)
        "Win32_SystemEnclosure" = $(Get-WmiObject Win32_SystemEnclosure)
        "Win32_ComputerSystem" = $(Get-WmiObject Win32_ComputerSystem)
        "PSVersionTable" = $($PSVersionTable)
        "LastReboot" = $($wmi = gwmi win32_operatingsystem;$wmi.ConvertToDateTime($wmi.LastBootUpTime))
        "CurrentKB" = $(Get-Hotfix | Select-Object -Last 1)
    }
    $Response
}

$MyQuery = Invoke-Command -ComputerName DavesLaptop -ScriptBlock $ScriptBlock3
```

Now, if you run that code, and then check ``$MyQuery`` it is not as pretty as ``$ScriptBlock1``, but if you check ``$MyQuery.Win32_Bios.SMBIOSBIOSVersion`` what do you get? Try that with ``$ScriptBlock2``. I'm not going anywhere.

> **Side Note:** when it comes to complicated, many layered objects, I like to pipe them through ``ConvertTo-Json`` for readability.

Now we just need to run the code against the field, and we are good; and if we hang on to the results, we might be able to respond to "you forgot the manufacturer," in moments.

## How Do We Run This Against the Field?

There are numerous ways to run against the field. It is much quicker to use a threaded methodology, but I am not good at that, and it is scope creep. What I tend to do is to get an object of system names. This might be from a Tanium question, or I will query SCCM.

> **Note:** be careful here, in your Enterprise. If you have a DEV environment, try a few systems there first. If you are running against the Enterprise, make sure you have buy in from someone first. This behavior could be misinterpreted by security. "Cover thy ass shall be the whole of the law."

So, in this example, I have afictional exported table from Tanium:

```
Computer Name,Count
Laptop1,1
Laptop2,1
Laptop5,1
```

I will take this text table, make it a Here String, take the space out of _Computer Name_, and convert from CSV.

```powershell
$Systems = @"
ComputerName,Count
Laptop1,1
Laptop2,1
Laptop5,1
"@ | ConvertFrom-Csv
```

Now it looks like this:

```
ComputerName Count
------------ -----
Laptop1      1
Laptop2      1
Laptop5      1
```

We want to gather the data from these systems, so we need a way to hold the results.

Then, we want to loop through the list of names, and run our scriptblock:

```powershell
$Results = @{} # An empty hashtable
$Systems.ForEach({
    $Results.Add($PSItem.ComputerName,$(Invoke-Command -ComputerName $PSItem.ComputerName -ScriptBlock $ScriptBlock3))
})
```

## The Final Bit: Who is this data for?

You need to know your audience. If I'm sending it to one of you folks, I might just send you JSON, or if I want to be cool I'll drop it on a web server and send you an API link to save you some work. What if I'm sending it to an Engineer or Tech who needs to address problem systems? What if I'm sending it to this guy?

<div style="text-align:center">

![That would be great...](https://davidsteimle.net/rtpsug/lundberg.gif)

</div>

Sometimes the key to having data is knowing how to give it to people, and having methods to do so in mind makes it pretty easy.

The easiest method for you to hang on to and share with other Powershell folks is JSON.

```powershell
$Results | ConvertTo-Json | Out-File ./MyResults.json
```

Send that in an email and they can ``$DavesResults = Get-Content ./MyResults.json | ConvertFrom-Json``, or drop it on a web server, and they can ``$DavesResults = Invoke-RestMethod -Uri https://davidsteimle.net/rtpsug/MyResults.json`` and they have all the data, and can do with it what they like.

However, that is a whole lot of data. Sometimes it is best to give what was aked for, so in this case we might want to build an accessible data set which we can work with.

### Trim That Data

What was that the boss asked for again?

* SerialNumber
* Manufacturer
* UUID
* BaseBoardProduct
* ChassisTypes
* SystemFamily
* SystemSKUNumber
* SMBIOSBIOSVersion

Let's go ahead and assume they wanted _Computer Name_ too, because, duh.

We need to know where these items are, and we do, because they were defined in our ``$ScriptBlock1`` query. Getting them out of our object will take a bit of digging. Let's work with a single system first.

$Results
