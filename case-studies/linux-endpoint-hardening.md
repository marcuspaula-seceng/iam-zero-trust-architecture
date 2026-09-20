# Case Study: Linux Endpoint Hardening & Security Baseline
**Systems Engineering Documentation**
> Author: Marcus Paula | Role: Independent security engineering lab
> Scenario: synthetic laboratory | Sites: Site A · Site B · Site C
> Document Version: 1.0 | Date: 2026-02-22

---

## 1. System Overview

### 1.1 Context

Linux endpoints in a fictional enterprise multi-site lab environment (primarily developer workstations and infrastructure nodes) required a standardized security baseline to ensure consistent hardening, compliance, and manageability across sites. Without a formal baseline, Linux systems had inconsistent configurations, varying patch levels, and no automated compliance enforcement.

This case study documents the Linux endpoint hardening initiative — from requirements through implementation with configuration-management platform and Bash automation.

### 1.2 CONOPS

**Mission:** Enforce a consistent, auditable security baseline on all Linux endpoints across multi-site lab, managed via configuration-management platform configuration management and automated via Bash scripts — ensuring CIS benchmark alignment and Zero Trust device compliance.

**Hardening Lifecycle:**

```
[New Linux Device Arrives]
        ↓
[OS Imaging via deployment service]  →  Standard Linux image deployed
        ↓
[configuration-management platform Agent Installed]  →  Connects to configuration-management platform (Site A)
        ↓
[Baseline Applied Automatically]
  - User accounts configured
  - SSH hardened
  - Firewall rules applied
  - Services minimized
  - Audit logging enabled
  - SELinux/AppArmor enforced
        ↓
[MDM Enrollment — endpoint protection platform]  →  Endpoint protection active
        ↓
[Compliance Check]  →  configuration-management platform reports: compliant / non-compliant
        ↓
[User Assigned]  →  Only after compliance confirmed
        ↓
[Ongoing Enforcement]  →  configuration-management platform runs every 30 min
                      →  Grafana monitors compliance state
        ↓
[Quarterly Audit]  →  Baseline drift report
```

---

## 2. Problem Statement

### 2.1 Gaps (Pre-Baseline)

| Problem | Risk | Severity |
|---------|------|---------|
| No standard Linux image across sites | Configuration drift, unknown security state | High |
| SSH with password auth enabled on some systems | Brute force / credential attack surface | Critical |
| Root login enabled on legacy systems | Direct privileged access without audit | Critical |
| Inconsistent firewall rules per device | Open ports, lateral movement risk | High |
| No centralized audit logging on Linux | Forensic gaps, compliance failures | High |
| configuration-management platform not enforced on all Linux endpoints | Manual configs drift from baseline | High |
| No automated stale account cleanup on Linux | Orphaned accounts after offboarding | High |

### 2.2 Business Need

> *"All Linux endpoints across multi-site lab must conform to a documented security baseline aligned with CIS Controls, enforced via configuration-management platform, auditable on-demand, and integrated with the Zero Trust access model."*

---

## 3. Requirements

### 3.1 Stakeholder Needs

| ID | Need | Stakeholder |
|----|------|------------|
| SN-001 | All Linux devices must have consistent, known-good configuration | Security |
| SN-002 | No Linux device should be accessible without individual user authentication | Security / Audit |
| SN-003 | Linux endpoints must be auto-remediated if they drift from baseline | IT Operations |
| SN-004 | User accounts on Linux must follow same lifecycle as AD | IT / Compliance |
| SN-005 | Compliance state must be visible in Grafana | IT Operations Lead |

---

### 3.2 System Requirements Specification

#### Functional Requirements

| ID | Requirement | Priority | Verification |
|----|------------|---------|-------------|
| REQ-F-001 | All Linux endpoints shall have configuration-management platform agent installed and active | High | Test |
| REQ-F-002 | configuration-management platform shall apply hardening baseline on first run and re-enforce every 30 minutes | High | Demonstration |
| REQ-F-003 | SSH password authentication shall be disabled — key-based auth only | Critical | Test |
| REQ-F-004 | Root login via SSH shall be disabled | Critical | Inspection |
| REQ-F-005 | Firewall (ufw/iptables) shall allow only required ports and block all others | High | Test |
| REQ-F-006 | Audit daemon (auditd) shall be enabled and logging all privileged commands | High | Inspection |
| REQ-F-007 | All unused services shall be disabled | Medium | Inspection |
| REQ-F-008 | User accounts shall be created/removed via onboard/offboard scripts | High | Test |
| REQ-F-009 | endpoint protection platform endpoint protection agent shall be installed and active | High | Test |
| REQ-F-010 | Compliance state shall be reported to Grafana dashboard | High | Demonstration |

#### Non-Functional Requirements — Security

| ID | Requirement | Standard |
|----|------------|---------|
| REQ-S-001 | Baseline shall align with CIS Linux Benchmark Level 1 | CIS Controls v8 |
| REQ-S-002 | All privileged command execution shall produce audit log entries | NIST 800-53 AU |
| REQ-S-003 | Failed login attempts shall trigger alert after 5 failures | CIS 16.7 |
| REQ-S-004 | All sensitive files shall have correct ownership and permissions | CIS 6.x |
| REQ-S-005 | Password policy shall enforce minimum complexity (12+ chars, mixed) | NIST 800-63B |

---

## 4. Architecture

### 4.1 configuration-management platform Architecture — Linux Management

