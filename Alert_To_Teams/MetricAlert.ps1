# get data from webhookdata
param
(
    [Parameter (Mandatory = $false)]
    [object] $WebhookData
)
if ($WebhookData) {
    $whd = (ConvertFrom-JSON -InputObject $WebhookData.RequestBody)
    # output purpose only
    $name = $whd.data.context.name
    $metricName = $whd.data.context.condition.allOf.metricName
    $metricValue = $whd.data.context.condition.allOf.metricValue
    $resourceName = $whd.data.context.resourceName
    #
    # set Teams webhook url
    $TeamsID = "" 
    #
    # convert text format to JSON format
    $postcontent = @{ "text" = "$metricName + $metricValue" }
    $json = ConvertTo-Json $postcontent
    # send message to Teams
    Invoke-RestMethod -Method post -ContentType 'Application/Json' -Body $json -Uri $TeamsID
} else
    {
        Write-Output "Sorry, there's no webhook data received. Please check if you have set the correct webhook url in your Azure Alert Action Group";
        exit;
    }
