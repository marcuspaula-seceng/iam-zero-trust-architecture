# Case Study: IAM Lifecycle Management — multi-site lab
**Systems Engineering Documentation**
> Author: Marcus Paula | Role: Independent security engineering lab
> Scenario: synthetic laboratory | Sites: Site A · Site B · Site C
> Document Version: 1.0 | Date: 2026-02-22

---

## 1. System Overview

### 1.1 Context

A global technology environment's multi-site lab operations required a standardized, secure, and auditable Identity and Access Management lifecycle covering a synthetic enterprise-scale population across Site A, Site B, and Site C. The IAM system governs the full user journey — from initial provisioning on day one, through role changes and access modifications, to complete deprovisioning on departure.

This case study documents the IAM lifecycle in formal Systems Engineering methodology, mapping real operational practice to requirements, architecture, and measurable outcomes.

### 1.2 CONOPS — Concept of Operations

**Mission:** Ensure that every user and device across multi-site lab has the right access, to the right resources, at the right time — and that access is completely revoked when no longer required.

**Operational Lifecycle Flow:**

```
[HR Triggers New Hire]
        ↓
[JIRA Ticket Created]  →  IT Engineer notified (SLA: 24h)
        ↓
[Active Directory Account Created]
  - Username format enforced
  - Group memberships assigned (role-based)
  - Password policy applied
        ↓
[Device Provisioned]
  - deployment service imaging (Windows / Linux)
  - MDM enrollment (MDM platform / configuration-management platform / endpoint protection platform)
  - Asset registered in asset inventory + Excel DB
        ↓
[Access Provisioned]
  - VPN access configured
  - Crypt Access assigned
  - Application access per role
  - Email + collaboration tools (collaboration platform)
        ↓
[Active Employment]
  - Quarterly access reviews
  - Role change requests via JIRA
  - MFA enforcement
  - Grafana monitoring
        ↓
[HR Triggers Offboarding]
        ↓
[Offboarding Checklist Executed — SLA: same day]
  - AD account disabled immediately
  - VPN access revoked
  - Crypt Access removed
  - All sessions terminated
  - Device recovered + wiped (NIST 800-88)
  - Asset returned to stock
        ↓
[Audit Log Preserved]  →  GDPR / applicable data-handling requirements compliance record
```

**Key Stakeholders:**

| Stakeholder | Concern |
|------------|---------|
| HR | Speed of onboarding/offboarding, reliability |
| New Hire | Day-1 access to all required systems |
| IT Operations Lead | Compliance, audit readiness, security posture |
| IT Engineer (Marcus) | Process accuracy, automation, efficiency |
| Security / Compliance | no unauthorised access as a design objective, GDPR, applicable data-handling requirements |
| Regional IT (Site B/Site C) | Consistent process across sites |
| Internal Audit | Full traceability of all access events |

---

## 2. Problem Statement

### 2.1 Operational Gaps (Pre-Standardization)

| Problem | Impact | Severity |
|---------|--------|---------|
| No standardized onboarding checklist across multi-site lab sites | Inconsistent access provisioning, delays | High |
| Offboarding delays — AD accounts not disabled same-day | Orphaned accounts, security risk | Critical |
| No centralized audit trail for access events | Compliance gaps, GDPR risk | High |
| Manual role-based access assignment | Human error, over-provisioning | High |
| No formal access review cadence | Stale permissions accumulated | High |
| Device-to-user mapping inconsistent | Assets unaccounted, audit failures | Medium |

### 2.2 Business Need

> *"The organization requires a standardized IAM lifecycle that enforces least-privilege access, ensures same-day deprovisioning, maintains GDPR and applicable data-handling requirements compliance, and provides full audit traceability for a synthetic enterprise-scale population across multi-site lab."*

---

## 3. Requirements

### 3.1 Stakeholder Needs

| ID | Need | Stakeholder |
|----|------|------------|
| SN-001 | New hires must have full access on Day 1 | HR / New Hire |
| SN-002 | Departed employees must have all access revoked same day | Security / HR |
| SN-003 | All access changes must be logged and auditable | Audit / Compliance |
| SN-004 | Access must follow least-privilege (role-based only) | Security |
| SN-005 | Process must be consistent across all multi-site lab sites | Operations |
| SN-006 | GDPR and applicable data-handling requirements compliance must be maintained | Legal / Compliance |

