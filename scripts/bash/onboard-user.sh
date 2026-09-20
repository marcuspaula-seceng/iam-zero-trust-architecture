#!/usr/bin/env bash
# ============================================================
# Linux User Onboarding Script
# Author: Marcus Paula | Independent security engineering lab
# Purpose: Create and configure new user accounts on Linux endpoints
# Usage:  sudo ./onboard-user.sh -u <username> -n <fullname> -r <role> -t <ticket>
# ============================================================

set -euo pipefail

# ── Defaults ────────────────────────────────────────────────
LOG_DIR="/var/log/it-ops"
LOG_FILE="$LOG_DIR/onboarding-$(date +%F).log"
SUDO_GROUP="sudo"            # Change to wheel on RHEL/CentOS
IT_TEAM_GROUP="it-team"
SHELL_DEFAULT="/bin/bash"
HOME_BASE="/home"
MIN_UID=2000                 # Avoid conflicts with system accounts

# ── Parse arguments ──────────────────────────────────────────
usage() {
    echo "Usage: $0 -u <username> -n <fullname> -r <role> -t <ticket>"
    echo "  -u  Username (lowercase, no spaces)"
    echo "  -n  Full name (quoted, e.g. 'John Smith')"
    echo "  -r  Role: standard | it-engineer | contractor"
    echo "  -t  JIRA ticket ID"
    exit 1
}

while getopts "u:n:r:t:" opt; do
    case $opt in
        u) USERNAME="$OPTARG" ;;
        n) FULLNAME="$OPTARG" ;;
        r) ROLE="$OPTARG" ;;
        t) TICKET="$OPTARG" ;;
        *) usage ;;
    esac
done

[[ -z "${USERNAME:-}" || -z "${FULLNAME:-}" || -z "${ROLE:-}" || -z "${TICKET:-}" ]] && usage

# ── Logging ──────────────────────────────────────────────────
mkdir -p "$LOG_DIR"
log() {
    local level="${2:-INFO}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] [$TICKET] $1" | tee -a "$LOG_FILE"
}

# ── Validation ───────────────────────────────────────────────
log "=== ONBOARDING START: $USERNAME ==="

# Must run as root
if [[ "$EUID" -ne 0 ]]; then
    log "Script must run as root" "ERROR"
    exit 1
fi

# Username format validation
if ! [[ "$USERNAME" =~ ^[a-z][a-z0-9._-]{2,31}$ ]]; then
    log "Invalid username format: $USERNAME" "ERROR"
    exit 1
fi

# Check user doesn't already exist
if id "$USERNAME" &>/dev/null; then
    log "User already exists: $USERNAME" "ERROR"
    exit 1
fi

# Validate role
case "$ROLE" in
    standard|it-engineer|contractor) ;;
    *) log "Invalid role: $ROLE. Use: standard | it-engineer | contractor" "ERROR"; exit 1 ;;
esac

# ── Create groups if missing ─────────────────────────────────
for grp in "$IT_TEAM_GROUP" "contractors"; do
    if ! getent group "$grp" &>/dev/null; then
        groupadd "$grp"
        log "Created group: $grp"
    fi
done

# ── Create user ───────────────────────────────────────────────
log "Creating user: $USERNAME | Full name: $FULLNAME | Role: $ROLE"

useradd \
    --create-home \
    --home-dir "$HOME_BASE/$USERNAME" \
    --shell "$SHELL_DEFAULT" \
    --comment "$FULLNAME" \
    --uid "$(awk -F: '$3 >= '"$MIN_UID"' {print $3}' /etc/passwd | sort -n | tail -1 | awk '{print $1+1}')" \
    "$USERNAME"

log "User created: $USERNAME (UID: $(id -u "$USERNAME"))"

# ── Set home directory permissions ───────────────────────────
chmod 750 "$HOME_BASE/$USERNAME"
log "Home directory permissions set: 750"

# ── Assign groups by role ─────────────────────────────────────
case "$ROLE" in
    standard)
        # No sudo, no extra groups
        log "Role: standard — no elevated groups"
        ;;
    it-engineer)
        usermod -aG "$SUDO_GROUP","$IT_TEAM_GROUP" "$USERNAME"
        log "Added to groups: $SUDO_GROUP, $IT_TEAM_GROUP"

        # Create sudoers rule with logging
        SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
        cat > "$SUDOERS_FILE" << EOF
# IT Engineer sudo access — $USERNAME
# Created: $(date +%F) | JIRA: $TICKET
Defaults:$USERNAME log_output
$USERNAME ALL=(ALL) ALL
EOF
        chmod 440 "$SUDOERS_FILE"
        log "Sudoers file created: $SUDOERS_FILE"
        ;;
    contractor)
        usermod -aG "contractors" "$USERNAME"
        log "Role: contractor — limited group access only"
        ;;
esac

# ── Force password change on first login ─────────────────────
# Set a temporary password (admin must share securely)
TEMP_PASS="Tmp@$(openssl rand -base64 8 | tr -dc 'A-Za-z0-9' | head -c8)!"
echo "$USERNAME:$TEMP_PASS" | chpasswd
passwd --expire "$USERNAME"
log "Temporary password set. Expires on first login."

# ── SSH directory setup ───────────────────────────────────────
SSH_DIR="$HOME_BASE/$USERNAME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/authorized_keys"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"
log "SSH directory created: $SSH_DIR"

# ── Audit log entry ───────────────────────────────────────────
logger -t "IT-ONBOARDING" "User created: $USERNAME | Role: $ROLE | JIRA: $TICKET | By: $(who am i | awk '{print $1}')"

# ── Summary ───────────────────────────────────────────────────
log "=== ONBOARDING COMPLETE: $USERNAME ==="
echo ""
echo "┌─────────────────────────────────────────┐"
echo "│  ONBOARDING COMPLETE                     │"
echo "├─────────────────────────────────────────┤"
echo "│  Username:   $USERNAME"
echo "│  Full name:  $FULLNAME"
echo "│  Role:       $ROLE"
echo "│  UID:        $(id -u "$USERNAME")"
echo "│  Home:       $HOME_BASE/$USERNAME"
echo "│  JIRA:       $TICKET"
echo "├─────────────────────────────────────────┤"
echo "│  NEXT STEPS:                             │"
echo "│  1. Share temp password securely         │"
echo "│  2. Add SSH public key to authorized_keys│"
echo "│  3. Verify VPN access provisioned        │"
echo "│  4. Update JIRA ticket                   │"
echo "└─────────────────────────────────────────┘"
