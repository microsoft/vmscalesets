param($storageBlob, $releaseFolderName)

Start-Transcript

# Windows features
Install-WindowsFeature Web-Server -IncludeManagementTools

# Install .NET Core 5.x 
.\dotnet-hosting-5.0.10-win.exe /install /quiet /norestart /log dotnetlog.txt

# Restart IIS
net stop was /y
net start w3svc

# Reconfigure App Pool
Start-IISCommitDelay
$pool = Get-IISAppPool -Name DefaultAppPool
$pool.ManagedRuntimeVersion = ""
Stop-IISCommitDelay

Stop-WebAppPool DefaultAppPool
net stop was /y
net start w3svc
Start-WebAppPool DefaultAppPool

# Deploy the app
Stop-WebAppPool DefaultAppPool
.\azcopy login --identity
.\azcopy cp $storageBlob/$releaseFolderName/* C:\inetpub\wwwroot --recursive
Start-WebAppPool DefaultAppPool

# App Pool recycle after .NET Core App Deploy
# Restart-Computer -Force
Stop-WebAppPool DefaultAppPool
net stop was /y
net start w3svc
Start-WebAppPool DefaultAppPool

Stop-Transcript
