@echo off
REM ============================================================
REM Windows Device Audit Script
REM Author: Marcus Paula | Independent security engineering lab
REM Purpose: Collect device info for asset inventory + compliance check
REM Usage:   Run as Administrator. Output: CSV + TXT report
REM ============================================================

setlocal EnableDelayedExpansion
title Enterprise multi-site lab IT - Device Audit

set REPORT_DIR=C:\IT-Ops\Audit
set DATE_STR=%DATE:~-4%-%DATE:~3,2%-%DATE:~0,2%
set REPORT_TXT=%REPORT_DIR%\device-audit-%COMPUTERNAME%-%DATE_STR%.txt
set REPORT_CSV=%REPORT_DIR%\device-audit-%COMPUTERNAME%-%DATE_STR%.csv

if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Run as Administrator.
    pause & exit /b 1
)

echo Collecting device information...
echo.

REM ── Collect Data via PowerShell ──────────────────────────────
powershell -NoProfile -ExecutionPolicy Bypass -Command "
    # System info
    \$os  = Get-CimInstance Win32_OperatingSystem
    \$cs  = Get-CimInstance Win32_ComputerSystem
    \$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    \$bios = Get-CimInstance Win32_BIOS
    \$disk = Get-CimInstance Win32_LogicalDisk -Filter 'DeviceID=\"C:\"'
    \$nic  = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { \$_.IPEnabled } | Select-Object -First 1

    # Security checks
    \$defender  = Get-MpComputerStatus 2>$null
    \$bitlocker = Get-BitLockerVolume -MountPoint C: 2>$null
    \$fw        = (Get-NetFirewallProfile | Where-Object { \$_.Enabled -eq \$true }).Count
    \$lastUpdate= (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1).InstalledOn

    # MDM check
    \$mdm = (Get-Service -Name 'IntuneManagementExtension' -ErrorAction SilentlyContinue)
    \$configuration-management platform = (Get-Service -Name 'configuration-management platform' -ErrorAction SilentlyContinue)

    # Current user
    \$user = \$env:USERNAME

    # Output TXT report
    \$report = @\"
================================================
  DEVICE AUDIT REPORT
================================================
  Date:           \$(Get-Date -Format 'yyyy-MM-dd HH:mm')
  Audited by IT:  Marcus Paula | Independent security engineering lab
------------------------------------------------
  DEVICE IDENTITY
  Hostname:       \$(\$cs.Name)
  Serial Number:  \$(\$bios.SerialNumber)
  Model:          \$(\$cs.Manufacturer) \$(\$cs.Model)
  OS:             \$(\$os.Caption) \$(\$os.Version)
  Build:          \$(\$os.BuildNumber)
  Last Boot:      \$(\$os.LastBootUpTime)
------------------------------------------------
  HARDWARE
  CPU:            \$(\$cpu.Name)
  RAM (GB):       \$([math]::Round(\$cs.TotalPhysicalMemory/1GB,1))
  Disk C: (GB):   Free \$([math]::Round(\$disk.FreeSpace/1GB,1)) / \$([math]::Round(\$disk.Size/1GB,1))
------------------------------------------------
  NETWORK
  IP Address:     \$(\$nic.IPAddress[0])
  MAC Address:    \$(\$nic.MACAddress)
  DNS Domain:     \$(\$cs.Domain)
------------------------------------------------
  LOGGED-IN USER
  Username:       \$user
------------------------------------------------
  SECURITY COMPLIANCE
  BitLocker:      \$(if (\$bitlocker.ProtectionStatus -eq 'On') {'ENABLED'} else {'NOT ENABLED - ACTION REQUIRED'})
  Defender:       \$(if (\$defender.AMServiceEnabled) {'ENABLED'} else {'NOT ENABLED - ACTION REQUIRED'})
  Real-time Prot: \$(if (\$defender.RealTimeProtectionEnabled) {'ON'} else {'OFF - ACTION REQUIRED'})
  Last AV Update: \$(\$defender.AntivirusSignatureLastUpdated)
  Firewall:       \$(\$fw) profiles active
  Last WU Patch:  \$lastUpdate
------------------------------------------------
  MANAGEMENT
  configuration-management platform Agent:   \$(if (\$configuration-management platform -and \$configuration-management platform.Status -eq 'Running') {'RUNNING'} else {'NOT FOUND / STOPPED'})
  MDM (Intune):   \$(if (\$mdm -and \$mdm.Status -eq 'Running') {'RUNNING'} else {'NOT FOUND / STOPPED'})
================================================
\"@

    \$report | Out-File -FilePath '$REPORT_TXT' -Encoding UTF8

    # Output CSV line for asset database
    \$csv = '\"{0}\",\"{1}\",\"{2}\",\"{3}\",\"{4}\",\"{5}\",\"{6}\",\"{7}\",\"{8}\",\"{9}\",\"{10}\"' -f
        \$(\$cs.Name),
        \$(\$bios.SerialNumber),
        \$('\$(\$cs.Manufacturer) \$(\$cs.Model)'),
        \$(\$os.Caption),
        \$(\$nic.IPAddress[0]),
        \$(\$nic.MACAddress),
        \$(if (\$bitlocker.ProtectionStatus -eq 'On') {'YES'} else {'NO'}),
        \$(if (\$defender.RealTimeProtectionEnabled) {'YES'} else {'NO'}),
        \$(if (\$configuration-management platform -and \$configuration-management platform.Status -eq 'Running') {'YES'} else {'NO'}),
        \$user,
        \$(Get-Date -Format 'yyyy-MM-dd')

    'Hostname,Serial,Model,OS,IP,MAC,BitLocker,Defender,configuration-management platform,CurrentUser,AuditDate' | Out-File '$REPORT_CSV' -Encoding UTF8
    \$csv | Add-Content '$REPORT_CSV' -Encoding UTF8

    Write-Host 'Audit complete.'
"

REM ── Display report ───────────────────────────────────────────
if exist "%REPORT_TXT%" (
    type "%REPORT_TXT%"
    echo.
    echo Reports saved:
    echo   %REPORT_TXT%
    echo   %REPORT_CSV%
    echo.
    echo Copy the CSV line to the multi-site lab asset database (asset inventory / Excel).
) else (
    echo ERROR: Report generation failed.
)

echo.
pause
endlocal
