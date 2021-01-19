# VM exception list(by default all VM that is running will be scanned)
$ExAzureVMList = @("") 
# Log Analytics Workspace ID
$WorkspaceID = ""
# Automation account information
$AutomationAccountName = ""
$AutomationAccountResourceGroup = ""
# Set webhook url for Teams & Logic App
$TeamsUrl = "" 
$LogicAppUrl = ""

function CheckVMBootTime($VMName)
{
    Write-Host "Start to check VM $($VMName) boot time"
    #Check if variable for VM exists, if not, add variable for that VM.
    try
    {
        $AutomationVariable = Get-AzAutomationVariable -AutomationAccountName $AutomationAccountName -Name $VMName -ResourceGroupName $AutomationAccountResourceGroup -ErrorAction Stop
        $BootTime = $AutomationVariable.Value
    }catch
    {
        Write-Host "create new boot time for VM $($VMName)"
        $Temp = New-AzAutomationVariable -AutomationAccountName $AutomationAccountName -Name $VMName -Encrypted $False -Value "By default" -ResourceGroupName $AutomationAccountResourceGroup
    }

    #Check activity log to see if VM restarted in the past 1 hour
    $Query = 'AzureActivity | where _ResourceId contains "' + $VMName + '" and TimeGenerated  > ago(1h) and ResourceProviderValue == "MICROSOFT.COMPUTE" and ActivityStatusValue == "Start" | where Properties contains "Microsoft.Compute/virtualMachines/start/action" or Properties  contains "Microsoft.Compute/virtualMachines/restart/action" | top 1 by TimeGenerated'
    $ExecuteQuery = (Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $Query).Results.Properties
    if($null -ne $ExecuteQuery)
    {
        $BootTimeString = (($ExecuteQuery | ConvertFrom-Json).eventSubmissionTimestamp).split(".")[0]
        $BootTimeDate = ([datetime]::ParseExact($BootTimeString, 'yyyy-MM-ddTHH:mm:ss',$null)).AddHours(8)
        $BootTime = $BootTimeDate.ToString()
        Write-Host "$($VMName)'s boot time needed to be updated"
        $Temp = Set-AzAutomationVariable -AutomationAccountName $AutomationAccountName -Name $VMName -ResourceGroupName $AutomationAccountResourceGroup -Value $BootTime -Encrypted $False
    }
    $BootTimeResult = "$VMName<br/>Last boot time is :  $BootTime<br/>"
    return $BootTimeResult
}

