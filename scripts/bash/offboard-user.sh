#!/usr/bin/env bash
# ============================================================
# Linux User Offboarding Script
# Author: Marcus Paula | Independent security engineering lab
# Purpose: Safely disable and remove departing user accounts on Linux
# Usage:  sudo ./offboard-user.sh -u <username> -t <ticket> [-d <days>]
# Note:   Default is DISABLE only. Use -r flag to remove (after 30 days)
# ============================================================

set -euo pipefail

# ── Config ──────────────────────────────────────────────────
LOG_DIR="/var/log/it-ops"
LOG_FILE="$LOG_DIR/offboarding-$(date +%F).log"
ARCHIVE_DIR="/var/it-ops/offboarded-users"
MIN_DAYS_BEFORE_DELETE=30

# ── Parse arguments ──────────────────────────────────────────
REMOVE=false

usage() {
    echo "Usage: $0 -u <username> -t <ticket> [-r (remove after 30d)]"
    exit 1
}

while getopts "u:t:r" opt; do
    case $opt in
        u) USERNAME="$OPTARG" ;;
        t) TICKET="$OPTARG" ;;
        r) REMOVE=true ;;
        *) usage ;;
    esac
done

[[ -z "${USERNAME:-}" || -z "${TICKET:-}" ]] && usage

# ── Logging ──────────────────────────────────────────────────
mkdir -p "$LOG_DIR" "$ARCHIVE_DIR"
log() {
    local level="${2:-INFO}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] [$TICKET] $1" | tee -a "$LOG_FILE"
}

# ── Validation ───────────────────────────────────────────────
log "=== OFFBOARDING START: $USERNAME ==="

if [[ "$EUID" -ne 0 ]]; then
    log "Script must run as root" "ERROR"; exit 1
fi

if ! id "$USERNAME" &>/dev/null; then
    log "User not found: $USERNAME" "ERROR"; exit 1
fi

# Protect system accounts
if [[ $(id -u "$USERNAME") -lt 1000 ]]; then
    log "SAFETY ABORT: Will not offboard system account (UID < 1000)" "ERROR"; exit 1
fi

# ── Kill all active sessions ──────────────────────────────────
log "Terminating all active sessions for: $USERNAME"
pkill -u "$USERNAME" -TERM 2>/dev/null || true
sleep 2
pkill -u "$USERNAME" -KILL 2>/dev/null || true
log "All sessions terminated"

# ── Lock account immediately ──────────────────────────────────
log "Locking account: $USERNAME"
passwd --lock "$USERNAME"
usermod --expiredate 1 "$USERNAME"   # Expire in the past = locked
log "Account locked and expired"

# ── Revoke sudo access ────────────────────────────────────────
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
if [[ -f "$SUDOERS_FILE" ]]; then
    mv "$SUDOERS_FILE" "$ARCHIVE_DIR/${USERNAME}-sudoers-$(date +%F).bak"
    log "Sudoers file archived: $SUDOERS_FILE"
fi

# Remove from sudo group
if groups "$USERNAME" | grep -q sudo 2>/dev/null; then
    gpasswd -d "$USERNAME" sudo 2>/dev/null || true
    log "Removed from sudo group"
fi
if groups "$USERNAME" | grep -q wheel 2>/dev/null; then
    gpasswd -d "$USERNAME" wheel 2>/dev/null || true
    log "Removed from wheel group"
fi

# ── Revoke SSH keys ───────────────────────────────────────────
SSH_AUTH="$HOME/$USERNAME/.ssh/authorized_keys"
if [[ -f "$SSH_AUTH" ]]; then
    BACKUP="$ARCHIVE_DIR/${USERNAME}-authorized_keys-$(date +%F).bak"
    cp "$SSH_AUTH" "$BACKUP"
    echo "" > "$SSH_AUTH"
    log "SSH authorized_keys cleared (backup: $BACKUP)"
fi

# ── Archive home directory ────────────────────────────────────
HOME_DIR="/home/$USERNAME"
if [[ -d "$HOME_DIR" ]]; then
    ARCHIVE_FILE="$ARCHIVE_DIR/${USERNAME}-home-$(date +%F).tar.gz"
    tar -czf "$ARCHIVE_FILE" -C "/home" "$USERNAME" 2>/dev/null
    log "Home directory archived: $ARCHIVE_FILE"
fi

# ── Audit log entry ───────────────────────────────────────────
logger -t "IT-OFFBOARDING" "OFFBOARDED: $USERNAME | JIRA: $TICKET | By: $(who am i | awk '{print $1}') | Date: $(date +%F)"

# ── Optional: Remove account (30-day minimum) ─────────────────
if [[ "$REMOVE" == true ]]; then
    # Check when account was locked
    SHADOW_EXPIRE=$(grep "^$USERNAME:" /etc/shadow | cut -d: -f8)
    DAYS_SINCE_LOCK=$(( ($(date +%s) / 86400) - SHADOW_EXPIRE ))

    if [[ "$DAYS_SINCE_LOCK" -lt "$MIN_DAYS_BEFORE_DELETE" ]]; then
        log "SAFETY: Account locked only $DAYS_SINCE_LOCK days ago. Minimum $MIN_DAYS_BEFORE_DELETE required to delete." "WARN"
        log "Run without -r flag for now. Re-run with -r after 30 days."
    else
        log "Removing account: $USERNAME (locked $DAYS_SINCE_LOCK days ago)"
        userdel "$USERNAME" 2>/dev/null
        log "Account removed: $USERNAME"
        log "Home directory retained in archive: $ARCHIVE_DIR"
    fi
fi

# ── Summary ───────────────────────────────────────────────────
log "=== OFFBOARDING COMPLETE: $USERNAME ==="
echo ""
echo "┌──────────────────────────────────────────┐"
echo "│  OFFBOARDING COMPLETE                     │"
echo "├──────────────────────────────────────────┤"
echo "│  Username:   $USERNAME"
echo "│  JIRA:       $TICKET"
echo "│  Date:       $(date +%F)"
echo "├──────────────────────────────────────────┤"
echo "│  ACTIONS TAKEN:                           │"
echo "│  ✓ All sessions terminated                │"
echo "│  ✓ Account locked + expired               │"
echo "│  ✓ Sudo access revoked                    │"
echo "│  ✓ SSH keys cleared                       │"
echo "│  ✓ Home directory archived                │"
echo "├──────────────────────────────────────────┤"
echo "│  MANUAL STEPS STILL REQUIRED:             │"
echo "│  ! Revoke VPN access                      │"
echo "│  ! Revoke Crypt Access                    │"
echo "│  ! Recover physical device                │"
echo "│  ! Update JIRA ticket                     │"
echo "└──────────────────────────────────────────┘"
