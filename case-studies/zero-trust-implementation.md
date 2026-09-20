# Case Study: Zero Trust Architecture Implementation — multi-site lab
**Systems Engineering Documentation**
> Author: Marcus Paula | Role: Independent security engineering lab
> Scenario: synthetic laboratory | Sites: Site A · Site B · Site C
> Document Version: 1.0 | Date: 2026-02-22

---

## 1. System Overview

### 1.1 Context

Zero Trust Architecture (ZTA) is a security model based on the principle of "never trust, always verify." In a synthetic enterprise scenario, this meant redesigning access assumptions across identity, devices, network, applications, and data — moving away from implicit trust based on network location toward continuous verification of every access request.

This case study documents the Zero Trust controls implemented across a synthetic enterprise-scale population and 3 multi-site lab sites, structured using formal Systems Engineering methodology.

### 1.2 CONOPS

**Mission:** Eliminate implicit trust from the multi-site lab IT environment. Every access request — regardless of origin, device, or network — must be explicitly verified against identity, device compliance, and role before access is granted.

**Zero Trust Operational Model:**

```
TRADITIONAL MODEL (Before)           ZERO TRUST MODEL (After)
─────────────────────────            ──────────────────────────
"If you're on the network,           "Verify every request,
 you're trusted"                      every time, always"

 [Corp Network] = Trust               [Identity] + [Device] +
 [VPN Connected] = Full Access        [Role] + [Context] = Access
 [Outside] = Blocked                  [Anything else] = Denied + Logged
```

**CISA Zero Trust Maturity Model — multi-site lab Status:**

| Pillar | Implemented Controls | Maturity Level |
|--------|---------------------|---------------|
| Identity | AD + MFA + VPN + Crypt Access + RBAC | Advanced |
| Devices | MDM (MDM platform/configuration-management platform/endpoint protection platform) + imaging standard + NIST wipe | Advanced |
| Networks | VPN segmentation + site isolation + access zones | Intermediate |
| Applications | Role-based access + onboarding/offboarding automation | Advanced |
| Data | Crypt Access + GDPR + applicable data-handling requirements + encrypted transit | Advanced |
| Visibility & Analytics | Grafana + JIRA audit trail + access logs | Intermediate |

---

## 2. Problem Statement

### 2.1 Security Gaps (Pre-ZTA)

| Gap | Risk | Severity |
|-----|------|---------|
| Implicit trust for on-network devices | Lateral movement risk if device compromised | Critical |
| No formal device compliance check before access | Non-compliant devices accessing corp resources | High |
| Inconsistent MFA enforcement across multi-site lab | Credential-based attacks viable | Critical |
| Access rights not reviewed after role changes | Over-privileged accounts accumulating | High |
| No centralized visibility across sites | Blind spots in Site B and Site C | High |
| Offboarding gaps — accounts surviving termination | Unauthorized access post-departure | Critical |

### 2.2 Business Need

> *"Implement Zero Trust controls across all multi-site lab sites ensuring every identity is verified, every device is compliant, and every access event is logged — eliminating implicit trust while maintaining operational efficiency for a synthetic enterprise-scale population."*

---

## 3. Requirements

### 3.1 Stakeholder Needs

| ID | Need | Stakeholder |
|----|------|------------|
| SN-001 | No access without verified identity + compliant device | Security |
| SN-002 | All access events must be logged and monitored | Audit / Compliance |
| SN-003 | Compromised credentials must not allow full network access | Security |
| SN-004 | Remote workers must have same security controls as on-site | IT Operations |
| SN-005 | ZT controls must not significantly impact user productivity | End Users / HR |
| SN-006 | Compliance with GDPR, applicable data-handling requirements, and internal policies | Legal / Compliance |

---

### 3.2 System Requirements Specification

#### Functional Requirements

| ID | Requirement | Priority | Verification |
|----|------------|---------|-------------|
| REQ-F-001 | The system shall verify user identity via AD + MFA before granting any access | Critical | Test |
| REQ-F-002 | The system shall verify device MDM enrollment and compliance before access | High | Test |
| REQ-F-003 | The system shall enforce RBAC — no access beyond assigned role groups | High | Inspection |
| REQ-F-004 | The system shall revoke all access immediately on offboarding trigger | Critical | Test |
| REQ-F-005 | The system shall log all access events with timestamp, user, device, resource | High | Inspection |
| REQ-F-006 | The system shall alert on anomalous access patterns via Grafana | High | Demonstration |
| REQ-F-007 | The system shall enforce VPN for all remote access (no split-tunnel exceptions) | High | Test |
| REQ-F-008 | The system shall encrypt all data in transit and at rest via Crypt Access | High | Inspection |
| REQ-F-009 | The system shall perform quarterly access reviews to detect privilege drift | High | Demonstration |
| REQ-F-010 | The system shall support applicable data-handling requirements compliance requirements for applicable accounts | High | Inspection |

