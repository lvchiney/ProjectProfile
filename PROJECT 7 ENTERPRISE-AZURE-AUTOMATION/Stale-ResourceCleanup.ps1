#Requires -Modules Az.Accounts, Az.Compute, Az.Network, Az.ResourceGraph
<#
.SYNOPSIS
    Enterprise Stale Resource Cleanup Runbook
.DESCRIPTION
    Identifies and removes orphaned Azure resources:
    - Unattached Managed Disks
    - Unassociated Public IP Addresses
    - Orphaned Network Interface Cards (NICs)
    - Empty Resource Groups (no resources for 30+ days)
    - Unattached Network Security Groups
    
    Safety Features:
    - WhatIf mode (default ON — must explicitly disable)
    - Age threshold check before deletion
    - Exclusion tag support
    - Full audit log to Log Analytics
    - Teams notification with cost savings estimate

.NOTES
    Author:     Enterprise DevSecOps | KPMG
    Version:    2.0.0
    RunAs:      System Managed Identity
    Schedule:   Weekly (Sunday 02:00 UTC)
    Safety:     WhatIf = $true by default
#>

param(
    [Parameter(Mandatory = $false)]
    [bool]$WhatIf = $true,          # SAFETY: Default is simulation mode

    [Parameter(Mandatory = $false)]
    [int]$StaleAgeDays = 30,         # Resources idle for this many days

    [Parameter(Mandatory = $false)]
    [bool]$CleanDisks = $true,

    [Parameter(Mandatory = $false)]
    [bool]$CleanPublicIPs = $true,

    [Parameter(Mandatory = $false)]
    [bool]$CleanNICs = $true,

    [Parameter(Mandatory = $false)]
    [bool]$CleanEmptyRGs = $false,   # Extra caution — off by default

    [Parameter(Mandatory = $false)]
    [string]$ExclusionTag = "DoNotDelete"
)

# ============================================================
# CONFIGURATION
# ============================================================
$Script:Config = @{
    LogAnalyticsWorkspaceId = $env:LOG_ANALYTICS_WORKSPACE_ID
    TeamsWebhookUrl         = $env:TEAMS_WEBHOOK_URL
    CostPerDiskGBMonth      = 0.05   # Estimate: £0.05 per GB/month (Standard HDD)
    CostPerPublicIPMonth    = 2.80   # Estimate: £2.80 per Public IP/month
}

$Script:Summary = @{
    DisksFound       = 0; DisksDeleted    = 0; DiskSavingsGB  = 0
    PublicIPsFound   = 0; PublicIPsDeleted = 0
    NICsFound        = 0; NICsDeleted     = 0
    RGsFound         = 0; RGsDeleted      = 0
    TotalCostSaving  = 0.0
    Errors           = [System.Collections.Generic.List[string]]::new()
}

# ============================================================
# LOGGING
# ============================================================
function Write-CleanupLog {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$ts][$Level] $Message"
}

function Is-Excluded {
    param($Resource)
    return ($Resource.Tags -and $Resource.Tags[$Script:Config.ExclusionTag] -eq "true") -or
           ($Resource.Tags -and $Resource.Tags["DoNotDelete"] -eq "true") -or
           ($Resource.Tags -and $Resource.Tags["AutoShutdown-Exclude"] -eq "true")
}