---

### 3.2 System Requirements Specification

#### Functional Requirements

| ID | Requirement | Priority | Verification |
|----|------------|---------|-------------|
| REQ-F-001 | The system shall create AD accounts within 24 hours of HR notification | High | Test |
| REQ-F-002 | The system shall enforce username format and password complexity policy on all accounts | High | Inspection |
| REQ-F-003 | The system shall assign group memberships based on role (RBAC) at provisioning | High | Test |
| REQ-F-004 | The system shall provision VPN access for all eligible users | High | Demonstration |
| REQ-F-005 | The system shall enroll all devices in MDM (MDM platform / configuration-management platform / endpoint protection platform) before user assignment | High | Test |
| REQ-F-006 | The system shall disable all AD accounts on offboarding day — no exceptions | Critical | Test |
| REQ-F-007 | The system shall revoke VPN and Crypt Access on same day as offboarding | Critical | Test |
| REQ-F-008 | The system shall terminate all active sessions on offboarding | High | Demonstration |
| REQ-F-009 | The system shall generate a JIRA ticket for every IAM lifecycle event | High | Inspection |
| REQ-F-010 | The system shall support quarterly access reviews across all multi-site lab users | High | Demonstration |
| REQ-F-011 | The system shall maintain audit logs for all access events for minimum 12 months | High | Inspection |
| REQ-F-012 | The system shall support role-change requests via formal JIRA approval workflow | Medium | Demonstration |

#### Non-Functional Requirements — Security

| ID | Requirement | Standard |
|----|------------|---------|
| REQ-S-001 | All accounts shall enforce MFA for remote access | NIST 800-63B |
| REQ-S-002 | Principle of least privilege shall be enforced — no default admin access | ISO 27001 A.9 |
| REQ-S-003 | Privileged accounts shall be separate from standard user accounts | CIS Controls |
| REQ-S-004 | All offboarded account data shall be retained per GDPR retention policy | GDPR Art. 5 |
| REQ-S-005 | Devices shall be cryptographically wiped on return (NIST 800-88) | NIST 800-88 |
| REQ-S-006 | All IAM events shall produce immutable audit logs | GDPR Art. 32 |
| REQ-S-007 | applicable data-handling requirements compliance requirements shall be met for all applicable accounts | applicable data-handling requirements Policy |

#### Non-Functional Requirements — Performance

| ID | Requirement | Target |
|----|------------|--------|
| REQ-P-001 | AD account creation shall complete within 24 hours of trigger | ≤24 hours |
| REQ-P-002 | Offboarding (account disable + access revoke) shall complete same day as HR trigger | Same day |
| REQ-P-003 | Device provisioning (imaging + MDM enroll) shall complete within 4 hours | ≤4 hours |

---

## 4. Architecture

### 4.1 Logical Architecture — IAM Stack

```
┌──────────────────────────────────────────────────────────────┐
│                    IAM CONTROL PLANE                          │
│                                                               │
│  ┌─────────────┐   ┌──────────────┐   ┌──────────────────┐  │
│  │  IDENTITY   │   │    ACCESS    │   │    GOVERNANCE    │  │
│  │  DIRECTORY  │──▶│   CONTROL    │──▶│   & AUDIT        │  │
│  │             │   │              │   │                  │  │
│  │ Active Dir  │   │ VPN          │   │ JIRA (tickets)   │  │
│  │ (users,     │   │ Crypt Access │   │ collaboration platform (docs)    │  │
│  │  groups,    │   │ RBAC groups  │   │ Grafana (monitor)│  │
│  │  policies)  │   │ MFA          │   │ Audit logs       │  │
│  └─────────────┘   └──────────────┘   └──────────────────┘  │
│         │                  │                    │             │
│         ▼                  ▼                    ▼             │
│  ┌──────────────────────────────────────────────────────┐    │
│  │              ENDPOINT ENFORCEMENT LAYER              │    │
│  │  MDM platform (macOS/iOS) · configuration-management platform (Win/Linux) · endpoint protection platform        │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 Physical Architecture — multi-site lab Sites

```
Site A (HQ — Identity Authority)
┌────────────────────────────────────┐
│  Active Directory (primary)        │
│  VPN Gateway                       │
│  Crypt Access Server               │
│  deployment service Imaging Server               │
│  MDM platform Server                       │
│  configuration-management platform                     │
│  Grafana Monitoring                │
│  JIRA (ticketing)                  │
│  collaboration platform (documentation)       │
└──────────────┬─────────────────────┘
               │ VPN tunnel
    ┌──────────┴────────────┐
    ▼                       ▼