```
configuration-management platform (Site A HQ)
┌──────────────────────────────────────────┐
│  configuration-management platform Server                            │
│  - Manifests: baseline hardening rules    │
│  - Hiera: per-site configurations         │
│  - Reports: compliance state per node     │
│  - Runs: every 30 minutes (all agents)    │
└─────────────────┬────────────────────────┘
                  │ HTTPS (8140)
        ┌─────────┴──────────────┐
        ▼                        ▼
Site A LINUX NODES         Site B / Site C NODES
┌──────────────────┐       ┌──────────────────┐
│ configuration-management platform Agent     │       │ configuration-management platform Agent      │
│ endpoint protection platform Agent        │       │ endpoint protection platform Agent         │
│ auditd           │       │ auditd            │
│ ufw/iptables     │       │ ufw/iptables      │
│ SSH (keys only)  │       │ SSH (keys only)   │
└──────────────────┘       └──────────────────┘
        │                          │
        └─────────────┬────────────┘
                      ▼
               GRAFANA (Site A)
               Compliance dashboards
               Alert on drift / failure
```

### 4.2 Hardening Layers

```
LAYER 1: OS BASELINE
  - Minimal packages installed
  - Unnecessary services disabled
  - File permissions hardened
  - /tmp noexec,nosuid mounted

LAYER 2: AUTHENTICATION
  - SSH key-based only (no passwords)
  - Root SSH disabled
  - sudo with logging
  - PAM password policy enforced
  - Account lockout after 5 failures

LAYER 3: NETWORK
  - ufw default deny inbound
  - Allow: SSH (22), specific app ports only
  - iptables rules enforced via configuration-management platform
  - No unnecessary listening services

LAYER 4: AUDIT & MONITORING
  - auditd: log all privileged commands
  - Log rotation: 12 months retention
  - endpoint protection platform: real-time endpoint protection
  - configuration-management platform: drift detection + auto-remediation
  - Grafana: compliance state dashboard

LAYER 5: USER MANAGEMENT
  - Accounts created/removed via scripts
  - AD integration where applicable
  - Stale account detection (quarterly)
  - /etc/sudoers managed via configuration-management platform
```

---

## 5. Scripts Overview

Full scripts in `/scripts/bash/` and `/scripts/powershell/`.

### Bash Scripts (Linux)

| Script | Purpose | Key Actions |
|--------|---------|------------|
| `endpoint-hardening.sh` | Apply CIS baseline | SSH config, firewall, auditd, services, permissions |
| `onboard-user.sh` | Create Linux user | adduser, groups, sudo rules, home dir permissions |
| `offboard-user.sh` | Remove Linux user | disable account, kill sessions, archive home, remove from sudoers |
| `vpn-access-audit.sh` | Audit VPN accounts | list active, find stale, report for review |

### PowerShell Scripts (Windows/AD — referenced)

| Script | Purpose |
|--------|---------|
| `ad-user-lifecycle.ps1` | AD user create/disable/remove lifecycle |
| `ad-audit-report.ps1` | Stale accounts + access anomaly report |

### Batch Scripts (Windows utilities)

| Script | Purpose |
|--------|---------|
| `new-hire-setup.bat` | Windows new hire environment prep |
| `device-audit.bat` | Windows device inventory + compliance check |

---

## 6. Verification & Validation

| Requirement | Method | Evidence | Result |
|------------|--------|---------|--------|
| REQ-F-003 (SSH key only) | Test | Attempt password login → denied | PASS |
| REQ-F-004 (No root SSH) | Test | Attempt root SSH → denied | PASS |
| REQ-F-005 (Firewall rules) | Test | Port scan from external → only expected ports open | PASS |
| REQ-F-006 (auditd active) | Inspection | `auditctl -l` output + log review | PASS |
| REQ-F-008 (User lifecycle scripts) | Demonstration | Onboard + offboard test user | PASS |
| REQ-S-001 (CIS Level 1) | Analysis | CIS-CAT scan report | PASS |
| REQ-S-003 (Lockout policy) | Test | 5 failed logins → account locked | PASS |

---

## 7. Outcomes & Metrics

| Metric | Before | After | Improvement |
|--------|--------|-------|------------|
| Linux endpoints with configuration-management platform enrolled | ~60% | 100% | Full coverage |
| SSH password auth enabled | ~30% of nodes | 0% | Eliminated |
| Root SSH enabled | ~10% of nodes | 0% | Eliminated |
| Baseline drift (configuration-management platform reports) | Unknown | <2% (auto-remediated) | Continuous enforcement |
| Stale Linux accounts after offboarding | 5–10/quarter | 0 | 100% cleanup |
| Time to harden new Linux endpoint | ~2 hours manual | ~15 min (configuration-management platform + script) | 87% faster |
| CIS benchmark compliance score | Unknown | Level 1 compliant | Baseline achieved |

---

## 8. Lessons Learned

| Lesson | Application |
|--------|------------|
| configuration-management platform manifests must be tested in staging before production rollout | Use separate configuration-management platform environment for testing |
| SSH key management needs a formal process (key rotation, revocation) | Add key rotation to quarterly access review |
| auditd log volume can be high — tune rules to focus on privileged actions | Define specific audit rules, not catch-all |
| Linux offboarding is often missed in Windows-centric processes | Explicit Linux checklist item, separate from AD offboarding |
| Firewall rules must be documented alongside configuration-management platform manifests | Maintain firewall rule register in collaboration platform |

---

*Case Study v1.0 — 2026-02-22*
*Marcus Paula | Independent security engineering lab*
