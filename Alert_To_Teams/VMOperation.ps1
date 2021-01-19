# get data from webhookdata
param
(
    [Parameter (Mandatory = $false)]
    [object] $WebhookData
)
if ($WebhookData) {
    $whd = (ConvertFrom-JSON -InputObject $WebhookData.RequestBody)
    # output purpose only
    $name = $whd.data.context.activityLog.resourceId
    $caller = $whd.data.context.activityLog.caller
    $operation = $whd.data.context.activityLog.operationName
    #
    # set Teams webhook url
    $TeamsID = "" 
    #
    # convert text format to JSON format
    if(operationName -eq "Microsoft.Compute/virtualMachines/restart/action"){
        $postcontent = @{ "text" = "$name was restarted by $caller" }
        $json = ConvertTo-Json $postcontent
    } elseif(operationName -eq "Microsoft.Compute/virtualMachines/stop/action"){
        $postcontent = @{ "text" = "$name was stopped by $caller" }
        $json = ConvertTo-Json $postcontent
    } elseif(operationName -eq "Microsoft.Compute/virtualMachines/started/action"){
        $postcontent = @{ "text"= "$name was started by $caller" }
        $json = ConvertTo-Json $postcontent
    } else {
        Write-Output "Sorry, this operation can not be recognized."
    }
    # send message to Teams
    Invoke-RestMethod -Method post -ContentType 'Application/Json' -Body $json -Uri $TeamsID
} else
    {
        Write-Output "Sorry, there's no webhook data received. Please check if you have set the correct webhook url in your Azure Alert Action Group";
        exit;
    }