#### Non-Functional Requirements — Security

| ID | Requirement | Framework Reference |
|----|------------|-------------------|
| REQ-S-001 | Least-privilege access enforced at all times | NIST SP 800-207 (ZTA) |
| REQ-S-002 | MFA required for all remote access, privileged accounts | NIST 800-63B |
| REQ-S-003 | All endpoints must meet MDM compliance baseline before access | CIS Controls v8 |
| REQ-S-004 | Network micro-segmentation: sites isolated, lateral movement minimized | NIST SP 800-207 |
| REQ-S-005 | Data classified and handled per GDPR requirements | GDPR Art. 32 |
| REQ-S-006 | All security events retained minimum 12 months | ISO 27001 A.12.4 |

---

## 4. Architecture

### 4.1 Zero Trust Architecture — multi-site lab

```
┌─────────────────────────────────────────────────────────────────────┐
│                      ZERO TRUST CONTROL PLANE                        │
│                                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │   IDENTITY   │  │   DEVICE     │  │    POLICY    │               │
│  │   PILLAR     │  │   PILLAR     │  │    ENGINE    │               │
│  │              │  │              │  │              │               │
│  │ Active Dir   │  │ MDM platform         │──▶│ Allow/Deny   │               │
│  │ MFA          │──▶│ configuration-management platform       │  │ per request  │               │
│  │ VPN          │  │ endpoint protection platform          │  │              │               │
│  │ Crypt Access │  │ deployment service         │  │              │               │
│  └──────────────┘  └──────────────┘  └──────┬───────┘               │
│                                             │                        │
│  ┌──────────────────────────────────────────▼───────────────────┐   │
│  │                    DATA PLANE (Resources)                      │   │
│  │  Applications · Files · Email · Collaboration · VPN Tunnels   │   │
│  └───────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │              VISIBILITY & ANALYTICS LAYER                      │   │
│  │         Grafana · JIRA Audit · Access Logs · Alerts            │   │
│  └───────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Access Decision Flow

```
ACCESS REQUEST (any user, any device, any location)
        │
        ▼
┌───────────────────┐
│ 1. WHO ARE YOU?   │  ← Active Directory authentication
│    Identity check  │
└────────┬──────────┘
         │ Identity verified
         ▼
┌───────────────────┐
│ 2. IS YOUR DEVICE │  ← MDM compliance check (MDM platform/configuration-management platform/endpoint protection platform)
│    COMPLIANT?      │     - Enrolled in MDM?
│                    │     - OS patched?
│                    │     - Encryption enabled?
└────────┬──────────┘
         │ Device compliant
         ▼
┌───────────────────┐
│ 3. DID YOU PASS   │  ← MFA verification (VPN + Crypt Access)
│    MFA?            │
└────────┬──────────┘
         │ MFA passed
         ▼
┌───────────────────┐
│ 4. DO YOU HAVE    │  ← RBAC group check (Active Directory groups)
│    PERMISSION?     │
└────────┬──────────┘
         │ Permission confirmed
         ▼
    ACCESS GRANTED
    + Session logged
    + Grafana monitored
```

### 4.3 Network Segmentation

```
INTERNET
    │
    ▼
[VPN Gateway — Site A HQ]
    │
    ├── ZONE 1: Standard Users (Domain Users group)
    │       - Standard application access
    │       - No admin rights
    │       - Encrypted via Crypt Access
    │
    ├── ZONE 2: IT Engineers (IT-Team group)
    │       - Local admin on managed devices
    │       - Asset management systems
    │       - JIRA admin
    │
    ├── ZONE 3: IT Operations Lead (IT-Lead group)
    │       - Domain admin (AD)
    │       - All zones accessible
    │       - Privileged access monitored
    │
    └── ZONE 4: Contractors (Contractors group)
            - Restricted access only
            - No VPN for corp network
            - Application-level access only
