# Remote Information Gathering with Powershell

### About Me
* Packaging Department with the USPS
* Started to learn Powershell (poorly) six years ago; three years later it became my primary job function
* Microsoft Configuration Manager
* A Linux user (Debian-style) who works primarily with Windows
* Contact
   * [davidsteimle.net](https://davidsteimle.net)
   * [@dbsteimle on Twitter](https://twitter.com/dbsteimle)
   * DavidSteimle#5975 on Discord
   

### Core Concepts

Some of the PowerShell Commands and methodology I will be using are listed below. I may not talk about them in-depth.

* ``Invoke-Command``
* ``New-Object``
* Script Blocks
* Generic Lists
* ``ConvertTo-Json``, ``Convert-To-Csv``, ``Out-File``
* Piping

-----

Sometimes you have a need to get information from systems in your Enterprise. While there are many tools to do this, you might not have access to them, or they do not behave as desired. Tanium, for example, out of the box can be rather poor about how it handles registry queries. PowerShell, however, can do a lot with them. Alternately, you may have access to the systems in the Production environment, but not the Production deployment tools (such as ConfigMgr) to use for reporting.

What is a scripter supposed to do?

## WinRM

If WinRM is enabled in your Enterprise it is a simple matter to run commands remotely. You could ``Enter-PsSession`` and run the desired commands and queries, or better yet, let ``Invoke-Command`` do it for you.

### Basic Use

At its most basic, ``Invoke-Command`` accepts a scriptblock and runs it. The benefit here is that the scriptblock may be run, via WinRM, on a remote system.

A simple example might be:

```powershell
Invoke-Command -ComputerName $RemotePC -Scriptblock { 
  Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime
}
```

The scriptlock above will use a CIM call to determine the last time the system booted as a ``datetime`` value.

The power comes in when we assign that example to a variable.

```powershell
$LastBootTime = Invoke-Command -ComputerName $RemotePC -Scriptblock { 
  Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime
}
```

Now, our last boot time is in the variable ``$LastBootTime`` and can be used elsewhere, or reformatted to suit our needs.

```powershell
$LastBootTime | Get-Date -Format "yyyy-MM-dd HH:mm:ss"
```

An alternative to the scriptblock as we have stated it above, is to create it as a variable. This is quite useful for complex scriptblocks.

```powershell
$MyScriptBlock = {
  Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime
}

$LastBootTime = Invoke-Command -ComputerName $RemotePC -ScriptBlock $MyScriptBlock
```

### Getting Multiple Responses

Let's gather some information about a system. 

> Partially taken from [Sample PowerShell script to query SMBIOS locally](https://docs.microsoft.com/en-us/windows-hardware/drivers/bringup/sample-powershell-script-to-query-smbios-locally), which has a cool tip on lookup tables for chasis type, which is out of my scope here. Worth looking at.

#### ScriptBlock1

```powershell
$ScriptBlock1 = {
    $namespace = "root\CIMV2"
    $obj1 = New-Object -Type PSObject | `
        Select-Object SerialNumber, Manufacturer, UUID, BaseBoardProduct, ChassisTypes, `
            SystemFamily, SystemSKUNumber

    $obj1.SerialNumber = Get-CimInstance -ClassName Win32_BIOS | `
        Select-Object -ExpandProperty SerialNumber
    $obj1.Manufacturer = Get-CimInstance -ClassName Win32_BIOS | `
        Select-Object -ExpandProperty Manufacturer
    $obj1.UUID = Get-CimInstance -ClassName Win32_ComputerSystemProduct | `
        Select-Object -ExpandProperty UUID
    $obj1.BaseBoardProduct = Get-CimInstance -ClassName Win32_BaseBoard | `
        Select-Object -ExpandProperty Product
    $obj1.ChassisTypes = Get-CimInstance -ClassName Win32_SystemEnclosure | `
        Select-Object -ExpandProperty ChassisTypes
    $obj1.SystemFamily = Get-CimInstance -ClassName Win32_ComputerSystem | `
        Select-Object -ExpandProperty SystemFamily

    $obj1
}

$MyQuery1 = Invoke-Command -ComputerName $RemotePC -ScriptBlock $ScriptBlock1
```

Which returns:

```
SerialNumber     : E9N0CJ06786239E
Manufacturer     : American Megatrends Inc.
UUID             : 45271B53-316F-9144-B4CB-E9B5F6EDB36F
BaseBoardProduct : TP300LD
ChassisTypes     : 10
SystemFamily     : TP
SystemSKUNumber  : ASUS-NotebookSKU
```

> *Side Note:* all values above are returned as strings. Enter ``$MyQuery1.SerialNumber.GetType()`` for example.

That's kind of pretty, right? However, we are making seven WMI calls to five WMI objects. What if we do this instead?

#### ScriptBlock2

```powershell
$ScriptBlock2 = {
    $namespace = "root\CIMV2"
    Get-WmiObject -class Win32_Bios -namespace $namespace
    Get-WmiObject Win32_ComputerSystemProduct
    Get-WmiObject Win32_BaseBoard
    Get-WmiObject Win32_SystemEnclosure
    Get-WmiObject Win32_ComputerSystem
}

$MyQuery2 = Invoke-Command -ComputerName Laptop1 -ScriptBlock $ScriptBlock2
```
Which returns:

```
SMBIOSBIOSVersion : TP300LD.201
Manufacturer      : American Megatrends Inc.
Name              : TP300LD.201
SerialNumber      : E9N0CJ06786239E
Version           : _ASUS_ - 1072009

IdentifyingNumber : E9N0CJ06786239E
Name              : TP300LD
Vendor            : ASUSTeK COMPUTER INC.
Version           : 1.0
Caption           : Computer System Product

Manufacturer : ASUSTeK COMPUTER INC.
Model        :
Name         : Base Board
SerialNumber : BSN12345678901234567
SKU          :
Product      : TP300LD

Manufacturer   : ASUSTeK COMPUTER INC.
Model          :
LockPresent    : False
SerialNumber   : E9N0CJ06786239E
SMBIOSAssetTag : No Asset Tag
SecurityStatus : 3

Domain              : WORKGROUP
Manufacturer        : ASUSTeK COMPUTER INC.
Model               : TP300LD
Name                : LOCALHOST
PrimaryOwnerName    : dave@davidsteimle.net
TotalPhysicalMemory : 6319890432
```

There are, obviously, several differences here. First, we are getting a lot more information from [``$ScriptBlock2``](#ScriptBlock2). Second, [``$ScriptBlock2``](#ScriptBlock2) is not as pretty, or usable as [``$ScriptBlock1``](#ScriptBlock1).

> *Side Note:* ``$ScriptBlock2`` will return arrays of objects. This is part of what makes it less useful. Enter ``$MyQuery2.Name`` and you will get several responses, but no way to differentiate which WMI call they belong to.

Just for fun, I ran both scriptblocks 10, 100, and 1000 times with ``Measure-Command`` against a a single (remote) system:

```
PS> Measure-Command {
    $i = 1
    while($i -le 10){
        Invoke-Command -ComputerName RemoteLaptop -ScriptBlock $ScriptBlock1
        $i++
    }
} | Select-Object -Property TotalSeconds

TotalSeconds
------------
  17.6947685

PS> Measure-Command {
    $i = 1
    while($i -le 10){
        Invoke-Command -ComputerName RemoteLaptop -ScriptBlock $ScriptBlock2
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

> *Side Note:* The point here is to make you aware of how long your actions take so that you can estimate how long your total job will take. Even if you are using a threaded option, it is worth knowing that every machine will take roughly two seconds to complete.

## Scenario

So, the Boss emails you and says:

```
Steimle: scan the field for SerialNumber, Manufacturer, UUID, BaseBoardProduct, ChassisTypes. Why are you still reading this? Go, man, go!
```

Sweet! Those are the items I am getting with [``$ScriptBlock1``](#ScriptBlock1). My fictional Enterprise has 10,000 machines. Based on my timing above, this should take about 5 hours, but it's easy!

```
Starts script, answers some emails, gets coffee, attends a meeting, goes to lunch. Waits a bit... Done!
```

So, I wrap my results up in a CSV, because managers love _Excel_, and off it goes.

Incoming email:

```
Steimle: I don't see BIOS version in these numbers. Get me the BIOS version ASAP!
```

> For the record, none of my current bosses talk to me this way.

Well, I still have [``$ScriptBlock2``](#ScriptBlock2), and it runs a little faster...

Reply to boss:

```
I'll have that for you in the morning, your benevolence.
```

```
Starts script, sweats a bit. Goes home. New data in the AM. All done.
```

Or am I...?

## Going a Bit Deeper

So, while [``$ScriptBlock2``](#ScriptBlock2) gives us more information, it does not come back to us in a useful manner. Go ahead and run it on your system now. I'll wait...

```powershell
$ScriptBlock2 = {
    $namespace = "root\CIMV2"
    Get-WmiObject -class Win32_Bios -namespace $namespace
    Get-WmiObject Win32_ComputerSystemProduct
    Get-WmiObject Win32_BaseBoard
    Get-WmiObject Win32_SystemEnclosure
    Get-WmiObject Win32_ComputerSystem
}

$MyQuery2 = Invoke-Command -ScriptBlock $ScriptBlock2

$MyQuery2
```

Your ``$MyQuery2`` is a mess, right? Well, you ain't seen nothing yet. Try this:

```powershell
$MyQuery2 | Select-Object -Property *
```

What we need is a way to make that information come back to us in a logical and useful form. Let's rebuild [``$ScriptBlock2``](#ScriptBlock2) as [``$ScriptBlock3``](#ScriptBlock3) and add some other data we can play with:

#### ScriptBlock3

```powershell
$ScriptBlock3 = {
    # Create an object with desired properties (named after our queries) 
    # and then populate the property with resultant objects
    $Response = New-Object -Type PSObject | `
        Select-Object ComputerName,Win32_Bios,Win32_ComputerSystemProduct,Win32_BaseBoard,`
            Win32_SystemEnclosure,Win32_ComputerSystem,PSVersionTable,LastReboot,CurrentKB
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
    $Response
}

$MyQuery3 = Invoke-Command -ComputerName Laptop1 -ScriptBlock $ScriptBlock3
```

Notice that I have added the property ``ComputerName`` to the ``$Response`` object. The computer name appears roughly 26 times in my query data, but I want to make it a top-level data point. I am also capturing the last installed KB, the Last Boot Time (per our previous example), and ``$PSVersionTable``.

Now, if you run that code, and then check ``$MyQuery3`` it is not as pretty as [``$ScriptBlock1``](#ScriptBlock1), but if you check ``$MyQuery3.Win32_Bios.SMBIOSBIOSVersion`` what do you get? Try that with the ``$MyQuery2`` from [``$ScriptBlock2``](#ScriptBlock2). I'm not going anywhere.

> **Side Note:** when it comes to reading complicated, many layered objects, I like to pipe them through ``ConvertTo-Json`` for readability.

Now we just need to run the code against the field, and we are good; and if we hang on to the results, we might be able to respond to the "you forgot the manufacturer," email we will receive shortly.

## How Do We Run This Against the Field?

There are numerous ways to do this. It is much quicker to use a threaded methodology, but I am not good at that, and it is beyond the scope of this discussion.

I will generally get an object of system names. This might be from a Tanium question, or I will query ConfigMgr for systems. A list of machines to check might have even come with my marching orders.

> **Note:** be careful here, in your Enterprise. If you have a DEV environment, try a few systems there first. If you are running against the Enterprise, make sure you have buy in from someone. This behavior could be misinterpreted by security. "Cover thy ass shall be the whole of the law."

So, in this example, I have a fictional exported table from Tanium:

```
Computer Name,Count
Laptop1,1
Laptop2,1
Laptop5,1
Laptop9,1
```

I will take this text table, make it a [Here String](https://devblogs.microsoft.com/scripting/powertip-use-here-strings-with-powershell/), take the space out of _Computer Name_, and convert from CSV.

```powershell
$Systems = @"
ComputerName,Count
Laptop1,1
Laptop2,1
Laptop5,1
Laptop9,1
"@ | ConvertFrom-Csv
```

Now it looks like this:

```
ComputerName Count
------------ -----
Laptop1      1
Laptop2      1
Laptop5      1
Laptop9      1
```

We want to gather the data from these systems, so we need a way to hold the results. A generic list is a good choice, and easily added to.

> Use a generic list rather than an array, unless you are sure of the array's size beforehand and build an empty array of that size. ``$Array += $Result`` is bad practice and will slow your process down exponentially.

```powershell
$Results = New-Object "System.Collections.Generic.List[PSObject]"
```

Then, we want to loop through the list of names, and run our scriptblock:

```powershell
$Systems.ForEach({
    $Results.Add($(Invoke-Command -ComputerName $PSItem.ComputerName -ScriptBlock $ScriptBlock3))
})
```

> **Side Note** ``$_`` is an alias for ``$PSItem``. ``$_`` is widely recognized, but ``$PSItem`` is best prectice.

The resultant object, ``$Results``, is not the most beautiful thing in the world, but we can work with it.

## The Final Bit: Who is this data for?

You need to know your audience. If I'm sending it to one of you folks, I might just send you a JSON file you could turn into an object, or if I want to be cool I'll drop it on a web server and send you an API link to save you some work. But what if I'm sending it to an Engineer or Tech who needs to address problem systems? What if I'm sending it to this guy?

<div style="text-align:center">

![That would be great...](https://davidsteimle.net/rtpsug/lundberg.gif)

</div>

Sometimes the key to having data is knowing how to give it to people, and having methods to do so in mind makes it pretty easy.

The easiest method for you to hang on to and share with other Powershell folks is JSON.

```powershell
$Results | ConvertTo-Json | Out-File ./MyResults.json
```

Send that in an email and they can ``$DavesResults = Get-Content ./MyResults.json | ConvertFrom-Json``, or drop it on a web server, and they can ``$DavesResults = Invoke-RestMethod -Uri https://davidsteimle.net/rtpsug/MyResults.json`` and they have all the data, and can do with it what they like. ([JSON Link](https://davidsteimle.net/rtpsug/MyResults.json))

However, that is a whole lot of data. Sometimes it is best to give what was asked for, so in this case we might want to build an accessible data set which includes the requested items in a flat object.

### Trim That Data

What was that the boss asked for again?

* SerialNumber
* Manufacturer
* UUID
* BaseBoardProduct
* ChassisTypes
* SMBIOSBIOSVersion

Let's go ahead and assume they wanted _Computer Name_ too, because, duh.

Let's build another generic list to hold our data:

```powershell
$BossRequest = New-Object "System.Collections.Generic.List[PSObject]"
```

We need to know where the items required are, and we do, because they were defined in our [``$ScriptBlock1``](#ScriptBlock1) query. Getting them out of our object will take a bit of digging. Let's work with a single system first.

```
$Results[0] | ConvertTo-Json

# I am missing something here...
```

In fact, with a bit of tweaking, [``$ScriptBlock1``](#ScriptBlock1) will be very useful to us now. For example, ``Get-WmiObject -class Win32_Bios -namespace $namespace | Select-Object -ExpandProperty SerialNumber`` becomes ``$Result.Win32_Bios.SerialNumber``, which is just Current Item ($Result), Class (Win32_Bios), Property (SerialNumber).

Let's make a loop, mimicing its behavior:

#### Modified ScriptBlock1 as a Loop

```powershell
foreach($Result in $Results){
    $obj = New-Object -Type PSObject | `
        Select-Object ComputerName, SerialNumber, Manufacturer, UUID, `
            BaseBoardProduct, ChassisTypes, SMBIOSBIOSVersion

    $obj.ComputerName = $Result.ComputerName
    $obj.SerialNumber = $Result.Win32_Bios.SerialNumber
    $obj.Manufacturer = $Result.Win32_Bios.Manufacturer
    $obj.UUID = $Result.Win32_ComputerSystemProduct.UUID
    $obj.BaseBoardProduct = $Result.Win32_BaseBoard.Product
    $obj.ChassisTypes = $Result.Win32_SystemEnclosure.ChassisTypes
    $obj.SMBIOSBIOSVersion = $Result.Win32_Bios.SMBIOSBIOSVersion

    $BossRequest.Add($obj)
}
```

That is now a nicely flattened data set that the boss can do with as they please. And if they come back and ask for another data point you have collected, you can modify the loop and re-run with the new addition.

### Sharing that Data

The easiest way to share with non-scripters is the CSV file. They can open it in Excel and add colors and sort... all those things people love to do. Simple:

```powershell
$BossRequest | ConvertTo-Csv | Out-File -Path ./DavesResults.csv
```

# After Thoughts

This was a basic look at gathering data, in a manner which I use fairly regularly. I did not include some things that will improve your time-to-run and eventual success, as they would have distracted a bit, but I want to include some of these here:

## Test-Connection

When we went through our list of systems, we easily could have added a test to see if the system was alive, or even existed. A system which cannot be reached by WinRM can take longer to process than a system which is available (as trying to establish a connection can go on for some time). Speed can be improved, and errors avoided, with something like:

```powershell
if(Test-Connection $PSItem.ComputerName){
    # Your code here
} else {
    # Note that the system was unavailable
}
```

You can set parameters to ``Test-Connection`` to speed it up, depending on how important every result is. If I need data fast and do not need 100% of possible answers I will do something like ``Test-Connection -ComputerName $PSItem.ComputerName -BufferSize 10 -Count 1 -ErrorAction SilentlyContinue``, which will skip a slow to respond or offline machine quickly. If I know my network is slow, a normal ``Test-Connection`` can help skip systems which I cannot reach, and I can note that they were unreachable.

## Error Handling

Similar to above, but more flexible:

```powershell
try {
    Test-Connection $PSItem.ComputerName -ErrorAction Stop
    # Connection was successful, so try your code
    # Your code here
} catch {
    # Note that the system was unavailable
}
```

## Record as You Go

So, if we are talking about a lot of systems, and a lot of time, what happens if you have a power outage, or IT sends a shutdown command in the middle of the night. Whether your script completed or not, its results were all stored in volatile memory. One way to keep the data you gain is to write it, in some manner.

I like to use a database, such as SQLite3. I will transform my results into a SQL query, and add them to a simple database. The above results, however, are multi-level, and might be hard to database. You could convert individual results to JSON and write each to a file or files for later retreival, or you could database that JSON in a text field.

The bottom line is that in the above scenario you are relying on your system state not changing. If you get everything, and your system is still in good shape when you are done, well, then you have both. If something happens during your run, at least you have the data you gathered, even if it is not complete. With some data management, you could begin where you left off and cut down your time to complete.



## Clearing Variables

When looping, as above, it is a good idea to recreate variables each time, or re-initialize them, to keep previous successful results from taining current failed results.

## Error Handling in Your Script Block

What happens when something goes wrong on the remote system? Perhaps you are trying to get a value that does not exist. You might want to control the response. A weird example I had was in getting a date from a registry query. My result set was littered with the date "01/01/0001 00:00:00". What in the world was going on? Turns out the registry value was empty, and returned a ``1`` (likely an exit code), so when I converted that to ``datetime`` I get:

```
PS C:\> [datetime]1

Monday, January 1, 0001 12:00:00 AM
```

In that case I did not want to run the query again, so I fixed my results, but had I handled things properly, a try/catch around that date query could have returned ``$null`` instead of messy data.

# Work on this....

But first, heres a little callback to some earlier presentations for you to play with:

```powershell
$ChassisTypes = Invoke-RestMethod https://davidsteimle.net/rtpsug/chassistypes.json
```
