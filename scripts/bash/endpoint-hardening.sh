#!/usr/bin/env bash
# ============================================================
# Linux Endpoint Hardening Script — CIS Level 1 Baseline
# Author: Marcus Paula | Independent security engineering lab
# Purpose: Apply security baseline to Linux endpoints (Ubuntu/Debian)
# Usage:  sudo ./endpoint-hardening.sh [-c (check only, no changes)]
# ============================================================

set -euo pipefail

LOG_DIR="/var/log/it-ops"
LOG_FILE="$LOG_DIR/hardening-$(date +%F-%H%M).log"
CHECK_ONLY=false
PASS=0; FAIL=0; FIXED=0

while getopts "c" opt; do
    case $opt in c) CHECK_ONLY=true ;; esac
done

mkdir -p "$LOG_DIR"
log() {
    local level="${2:-INFO}"
    echo "$(date '+%H:%M:%S') [$level] $1" | tee -a "$LOG_FILE"
}
pass()  { log "  PASS: $1" "PASS";  ((PASS++));  }
fail()  { log "  FAIL: $1" "FAIL";  ((FAIL++));  }
fixed() { log "  FIXED: $1" "FIX"; ((FIXED++)); }

apply() {
    # apply <description> <check_command> <fix_command>
    local desc="$1" check="$2" fix="$3"
    if eval "$check" &>/dev/null; then
        pass "$desc"
    elif [[ "$CHECK_ONLY" == true ]]; then
        fail "$desc (check only — not fixing)"
    else
        eval "$fix" &>/dev/null && fixed "$desc" || fail "$desc (fix failed)"
    fi
}

# ── Preflight ────────────────────────────────────────────────
log "=== ENDPOINT HARDENING START === Host: $(hostname) | $(date) ==="

if [[ "$EUID" -ne 0 ]]; then
    log "Must run as root" "ERROR"; exit 1
fi

# ── 1. SSH Hardening ─────────────────────────────────────────
log "--- SSH Hardening ---"
SSHD="/etc/ssh/sshd_config"

apply "SSH: PasswordAuthentication disabled" \
    "grep -q '^PasswordAuthentication no' $SSHD" \
    "sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' $SSHD && systemctl reload ssh"

apply "SSH: PermitRootLogin disabled" \
    "grep -q '^PermitRootLogin no' $SSHD" \
    "sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' $SSHD && systemctl reload ssh"

apply "SSH: Protocol 2 only" \
    "grep -q '^Protocol 2' $SSHD" \
    "echo 'Protocol 2' >> $SSHD && systemctl reload ssh"

apply "SSH: MaxAuthTries set to 4" \
    "grep -q '^MaxAuthTries 4' $SSHD" \
    "sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 4/' $SSHD && systemctl reload ssh"

apply "SSH: LoginGraceTime 60s" \
    "grep -q '^LoginGraceTime 60' $SSHD" \
    "sed -i 's/^#*LoginGraceTime.*/LoginGraceTime 60/' $SSHD && systemctl reload ssh"

apply "SSH: X11Forwarding disabled" \
    "grep -q '^X11Forwarding no' $SSHD" \
    "sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' $SSHD && systemctl reload ssh"

apply "SSH: AllowTcpForwarding disabled" \
    "grep -q '^AllowTcpForwarding no' $SSHD" \
    "sed -i 's/^#*AllowTcpForwarding.*/AllowTcpForwarding no/' $SSHD && systemctl reload ssh"

# ── 2. Firewall ───────────────────────────────────────────────
log "--- Firewall (UFW) ---"

apply "UFW: installed" \
    "command -v ufw" \
    "apt-get install -y ufw"

apply "UFW: enabled" \
    "ufw status | grep -q 'Status: active'" \
    "ufw --force enable"

apply "UFW: default deny incoming" \
    "ufw status verbose | grep -q 'Default: deny (incoming)'" \
    "ufw default deny incoming"

apply "UFW: default allow outgoing" \
    "ufw status verbose | grep -q 'Default: allow (outgoing)'" \
    "ufw default allow outgoing"

apply "UFW: SSH allowed" \
    "ufw status | grep -q '22.*ALLOW'" \
    "ufw allow ssh"

# ── 3. Auditd ─────────────────────────────────────────────────
log "--- Audit Daemon ---"

apply "auditd: installed" \
    "command -v auditctl" \
    "apt-get install -y auditd audispd-plugins"

apply "auditd: running" \
    "systemctl is-active auditd | grep -q active" \
    "systemctl enable auditd && systemctl start auditd"

