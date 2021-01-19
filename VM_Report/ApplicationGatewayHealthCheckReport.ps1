$GatewayName = ""
$ResourceGroupName = ""

#Get health status of Application Gateway
Write-Host "Starting to check the Application Gateway status"
$Result += "<h2>------Application Gateway------</h2>"
$AGHealthList = Get-AzApplicationGatewayBackendHealth -Name $GatewayName -ResourceGroupName $ResourceGroupName
if($AGHealthList -ne $null) 
{
    $AGHealthListObject = $AGHealthList.BackendAddressPoolsText | ConvertFrom-Json
    foreach($AGHealth in $AGHealthListObject)
    {
        $PoolName = ($AGHealth.BackendAddressPool.Id).split("/")[10]
        $HttpSetting =  ($AGHealth.BackendHttpSettingsCollection.BackendHttpSettings.Id).split("/")[10]
        $AGServerList = $AGHealth.BackendHttpSettingsCollection.Servers
        $Result += "PoolName: $PoolName<br/>HttpSetting: $HttpSetting<br/>"
    foreach($AGServer in $AGServerList)
    {
        $AGServerAddress = $AGServer.Address
        $HealthStatus = $AGServer.Health
        $Result += "Address: $AGServerAddress<br/>Health Status: $HealthStatus<br/>"
    }
        $Result += "<br/>"
    }
} else {
    Write-Host "No backend health found, please contact script owner"
}
