# IAM Governance Policies — multi-site lab
> Author: Marcus Paula | Independent security engineering lab
> Version: 1.0 | Date: 2026-02-22
> Review Cycle: Quarterly

---

## 1. Account Lifecycle Policy

### 1.1 Provisioning SLAs
| Event | SLA | Escalation |
|-------|-----|-----------|
| New hire account creation | 24 hours from HR trigger | IT Lead if missed |
| Device provisioning | 4 hours | IT Lead if missed |
| VPN + Crypt Access | Same day as account | IT Lead if missed |
| Role change (approved) | 48 hours | Manager if missed |

### 1.2 Offboarding SLAs
| Action | SLA | Owner |
|--------|-----|-------|
| AD account disabled | Same day, within 4 hours of HR trigger | IT Engineer |
| VPN access revoked | Same day | IT Engineer |
| Crypt Access revoked | Same day | IT Engineer |
| All sessions terminated | Same day | IT Engineer |
| Device recovered | Within 5 business days | IT Engineer + Manager |
| Device wiped (NIST 800-88) | Before reassignment | IT Engineer |

### 1.3 Account Naming Convention
```
Format: firstname.lastname
Example: john.smith
Conflicts: john.smith2, john.smith3
Service accounts: svc-<service>-<env> (e.g., svc-configuration-management platform-prod)
Admin accounts: adm-<username> (e.g., adm-john.smith)
```

---

## 2. Access Control Policy

### 2.1 Principle of Least Privilege
- All accounts start with minimum required access only
- Additional access requires formal request via JIRA
- Requests must include business justification and manager approval
- Access is time-bound where possible

### 2.2 RBAC Group Matrix
| Role | AD Groups | VPN | Sudo/Admin | Review |
|------|----------|-----|-----------|--------|
| Standard Employee | Domain Users, AppAccess | Yes | No | Annual |
| IT Engineer | IT-Team, HelpDesk, AssetMgmt | Yes | Local admin | Quarterly |
| IT Operations Lead | IT-Lead, IT-Team | Yes | Domain admin | Quarterly |
| Contractor | Contractors, LimitedAccess | Restricted | No | Monthly |

### 2.3 Privileged Access Rules
- Privileged accounts are separate from standard accounts
- Privileged account activity is logged by auditd (Linux) and AD logs (Windows)
- Privileged accounts are reviewed quarterly
- Domain admin accounts require JIRA approval before use for each task

---

## 3. Access Review Policy

### 3.1 Quarterly Access Review Process
1. IT Engineer generates AD audit report (`ad-audit-report.ps1 -ReportType full`)
2. Report reviewed with IT Operations Lead
3. Stale accounts (>90 days inactive) → disable within 5 business days
4. Over-privileged accounts → remove excess permissions within 5 business days
5. Results documented in collaboration platform
6. JIRA ticket created for each remediation action

### 3.2 Review Triggers (Outside Quarterly Cycle)
- Employee role change → immediate access review
- Employee departure → immediate full revocation
- Security incident → immediate review of affected accounts
- Audit finding → remediation within 10 business days

---

## 4. Password Policy

| Parameter | Requirement |
|-----------|------------|
| Minimum length | 12 characters |
| Complexity | Uppercase + lowercase + number + symbol |
| Maximum age | 90 days |
| Minimum age | 7 days |
| History | Last 12 passwords remembered |
| Lockout threshold | 5 failed attempts |
| Lockout duration | 15 minutes (auto-unlock) |
| Admin accounts | 60-day max, manual unlock only |

---

## 5. Device Policy

| Requirement | Standard | IT Engineer | Contractor |
|------------|---------|------------|-----------|
| MDM enrollment | Mandatory | Mandatory | Mandatory |
| BitLocker/FileVault | Mandatory | Mandatory | Mandatory |
| OS patch level | Current-1 max | Current-1 max | Current-1 max |
| Antivirus (endpoint protection platform/Defender) | Mandatory | Mandatory | Mandatory |
| Screen lock | 5 minutes | 5 minutes | 5 minutes |
| Local admin rights | No | Yes | No |
| Personal device (BYOD) | Not permitted | Not permitted | Not permitted |

---

## 6. Compliance References

| Policy | Standard | Owner |
|--------|---------|-------|
| Data protection | GDPR Art. 32 | Legal / DPO |
| US data segregation | applicable data-handling requirements Policy | Compliance |
| Export controls | applicable compliance requirements | Legal |
| Security baseline | CIS Controls v8 | IT Security |
| Crypto standards | NIST 800-175B | IT Security |
| Access control | NIST SP 800-207 (ZTA) | IT Security |

---

## 7. Configuration Control Board (CCB) Process

### 7.1 What Requires CCB Approval
- Changes to AD group policy
- Changes to VPN configuration
- New firewall rules
- Changes to RBAC group assignments at the policy level
- New service accounts
- Changes to MDM profiles affecting security settings

### 7.2 CCB Process
```
1. Requestor submits change via JIRA (Change Request template)
2. JIRA ticket includes: description, impact, rollback plan, test plan
3. IT Operations Lead reviews and approves/rejects
4. Approved changes scheduled for maintenance window
5. Change implemented with post-implementation test
6. JIRA ticket updated with outcome
7. collaboration platform documentation updated
```

### 7.3 Emergency Changes
- Emergency changes can bypass standard CCB with IT Lead verbal approval
- Must be documented in JIRA within 24 hours
- Full post-change review completed within 5 business days

---

*IAM Governance Policies v1.0 — 2026-02-22*
*Marcus Paula | Independent security engineering lab*
*Next review: 2026-05-22 (quarterly)*