function CheckVMMetric($VMId)
{
    #VMName
    $VMName = $VMId.split("/")[8]
    Write-Host "Start to check VM $($VMName) Metrics"
    #Average CPU Utilization
    $MetricCPU = Get-AzMetric `
        -ResourceId $VMId `
        -MetricName "Percentage CPU" `
        -TimeGrain 00:01:00
    $CPUUsage = $MetricCPU.Data[$MetricCPU.Data.Count-3].Average
    #Network Received
    $MetricNetworkReceived = Get-AzMetric `
        -ResourceId $VMId `
        -MetricName "Network In Total" `
        -TimeGrain 00:01:00
    $NetworkReceivedTemp = ($MetricNetworkReceived.Data[$MetricNetworkReceived.Data.Count-3].Total) / 1024
    if($null -ne $NetworkReceivedTemp)
    {
        $NetworkReceived = [math]::round([double]::Parse($NetworkReceivedTemp), 2)
    }
    #Network Sent
    $MetricNetworkSent = Get-AzMetric `
        -ResourceId $VMId `
        -MetricName "Network Out Total" `
        -TimeGrain 00:01:00
    $NetworkSentTemp = ($MetricNetworkSent.Data[$MetricNetworkSent.Data.Count-3].Total) / 1024
    if($null -ne $NetworkSentTemp)
    {
        $NetworkSent = [math]::round([double]::Parse($NetworkSentTemp), 2)
    }
    #Result that will be sent to Teams
    $MetricResult = "Average CPU Utilization: $CPUUsage %<br/>Network Received: $NetworkReceived KB<br/>Network Sent: $NetworkSent KB<br/>"
    return $MetricResult
}

function CheckVMLog($VMName)
{
    Write-Host "Start to check VM $($VMName) Logs"
    #Get Used Memory
    $Query = 'InsightsMetrics | where Computer contains "' + $VMName + '"and TimeGenerated > ago(15m) and Name == "AvailableMB" | top 1 by TimeGenerated'
    $AvailableMemoryQueryResult = (Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $Query).Results
    $AvailableMemory = $AvailableMemoryQueryResult.Val
    if($null -ne $AvailableMemory)
    {
        $MemorySize = [double]::Parse($AvailableMemoryQueryResult.Tags.split(":")[1].trim("}"))
        if($null -ne $MemorySize)
        {
            $UsedMemoryTemp = ($MemorySize - $AvailableMemory) / $MemorySize * 100
            $UsedMemory = [math]::round([double]::Parse($UsedMemoryTemp), 2)
        }
    }
    $LogResult += "Memory Utilization: $UsedMemory %<br/>"
    #Get disk free space
    $Query = 'InsightsMetrics | where Computer contains "' + $VMName + '" | top 1 by TimeGenerated | join kind=rightsemi(InsightsMetrics) on TimeGenerated | where Computer contains "' + $VMName + '" and TimeGenerated > ago(15m) and Name == "FreeSpaceMB"'
    $DiskQueryResult = (Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $Query).Results
    $TotalDiskFreeSpace = 0
    $TotalDiskSpace = 0
    for($num = 0; $num -le $DiskQueryResult.Tags.Length-1; $num++)
    {
        #Total free disk space
        $TotalDiskFreeSpace += [double]::Parse($DiskQueryResult.Val[$num])
        #Total disk space
        $Tag = $DiskQueryResult.Tags[$num]
        $SpaceInTag = [double]::Parse($Tag.split(":")[$Tag.split(":").Length-1].Trim("}"))
        $TotalDiskSpace += $SpaceInTag
        #Get "/" & "C:" partition free space
        if($Tag.Contains('"/"'))
        {
            $RootFreeSpace = [math]::round([double]::Parse($DiskQueryResult.Val[$num] / $SpaceInTag * 100), 2)
            $LogResult += "Free Storage Space (/, %): $RootFreeSpace %<br/>"
        }
        if($Tag.Contains('"C:"'))
        {
            $CFreeSpace = [math]::round([double]::Parse($DiskQueryResult.Val[$num] / $SpaceInTag * 100), 2)
            $LogResult += "Free Storage Space (C:, %): $CFreeSpace %<br/>"
        }
    }
    if(0 -ne $TotalDiskFreeSpace -and 0 -ne $TotalDiskSpace)
    {
        $FreeSpace = [math]::round($TotalDiskFreeSpace / $TotalDiskSpace, 2) * 100
    }
    $LogResult += "Free Storage Space (Total, %): $FreeSpace %<br/><br/>"
    return $LogResult
}

$Result = ""

#Get current time zone and time
$TimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Singapore Standard Time")
$Time = ([System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $TimeZone)).ToString()
$Result += "Current time: $Time<br/><br/>"

Write-Host "Start to check the VM status"
$Result += "<h2>------VM------</h2>"
#Check required VMs and thier OS type
$VMList = @()
$AllVMList = Get-AzVM -status
foreach($VM in $AllVMList)
{
    if($VM.PowerState -eq "VM running" -and $ExAzureVMList -inotcontains $VM.Name)
    {
        $VMList += $VM.Id
    }
}

foreach($VMId in $VMList)
{
    $VMName = $VMId.split("/")[8]
    #Get system boot time
    $BootTimeResult = CheckVMBootTime $VMName
    $Result += $BootTimeResult

    #Get CPU & Network metricsof VM
    $MetricResult = CheckVMMetric $VMId
    $Result += $MetricResult

    #Get memory size & disk space metrics of VM
    $LogResult = CheckVMLog $VMName $WorkspaceID
    $Result += $LogResult
}

#Send metric value to Teams Channel & Logic App(Email)
if ($Result) {
    # convert text format to JSON format
    $postcontent = @{ "text" = "$Result" }
    $json = ConvertTo-Json $postcontent
    # send message to Teams
    Invoke-RestMethod -Method post -ContentType 'Application/Json' -Body $json -Uri $TeamsUrl
    # send message to Logic App
    Invoke-RestMethod -Method post -Body $Result -Uri $LogicAppUrl
} else
    {
        Write-Host "Sorry, there's no metric currently. Please contact script owner for further investigation"
        exit
    }
