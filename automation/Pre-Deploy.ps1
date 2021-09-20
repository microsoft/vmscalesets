[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $resourceGroupName
)

$autoScaleSettingsList = Get-AzAutoscaleSetting -ResourceGroupName $resourceGroupName -WarningAction Ignore
foreach ($setting in $autoScaleSettingsList) {
    Write-Host "Removing $($setting.Name)"
    Remove-AzAutoscaleSetting -ResourceGroupName $resourceGroupName -Name $setting.Name -WarningAction Ignore | Out-Null
}

$metricRuleList = Get-AzMetricAlertRuleV2 -ResourceGroupName $resourceGroupName -WarningAction Ignore
foreach ($rule in $metricRuleList) {
    Write-Host "Removing $($rule.Name)"
    $rule | Remove-AzMetricAlertRuleV2 -WarningAction Ignore | Out-Null
}

$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName

if ($storageAccount) {
    $storageDataContributorRoles = az role assignment list --role "Storage Blob Data Contributor" --scope $storageAccount.Id
    if ($storageDataContributorRoles -ne "[]") {
        Write-Host "Removing 'Storage Blob Data Contributor' roles from: $($storageAccount.StorageAccountName)"
        az role assignment delete --role "Storage Blob Data Contributor" --scope $storageAccount.Id
    }
    else {
        Write-Host "No 'Storage Blob Data Contributor' roles in: $($storageAccount.StorageAccountName) to remove"
    }

    
    $storageReaderRoles = az role assignment list --role "Reader" --scope $storageAccount.Id 
    if ($storageReaderRoles -ne "[]") {
        Write-Host "Removing 'Reader' roles from: $($storageAccount.StorageAccountName)"
        az role assignment delete --role "Reader" --scope $storageAccount.Id
    }
    else {
        Write-Host "No 'Reader' roles in: $($storageAccount.StorageAccountName) to remove"
    }

    $resGroupReaderRoles = az role assignment list --role "Reader" --resource-group $storageAccount.ResourceGroupName 
    if ($resGroupReaderRoles -ne "[]") {
        Write-Host "Removing 'Reader' roles from: $($storageAccount.ResourceGroupName)"
        az role assignment delete --role "Reader" --resource-group $storageAccount.ResourceGroupName 
    }
    else {
        Write-Host "No 'Reader' roles in: $($storageAccount.ResourceGroupName) to remove"
    }
}