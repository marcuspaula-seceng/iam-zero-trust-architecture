# Zero Trust Maturity Model — multi-site lab Assessment
**Based on CISA Zero Trust Maturity Model v2.0**
> Author: Marcus Paula | Independent security engineering lab
> Assessment Date: 2026-02-22

---

## Maturity Levels

| Level | Description |
|-------|------------|
| **Traditional** | Implicit trust, perimeter-based security |
| **Initial** | Some ZT controls, mostly manual |
| **Advanced** | ZT controls automated, cross-pillar integration |
| **Optimal** | Fully automated, continuous verification, AI-assisted |

---

## multi-site lab Assessment by Pillar

### Pillar 1: Identity
| Control | Status | Maturity | Notes |
|---------|--------|---------|-------|
| MFA for all users | ✅ | Advanced | VPN + Crypt Access |
| RBAC enforced | ✅ | Advanced | AD groups per role |
| Privileged access management | ✅ | Advanced | Separate admin accounts |
| Continuous session validation | ⚠️ | Initial | VPN session timeout |
| Identity governance (quarterly review) | ✅ | Advanced | Quarterly access audit |
| Just-in-time access | ❌ | Traditional | Not yet implemented |

**Overall Identity Maturity: Advanced**

---

### Pillar 2: Devices
| Control | Status | Maturity | Notes |
|---------|--------|---------|-------|
| Device inventory | ✅ | Optimal | 99% visibility (synthetic scale+) |
| MDM enrollment required | ✅ | Advanced | MDM platform + configuration-management platform + endpoint protection platform |
| OS imaging standard | ✅ | Advanced | deployment service deployment |
| Compliance check before access | ✅ | Advanced | MDM compliance gate |
| Automated remediation (configuration-management platform) | ✅ | Advanced | 30-min enforcement cycle |
| Device health attestation | ⚠️ | Initial | Manual via MDM reports |

**Overall Device Maturity: Advanced**

---

### Pillar 3: Networks
| Control | Status | Maturity | Notes |
|---------|--------|---------|-------|
| VPN mandatory for remote access | ✅ | Advanced | All sites |
| Network segmentation by role | ✅ | Advanced | 4 access zones |
| Site isolation (Site A/Site B/Site C) | ✅ | Advanced | VPN tunnels |
| Micro-segmentation | ⚠️ | Initial | Basic, not application-level |
| East-west traffic inspection | ❌ | Traditional | Not implemented |
| Software-defined perimeter | ❌ | Traditional | Future roadmap |

**Overall Network Maturity: Intermediate**

---

### Pillar 4: Applications
| Control | Status | Maturity | Notes |
|---------|--------|---------|-------|
| Role-based application access | ✅ | Advanced | AD group-based |
| Application access inventory | ✅ | Advanced | Onboarding/offboarding matrix |
| Automated provisioning/deprovisioning | ✅ | Advanced | JIRA + AD scripts |
| Application-level authentication | ✅ | Advanced | collaboration platform, JIRA, VPN |
| API access control | ⚠️ | Initial | Partial coverage |
| CASB / app-layer inspection | ❌ | Traditional | Not implemented |

**Overall Application Maturity: Advanced**

---

### Pillar 5: Data
| Control | Status | Maturity | Notes |
|---------|--------|---------|-------|
| Data encryption at rest | ✅ | Advanced | Crypt Access + BitLocker |
| Data encryption in transit | ✅ | Advanced | TLS enforced |
| GDPR compliance | ✅ | Optimal | Full compliance maintained |
| applicable data-handling requirements compliance | ✅ | Advanced | Applicable accounts covered |
| Data classification | ⚠️ | Initial | Informal classification |
| DLP (Data Loss Prevention) | ⚠️ | Initial | Partial |

**Overall Data Maturity: Advanced**

---

### Pillar 6: Visibility & Analytics
| Control | Status | Maturity | Notes |
|---------|--------|---------|-------|
| Centralized logging | ✅ | Advanced | JIRA + system logs |
| Real-time monitoring | ✅ | Advanced | Grafana dashboards |
| Access event audit trail | ✅ | Advanced | JIRA lifecycle tickets |
| Anomaly alerting | ✅ | Advanced | Grafana alerts |
| SIEM integration | ❌ | Traditional | Not implemented |
| Automated threat response | ❌ | Traditional | Manual response |

**Overall Visibility Maturity: Intermediate**

---

## Overall Maturity Summary

| Pillar | Maturity |
|--------|---------|
| Identity | **Advanced** |
| Devices | **Advanced** |
| Networks | **Intermediate** |
| Applications | **Advanced** |
| Data | **Advanced** |
| Visibility | **Intermediate** |

**Overall multi-site lab Zero Trust Maturity: Advanced (4 of 6 pillars)**

---

## Roadmap to Optimal

| Priority | Gap | Effort | Impact |
|---------|-----|--------|--------|
| High | Just-in-time privileged access | Medium | High |
| High | SIEM integration | High | High |
| Medium | Application-level micro-segmentation | High | Medium |
| Medium | Data classification formal process | Low | Medium |
| Low | Software-defined perimeter | High | Medium |

---

*Assessment v1.0 — 2026-02-22 | Marcus Paula*
*Framework: CISA Zero Trust Maturity Model v2.0*
