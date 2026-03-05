#Requires -Modules Az.Accounts, Az.Compute, Az.ResourceGraph
<#
.SYNOPSIS
    Enterprise VM Auto Start/Stop Automation Runbook
.DESCRIPTION
    Automatically starts or stops Azure VMs based on schedule tags.
    Supports: Individual VMs, Resource Groups, Subscriptions
    Tags Used:
        AutoShutdown-Enabled   = "true"
        AutoShutdown-Time      = "19:00"     (24hr UTC)
        AutoStartup-Time       = "07:00"     (24hr UTC)
        AutoShutdown-Weekdays  = "true"      (Mon-Fri only)
        AutoShutdown-Timezone  = "GMT Standard Time"
    
.PARAMETER Action
    "Start" or "Stop" or "Auto" (evaluates tags)
.PARAMETER Scope
    "Subscription" or "ResourceGroup" or "VM"
.PARAMETER ResourceGroupName
    Required if Scope = ResourceGroup
.PARAMETER VMName
    Required if Scope = VM
.PARAMETER WhatIf
    Simulation mode — logs actions without executing

.NOTES
    Author:     Enterprise DevSecOps | KPMG
    Version:    2.0.0
    RunAs:      System Managed Identity
    Schedule:   Every 30 minutes via Azure Automation Schedule
    Alerting:   Sends summary to Log Analytics + Teams webhook
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Start", "Stop", "Auto")]
    [string]$Action = "Auto",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Subscription", "ResourceGroup", "VM")]
    [string]$Scope = "Subscription",

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$VMName,

    [Parameter(Mandatory = $false)]
    [bool]$WhatIf = $false
)

# ============================================================
# CONFIGURATION
# ============================================================
$Script:Config = @{
    LogAnalyticsWorkspaceId = $env:LOG_ANALYTICS_WORKSPACE_ID
    LogAnalyticsKey         = $env:LOG_ANALYTICS_KEY
    TeamsWebhookUrl         = $env:TEAMS_WEBHOOK_URL
    LogType                 = "VMAutoStartStop"
    DefaultTimezone         = "GMT Standard Time"
    TagPrefix               = "AutoShutdown"
}

# ============================================================
# LOGGING FUNCTIONS
# ============================================================
function Write-AutoLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry  = "[$timestamp][$Level] $Message"
    Write-Output $logEntry

    # Send to Log Analytics
    Send-LogAnalytics -Message $Message -Level $Level -Timestamp $timestamp
}

function Send-LogAnalytics {
    param([string]$Message, [string]$Level, [string]$Timestamp)

    if (-not $Script:Config.LogAnalyticsWorkspaceId) { return }

    $body = @{
        TimeGenerated = $Timestamp
        Level         = $Level
        Message       = $Message
        Runbook       = "VMAutoStartStop"
        Environment   = $env:AZURE_SUBSCRIPTION_ID
    } | ConvertTo-Json

    try {
        $date   = [DateTime]::UtcNow.ToString("r")
        $contentLength = $body.Length
        $signature = Build-LogAnalyticsSignature -WorkspaceId $Script:Config.LogAnalyticsWorkspaceId `
                                                  -SharedKey $Script:Config.LogAnalyticsKey `
                                                  -Date $date `
                                                  -ContentLength $contentLength `
                                                  -LogType $Script:Config.LogType

        $headers = @{
            "Authorization"        = $signature
            "Log-Type"             = $Script:Config.LogType
            "x-ms-date"            = $date
            "time-generated-field" = "TimeGenerated"
        }

        $uri = "https://$($Script:Config.LogAnalyticsWorkspaceId).ods.opinsights.azure.com/api/logs?api-version=2016-04-01"
        Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json" -Headers $headers -Body $body
    }
    catch {
        Write-Warning "Log Analytics send failed: $_"
    }
}

function Build-LogAnalyticsSignature {
    param($WorkspaceId, $SharedKey, $Date, $ContentLength, $LogType)
    $stringToHash = "POST`n$ContentLength`napplication/json`nx-ms-date:$Date`n/api/logs"
    $bytesToHash   = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes      = [Convert]::FromBase64String($SharedKey)
    $hmac          = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key      = $keyBytes
    $calculatedHash = [Convert]::ToBase64String($hmac.ComputeHash($bytesToHash))
    return "SharedKey ${WorkspaceId}:${calculatedHash}"
}