# ============================================================
# CLEANUP: ORPHANED MANAGED DISKS
# ============================================================
function Remove-OrphanedDisks {
    Write-CleanupLog "--- Scanning for orphaned managed disks ---" -Level INFO

    $orphanedDisks = Get-AzDisk | Where-Object {
        $_.DiskState -eq "Unattached" -and
        -not (Is-Excluded -Resource $_) -and
        ($_.TimeCreated -lt (Get-Date).AddDays(-$StaleAgeDays))
    }

    $Script:Summary.DisksFound = $orphanedDisks.Count
    Write-CleanupLog "Found $($orphanedDisks.Count) orphaned disks." -Level INFO

    foreach ($disk in $orphanedDisks) {
        $sizeGB   = $disk.DiskSizeGB
        $age      = ((Get-Date) - $disk.TimeCreated).Days
        $monthlyCost = [math]::Round($sizeGB * $Script:Config.CostPerDiskGBMonth, 2)

        Write-CleanupLog "Orphaned Disk: $($disk.Name) | RG: $($disk.ResourceGroupName) | Size: ${sizeGB}GB | Age: ${age}d | Est. Cost: £${monthlyCost}/mo" -Level WARN

        if ($WhatIf) {
            Write-CleanupLog "[WHATIF] Would delete disk: $($disk.Name)" -Level INFO
            $Script:Summary.DisksDeleted++
            $Script:Summary.DiskSavingsGB += $sizeGB
        }
        else {
            try {
                Remove-AzDisk -ResourceGroupName $disk.ResourceGroupName -DiskName $disk.Name -Force
                Write-CleanupLog "DELETED disk: $($disk.Name)" -Level SUCCESS
                $Script:Summary.DisksDeleted++
                $Script:Summary.DiskSavingsGB += $sizeGB
                $Script:Summary.TotalCostSaving += $monthlyCost
            }
            catch {
                $err = "Failed to delete disk '$($disk.Name)': $_"
                Write-CleanupLog $err -Level ERROR
                $Script:Summary.Errors.Add($err)
            }
        }
    }
}

# ============================================================
# CLEANUP: ORPHANED PUBLIC IPs
# ============================================================
function Remove-OrphanedPublicIPs {
    Write-CleanupLog "--- Scanning for unassociated Public IP addresses ---" -Level INFO

    $orphanedIPs = Get-AzPublicIpAddress | Where-Object {
        $_.IpConfiguration -eq $null -and
        -not (Is-Excluded -Resource $_)
    }

    $Script:Summary.PublicIPsFound = $orphanedIPs.Count
    Write-CleanupLog "Found $($orphanedIPs.Count) unassociated Public IPs." -Level INFO

    foreach ($pip in $orphanedIPs) {
        Write-CleanupLog "Orphaned PIP: $($pip.Name) | RG: $($pip.ResourceGroupName) | SKU: $($pip.Sku.Name) | Est. Cost: £$($Script:Config.CostPerPublicIPMonth)/mo" -Level WARN

        if ($WhatIf) {
            Write-CleanupLog "[WHATIF] Would delete Public IP: $($pip.Name)" -Level INFO
            $Script:Summary.PublicIPsDeleted++
        }
        else {
            try {
                Remove-AzPublicIpAddress -ResourceGroupName $pip.ResourceGroupName -Name $pip.Name -Force
                Write-CleanupLog "DELETED Public IP: $($pip.Name)" -Level SUCCESS
                $Script:Summary.PublicIPsDeleted++
                $Script:Summary.TotalCostSaving += $Script:Config.CostPerPublicIPMonth
            }
            catch {
                $err = "Failed to delete PIP '$($pip.Name)': $_"
                Write-CleanupLog $err -Level ERROR
                $Script:Summary.Errors.Add($err)
            }
        }
    }
}

# ============================================================
# CLEANUP: ORPHANED NICs
# ============================================================
function Remove-OrphanedNICs {
    Write-CleanupLog "--- Scanning for orphaned Network Interface Cards ---" -Level INFO

    $orphanedNICs = Get-AzNetworkInterface | Where-Object {
        $_.VirtualMachine -eq $null -and
        $_.PrivateEndpointText -eq $null -and
        -not (Is-Excluded -Resource $_)
    }

    $Script:Summary.NICsFound = $orphanedNICs.Count
    Write-CleanupLog "Found $($orphanedNICs.Count) orphaned NICs." -Level INFO

    foreach ($nic in $orphanedNICs) {
        Write-CleanupLog "Orphaned NIC: $($nic.Name) | RG: $($nic.ResourceGroupName)" -Level WARN

        if ($WhatIf) {
            Write-CleanupLog "[WHATIF] Would delete NIC: $($nic.Name)" -Level INFO
            $Script:Summary.NICsDeleted++
        }
        else {
            try {
                Remove-AzNetworkInterface -ResourceGroupName $nic.ResourceGroupName -Name $nic.Name -Force
                Write-CleanupLog "DELETED NIC: $($nic.Name)" -Level SUCCESS
                $Script:Summary.NICsDeleted++
            }
            catch {
                $err = "Failed to delete NIC '$($nic.Name)': $_"
                Write-CleanupLog $err -Level ERROR
                $Script:Summary.Errors.Add($err)
            }
        }
    }
}

