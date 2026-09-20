@echo off
REM ============================================================
REM New Hire Windows Setup Script
REM Author: Marcus Paula | Independent security engineering lab
REM Purpose: Prepare Windows environment for new hire
REM Usage:   Run as Administrator. Double-click or: new-hire-setup.bat
REM ============================================================

setlocal EnableDelayedExpansion
title Enterprise multi-site lab IT - New Hire Setup

REM ── Config ──────────────────────────────────────────────────
set LOG_DIR=C:\IT-Ops\Logs
set LOG_FILE=%LOG_DIR%\new-hire-setup-%DATE:~-4%-%DATE:~3,2%-%DATE:~0,2%.log
set TICKET=

REM ── Check admin ──────────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Run as Administrator.
    pause & exit /b 1
)

REM ── Create log dir ───────────────────────────────────────────
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM ── Prompt for info ──────────────────────────────────────────
echo.
echo ================================================
echo   Enterprise multi-site lab IT - New Hire Setup
echo ================================================
echo.
set /p TICKET=Enter JIRA Ticket ID:
set /p USERNAME=Enter username (SAMAccountName):
set /p SITE=Enter site (Site A/Site B/Site C):

echo. >> "%LOG_FILE%"
echo [%DATE% %TIME%] NEW HIRE SETUP START >> "%LOG_FILE%"
echo [%DATE% %TIME%] User: %USERNAME% ^| Site: %SITE% ^| JIRA: %TICKET% >> "%LOG_FILE%"

echo.
echo Starting setup for %USERNAME% [%TICKET%]...
echo.

REM ── 1. Windows Updates ───────────────────────────────────────
echo [1/8] Checking Windows Updates...
echo [%DATE% %TIME%] Triggering Windows Update scan >> "%LOG_FILE%"
powershell -Command "& {
    \$UpdateSession = New-Object -ComObject Microsoft.Update.Session
    \$UpdateSearcher = \$UpdateSession.CreateUpdateSearcher()
    Write-Host '  Scanning for updates...'
    \$SearchResult = \$UpdateSearcher.Search('IsInstalled=0 and Type=Software')
    Write-Host \"  Updates available: \$(\$SearchResult.Updates.Count)\"
}" 2>>"%LOG_FILE%"
echo   Done. >> "%LOG_FILE%"

REM ── 2. Enable BitLocker ───────────────────────────────────────
echo [2/8] Checking BitLocker encryption...
powershell -Command "
    \$vol = Get-BitLockerVolume -MountPoint C: 2>$null
    if (\$vol.ProtectionStatus -eq 'On') {
        Write-Host '  BitLocker: ENABLED'
    } else {
        Write-Host '  BitLocker: NOT ENABLED - Manual action required'
        Write-Host '  ACTION: Enable via Control Panel > BitLocker Drive Encryption'
    }
" 2>>"%LOG_FILE%"
echo [%DATE% %TIME%] BitLocker check complete >> "%LOG_FILE%"

REM ── 3. Configure Firewall ─────────────────────────────────────
echo [3/8] Configuring Windows Firewall...
netsh advfirewall set allprofiles state on >> "%LOG_FILE%" 2>&1
echo   Firewall enabled (all profiles) >> "%LOG_FILE%"
echo   Firewall: Enabled

REM ── 4. Set Power Settings ─────────────────────────────────────
echo [4/8] Setting power configuration...
powercfg /change standby-timeout-ac 60 >> "%LOG_FILE%" 2>&1
powercfg /change hibernate-timeout-ac 0 >> "%LOG_FILE%" 2>&1
powercfg /change monitor-timeout-ac 15 >> "%LOG_FILE%" 2>&1
echo   Power settings configured >> "%LOG_FILE%"
echo   Power: Configured

REM ── 5. Set Screen Lock ────────────────────────────────────────
echo [5/8] Configuring screen lock (5 min inactivity)...
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" ^
    /v InactivityTimeoutSecs /t REG_DWORD /d 300 /f >> "%LOG_FILE%" 2>&1
echo   Screen lock set to 300 seconds >> "%LOG_FILE%"
echo   Screen lock: 5 minutes

REM ── 6. Disable Autorun ────────────────────────────────────────
echo [6/8] Disabling AutoRun (USB security)...
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" ^
    /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f >> "%LOG_FILE%" 2>&1
echo   AutoRun disabled >> "%LOG_FILE%"
echo   AutoRun: Disabled

REM ── 7. Configure Windows Defender ────────────────────────────
echo [7/8] Verifying Windows Defender status...
powershell -Command "
    \$status = Get-MpComputerStatus 2>$null
    if (\$status) {
        Write-Host \"  Defender: \$(\$status.AMServiceEnabled)\"
        Write-Host \"  Real-time protection: \$(\$status.RealTimeProtectionEnabled)\"
        Write-Host \"  Signatures updated: \$(\$status.AntivirusSignatureLastUpdated)\"
    } else {
        Write-Host '  WARNING: Could not query Defender status'
    }
" 2>>"%LOG_FILE%"

REM ── 8. Generate Report ────────────────────────────────────────
echo [8/8] Generating setup report...

set REPORT=%LOG_DIR%\new-hire-report-%USERNAME%-%DATE:~-4%%DATE:~3,2%%DATE:~0,2%.txt
(
echo ================================================
echo   NEW HIRE SETUP REPORT
echo ================================================
echo   Date:     %DATE% %TIME%
echo   Username: %USERNAME%
echo   Site:     %SITE%
echo   JIRA:     %TICKET%
echo   Host:     %COMPUTERNAME%
echo ------------------------------------------------
echo   COMPLETED:
echo   [x] Windows Update scan triggered
echo   [x] BitLocker status checked
echo   [x] Firewall enabled (all profiles)
echo   [x] Power settings configured
echo   [x] Screen lock set (5 min)
echo   [x] AutoRun disabled
echo   [x] Windows Defender verified
echo ------------------------------------------------
echo   MANUAL STEPS REMAINING:
echo   [ ] Enroll in MDM platform/MDM if macOS provided
echo   [ ] VPN client installed and tested
echo   [ ] Crypt Access configured
echo   [ ] collaboration platform installed and logged in
echo   [ ] JIRA access verified
echo   [ ] User briefed on security policies
echo   [ ] JIRA ticket %TICKET% updated
echo ================================================
) > "%REPORT%"

type "%REPORT%"

echo.
echo [%DATE% %TIME%] Setup complete. Report: %REPORT% >> "%LOG_FILE%"
echo.
echo Setup complete. Report saved to: %REPORT%
echo.
pause
endlocal
