# ============================================================
# AD User Lifecycle Management
# Author: Marcus Paula | Independent security engineering lab
# Purpose: Create, modify, disable, and remove AD accounts
# Usage:  ./ad-user-lifecycle.ps1 -Action <create|modify|disable|remove> -Username <user>
# ============================================================

param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("create","modify","disable","remove")]
    [string]$Action,

    [Parameter(Mandatory=$true)]
    [string]$Username,

    [string]$DisplayName,
    [string]$Department,
    [string]$Title,
    [string]$Manager,
    [string]$Site,           # Site A | Site B | Site C
    [string]$Role,           # Standard | ITEngineer | ITLead | Contractor
    [string]$TicketID        # JIRA ticket reference
)

# ── Config ──────────────────────────────────────────────────
$LogFile    = "C:\Logs\AD-Lifecycle\ad-lifecycle-$(Get-Date -Format 'yyyy-MM-dd').log"
$Domain     = "CONTOSO-multi-site lab"
$OUBase     = "OU=multi-site lab,DC=corp,DC=example,DC=com"
$AdminEmail = "it-ops@example.com"

# Role → AD Group mapping (RBAC)
$RoleGroups = @{
    "Standard"    = @("Domain Users", "AppAccess", "CollaborationUsers")
    "ITEngineer"  = @("Domain Users", "IT-Team", "HelpDesk", "AssetMgmt", "JIRAAdmin")
    "ITLead"      = @("Domain Users", "IT-Team", "IT-Lead", "HelpDesk", "AssetMgmt", "JIRAAdmin")
    "Contractor"  = @("Contractors", "LimitedAccess")
}

# Site → OU mapping
$SiteOUs = @{
    "Site A" = "OU=Site A,$OUBase"
    "Site B" = "OU=Site B,$OUBase"
    "Site C"  = "OU=Site C,$OUBase"
}

# ── Logging ─────────────────────────────────────────────────
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] [$TicketID] $Message"
    Add-Content -Path $LogFile -Value $Entry
    Write-Host $Entry
}

# ── Create User ──────────────────────────────────────────────
function New-ADUserAccount {
    Write-Log "Creating AD account for: $Username | Role: $Role | Site: $Site"

    $OU       = $SiteOUs[$Site]
    $Password = ConvertTo-SecureString "TempP@ss$(Get-Random -Min 1000 -Max 9999)!" -AsPlainText -Force

    $Params = @{
        SamAccountName        = $Username
        UserPrincipalName     = "$Username@corp.example.com"
        Name                  = $DisplayName
        DisplayName           = $DisplayName
        Department            = $Department
        Title                 = $Title
        Manager               = $Manager
        Path                  = $OU
        AccountPassword       = $Password
        Enabled               = $true
        PasswordNeverExpires  = $false
        ChangePasswordAtLogon = $true
    }

    try {
        New-ADUser @Params
        Write-Log "AD account created: $Username"

        # Assign RBAC groups
        $Groups = $RoleGroups[$Role]
        foreach ($Group in $Groups) {
            Add-ADGroupMember -Identity $Group -Members $Username
            Write-Log "Added to group: $Group"
        }

        Write-Log "Account creation complete. Temp password set. JIRA: $TicketID"
    }
    catch {
        Write-Log "ERROR creating account: $_" "ERROR"
        exit 1
    }
}

# ── Modify User ──────────────────────────────────────────────
function Update-ADUserAccount {
    Write-Log "Modifying AD account: $Username"

    $UpdateParams = @{}
    if ($Department) { $UpdateParams["Department"] = $Department }
    if ($Title)      { $UpdateParams["Title"]      = $Title }
    if ($Manager)    { $UpdateParams["Manager"]    = $Manager }

    try {
        Set-ADUser -Identity $Username @UpdateParams
        Write-Log "Account modified: $Username. JIRA: $TicketID"

        # Update groups if Role changed
        if ($Role) {
            $CurrentGroups = (Get-ADUser $Username -Properties MemberOf).MemberOf
            foreach ($Group in $CurrentGroups) {
                Remove-ADGroupMember -Identity $Group -Members $Username -Confirm:$false -ErrorAction Stop
            }
            foreach ($Group in $RoleGroups[$Role]) {
                Add-ADGroupMember -Identity $Group -Members $Username
                Write-Log "Updated group membership: $Group"
            }
        }
    }
    catch {
        Write-Log "ERROR modifying account: $_" "ERROR"
        exit 1
    }
}

