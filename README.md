# Necommerce Security Assessment

[Русская версия](README-rus.md)

## Overview

This repository contains a risk-based security assessment of **Necommerce**, a Dockerized e-commerce web application consisting of a frontend and backend service.

The assessment was performed as a course project in information security and was accepted on the first review. The original Russian report is preserved in [`README-rus.md`](README-rus.md). This English README is a condensed portfolio-oriented version focused on methodology, reproducibility, findings, risk assessment, and remediation.

### Assessment targets

- Frontend source: [netology-code/necommerce-frontend](https://github.com/netology-code/necommerce-frontend)
- Backend source: [netology-code/necommerce-backend](https://github.com/netology-code/necommerce-backend)
- Locally deployed frontend, backend, REST API, Docker images, and runtime configuration
- Publicly visible GitHub Actions and development-process artifacts

### Security references

The assessment used a risk-oriented selection of requirements and techniques from:

- OWASP ASVS
- OWASP Web Security Testing Guide (WSTG)
- OWASP Top 10
- OWASP API Security Top 10
- CIS Docker Benchmark
- CWE
- CVSS 4.0

The work does **not** claim formal ASVS certification. Coverage was intentionally prioritized around authentication, authorization, orders, personal data, secrets, dependencies, containers, CI/CD, logging, and web/API attack surface.

---

## Test environment

The application was reproduced locally with Docker Compose using the published Necommerce images.

```yaml
version: '3.7'
services:
  backend:
    image: ghcr.io/netology-code/necommerce-backend
    ports:
      - 9999:9999

  frontend:
    image: ghcr.io/netology-code/necommerce-frontend
    environment:
      - API=http://backend:9999
      - MEDIA=http://backend:9999
    ports:
      - 8888:80
    depends_on:
      - backend
```

Local image IDs and registry digests were recorded for reproducibility. Runtime behavior, network exposure, process user, logs, image contents, and security-relevant Docker configuration were inspected separately.

---

## Assessment workflow

The work was divided into 12 packages.

| # | Area | Main techniques/tools | Result |
|---|---|---|---|
| 1 | Test stand and reproducibility | Docker Compose, `docker inspect`, logs, image IDs/digests | FINDING |
| 2 | Architecture and attack surface | Source review, endpoint inventory, trust boundaries | COMPLETED |
| 3 | Repositories and SDLC | GitHub Actions review, branch/security process review | FINDING |
| 4 | Secrets | Gitleaks, Trivy secret scan, image inspection | FINDING |
| 5 | Dependencies / SCA / SBOM | Trivy filesystem scan, `npm audit` | FINDING / PARTIAL |
| 6 | Source code security | Semgrep + manual security review | FINDING |
| 7 | Containers and runtime configuration | Trivy image scan, Docker runtime inspection | FINDING |
| 8 | Automated DAST | OWASP ZAP Baseline and Automation Framework | FINDING |
| 9 | Manual web/API negative testing | Reproducible `curl` scenarios | FINDING / PARTIAL |
| 10 | Authentication and authorization | Role matrix, BOLA/BFLA tests | FINDING |
| 11 | Verification and risk assessment | Deduplication, CWE/OWASP mapping, CVSS 4.0 | FINDING |
| 12 | Final recommendations | Evidence-driven remediation plan | COMPLETED |

`FINDING` means that the test was completed and an issue was confirmed; it does not mean the test itself was left unfinished.

---

## Key findings

### F-01 — Broken Object Level Authorization (BOLA/IDOR)

**Severity:** High  
**CVSS 4.0:** `8.7`  
**Vector:** `CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:N/VA:N/SC:N/SI:N/SA:N`  
**CWE:** CWE-639  
**OWASP API:** API1:2023 Broken Object Level Authorization  
**Confidence:** High — dynamically reproduced

A test order belonging to `userA` was created. The following request returned the order data with **no authentication**:

```http
GET /api/orders/1
```

The same object was also successfully retrieved by a different user (`userB`). The response included owner-related data such as user ID, name, and phone number.

This confirms that knowledge or enumeration of an order ID is sufficient to access another user's order.

**Impact:** unauthorized disclosure of order and personal data.

**Recommended fix:** require authentication on `/api/orders/{id}` and enforce ownership or an explicitly privileged role at the object-access layer. Add cross-user and anonymous regression tests.

Evidence: [`evidence/10-authz`](evidence/10-authz/README.md)

---

### F-02 — Product deletion without authentication

**Severity:** High  
**CVSS 4.0:** `8.7`  
**Vector:** `CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:N/VI:H/VA:N/SC:N/SI:N/SA:N`  
**CWE:** CWE-862  
**OWASP API:** API5:2023 Broken Function Level Authorization  
**Confidence:** High — reproduced more than once

An unauthenticated request successfully deleted a product:

```http
DELETE /api/products/{id}
```

The server returned `HTTP 200`, and a subsequent `GET` for the same object returned `404`, confirming that the object had actually been deleted.

**Impact:** unauthenticated modification of catalog data and loss of integrity.

**Recommended fix:** deny anonymous state-changing operations and restrict product deletion to the intended administrative role. Add authorization regression tests for all mutating endpoints.

Evidence: [`evidence/09-manual-api`](evidence/09-manual-api/README.md), [`evidence/10-authz`](evidence/10-authz/README.md)

---

### F-03 — Administrative credentials written to application logs

**Severity:** High  
**CVSS 4.0:** `8.5`  
**Vector:** `CVSS:4.0/AV:L/AC:L/AT:N/PR:L/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N`  
**CWE:** CWE-532  
**OWASP:** A09:2021 Security Logging and Monitoring Failures  
**Confidence:** High — source and runtime evidence

During backend startup, an automatically generated administrative account is written to application logs, including its password. Secret values were intentionally removed from the repository evidence.

**Impact:** anyone with access to application logs may obtain privileged credentials.

**Recommended fix:** never log credentials or authentication secrets, rotate potentially exposed credentials, and restrict/monitor access to production logs.

Evidence: [`evidence/06-source-code`](evidence/06-source-code/manual-security-review.md)

---

### F-04 — Weak authentication-token lifecycle

**Priority:** High  
**CWE:** CWE-330 / CWE-613  
**OWASP:** A07:2021 Identification and Authentication Failures  
**Confidence:** High for source-code weakness; exploitability was not fully demonstrated dynamically

Manual source review identified:

- token generation based on `java.util.Random(9999)` with a fixed seed;
- a scheduled token invalidation routine containing an unimplemented `TODO`.

This creates concerns around token predictability and session lifetime/revocation.

**Recommended fix:** use a cryptographically secure token mechanism (`SecureRandom` or a standard authentication framework), enforce expiration, and implement revocation/invalidation.

No standalone CVSS score was assigned because end-to-end exploitability was not reproduced as a single runtime vulnerability during the assessment.

---

### F-05 — Secret embedded in the backend image

**Priority:** P0 pending owner validation  
**Confidence:** High for the presence of the credential file; validity and IAM impact were intentionally not tested

Trivy identified a Google Cloud service-account JSON credential inside the backend container image at:

```text
/src/fcm.json
```

Image-layer analysis associated it with the build process. The credential value itself is not stored in the public evidence.

**Impact:** if the credential remains active, compromise depends on its IAM permissions and could extend outside the application.

**Recommended fix:** revoke/rotate the key, inspect cloud audit logs and IAM permissions, remove secrets from source/build context, and rebuild all affected image layers.

Evidence: [`evidence/04-secrets`](evidence/04-secrets/)

---

## Source-code review

### Semgrep

Backend:

- 63 files scanned
- 111 rules
- 5 findings
  - 4 warnings for mutable GitHub Actions references
  - 1 error: backend Dockerfile does not define a non-root `USER`

Frontend:

- 41 files scanned
- 256 rules
- 5 warnings for mutable GitHub Actions references

No Semgrep findings were reported directly in Kotlin or JavaScript application logic. The most important application-level authorization problems were instead identified during manual source review and later confirmed dynamically.

### Manual review highlights

Manual analysis identified several security-relevant patterns, including:

- global Spring Security configuration with `anyRequest().permitAll()`;
- missing object-level authorization on `GET /api/orders/{id}`;
- missing role protection on `DELETE /api/products/{id}`;
- predictable authentication-token generation;
- incomplete token invalidation;
- administrative credentials being written to logs;
- media-type validation based on Apache Tika and server-generated filenames, but no obvious upload-size limit.

Evidence: [`evidence/06-source-code/manual-security-review.md`](evidence/06-source-code/manual-security-review.md)

---

## Dependency and image security

### Frontend dependency analysis

Trivy filesystem scan:

- **235** findings total
- 20 Critical
- 108 High
- 87 Medium
- 20 Low

`npm audit`:

- **204** advisories
- 21 Critical
- 60 High
- 116 Moderate
- 7 Low

Direct vulnerable dependencies included `axios` and `react-scripts`; many critical package-level findings were transitive.

These counts represent scanner results, not 204 independent exploitable vulnerabilities. Reachability and runtime applicability of individual CVEs require further triage.

Evidence: [`evidence/05-dependencies`](evidence/05-dependencies/)

### Container image analysis

Trivy image scans produced the following counts:

| Image/component | Critical | High | Medium | Low | Unknown |
|---|---:|---:|---:|---:|---:|
| Backend Debian packages | 53 | 217 | 188 | 68 | 12 |
| Backend Java/JAR components | 44 | 284 | 303 | 34 | — |
| Frontend Debian packages | 43 | 159 | 184 | 50 | 9 |

The backend runtime image also contains Gradle cache/build-time JAR files under `/root/.gradle/caches/...`, increasing image size and attack surface.

Runtime inspection additionally showed:

- backend process running as root;
- writable root filesystem;
- no capability drops;
- no `SecurityOpt` restrictions;
- no Docker healthcheck;
- ports published on `0.0.0.0` / `::` rather than loopback only.

Evidence: [`evidence/07-containers`](evidence/07-containers/README.md)

---

## Dynamic application testing

### OWASP ZAP — frontend

ZAP Baseline identified missing or weak HTTP response protections, including:

- Content-Security-Policy not set;
- missing anti-clickjacking protection reported by ZAP;
- missing COEP/COOP/CORP headers;
- missing Permissions-Policy;
- `X-Content-Type-Options` missing on tested frontend responses;
- server version disclosure (`nginx/1.19.8`).

The frontend was therefore classified as `FINDING` for this test package.

### OWASP ZAP — backend

The initial baseline scan of `/` was not useful because the API root returned `404`. A ZAP Automation Framework requestor plan was then used to exercise selected real API endpoints.

Tested endpoints returned `200` JSON responses. ZAP reported `Timestamp Disclosure - Unix`, but manual verification showed that the detected value was simply the application's normal public `published` timestamp field. It was therefore classified as **false positive / not security relevant**.

Evidence: [`evidence/08-dast`](evidence/08-dast/)

---

## Authentication and authorization matrix

The assessment used separate subjects representing:

- anonymous user;
- `userA`;
- `userB`;
- manager;
- administrator-related operations where applicable.

Examples of correctly enforced access control:

| Scenario | Result |
|---|---|
| Anonymous → `GET /api/orders` | `403 Forbidden` |
| `ROLE_USER` → `GET /api/orders` | `403 Forbidden` |
| `ROLE_MANAGER` → `GET /api/orders` | `200 OK` |
| `ROLE_USER` → `GET /api/orders/my` | `200 OK` |
| `ROLE_USER` attempts admin-only user creation | `403 Forbidden` |
| Invalid credentials | `400 Bad Request` |

However, the same application allowed both anonymous and cross-user access to `GET /api/orders/{id}`, demonstrating that role-level protection was applied inconsistently and was not sufficient at the object level.

Evidence: [`evidence/10-authz`](evidence/10-authz/README.md)

---

## Verification and risk assessment

Automated results were manually reviewed before inclusion in the final register.

Examples of normalization performed during verification:

- repeated Semgrep warnings for mutable GitHub Actions references were grouped into one CI/CD supply-chain issue;
- package advisories were treated as an SCA management problem rather than one independent application vulnerability per package;
- ZAP Unix timestamp disclosure was classified as a false positive;
- expected `400`, `404`, and `405` responses without stack traces were not treated as vulnerabilities;
- public self-registration was not classified as a vulnerability because users could not assign themselves privileged roles in the tested flow.

Full risk-register evidence is available in [`evidence/11-risk-register`](evidence/11-risk-register/README.md).

---

## Remediation priorities

### P0 / immediate

1. Fix BOLA/IDOR on `/api/orders/{id}` by enforcing authentication and ownership/privileged-role checks.
2. Protect all state-changing catalog operations, especially `DELETE /api/products/{id}`.
3. Remove credentials from application logs and rotate potentially exposed administrative credentials.
4. Validate and, if active, revoke/rotate the service-account credential found in the backend image.
5. Replace predictable authentication-token generation and implement expiration/revocation.

### P1 / high priority

1. Upgrade vulnerable dependencies and base images after reachability/applicability triage.
2. Build smaller multi-stage runtime images without Gradle caches/build artifacts.
3. Run application containers as non-root and apply container hardening.
4. Pin GitHub Actions to full commit SHAs and make security checks blocking where appropriate.
5. Reduce debug/trace logging and prevent sensitive data from entering logs.
6. Restrict locally exposed service ports to the required interfaces.

### P2 / hardening

1. Configure applicable browser security headers on the frontend.
2. Pin container image references by immutable digest for reproducible deployments.
3. Add negative regression tests for authorization, authentication, file handling, and error processing.

---

## Evidence structure

The repository keeps reproducible evidence grouped by assessment package:

```text
evidence/
├── 01-stand/
├── 02-attack-surface/
├── 03-sdlc/
├── 04-secrets/
├── 05-dependencies/
├── 06-source-code/
├── 07-containers/
├── 08-dast/
├── 09-manual-api/
├── 10-authz/
└── 11-risk-register/
```

Sensitive values such as authentication tokens, passwords, and raw cloud credentials were deliberately excluded or redacted from committed evidence.

---

## Limitations

The assessment intentionally documents incomplete or inaccessible areas instead of treating them as passed:

- backend SCA and a complete SBOM were not finished;
- manual API and authorization testing did not cover every one of the mapped API routes;
- token lifecycle, rate limiting, authenticated upload scenarios, and some manager/admin combinations were not fully exercised dynamically;
- private GitHub repository settings, rulesets, and security reports were unavailable and were classified as `BLOCKED`, not `PASS`;
- the validity and IAM permissions of the discovered Google Cloud credential were intentionally not tested against the external cloud environment.

---

## Main conclusion

The most important systemic issue was **inconsistent authorization enforcement**.

Some endpoints correctly enforced role-based restrictions, while individual object-level and function-level operations bypassed those controls entirely. This resulted in two directly reproducible high-impact vulnerabilities: unauthenticated/cross-user access to order data and unauthenticated deletion of products.

The assessment also identified significant security debt around secret management, authentication-token lifecycle, vulnerable dependencies, container hardening, CI/CD integrity, and logging.

The project demonstrates a full security-assessment workflow from environment reproduction and attack-surface mapping through SAST/SCA/secret scanning, container analysis, DAST, manual API testing, authorization verification, false-positive triage, CWE/OWASP mapping, CVSS 4.0 scoring, and evidence-driven remediation.

---

## Tools used

- Docker / Docker Compose
- Trivy
- Gitleaks
- Semgrep
- npm audit
- OWASP ZAP
- curl / jq
- Git / GitHub
- manual source-code and API review

---

## Language versions

- **English portfolio summary:** this file
- **Full Russian course report:** [`README-rus.md`](README-rus.md)
