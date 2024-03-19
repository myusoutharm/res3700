## Check if RES 3700 AutoSequence is stuck
## When RES 3700 Autosequence is stuck, EOD procedure often fails to execute, resulting in sales numbers not posted and incorrect report
## A common fix, recommneded by Oracle, is to re-install AutoSequence service
## Save this file and its configuration file in INSTALLATION_PATH\RES\POS\Scripts
## Corpyright Minghui Yu, myu@southarm.ca
## Free script; no support; use at your own risk

# Read config file
$configFile = "config-autosequencecheck.txt"
$config = @{}
Get-Content $configFile | ForEach-Object {
    $key, $value = $_ -split '=', 2
    $config[$key.Trim()] = $value.Trim()
}

# Define the API key and JSON template
$apiKey = 'API_KEY_HERE' ##smtp2go API. 
$to = $config["to"]
$sender = $config["sender"]
$templateId = $config["template_id"]

$jsonTemplate = @"
{
    "api_key": "$apiKey",
    "to": $to,
    "sender": "$sender",
    "template_id": "$templateId"
}
"@

# Send HTTP POST request
# https://apidoc.smtp2go.com/documentation/
function SendHttpPostRequest {
    param (
        [string]$url,
        [string]$body
    )

    try {
        $headers=@{}
        $headers.Add("accept", "application/json")
        $headers.Add("Content-Type", "application/json")
        $response = Invoke-WebRequest  -Uri $url -Method Post -Headers $headers -ContentType 'application/json' -Body $body
        #Write-Output "HTTP POST request sent successfully."
    }
    catch {
        Write-Error "Failed to send HTTP POST request: $_"
    }
}

# Search for the string "still running" in each log file
$logFiles = @("..\etc\3700d.log", "..\etc\3700d.log.0")
foreach ($logFile in $logFiles) {
    if (Test-Path $logFile) {
        $content = Get-Content $logFile -Raw
        if ($content -match "still running") {
            #Write-Host "String 'still running' found in $logFile. Sending HTTP POST request..."
            #Write-Host "To is $to"
            #Write-Host "Sender is $sender"
            #Write-Host "Template id Is $templateId"
            SendHttpPostRequest -url "https://api.smtp2go.com/v3/email/send/" -body $jsonTemplate
        }
        else {
            #Write-Host "String 'still running' not found in $logFile."
        }
    }
    else {
        Write-Warning "File $logFile not found."
    }
}
