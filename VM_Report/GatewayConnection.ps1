#Input your connection name
$ConnectionList = @("","")

#Check Connection Status
Write-Host "Start to check the Virtual Network Gateway Connection status"
$Result += "<h2>------Connection------</h2>"
$RGNameList = (Get-AzResourceGroup).ResourceGroupName
foreach($RGName in $RGNameList)
{
    $VNGCList = Get-AzVirtualNetworkGatewayConnection `
            -ResourceGroupName $RGName
    if($VNGCList -ne $null)
    {
        foreach($VNGC1 in $VNGCList)
        {
            #Check if the connection is in the required list
            if($ConnectionList -contains $VNGC1.Name)
            {
                $VNGC2 = Get-AzVirtualNetworkGatewayConnection `
                    -ResourceGroupName $RGName `
                    -Name $VNGC1.Name
                Write-Host "Start to check Connection $($VNGC2.Name)"
                #VNGCStatus
                $VNGCStatus = $VNGC2.ConnectionStatus
                #VNGCName
                $VNGCName = $VNGC2.Name
                $Temp = "VNGCName: $VNGCName<br/>VNGCStatus: $VNGCStatus<br/><br/>"
                $Result += $Temp
            }
        }
    } 
}