# Audit rules for privileged commands
AUDIT_RULES="/etc/audit/rules.d/it-ops.rules"
if [[ ! -f "$AUDIT_RULES" ]] && [[ "$CHECK_ONLY" == false ]]; then
    cat > "$AUDIT_RULES" << 'EOF'
# IT-Ops Audit Rules — Marcus Paula / Independent security engineering lab
# Privileged command execution
-a always,exit -F arch=b64 -S execve -F euid=0 -k privileged
# User/group management
-w /etc/passwd -p wa -k user-management
-w /etc/group  -p wa -k user-management
-w /etc/shadow -p wa -k user-management
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
# SSH config changes
-w /etc/ssh/sshd_config -p wa -k ssh-config
# Login events
-w /var/log/auth.log -p wa -k auth-log
-w /var/log/faillog -p wa -k login-fail
# Cron
-w /etc/cron.d/ -p wa -k cron
-w /var/spool/cron/ -p wa -k cron
EOF
    augenrules --load 2>/dev/null || auditctl -R "$AUDIT_RULES" 2>/dev/null
    fixed "auditd: IT-Ops audit rules deployed"
else
    apply "auditd: IT-Ops rules present" \
        "test -f $AUDIT_RULES" ""
fi

# ── 4. Account / Password Policy ─────────────────────────────
log "--- Account & Password Policy ---"

apply "login.defs: PASS_MAX_DAYS 90" \
    "grep -q '^PASS_MAX_DAYS.*90' /etc/login.defs" \
    "sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs"

apply "login.defs: PASS_MIN_DAYS 7" \
    "grep -q '^PASS_MIN_DAYS.*7' /etc/login.defs" \
    "sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   7/' /etc/login.defs"

apply "login.defs: PASS_WARN_AGE 14" \
    "grep -q '^PASS_WARN_AGE.*14' /etc/login.defs" \
    "sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' /etc/login.defs"

# PAM: account lockout after 5 failures
FAILLOCK_CONF="/etc/security/faillock.conf"
if [[ -f "$FAILLOCK_CONF" ]]; then
    apply "PAM: faillock deny=5" \
        "grep -q '^deny = 5' $FAILLOCK_CONF" \
        "sed -i 's/^#*deny.*/deny = 5/' $FAILLOCK_CONF"
    apply "PAM: faillock unlock_time=900" \
        "grep -q '^unlock_time = 900' $FAILLOCK_CONF" \
        "sed -i 's/^#*unlock_time.*/unlock_time = 900/' $FAILLOCK_CONF"
fi

# ── 5. File Permissions ───────────────────────────────────────
log "--- Critical File Permissions ---"

apply "Permissions: /etc/passwd (644)" \
    "stat -c '%a' /etc/passwd | grep -q '644'" \
    "chmod 644 /etc/passwd"

apply "Permissions: /etc/shadow (640)" \
    "stat -c '%a' /etc/shadow | grep -q '640'" \
    "chmod 640 /etc/shadow"

apply "Permissions: /etc/group (644)" \
    "stat -c '%a' /etc/group | grep -q '644'" \
    "chmod 644 /etc/group"

apply "Permissions: /etc/sudoers (440)" \
    "stat -c '%a' /etc/sudoers | grep -q '440'" \
    "chmod 440 /etc/sudoers"

# ── 6. Disable Unused Services ────────────────────────────────
log "--- Disable Unused Services ---"

for svc in telnet rsh rlogin tftp xinetd avahi-daemon cups; do
    apply "Service disabled: $svc" \
        "! systemctl is-active $svc 2>/dev/null | grep -q active" \
        "systemctl disable --now $svc 2>/dev/null || true"
done

# ── 7. /tmp Hardening ─────────────────────────────────────────
log "--- /tmp Hardening ---"

apply "tmpfs: /tmp noexec mount" \
    "mount | grep -q '/tmp.*noexec'" \
    "mount -o remount,noexec,nosuid,nodev /tmp"

# ── Summary ───────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + FIXED))
log "=== HARDENING COMPLETE === Host: $(hostname)"
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  HARDENING REPORT — $(hostname)"
echo "╠══════════════════════════════════════════╣"
printf "║  %-38s ║\n" "Total checks:  $TOTAL"
printf "║  %-38s ║\n" "✓ PASS:        $PASS"
printf "║  %-38s ║\n" "✓ FIXED:       $FIXED"
printf "║  %-38s ║\n" "✗ FAILED:      $FAIL"
echo "╠══════════════════════════════════════════╣"
printf "║  %-38s ║\n" "Log: $LOG_FILE"
echo "╚══════════════════════════════════════════╝"

[[ $FAIL -gt 0 ]] && exit 1 || exit 0