Site B                   Site C
┌──────────────┐      ┌──────────────┐
│ AD replica   │      │ AD replica   │
│ Local VPN    │      │ Local VPN    │
│ MDM platform (local) │      │ MDM platform (local) │
│ configuration-management platform agent │      │ configuration-management platform agent │
│ JIRA tickets │      │ JIRA tickets │
└──────────────┘      └──────────────┘
```

### 4.3 Zero Trust Access Model

```
USER REQUEST
    │
    ▼
[Identity Verified?]  ──NO──▶  [Deny + Log]
    │ YES
    ▼
[Device Compliant?]   ──NO──▶  [Deny + Alert]
    │ YES
    ▼
[MFA Passed?]         ──NO──▶  [Deny + Log]
    │ YES
    ▼
[Role Has Access?]    ──NO──▶  [Deny + Log]
    │ YES
    ▼
[Access Granted]  ──▶  [Session Logged]  ──▶  [Grafana monitored]
```

### 4.4 Interface Control

| Interface | System A | System B | Data Flow | Protocol |
|----------|---------|---------|----------|---------|
| INT-001 | HR System | JIRA | New hire / leaver trigger | Web form / email |
| INT-002 | JIRA | IT Engineer | Ticket assignment + SLA tracking | JIRA API |
| INT-003 | AD | VPN Gateway | Authentication + group-based access | LDAP / Kerberos |
| INT-004 | AD | MDM platform | Device-user binding + policy | LDAP |
| INT-005 | AD | configuration-management platform | Group policy enforcement (Windows/Linux) | Agent / LDAP |
| INT-006 | AD | Crypt Access | Encryption key management | LDAP |
| INT-007 | Grafana | AD / VPN / MDM | Real-time monitoring & alerting | API / SNMP |
| INT-008 | collaboration platform | IT Team | Documentation + change approvals | Web platform |

---

## 5. Implementation

### 5.1 Work Breakdown Structure

```
1.0 IAM Lifecycle — multi-site lab
│
├── 1.1 Identity Foundation
│   ├── 1.1.1 AD structure design (OUs, groups, policies)
│   ├── 1.1.2 Naming convention standardization
│   ├── 1.1.3 Password policy enforcement
│   └── 1.1.4 RBAC group matrix definition
│
├── 1.2 Onboarding Process
│   ├── 1.2.1 JIRA workflow: new hire trigger → IT ticket
│   ├── 1.2.2 AD provisioning checklist
│   ├── 1.2.3 Device imaging + MDM enrollment
│   ├── 1.2.4 VPN + Crypt Access setup
│   └── 1.2.5 Day-1 validation test
│
├── 1.3 Offboarding Process
│   ├── 1.3.1 JIRA workflow: leaver trigger → IT ticket
│   ├── 1.3.2 Same-day AD disable checklist
│   ├── 1.3.3 VPN + Crypt Access revoke
│   ├── 1.3.4 Device recovery + NIST 800-88 wipe
│   └── 1.3.5 Audit log preservation
│
├── 1.4 Access Governance
│   ├── 1.4.1 Quarterly access review process
│   ├── 1.4.2 Role-change request workflow
│   ├── 1.4.3 Stale account detection + cleanup
│   └── 1.4.4 Privileged access review
│
├── 1.5 Compliance
│   ├── 1.5.1 GDPR data handling documentation
│   ├── 1.5.2 applicable data-handling requirements compliance validation
│   └── 1.5.3 Internal audit support
│
└── 1.6 Automation (Scripts)
    ├── 1.6.1 PowerShell: AD user lifecycle
    ├── 1.6.2 PowerShell: Access audit reports
    ├── 1.6.3 Bash: Linux onboard/offboard
    ├── 1.6.4 Bash: VPN audit
    └── 1.6.5 Batch: Windows new-hire setup