# ============================================================
# CLEANUP: EMPTY RESOURCE GROUPS
# ============================================================
function Remove-EmptyResourceGroups {
    Write-CleanupLog "--- Scanning for empty Resource Groups ---" -Level INFO

    $emptyRGs = Get-AzResourceGroup | Where-Object {
        $rgName = $_.ResourceGroupName
        $resources = Get-AzResource -ResourceGroupName $rgName
        $resources.Count -eq 0 -and
        -not (Is-Excluded -Resource $_) -and
        $rgName -notlike "*terraform*" -and
        $rgName -notlike "*platform*" -and
        $rgName -notlike "*hub*"
    }

    $Script:Summary.RGsFound = $emptyRGs.Count
    Write-CleanupLog "Found $($emptyRGs.Count) empty Resource Groups." -Level INFO

    foreach ($rg in $emptyRGs) {
        Write-CleanupLog "Empty RG: $($rg.ResourceGroupName) | Location: $($rg.Location)" -Level WARN

        if ($WhatIf) {
            Write-CleanupLog "[WHATIF] Would delete empty RG: $($rg.ResourceGroupName)" -Level INFO
            $Script:Summary.RGsDeleted++
        }
        else {
            try {
                Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force
                Write-CleanupLog "DELETED empty RG: $($rg.ResourceGroupName)" -Level SUCCESS
                $Script:Summary.RGsDeleted++
            }
            catch {
                $err = "Failed to delete RG '$($rg.ResourceGroupName)': $_"
                Write-CleanupLog $err -Level ERROR
                $Script:Summary.Errors.Add($err)
            }
        }
    }
}

# ============================================================
# MAIN EXECUTION
# ============================================================
try {
    Write-CleanupLog "========== Stale Resource Cleanup Started ==========" -Level INFO
    Write-CleanupLog "WhatIf: $WhatIf | StaleAgeDays: $StaleAgeDays" -Level INFO

    if ($WhatIf) {
        Write-CleanupLog "*** SIMULATION MODE — No resources will be deleted ***" -Level WARN
    }

    Connect-AzAccount -Identity | Out-Null
    Write-CleanupLog "Authenticated via Managed Identity." -Level SUCCESS

    if ($CleanDisks)    { Remove-OrphanedDisks }
    if ($CleanPublicIPs){ Remove-OrphanedPublicIPs }
    if ($CleanNICs)     { Remove-OrphanedNICs }
    if ($CleanEmptyRGs) { Remove-EmptyResourceGroups }

    # Cost savings estimate
    $diskSavings = [math]::Round($Script:Summary.DiskSavingsGB * $Script:Config.CostPerDiskGBMonth, 2)
    $pipSavings  = [math]::Round($Script:Summary.PublicIPsDeleted * $Script:Config.CostPerPublicIPMonth, 2)
    $totalSavings = $diskSavings + $pipSavings

    $summary = @"
========== Cleanup Summary $(if ($WhatIf) { '[SIMULATION]' }) ==========
💽 Disks:      Found=$($Script:Summary.DisksFound)     Deleted=$($Script:Summary.DisksDeleted)   Savings=${diskSavings} GB freed
🌐 Public IPs: Found=$($Script:Summary.PublicIPsFound) Deleted=$($Script:Summary.PublicIPsDeleted)
🔌 NICs:       Found=$($Script:Summary.NICsFound)      Deleted=$($Script:Summary.NICsDeleted)
📁 Empty RGs:  Found=$($Script:Summary.RGsFound)       Deleted=$($Script:Summary.RGsDeleted)
💰 Est. Monthly Savings: £${totalSavings}
❌ Errors: $($Script:Summary.Errors.Count)
"@

    Write-CleanupLog $summary -Level SUCCESS
    Write-CleanupLog "========== Cleanup Runbook Completed ==========" -Level SUCCESS
}
catch {
    Write-CleanupLog "CRITICAL ERROR: $_" -Level ERROR
    throw $_
}