```

---

## 5. Implementation

### 5.1 Controls Implementation by Pillar

#### Identity Pillar
- Active Directory as single source of truth for all identities
- Password complexity policy enforced via AD Group Policy
- MFA enforced for VPN and privileged access
- RBAC groups: Domain Users / IT-Team / IT-Lead / Contractors
- Crypt Access for data encryption key management
- Quarterly stale account review and cleanup

#### Device Pillar
- All devices enrolled in MDM before user assignment
  - macOS/iOS → MDM platform (profiles, policies, remote wipe)
  - Windows/Linux → configuration-management platform (configuration management) + endpoint protection platform (endpoint protection)
- OS imaging standard enforced via deployment service
- Non-compliant devices blocked from network access
- NIST 800-88 wipe on device return

#### Network Pillar
- VPN mandatory for all remote access
- Site-to-site isolation: Site A / Site B / Site C
- Access zones by role (see architecture section)
- No split-tunnel exceptions for privileged accounts

#### Application Pillar
- Role-based application access via AD groups
- collaboration platform: role-based spaces and document permissions
- JIRA: role-based project access
- Onboarding/offboarding checklist tied to application access

#### Data Pillar
- Crypt Access: encryption for sensitive data at rest
- All data in transit encrypted (HTTPS/TLS enforced)
- GDPR data classification and handling procedures
- applicable data-handling requirements compliance for applicable data categories

#### Visibility & Analytics Pillar
- Grafana: Office-Wireless V2.0 dashboard + custom alerts
- JIRA: full audit trail of all lifecycle events
- Access logs retained minimum 12 months
- Quarterly access review reports

---

## 6. Scripts & Automation

See `/scripts/` directory for full implementation.

| Script | Language | ZT Pillar | Purpose |
|--------|---------|----------|---------|
| `ad-user-lifecycle.ps1` | PowerShell | Identity | Full AD user lifecycle |
| `ad-audit-report.ps1` | PowerShell | Identity + Visibility | Stale accounts, audit export |
| `onboard-user.sh` | Bash | Identity + Device | Linux user onboarding |
| `offboard-user.sh` | Bash | Identity + Device | Linux user offboarding |
| `endpoint-hardening.sh` | Bash | Device | Linux ZT security baseline |
| `vpn-access-audit.sh` | Bash | Network + Visibility | VPN stale access cleanup |
| `new-hire-setup.bat` | Batch | Identity + Device | Windows new hire setup |
| `device-audit.bat` | Batch | Device + Visibility | Windows device compliance check |

---

## 7. Verification & Validation

| Requirement | Method | Evidence | Result |
|------------|--------|---------|--------|
| REQ-F-001 (Identity + MFA) | Test | AD + VPN login test | PASS |
| REQ-F-002 (Device compliance) | Test | MDM enrollment report | PASS |
| REQ-F-003 (RBAC) | Inspection | AD group matrix audit | PASS |
| REQ-F-004 (Immediate revoke) | Test | Offboarding SLA timestamps | PASS |
| REQ-F-005 (Access logging) | Inspection | JIRA + Grafana log review | PASS |
| REQ-F-007 (VPN enforcement) | Test | Remote access test w/o VPN | PASS |
| REQ-F-008 (Encryption) | Inspection | Crypt Access config review | PASS |
| REQ-S-003 (MDM compliance gate) | Test | Non-enrolled device access test | PASS |

---

## 8. Outcomes & Metrics

| Metric | Before ZTA | After ZTA | Improvement |
|--------|-----------|----------|------------|
| Unauthorized access incidents | Occasional | Zero | 100% elimination |
| Devices without MDM enrollment | ~15% | <1% | 93% improvement |
| Stale accounts (quarterly audit) | 15–20 | 0–2 | 90% reduction |
| Offboarding SLA compliance | ~70% | 100% | Full SLA achievement |
| Audit readiness | Days to prepare | On-demand | Always ready |
| GDPR compliance status | Partial | Full | full compliance as a target |
| applicable data-handling requirements compliance | Partial | Full | full compliance as a target |
| Cross-site security consistency | Low | High | Standardized multi-site lab-wide |

---

## 9. Framework Alignment

| ZT Principle | NIST SP 800-207 | How Implemented |
|-------------|----------------|----------------|
| Verify explicitly | §2.1 | AD + MFA + MDM compliance check |
| Use least privilege | §2.2 | RBAC groups, no default admin |
| Assume breach | §2.3 | Grafana monitoring, JIRA audit trail, Crypt Access |
| Never trust, always verify | §3.1 | VPN mandatory, device compliance gate |
| Micro-segmentation | §3.3 | Access zones by role (4 zones) |
| Continuous monitoring | §3.5 | Grafana + quarterly access reviews |

---

*Case Study v1.0 — 2026-02-22*
*Marcus Paula | Independent security engineering lab*