# ── Disable User (Offboarding) ────────────────────────────────
function Disable-ADUserAccount {
    Write-Log "OFFBOARDING: Disabling AD account: $Username | JIRA: $TicketID"

    try {
        # Disable account immediately
        Disable-ADAccount -Identity $Username -ErrorAction Stop
        Write-Log "Account disabled: $Username"

        # Move to Disabled OU
        $DisabledOU = "OU=Disabled,OU=multi-site lab,DC=corp,DC=example,DC=com"
        Move-ADObject -Identity (Get-ADUser $Username -ErrorAction Stop).DistinguishedName -TargetPath $DisabledOU -ErrorAction Stop
        Write-Log "Account moved to Disabled OU"

        # Remove all group memberships except Domain Users
        $Groups = (Get-ADUser $Username -Properties MemberOf -ErrorAction Stop).MemberOf
        $GroupFailures = 0
        foreach ($Group in $Groups) {
            try {
                Remove-ADGroupMember -Identity $Group -Members $Username -Confirm:$false
                Write-Log "Removed from group: $Group"
            } catch {
                $GroupFailures++
                Write-Log "Could not remove group membership: ${Group}. $_" "WARN"
            }
        }

        # Expire password immediately
        Set-ADAccountExpiration -Identity $Username -DateTime (Get-Date) -ErrorAction Stop
        Write-Log "Account expiration set to now"

        # Add offboarding note to description
        Set-ADUser -Identity $Username -Description "DISABLED $(Get-Date -Format 'yyyy-MM-dd') | JIRA: $TicketID" -ErrorAction Stop

        if ($GroupFailures -gt 0) {
            Write-Log "AD OFFBOARDING PARTIAL: $Username | $GroupFailures group removal(s) failed | JIRA: $TicketID" "WARN"
        } else {
            Write-Log "AD OFFBOARDING STEPS COMPLETE: $Username | Account disabled; external access not verified | JIRA: $TicketID"
        }
        Write-Log "NEXT STEPS: Revoke VPN and Crypt Access, revoke external sessions, recover device, and verify remaining access"
        if ($GroupFailures -gt 0) { exit 1 }
    }
    catch {
        Write-Log "ERROR during offboarding: $_" "ERROR"
        exit 1
    }
}

# ── Remove User (90-day post-offboarding cleanup) ─────────────
function Remove-ADUserAccount {
    Write-Log "REMOVING AD account: $Username (90-day cleanup) | JIRA: $TicketID"

    $User = Get-ADUser $Username -Properties Description, WhenChanged

    # Safety check: must be disabled and older than 30 days
    if ($User.Enabled) {
        Write-Log "SAFETY ABORT: Account $Username is still enabled. Disable first." "ERROR"
        exit 1
    }

    $DaysSinceChange = ((Get-Date) - $User.WhenChanged).Days
    if ($DaysSinceChange -lt 30) {
        Write-Log "SAFETY ABORT: Account disabled only $DaysSinceChange days ago. Minimum 30 days required." "WARN"
        exit 1
    }

    try {
        Remove-ADUser -Identity $Username -Confirm:$false
        Write-Log "AD account permanently removed: $Username | JIRA: $TicketID"
    }
    catch {
        Write-Log "ERROR removing account: $_" "ERROR"
        exit 1
    }
}

# ── Main ─────────────────────────────────────────────────────
Write-Log "=== AD Lifecycle Script START === Action: $Action | User: $Username"

switch ($Action) {
    "create"  { New-ADUserAccount }
    "modify"  { Update-ADUserAccount }
    "disable" { Disable-ADUserAccount }
    "remove"  { Remove-ADUserAccount }
}

Write-Log "=== AD Lifecycle Script END ==="
