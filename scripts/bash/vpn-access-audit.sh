#!/usr/bin/env bash
# ============================================================
# VPN Access Audit Script
# Author: Marcus Paula | Independent security engineering lab
# Purpose: Audit VPN accounts — find stale/unused access for review
# Usage:  ./vpn-access-audit.sh [-d <days>] [-o <output_dir>]
# ============================================================

set -euo pipefail

# ── Config ──────────────────────────────────────────────────
STALE_DAYS="${STALE_DAYS:-60}"
OUTPUT_DIR="${OUTPUT_DIR:-/var/log/it-ops/vpn-audit}"
REPORT_DATE=$(date +%F)
LOG_FILE="$OUTPUT_DIR/vpn-audit-$REPORT_DATE.log"

# VPN config paths (adjust for your VPN solution)
VPN_USERS_FILE="/etc/vpn/users.conf"       # Adjust to your VPN
LAST_LOGIN_LOG="/var/log/vpn/access.log"   # Adjust to your VPN log path
AD_GROUP_VPN="VPN-Access"                  # AD group for VPN (if using AD auth)

while getopts "d:o:" opt; do
    case $opt in
        d) STALE_DAYS="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
    esac
done

mkdir -p "$OUTPUT_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log "=== VPN ACCESS AUDIT START === Stale threshold: ${STALE_DAYS} days ==="

# ── Parse VPN access log for last login per user ──────────────
declare -A LAST_SEEN

if [[ -f "$LAST_LOGIN_LOG" ]]; then
    log "Parsing VPN access log: $LAST_LOGIN_LOG"
    while IFS= read -r line; do
        # Example log format: "2026-01-15 10:23:45 user john.smith connected"
        # Adjust regex to match your VPN log format
        if [[ "$line" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}).*user[[:space:]]+([a-z][a-z0-9._-]+)[[:space:]]+connected ]]; then
            DATE="${BASH_REMATCH[1]}"
            USER="${BASH_REMATCH[2]}"
            LAST_SEEN["$USER"]="$DATE"
        fi
    done < "$LAST_LOGIN_LOG"
    log "Parsed ${#LAST_SEEN[@]} unique VPN users from log"
else
    log "VPN log not found at $LAST_LOGIN_LOG — using AD group membership only"
fi

# ── Get VPN users from AD group (if ldapsearch available) ─────
STALE_REPORT="$OUTPUT_DIR/vpn-stale-$REPORT_DATE.csv"
ACTIVE_REPORT="$OUTPUT_DIR/vpn-active-$REPORT_DATE.csv"

echo "username,last_vpn_login,days_since_login,status,action" > "$STALE_REPORT"
echo "username,last_vpn_login,days_since_login,status" > "$ACTIVE_REPORT"

STALE_COUNT=0
ACTIVE_COUNT=0
NO_LOGIN_COUNT=0

# ── Analyze each user ─────────────────────────────────────────
if command -v ldapsearch &>/dev/null && [[ -n "${LDAP_URI:-}" ]]; then
    log "Querying AD group: $AD_GROUP_VPN"
    VPN_USERS=$(ldapsearch -H "$LDAP_URI" -b "$LDAP_BASE" \
        "(memberOf=CN=${AD_GROUP_VPN},OU=Groups,${LDAP_BASE})" \
        sAMAccountName 2>/dev/null | grep "^sAMAccountName:" | awk '{print $2}')
else
    log "ldapsearch not configured — reading from $VPN_USERS_FILE"
    if [[ -f "$VPN_USERS_FILE" ]]; then
        VPN_USERS=$(grep -v '^#' "$VPN_USERS_FILE" | awk '{print $1}' | sort -u)
    else
        log "No VPN users source available. Check VPN_USERS_FILE or configure LDAP." "WARN"
        VPN_USERS=""
    fi
fi

TODAY_EPOCH=$(date +%s)
CUTOFF_EPOCH=$(date -d "$STALE_DAYS days ago" +%s 2>/dev/null || date -v -"${STALE_DAYS}"d +%s)

for USER in $VPN_USERS; do
    [[ -z "$USER" ]] && continue

    LAST_LOGIN="${LAST_SEEN[$USER]:-NEVER}"

    if [[ "$LAST_LOGIN" == "NEVER" ]]; then
        DAYS_SINCE=999
        STATUS="NO_LOGIN_RECORDED"
        echo "$USER,$LAST_LOGIN,$DAYS_SINCE,$STATUS,REVIEW" >> "$STALE_REPORT"
        ((NO_LOGIN_COUNT++))
    else
        LOGIN_EPOCH=$(date -d "$LAST_LOGIN" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$LAST_LOGIN" +%s)
        DAYS_SINCE=$(( (TODAY_EPOCH - LOGIN_EPOCH) / 86400 ))

        if [[ $DAYS_SINCE -ge $STALE_DAYS ]]; then
            echo "$USER,$LAST_LOGIN,$DAYS_SINCE,STALE,REVOKE" >> "$STALE_REPORT"
            ((STALE_COUNT++))
        else
            echo "$USER,$LAST_LOGIN,$DAYS_SINCE,ACTIVE" >> "$ACTIVE_REPORT"
            ((ACTIVE_COUNT++))
        fi
    fi
done

# ── Summary ───────────────────────────────────────────────────
log "=== VPN AUDIT COMPLETE ==="
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  VPN ACCESS AUDIT — $REPORT_DATE"
echo "╠══════════════════════════════════════════════╣"
printf "║  %-44s ║\n" "Active users (last ${STALE_DAYS} days):  $ACTIVE_COUNT"
printf "║  %-44s ║\n" "Stale users (>${STALE_DAYS} days inactive): $STALE_COUNT"
printf "║  %-44s ║\n" "No login recorded:              $NO_LOGIN_COUNT"
echo "╠══════════════════════════════════════════════╣"
printf "║  %-44s ║\n" "Stale report:  $STALE_REPORT"
printf "║  %-44s ║\n" "Active report: $ACTIVE_REPORT"
echo "╠══════════════════════════════════════════════╣"
echo "║  ACTION: Review stale report and revoke       ║"
echo "║  unused VPN access via JIRA change request    ║"
echo "╚══════════════════════════════════════════════╝"