```

### 5.2 RBAC Group Matrix (Example)

| Role | AD Groups | VPN | Crypt Access | Admin Rights |
|------|----------|-----|-------------|-------------|
| Standard Employee | Domain Users, AppAccess | Yes | Standard | No |
| IT Engineer | IT-Team, HelpDesk, AssetMgmt | Yes | Full | Local admin |
| IT Operations Lead | IT-Lead, IT-Team, HelpDesk | Yes | Full | Domain admin |
| Regional IT Contact | IT-Regional, HelpDesk | Yes | Standard | Local admin |
| Contractor | Contractors, LimitedAccess | Restricted | No | No |

---

## 6. Scripts & Automation

> All scripts documented in `/scripts/` directory.
> See individual script files for full code and usage.

| Script | Language | Automates |
|--------|---------|----------|
| `ad-user-lifecycle.ps1` | PowerShell | Full AD user create/modify/disable/delete |
| `ad-audit-report.ps1` | PowerShell | Stale accounts, access anomalies, audit export |
| `onboard-user.sh` | Bash | Linux account creation + group assignment |
| `offboard-user.sh` | Bash | Linux account disable + access revoke |
| `endpoint-hardening.sh` | Bash | Linux security baseline (CIS-aligned) |
| `vpn-access-audit.sh` | Bash | VPN account review + stale access report |
| `new-hire-setup.bat` | Batch | Windows environment setup for new hires |
| `device-audit.bat` | Batch | Windows device info + inventory check |

---

## 7. Verification & Validation

| Requirement | Method | Evidence | Result |
|------------|--------|---------|--------|
| REQ-F-001 (24h provisioning) | Test | JIRA SLA reports | PASS |
| REQ-F-006 (same-day disable) | Test | AD log + JIRA ticket timestamps | PASS |
| REQ-F-007 (VPN/Crypt revoke) | Demonstration | Revocation checklist audit | PASS |
| REQ-F-010 (quarterly review) | Demonstration | Q1/Q2/Q3/Q4 review records | PASS |
| REQ-S-001 (MFA enforcement) | Inspection | AD MFA policy + VPN config | PASS |
| REQ-S-002 (least privilege) | Inspection | RBAC group matrix audit | PASS |
| REQ-S-005 (NIST 800-88 wipe) | Test | Device wipe log + cert | PASS |
| REQ-P-002 (same-day offboard) | Test | JIRA timestamp comparison | PASS |

---

## 8. Outcomes & Metrics

| Metric | Before | After | Improvement |
|--------|--------|-------|------------|
| Average onboarding time | 2–3 days | ≤4 hours | 85% faster |
| Offboarding completion time | 1–2 days | Same day | 100% SLA met |
| Orphaned accounts found quarterly | 15–20 | 0–2 | 90% reduction |
| Manual provisioning steps per user | ~30 steps | ~8 steps (scripted) | 73% reduction |
| Audit readiness | Manual, days to prepare | On-demand reports | Always ready |
| GDPR compliance incidents | Occasional gaps | no incidents as a design objective | full compliance as a target |
| applicable data-handling requirements compliance | Partial | Full | Full coverage |

---

## 9. Lessons Learned

| Lesson | Application |
|--------|------------|
| Same-day offboarding must be a hard SLA, not a best-effort | Enforce via JIRA escalation if not completed within 4h |
| RBAC groups must be reviewed when roles change, not just on/off | Add role-change trigger to quarterly review |
| Linux endpoints need separate offboarding scripts from Windows | Platform-specific automation prevents gaps |
| VPN and Crypt Access are often forgotten in offboarding | Add explicit line items to checklist — not implied by AD disable |
| Audit logs need to survive account deletion | Preserve in separate log archive before account removal |

---

*Case Study v1.0 — 2026-02-22*
*Marcus Paula | Independent security engineering lab*