function Send-TeamsNotification {
    param([string]$Title, [string]$Message, [string]$Color = "0076D7")

    if (-not $Script:Config.TeamsWebhookUrl) { return }

    $payload = @{
        "@type"      = "MessageCard"
        "@context"   = "http://schema.org/extensions"
        "themeColor" = $Color
        "summary"    = $Title
        "sections"   = @(@{
            "activityTitle"    = "🤖 Azure VM Automation"
            "activitySubtitle" = $Title
            "text"             = $Message
            "facts"            = @(
                @{ "name" = "Runbook";     "value" = "VMAutoStartStop" },
                @{ "name" = "Timestamp";   "value" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC") },
                @{ "name" = "WhatIf Mode"; "value" = $WhatIf.ToString() }
            )
        })
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-RestMethod -Uri $Script:Config.TeamsWebhookUrl -Method Post -ContentType "application/json" -Body $payload
    }
    catch {
        Write-Warning "Teams notification failed: $_"
    }
}

# ============================================================
# TIMEZONE & SCHEDULE EVALUATION
# ============================================================
function Get-LocalTime {
    param([string]$TimezoneId = "GMT Standard Time")
    try {
        $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById($TimezoneId)
        return [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tz)
    }
    catch {
        Write-AutoLog "Timezone '$TimezoneId' not found. Using UTC." -Level WARN
        return [DateTime]::UtcNow
    }
}

function Should-VMBeRunning {
    param([Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM)

    $tags = $VM.Tags

    # Check if automation is enabled
    if ($tags["AutoShutdown-Enabled"] -ne "true") {
        return $null  # Not managed by this automation
    }

    $timezone     = if ($tags["AutoShutdown-Timezone"]) { $tags["AutoShutdown-Timezone"] } else { $Script:Config.DefaultTimezone }
    $localTime    = Get-LocalTime -TimezoneId $timezone
    $currentHour  = $localTime.TimeOfDay
    $isWeekday    = $localTime.DayOfWeek -notin @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)

    # Weekday-only check
    $weekdayOnly  = $tags["AutoShutdown-Weekdays"] -eq "true"
    if ($weekdayOnly -and -not $isWeekday) {
        return $false  # Weekend — should be off
    }

    # Parse startup and shutdown times
    $startupTime  = if ($tags["AutoStartup-Time"])  { [TimeSpan]::Parse($tags["AutoStartup-Time"])  } else { [TimeSpan]::Parse("07:00") }
    $shutdownTime = if ($tags["AutoShutdown-Time"]) { [TimeSpan]::Parse($tags["AutoShutdown-Time"]) } else { [TimeSpan]::Parse("19:00") }

    # Should VM be running?
    if ($currentHour -ge $startupTime -and $currentHour -lt $shutdownTime) {
        return $true   # Within business hours — should be ON
    }
    else {
        return $false  # Outside business hours — should be OFF
    }
}

# ============================================================
# VM ACTION FUNCTIONS
# ============================================================
function Start-VMSafely {
    param([Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM)

    $vmStatus = Get-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Status
    $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus

    if ($powerState -eq "VM running") {
        Write-AutoLog "VM '$($VM.Name)' already running — skipping." -Level INFO
        return @{ Action = "Skipped"; Reason = "Already running" }
    }

    if ($WhatIf) {
        Write-AutoLog "[WHATIF] Would START VM: $($VM.Name) in $($VM.ResourceGroupName)" -Level INFO
        return @{ Action = "WhatIf-Start"; VMName = $VM.Name }
    }

    try {
        Write-AutoLog "Starting VM: $($VM.Name) in $($VM.ResourceGroupName)" -Level INFO
        Start-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -NoWait
        return @{ Action = "Started"; VMName = $VM.Name; ResourceGroup = $VM.ResourceGroupName }
    }
    catch {
        Write-AutoLog "Failed to start VM '$($VM.Name)': $_" -Level ERROR
        return @{ Action = "Failed"; VMName = $VM.Name; Error = $_.Exception.Message }
    }
}

function Stop-VMSafely {
    param([Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]$VM)

    # Check for exclusion tag
    if ($VM.Tags["AutoShutdown-Exclude"] -eq "true") {
        Write-AutoLog "VM '$($VM.Name)' has exclusion tag — skipping." -Level INFO
        return @{ Action = "Excluded"; VMName = $VM.Name }
    }

    $vmStatus   = Get-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Status
    $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus

    if ($powerState -eq "VM deallocated") {
        Write-AutoLog "VM '$($VM.Name)' already stopped — skipping." -Level INFO
        return @{ Action = "Skipped"; Reason = "Already stopped" }
    }

    if ($WhatIf) {
        Write-AutoLog "[WHATIF] Would STOP VM: $($VM.Name) in $($VM.ResourceGroupName)" -Level INFO
        return @{ Action = "WhatIf-Stop"; VMName = $VM.Name }
    }

    try {
        Write-AutoLog "Stopping VM: $($VM.Name) in $($VM.ResourceGroupName)" -Level INFO
        Stop-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Force -NoWait
        return @{ Action = "Stopped"; VMName = $VM.Name; ResourceGroup = $VM.ResourceGroupName }
    }
    catch {
        Write-AutoLog "Failed to stop VM '$($VM.Name)': $_" -Level ERROR
        return @{ Action = "Failed"; VMName = $VM.Name; Error = $_.Exception.Message }
    }
}

# ============================================================
# MAIN EXECUTION
# ============================================================
try {
    Write-AutoLog "========== VM AutoStartStop Runbook Started ==========" -Level INFO
    Write-AutoLog "Action: $Action | Scope: $Scope | WhatIf: $WhatIf" -Level INFO

    # Authenticate using Managed Identity
    Write-AutoLog "Authenticating via Managed Identity..." -Level INFO
    Connect-AzAccount -Identity | Out-Null
    Write-AutoLog "Authentication successful." -Level SUCCESS

    # Get VMs based on scope
    $vms = switch ($Scope) {
        "VM"            { @(Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName) }
        "ResourceGroup" { Get-AzVM -ResourceGroupName $ResourceGroupName }
        "Subscription"  { Get-AzVM }
    }

    Write-AutoLog "Found $($vms.Count) VMs in scope." -Level INFO

    # Process results tracking
    $results = @{
        Started   = [System.Collections.Generic.List[string]]::new()
        Stopped   = [System.Collections.Generic.List[string]]::new()
        Skipped   = [System.Collections.Generic.List[string]]::new()
        Failed    = [System.Collections.Generic.List[string]]::new()
        Excluded  = [System.Collections.Generic.List[string]]::new()
    }

    foreach ($vm in $vms) {
        Write-AutoLog "Processing VM: $($vm.Name)" -Level INFO

        $actionResult = switch ($Action) {
            "Start" { Start-VMSafely -VM $vm }
            "Stop"  { Stop-VMSafely -VM $vm }
            "Auto"  {
                $shouldRun = Should-VMBeRunning -VM $vm
                if ($null -eq $shouldRun) {
                    Write-AutoLog "VM '$($vm.Name)' not tagged for automation — skipping." -Level INFO
                    @{ Action = "Skipped"; Reason = "No automation tags" }
                }
                elseif ($shouldRun) {
                    Start-VMSafely -VM $vm
                }
                else {
                    Stop-VMSafely -VM $vm
                }
            }
        }

        # Track results
        switch ($actionResult.Action) {
            "Started"      { $results.Started.Add($vm.Name) }
            "Stopped"      { $results.Stopped.Add($vm.Name) }
            "Skipped"      { $results.Skipped.Add($vm.Name) }
            "Failed"       { $results.Failed.Add($vm.Name) }
            "Excluded"     { $results.Excluded.Add($vm.Name) }
            "WhatIf-Start" { $results.Started.Add("(WhatIf) $($vm.Name)") }
            "WhatIf-Stop"  { $results.Stopped.Add("(WhatIf) $($vm.Name)") }
        }
    }

    # Summary
    $summary = @"
VM Auto Start/Stop Summary:
✅ Started:  $($results.Started.Count)  — $($results.Started -join ', ')
🛑 Stopped:  $($results.Stopped.Count)  — $($results.Stopped -join ', ')
⏭️  Skipped:  $($results.Skipped.Count)
❌ Failed:   $($results.Failed.Count)   — $($results.Failed -join ', ')
🚫 Excluded: $($results.Excluded.Count)
"@

    Write-AutoLog $summary -Level SUCCESS

    # Send Teams notification if any actions taken
    if ($results.Started.Count -gt 0 -or $results.Stopped.Count -gt 0 -or $results.Failed.Count -gt 0) {
        $color = if ($results.Failed.Count -gt 0) { "FF0000" } else { "00AA00" }
        Send-TeamsNotification -Title "VM AutoStartStop Completed" -Message $summary -Color $color
    }

    Write-AutoLog "========== Runbook Completed Successfully ==========" -Level SUCCESS
}
catch {
    $errorMsg = "Critical runbook failure: $_"
    Write-AutoLog $errorMsg -Level ERROR
    Send-TeamsNotification -Title "VM AutoStartStop FAILED" -Message $errorMsg -Color "FF0000"
    throw $_
}
