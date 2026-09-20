# ============================================================
# AD Access Audit Report
# Author: Marcus Paula | Independent security engineering lab
# Purpose: Detect stale accounts, over-privileged users, orphaned accounts
# Usage:  ./ad-audit-report.ps1 -ReportType <stale|privileged|full>
# Output: CSV report + console summary
# ============================================================

param (
    [ValidateSet("stale","privileged","full")]
    [string]$ReportType = "full",
    [int]$StaleThresholdDays = 90,
    [string]$OutputPath = "C:\Reports\AD-Audit"
)

# ── Config ──────────────────────────────────────────────────
$ReportDate = Get-Date -Format 'yyyy-MM-dd'
$LogFile    = "$OutputPath\audit-log-$ReportDate.log"

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

function Write-Log {
    param([string]$Message)
    $Entry = "$(Get-Date -Format 'HH:mm:ss') $Message"
    Add-Content -Path $LogFile -Value $Entry
    Write-Host $Entry
}

# ── Stale Accounts Report ─────────────────────────────────────
function Get-StaleAccounts {
    Write-Log "Scanning for stale accounts (inactive > $StaleThresholdDays days)..."

    $CutoffDate = (Get-Date).AddDays(-$StaleThresholdDays)

    $StaleUsers = Get-ADUser -Filter {
        Enabled -eq $true -and LastLogonDate -lt $CutoffDate
    } -Properties LastLogonDate, Department, Title, Description, Created |
    Where-Object { $_.LastLogonDate -ne $null } |
    Select-Object @{N="Username";E={$_.SamAccountName}},
                  @{N="DisplayName";E={$_.Name}},
                  @{N="Department";E={$_.Department}},
                  @{N="Title";E={$_.Title}},
                  @{N="LastLogon";E={$_.LastLogonDate}},
                  @{N="DaysSinceLogon";E={((Get-Date) - $_.LastLogonDate).Days}},
                  @{N="AccountCreated";E={$_.Created}},
                  @{N="Description";E={$_.Description}}

    $ReportFile = "$OutputPath\stale-accounts-$ReportDate.csv"
    $StaleUsers | Export-Csv -Path $ReportFile -NoTypeInformation
    Write-Log "Stale accounts found: $($StaleUsers.Count) | Report: $ReportFile"

    return $StaleUsers
}

# ── Privileged Accounts Report ────────────────────────────────
function Get-PrivilegedAccounts {
    Write-Log "Scanning privileged group memberships..."

    $PrivilegedGroups = @(
        "Domain Admins",
        "Enterprise Admins",
        "Schema Admins",
        "IT-Lead",
        "IT-Team",
        "JIRAAdmin",
        "AssetMgmt"
    )

    $Results = @()

    foreach ($Group in $PrivilegedGroups) {
        try {
            $Members = Get-ADGroupMember -Identity $Group -Recursive |
                       Where-Object { $_.objectClass -eq "user" } |
                       ForEach-Object {
                           $User = Get-ADUser $_.SamAccountName -Properties LastLogonDate, Department, Enabled
                           [PSCustomObject]@{
                               Group        = $Group
                               Username     = $User.SamAccountName
                               DisplayName  = $User.Name
                               Department   = $User.Department
                               Enabled      = $User.Enabled
                               LastLogon    = $User.LastLogonDate
                           }
                       }
            $Results += $Members
            Write-Log "  ${Group}: $($Members.Count) members"
        }
        catch {
            Write-Log "  Could not query group: $Group"
        }
    }

    $ReportFile = "$OutputPath\privileged-accounts-$ReportDate.csv"
    $Results | Export-Csv -Path $ReportFile -NoTypeInformation
    Write-Log "Privileged accounts report saved: $ReportFile"

    return $Results
}

# ── Disabled Accounts Still In Groups ─────────────────────────
function Get-OrphanedMemberships {
    Write-Log "Scanning disabled accounts with remaining group memberships..."

    $DisabledWithGroups = Get-ADUser -Filter { Enabled -eq $false } -Properties MemberOf, Description |
        Where-Object { $_.MemberOf.Count -gt 1 } |
        Select-Object @{N="Username";E={$_.SamAccountName}},
                      @{N="DisplayName";E={$_.Name}},
                      @{N="GroupCount";E={$_.MemberOf.Count}},
                      @{N="Description";E={$_.Description}}

    $ReportFile = "$OutputPath\orphaned-memberships-$ReportDate.csv"
    $DisabledWithGroups | Export-Csv -Path $ReportFile -NoTypeInformation
    Write-Log "Disabled accounts with group memberships: $($DisabledWithGroups.Count)"

    return $DisabledWithGroups
}

# ── Console Summary ───────────────────────────────────────────
function Write-Summary {
    param($Stale, $Privileged, $Orphaned)

    Write-Host "`n========================================"
    Write-Host "  AD AUDIT REPORT — $ReportDate"
    Write-Host "========================================"
    Write-Host "  Stale accounts (>$StaleThresholdDays days): $($Stale.Count)"
    Write-Host "  Privileged account memberships:  $($Privileged.Count)"
    Write-Host "  Disabled with group access:      $($Orphaned.Count)"
    Write-Host ""
    Write-Host "  ACTION REQUIRED:"
    if ($Stale.Count -gt 0)    { Write-Host "  ! Review stale accounts — disable if no longer needed" }
    if ($Orphaned.Count -gt 0) { Write-Host "  ! Remove group memberships from disabled accounts" }
    Write-Host "========================================"
    Write-Host "  Reports saved to: $OutputPath"
    Write-Host "========================================`n"
}

# ── Main ─────────────────────────────────────────────────────
Write-Log "=== AD Audit Report START === Type: $ReportType ==="

$Stale     = @()
$Privileged = @()
$Orphaned  = @()

switch ($ReportType) {
    "stale"      { $Stale      = Get-StaleAccounts }
    "privileged" { $Privileged = Get-PrivilegedAccounts }
    "full" {
        $Stale      = Get-StaleAccounts
        $Privileged = Get-PrivilegedAccounts
        $Orphaned   = Get-OrphanedMemberships
    }
}

Write-Summary -Stale $Stale -Privileged $Privileged -Orphaned $Orphaned
Write-Log "=== AD Audit Report END ==="
