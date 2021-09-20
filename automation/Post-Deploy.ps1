[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $resourceGroupName
)

$vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName
$natGateway = Get-AzNatGateway -ResourceGroupName $resourceGroupName

if ($vnet -and $natGateway) {
    foreach ($subnet in $vnet.Subnets) {
        $subnet.NatGateway = $natGateway
    }
    Write-Host "Setting NAT Gateway for subnets in VNET $($vnet.Name)"    
    $vnet | Set-AzVirtualNetwork
    Write-Host "Done setting NAT Gateway for subnets in VNET $($vnet.Name)"    
}
else {
    Write-Host 'No NAT Gateway found, outbound connectivity to public Azure impacted'
}