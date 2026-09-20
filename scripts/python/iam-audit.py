#!/usr/bin/env python3
"""
IAM Audit - Least Privilege Checker
Identifies overprivileged users, stale accounts and policy misconfigurations
in Active Directory and AWS IAM environments.

Usage:
    python3 iam-audit.py --mode ad   # Active Directory audit
    python3 iam-audit.py --mode aws  # AWS IAM audit
    python3 iam-audit.py --mode all  # Full audit
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path


# Audit output directory
OUTPUT_DIR = Path("audit-reports")
OUTPUT_DIR.mkdir(exist_ok=True)


# ---------------------------------------------------------------------------
# Active Directory audit (read-only, uses net and wmic via subprocess)
# ---------------------------------------------------------------------------

def audit_ad_stale_accounts(threshold_days: int = 90) -> list:
    """
    Lists local accounts that have not logged in within threshold_days.
    Intended as a starting point — adapt for domain-joined environments
    using LDAP queries or PowerShell Get-ADUser.
    """
    issues = []
    cutoff = datetime.now() - timedelta(days=threshold_days)

    try:
        result = subprocess.run(
            ["net", "user"],
            capture_output=True, text=True, timeout=10
        )
        # Parse output for usernames
        lines = result.stdout.splitlines()
        users = []
        for line in lines:
            if line.startswith("User accounts") or line.startswith("-") or not line.strip():
                continue
            users.extend(line.split())

        for user in users:
            if user in ("The", "command", "completed", "successfully."):
                continue
            # Flag for manual review (last logon check requires domain tools)
            issues.append({
                "type": "STALE_ACCOUNT_CANDIDATE",
                "account": user,
                "note": f"Verify last logon — flag if > {threshold_days} days",
                "severity": "MEDIUM"
            })
    except (subprocess.TimeoutExpired, FileNotFoundError):
        issues.append({
            "type": "ERROR",
            "note": "net user not available — run on Windows or domain-joined host",
            "severity": "INFO"
        })

    return issues


def check_privileged_group_membership() -> list:
    """
    Checks for accounts in high-privilege groups (Administrators, Domain Admins).
    Adapt LDAP query for domain environments.
    """
    issues = []
    privileged_groups = ["Administrators", "Domain Admins", "Enterprise Admins", "Schema Admins"]

    for group in privileged_groups:
        try:
            result = subprocess.run(
                ["net", "localgroup", group],
                capture_output=True, text=True, timeout=10
            )
            members = []
            in_members = False
            for line in result.stdout.splitlines():
                if "---" in line:
                    in_members = True
                    continue
                if in_members and line.strip() and "The command" not in line:
                    members.append(line.strip())

            if len(members) > 3:
                issues.append({
                    "type": "EXCESSIVE_PRIVILEGE",
                    "group": group,
                    "member_count": len(members),
                    "members": members,
                    "note": f"Group has {len(members)} members — review for least privilege",
                    "severity": "HIGH"
                })
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    return issues


# ---------------------------------------------------------------------------
# AWS IAM audit (uses AWS CLI — requires configured credentials)
# ---------------------------------------------------------------------------

def aws_cli(args: list) -> dict | list | None:
    """Wrapper for AWS CLI calls returning parsed JSON."""
    try:
        result = subprocess.run(
            ["aws"] + args + ["--output", "json"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            return None
        return json.loads(result.stdout)
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError):
        return None


def audit_aws_iam_users() -> list:
    """
    Checks AWS IAM users for:
    - Console access with no MFA
    - Access keys older than 90 days
    - Users with AdministratorAccess policy
    """
    issues = []

    users_data = aws_cli(["iam", "list-users"])
    if not users_data:
        return [{"type": "ERROR", "note": "AWS CLI not configured or no access", "severity": "INFO"}]

    users = users_data.get("Users", [])

    for user in users:
        username = user["UserName"]

        # Check MFA
        mfa_data = aws_cli(["iam", "list-mfa-devices", "--user-name", username])
        if mfa_data and len(mfa_data.get("MFADevices", [])) == 0:
            # Check if user has console access
            login_profile = aws_cli(["iam", "get-login-profile", "--user-name", username])
            if login_profile:
                issues.append({
                    "type": "MFA_NOT_ENABLED",
                    "user": username,
                    "note": "Console access enabled but no MFA device registered",
                    "severity": "HIGH"
                })

        # Check access key age
        keys_data = aws_cli(["iam", "list-access-keys", "--user-name", username])
        if keys_data:
            for key in keys_data.get("AccessKeyMetadata", []):
                if key["Status"] == "Active":
                    created = datetime.strptime(
                        key["CreateDate"][:10], "%Y-%m-%d"
                    )
                    age_days = (datetime.now() - created).days
                    if age_days > 90:
                        issues.append({
                            "type": "STALE_ACCESS_KEY",
                            "user": username,
                            "key_id": key["AccessKeyId"],
                            "age_days": age_days,
                            "note": f"Access key is {age_days} days old — rotate",
                            "severity": "MEDIUM"
                        })

        # Check for AdministratorAccess
        attached = aws_cli(["iam", "list-attached-user-policies", "--user-name", username])
        if attached:
            for policy in attached.get("AttachedPolicies", []):
                if policy["PolicyName"] == "AdministratorAccess":
                    issues.append({
                        "type": "ADMIN_POLICY_ATTACHED",
                        "user": username,
                        "note": "AdministratorAccess policy directly attached to user — use roles instead",
                        "severity": "HIGH"
                    })

    return issues


def audit_aws_root_account() -> list:
    """Checks AWS root account security posture."""
    issues = []

    summary = aws_cli(["iam", "get-account-summary"])
    if not summary:
        return issues

    s = summary.get("SummaryMap", {})

    if s.get("AccountMFAEnabled", 0) == 0:
        issues.append({
            "type": "ROOT_MFA_DISABLED",
            "note": "Root account MFA is not enabled",
            "severity": "CRITICAL"
        })

    if s.get("AccountAccessKeysPresent", 0) > 0:
        issues.append({
            "type": "ROOT_ACCESS_KEY_EXISTS",
            "note": "Root account has active access keys — remove immediately",
            "severity": "CRITICAL"
        })

    return issues


def audit_aws_password_policy() -> list:
    """Validates IAM account password policy against CIS benchmarks."""
    issues = []

    policy = aws_cli(["iam", "get-account-password-policy"])
    if not policy:
        issues.append({
            "type": "NO_PASSWORD_POLICY",
            "note": "No IAM password policy configured",
            "severity": "HIGH"
        })
        return issues

    p = policy.get("PasswordPolicy", {})

    checks = [
        ("MinimumPasswordLength", 14, "Minimum password length should be >= 14 (CIS)"),
        ("RequireUppercaseCharacters", True, "Uppercase characters required"),
        ("RequireLowercaseCharacters", True, "Lowercase characters required"),
        ("RequireNumbers", True, "Numbers required"),
        ("RequireSymbols", True, "Symbols required"),
        ("MaxPasswordAge", 90, "Password max age should be <= 90 days"),
        ("PasswordReusePrevention", 24, "Password reuse prevention should be >= 24"),
    ]

    for key, expected, message in checks:
        value = p.get(key)
        fail = False
        if isinstance(expected, bool):
            fail = value is not True
        elif key == "MaxPasswordAge":
            fail = value is None or value > expected
        else:
            fail = value is None or value < expected

        if fail:
            issues.append({
                "type": "WEAK_PASSWORD_POLICY",
                "field": key,
                "current": value,
                "expected": expected,
                "note": message,
                "severity": "MEDIUM"
            })

    return issues


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def generate_report(all_issues: list, mode: str) -> Path:
    """Saves audit results to a timestamped JSON report."""
    counts = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0, "INFO": 0}
    for issue in all_issues:
        sev = issue.get("severity", "INFO")
        counts[sev] = counts.get(sev, 0) + 1

    report = {
        "generated": datetime.now().isoformat(),
        "mode": mode,
        "total_findings": len(all_issues),
        "severity_counts": counts,
        "findings": all_issues
    }

    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    path = OUTPUT_DIR / f"iam-audit-{mode}-{ts}.json"
    path.write_text(json.dumps(report, indent=2))
    return path


def print_summary(issues: list, mode: str) -> None:
    counts = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0}
    for i in issues:
        sev = i.get("severity", "")
        if sev in counts:
            counts[sev] += 1

    print(f"\n[IAM Audit — {mode.upper()}]")
    print(f"  Total findings : {len(issues)}")
    print(f"  CRITICAL       : {counts['CRITICAL']}")
    print(f"  HIGH           : {counts['HIGH']}")
    print(f"  MEDIUM         : {counts['MEDIUM']}")

    print("\nTop findings:")
    for i in issues:
        if i.get("severity") in ("CRITICAL", "HIGH"):
            print(f"  [{i['severity']}] {i['type']} — {i.get('note', '')}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="IAM Audit — Least Privilege Checker")
    parser.add_argument("--mode", choices=["ad", "aws", "all"], default="all",
                        help="Audit scope (default: all)")
    parser.add_argument("--stale-days", type=int, default=90,
                        help="Days threshold for stale account detection (default: 90)")
    args = parser.parse_args()

    all_issues = []

    if args.mode in ("ad", "all"):
        print("[*] Auditing Active Directory...")
        all_issues += audit_ad_stale_accounts(args.stale_days)
        all_issues += check_privileged_group_membership()

    if args.mode in ("aws", "all"):
        print("[*] Auditing AWS IAM...")
        all_issues += audit_aws_root_account()
        all_issues += audit_aws_iam_users()
        all_issues += audit_aws_password_policy()

    print_summary(all_issues, args.mode)
    report_path = generate_report(all_issues, args.mode)
    print(f"\n[+] Report saved: {report_path}")


if __name__ == "__main__":
    main()
