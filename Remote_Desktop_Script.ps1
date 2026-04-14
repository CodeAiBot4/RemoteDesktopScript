# --------------------------------------------------------------
# Remote Utilities free install + Discord webhook notification
# --------------------------------------------------------------

# ------------------- 0️⃣ USER SETTINGS -------------------------
# If the environment variable RU_DISCORD_WEBHOOK is set it will be used,
# otherwise the hard‑coded fallback URL below is used.
$discordWebhook = $env:RU_DISCORD_WEBHOOK `
    ?? "https://discord.com/api/webhooks/1493692725919219792/LCiq_4OQ2jPQyPD9SrkMx7ux7oHAhSQOS5s4NZ1_H4aXU4eVpZm4SS2c8NsLwRVE2xGT"

# Password that the Remote Utilities host will use (change per machine if you wish)
$hostPassword = "FreePwd123!"

# Direct download link for the free Remote Utilities installer (latest free build)
$downloadUrl = "https://www.remoteutilities.com/download/RemoteUtilities_Desktop_17_4_0.exe"

# -----------------------------------------------------------------
$installerPath = "$env:TEMP\RU-Setup.exe"
$hostName      = $env:COMPUTERNAME
$hostKey       = "HKLM:\SOFTWARE\Remote Utilities\Host"
$serviceName   = "RemoteUtilitiesHost"

# 1️⃣ Download the installer
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

# 2️⃣ Silent installation
Start-Process -FilePath $installerPath -ArgumentList "/SILENT","/NORESTART" -Wait -NoNewWindow

# 3️⃣ Configure the host (set password)
if (-not (Test-Path $hostKey)) { New-Item -Path $hostKey -Force | Out-Null }
Set-ItemProperty -Path $hostKey -Name "HostName" -Value $hostName

# Remote Utilities expects the password as an MD5 hash
$md5      = [System.Security.Cryptography.MD5]::Create()
$hashHex  = ($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hostPassword)) |
            ForEach-Object { $_.ToString("x2") }) -join ""
Set-ItemProperty -Path $hostKey -Name "PasswordEnabled" -Value 1
Set-ItemProperty -Path $hostKey -Name "PasswordMD5"      -Value $hashHex

# 4️⃣ Open firewall (TCP 3360)
New-NetFirewallRule -DisplayName "Remote Utilities Host" `
    -Direction Inbound -Protocol TCP -LocalPort 3360 -Action Allow -Profile Any

# 5️⃣ Start the host service and set it to start automatically
Set-Service -Name $serviceName -StartupType Automatic
Start-Service -Name $serviceName

# 6️⃣ Retrieve the Host ID (wait a second if it isn’t there yet)
$hostID = (Get-ItemProperty -Path $hostKey -Name HostID -ErrorAction SilentlyContinue).HostID
if (-not $hostID) {
    Start-Sleep -Seconds 5
    $hostID = (Get-ItemProperty -Path $hostKey -Name HostID).HostID
}

# 7️⃣ Send a Discord webhook notification (optional)
if ($discordWebhook -and $hostID) {
    $payload = @{
        username = "RU‑Free‑Installer"
        embeds   = @(
            @{
                title       = "Remote Utilities Host ready"
                description = "Computer **$hostName** installed."
                color       = 0x00FF00
                fields = @(
                    @{ name = "Host ID";   value = "`$hostID`";   inline = $true }
                    @{ name = "Password";  value = "`$hostPassword`"; inline = $true }
                )
                timestamp = (Get-Date).ToString('o')
            }
        )
    } | ConvertTo-Json -Depth 4

    try {
        Invoke-RestMethod -Uri $discordWebhook -Method Post -ContentType "application/json" -Body $payload
    } catch {
        Write-Warning "Discord post failed: $_"
    }
} else {
    Write-Warning "Discord webhook URL or Host ID missing – no notification sent."
}

# 8️⃣ Clean up installer file
Remove-Item $installerPath -Force

Write-Host "`nRemote Utilities installed. Host ID: $hostID"
