# Zero Trust Network Access — Implementation Checklist

Based on NIST SP 800-207 and public standards and laboratory validation.

## Identity Verification

- [ ] MFA enforced for all users (no exceptions)
- [ ] Phishing-resistant MFA (FIDO2/WebAuthn) for privileged accounts
- [ ] Conditional access policies based on device compliance + user risk score
- [ ] Service accounts use short-lived tokens, not static passwords
- [ ] Regular access reviews (quarterly minimum for privileged accounts)

## Device Trust

- [ ] All devices registered in MDM (MDM platform, Intune, or equivalent)
- [ ] Device compliance checked before granting access (OS version, disk encryption, AV)
- [ ] Certificate-based device authentication for corporate resources
- [ ] BYOD isolated in separate network segment or via VDI
- [ ] Endpoint telemetry sent to SIEM for anomaly detection

## Network Segmentation

- [ ] Micro-segmentation implemented (no flat network)
- [ ] East-west traffic inspected (lateral movement detection)
- [ ] VPN replaced or augmented with ZTNA proxy (per-app access)
- [ ] DNS filtering enabled to block C2 and malicious domains
- [ ] Network access logs centralised (NetFlow / firewall logs to SIEM)

## Least Privilege Access

- [ ] No user has standing admin rights (Just-In-Time elevation)
- [ ] Role-based access control (RBAC) defined for all systems
- [ ] AdministratorAccess / Domain Admin membership reviewed monthly
- [ ] Privileged Access Workstations (PAW) used for admin tasks
- [ ] Break-glass accounts documented, monitored and tested quarterly

## Data Protection

- [ ] Data classification policy in place (Public / Internal / Confidential / Restricted)
- [ ] DLP controls on endpoints and email gateways
- [ ] Encryption at rest and in transit enforced
- [ ] Cloud storage buckets audited for public access
- [ ] Data access logged and alerts configured for anomalous access patterns

## Monitoring & Response

- [ ] SIEM ingesting: AD/AAD, endpoint, network, cloud, application logs
- [ ] Alerting on: failed MFA, impossible travel, off-hours admin activity
- [ ] Incident response playbooks documented and tested
- [ ] Mean Time to Detect (MTTD) and Respond (MTTR) tracked
- [ ] Threat hunting performed regularly (MITRE ATT&CK based)

## Governance

- [ ] Zero Trust policy documented and approved by leadership
- [ ] Asset inventory complete and current (< 5% unknown assets)
- [ ] Vendor/third-party access reviewed and time-limited
- [ ] Audit logs retained per compliance requirement (min 1 year)
- [ ] Annual ZTA maturity assessment performed

---

## Maturity Levels

| Level | Description |
|-------|-------------|
| 0 — Traditional | Implicit trust inside perimeter, VPN-only |
| 1 — Initial | MFA deployed, basic RBAC, some segmentation |
| 2 — Advanced | Continuous verification, device trust, micro-segmentation |
| 3 — Optimal | Fully automated policy, AI-driven anomaly detection, JIT access |

## References

- [NIST SP 800-207 — Zero Trust Architecture](https://csrc.nist.gov/publications/detail/sp/800-207/final)
- [CISA Zero Trust Maturity Model](https://www.cisa.gov/zero-trust-maturity-model)
- [Microsoft Zero Trust Guidance](https://learn.microsoft.com/en-us/security/zero-trust/)
- [MITRE ATT&CK Enterprise](https://attack.mitre.org/)
