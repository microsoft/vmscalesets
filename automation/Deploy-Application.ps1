[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    $BlobContainerName,
    [Parameter(Mandatory = $true)]
    $ReleaseFolderName
)

$extensionName = "AppInstallExtension"
$warningPreference = "SilentlyContinue"

$storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName
$autoScaleSettings = Get-AzAutoscaleSetting -ResourceGroupName $ResourceGroupName

# Find the autoscale which has zero instances = inactive
# Find the autoscale which has non-zero instances = active
foreach ($item in $autoScaleSettings) {
    $someResource = Get-AzResource -ResourceId $item.TargetResourceUri
    $someVmss = Get-AzVmss -ResourceGroupName $someResource.ResourceGroupName -VMScaleSetName $someResource.ResourceName 
    # sanity check; actual VMSS count should be zero <-- matches auto-scale 0 default
    if ($item.Profiles[0].Capacity.DefaultProperty -eq 0 -and $someVmss.Sku.Capacity -eq 0) {
        $inactiveAutoScaleProfile = $item
    }
    # actual VMSS count should be non-zero <-- matches auto-scale non-zero default
    if ($item.Profiles[0].Capacity.DefaultProperty -gt 0 -and $someVmss.Sku.Capacity -gt 0) {
        $activeAutoScaleProfile = $item
    }
}

# Ensure state of resource group is consistent for performing blue/green deployment
# Should be 2 profiles for CPU autoscale, a VMSS with non-zero instances, 
# a VMSS with zero instance and a single storage account.
if ($inactiveAutoScaleProfile -and $activeAutoScaleProfile -and $storageAccount -and $storageAccount.Count -eq 1) {
    # Get the VMSS associated with inactive autoscale
    $inactiveResource = Get-AzResource -ResourceId $inactiveAutoScaleProfile.TargetResourceUri
    $inactiveVmss = Get-AzVmss -ResourceGroupName $inactiveResource.ResourceGroupName -VMScaleSetName $inactiveResource.ResourceName
    # Can't update an extension in PowerShell, remove it and add it (release folder will change)
    try {
        Write-Output "Removing extension from $($inactiveVmss.Name)"
        Remove-AzVmssExtension -VirtualMachineScaleSet $inactiveVmss -Name $extensionName | Out-Null
        $inactiveVmss | Update-AzVmss | Out-Null
        Write-Output "Removed extension from $($inactiveVmss.Name)"
    }
    catch {
        Write-Host "No extension found with name $extensionName, will continue"
    }
    # Files to downloaded to VMSS, note that when using folders, the file name should be qualified in "commandToExecute"
    $settings = @{
        "fileUris"         = (
            "$($storageAccount.PrimaryEndpoints.Blob)$BlobContainerName/install.ps1",
            "$($storageAccount.PrimaryEndpoints.Blob)$BlobContainerName/azcopy.exe",
            "$($storageAccount.PrimaryEndpoints.Blob)$BlobContainerName/dotnet-hosting-5.0.10-win.exe"
        );
        "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File install.ps1 $($storageAccount.PrimaryEndpoints.Blob)$BlobContainerName  $ReleaseFolderName"
    }

    $storageAccountKey = Get-AzStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName

    $protectedSettings = @{
        "storageAccountName" = $storageAccount.StorageAccountName; 
        "storageAccountKey"  = $storageAccountKey[0].Value
    };

    # Update inactive VMSS with the extension pointing to latest app version
    Write-Output "Adding extension to VMSS $($inactiveVmss.Name)"
    $inactiveVmss = Add-AzVmssExtension `
        -VirtualMachineScaleSet $inactiveVmss `
        -Name $extensionName `
        -Publisher "Microsoft.Compute"  `
        -Type "CustomScriptExtension" `
        -TypeHandlerVersion "1.9" `
        -Setting $settings `
        -ProtectedSetting $protectedSettings
    $inactiveVmss | Update-AzVmss | Out-Null
    Write-Output "Added extension to VMSS $($inactiveVmss.Name)"
        
    # Get the active VMSS
    $activeResource = Get-AzResource -ResourceId $activeAutoScaleProfile.TargetResourceUri
    $activeVmss = Get-AzVmss -ResourceGroupName $activeResource.ResourceGroupName -VMScaleSetName $activeResource.ResourceName      
        
    # Prevent auto-scale from doing anything till the new version is handling load
    Remove-AzAutoscaleSetting -ResourceGroupName $ResourceGroupName -Name $inactiveAutoScaleProfile.Name | Out-Null
    Remove-AzAutoscaleSetting -ResourceGroupName $ResourceGroupName -Name $activeAutoScaleProfile.Name | Out-Null
        
    # Scale-out new version to old version's capacity 
    Write-Output "Scaling-out $($inactiveVmss.Name) from 0 to $($activeVmss.Sku.Capacity)"
    $inactiveVmss.Sku.Capacity = $activeVmss.Sku.Capacity
    $inactiveVmss | Update-AzVmss | Out-Null 
    Write-Output "Scale-out $($inactiveVmss.Name) completed"
        
    # Scale in the active VMSS (old app version) to 0
    Write-Output "Scaling-in $($activeVmss.Name) from $($activeVmss.Sku.Capacity) to 0"
    $activeVmss.Sku.Capacity = 0
    $activeVmss | Update-AzVmss | Out-Null
    Write-Output "Scale-in $($activeVmss.Name) completed"

    # Swap autoscale profiles between active & inactive VMSS
    $inactiveAutoScaleProfile.Profiles[0].Capacity, $activeAutoScaleProfile.Profiles[0].Capacity = $activeAutoScaleProfile.Profiles[0].Capacity, $inactiveAutoScaleProfile.Profiles[0].Capacity
    $inactiveAutoScaleProfile | Add-AzAutoscaleSetting | Out-Null
    $activeAutoScaleProfile | Add-AzAutoscaleSetting | Out-Null
        
    Write-Output "################## Done scale swap ##################"
}
else {
    Write-Error "Blue/Green VMSS doesn't seem to be a consistent state that permits upgrading."
}

