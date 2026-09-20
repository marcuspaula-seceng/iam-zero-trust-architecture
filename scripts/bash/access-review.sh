#!/bin/bash
# access-review.sh — Periodic Access Review Helper
#
# Generates a summary of user accounts, group memberships and
# sudo privileges for quarterly access reviews.
# Designed for Linux endpoints in enterprise environments.
#
# Usage:
#   ./access-review.sh              # Full review
#   ./access-review.sh --sudo-only  # Only sudo/privileged check
#   ./access-review.sh --export csv # Export to CSV

set -euo pipefail

REPORT_DIR="./access-review-reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="${REPORT_DIR}/access-review-${TIMESTAMP}.txt"
CSV_FILE="${REPORT_DIR}/access-review-${TIMESTAMP}.csv"

mkdir -p "$REPORT_DIR"

# Colours
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

MODE="full"
EXPORT=""

for arg in "$@"; do
    case "$arg" in
        --sudo-only) MODE="sudo" ;;
        --export) EXPORT="csv" ;;
        --export=csv) EXPORT="csv" ;;
    esac
done

# ---------------------------------------------------------------------------
header() {
    echo -e "\n${BLUE}══════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
}

warn() { echo -e "${YELLOW}  [WARN] $1${NC}"; }
risk() { echo -e "${RED}  [RISK] $1${NC}"; }
ok()   { echo -e "${GREEN}  [OK]   $1${NC}"; }
info() { echo -e "         $1"; }

# ---------------------------------------------------------------------------
review_local_users() {
    header "LOCAL USER ACCOUNTS"

    echo "USERNAME | UID | SHELL | HOME | LAST_LOGIN" > "$CSV_FILE"

    while IFS=: read -r user _ uid gid _ home shell; do
        # Only human accounts (UID >= 1000) and root
        if [[ "$uid" -ge 1000 || "$uid" -eq 0 ]]; then
            last_login=$(last -n 1 "$user" 2>/dev/null | awk 'NR==1{print $4,$5,$6,$7}' || echo "never")
            info "${user} | uid=${uid} | shell=${shell} | last=${last_login}"
            echo "${user}|${uid}|${shell}|${home}|${last_login}" >> "$CSV_FILE"

            # Flag inactive shells
            if [[ "$shell" == "/bin/false" || "$shell" == "/usr/sbin/nologin" ]]; then
                ok "$user has no login shell (good)"
            fi

            # Flag accounts with no recent login
            if [[ "$last_login" == *"never"* && "$uid" -ne 0 ]]; then
                warn "$user has never logged in — consider disabling"
            fi
        fi
    done < /etc/passwd
}

# ---------------------------------------------------------------------------
review_sudo_access() {
    header "SUDO / PRIVILEGED ACCESS"

    # Users in sudo group
    if getent group sudo &>/dev/null; then
        sudo_members=$(getent group sudo | cut -d: -f4 | tr ',' '\n')
        member_count=$(echo "$sudo_members" | grep -c . || true)
        info "sudo group members (${member_count}):"
        while read -r member; do
            [[ -z "$member" ]] && continue
            if [[ "$member_count" -gt 5 ]]; then
                warn "$member is in sudo group (count > 5 — review)"
            else
                info "  - $member"
            fi
        done <<< "$sudo_members"
    fi

    # Users in wheel group (RHEL/CentOS)
    if getent group wheel &>/dev/null; then
        wheel_members=$(getent group wheel | cut -d: -f4 | tr ',' '\n')
        info "wheel group members:"
        while read -r member; do
            [[ -z "$member" ]] && continue
            info "  - $member"
        done <<< "$wheel_members"
    fi

    # Check /etc/sudoers for NOPASSWD
    header "NOPASSWD entries in sudoers"
    if grep -r "NOPASSWD" /etc/sudoers /etc/sudoers.d/ 2>/dev/null; then
        risk "NOPASSWD entries found — validate each is intentional"
    else
        ok "No NOPASSWD entries found"
    fi

    # Check for ALL=(ALL) ALL wildcards
    header "Wildcard sudo rules"
    if grep -r "ALL=(ALL) ALL" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v "^#"; then
        risk "Unrestricted sudo rules found — apply least privilege"
    else
        ok "No unrestricted wildcard sudo rules"
    fi
}

# ---------------------------------------------------------------------------
review_ssh_keys() {
    header "SSH AUTHORIZED KEYS"

    while IFS=: read -r user _ uid _ _ home _; do
        [[ "$uid" -lt 1000 && "$uid" -ne 0 ]] && continue
        auth_keys="${home}/.ssh/authorized_keys"
        if [[ -f "$auth_keys" ]]; then
            key_count=$(grep -c "^ssh-" "$auth_keys" 2>/dev/null || echo 0)
            if [[ "$key_count" -gt 0 ]]; then
                info "$user: ${key_count} authorized key(s)"
                if [[ "$key_count" -gt 3 ]]; then
                    warn "$user has ${key_count} SSH keys — verify all are still needed"
                fi
            fi
        fi
    done < /etc/passwd
}

# ---------------------------------------------------------------------------
review_open_sessions() {
    header "ACTIVE SESSIONS"
    who
    echo ""
    info "Login history (last 20):"
    last -n 20 | head -20
}

# ---------------------------------------------------------------------------
review_suid_sgid() {
    header "SUID / SGID BINARIES"
    info "Searching for SUID binaries (may take a moment)..."
    find / -xdev -perm /4000 -type f 2>/dev/null | while read -r bin; do
        warn "SUID: $bin"
    done

    info "Searching for SGID binaries..."
    find / -xdev -perm /2000 -type f 2>/dev/null | while read -r bin; do
        info "SGID: $bin"
    done
}

# ---------------------------------------------------------------------------
main() {
    echo "Access Review Report" > "$REPORT_FILE"
    echo "Generated: $(date)" >> "$REPORT_FILE"
    echo "Host: $(hostname)" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"

    {
        if [[ "$MODE" == "sudo" ]]; then
            review_sudo_access
        else
            review_local_users
            review_sudo_access
            review_ssh_keys
            review_open_sessions
            review_suid_sgid
        fi
    } | tee -a "$REPORT_FILE"

    echo ""
    echo -e "${GREEN}[+] Report saved: ${REPORT_FILE}${NC}"
    [[ -n "$EXPORT" ]] && echo -e "${GREEN}[+] CSV saved:    ${CSV_FILE}${NC}"
}

main
