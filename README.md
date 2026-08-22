# Necommerce Security Assessment

**Risk-oriented application security assessment of an e-commerce platform**

[Русская версия / Full Russian report](README-rus.md)

## Overview

This repository documents a security assessment of **Necommerce**, a training e-commerce application consisting of separate frontend and backend services.

The assessment was performed as a course project for the Information Security Specialist program, but the work was intentionally structured as a reproducible application-security review rather than as a collection of isolated tool runs.

The scenario assumes that the application has previously experienced a large-scale leak of user and purchase data. The objective was therefore to review the application, its source code, dependencies, container images, CI/CD configuration, runtime behavior, authentication and authorization controls, and to identify security weaknesses that could lead to another incident.

Upstream application repositories:

- [Frontend](https://github.com/netology-code/necommerce-frontend)
- [Backend](https://github.com/netology-code/necommerce-backend)

> The detailed Russian-language report, including the original assignment, planning material, command output, intermediate analysis, and complete evidence references, is preserved in [`README-rus.md`](README-rus.md).

## Assessment approach

The work followed a risk-oriented workflow based primarily on:

- OWASP Application Security Verification Standard (ASVS)
- OWASP Web Security Testing Guide (WSTG)
- OWASP Top 10
- OWASP API Security Top 10
- CIS Docker Benchmark
- CWE
- CVSS 4.0

This was not intended to be a full ASVS certification. Testing focused on the attack paths most relevant to the incident scenario: authentication, authorization, orders, personal data, API endpoints, secrets, dependencies, container configuration, CI/CD, logging, and exposed application functionality.

## Scope

The assessment covered:

- frontend and backend source code;
- application architecture and attack surface;
- GitHub Actions workflows and publicly visible development controls;
- secrets in repositories and container images;
- frontend and backend dependencies;
- static application security testing (SAST);
- Dockerfiles, Docker Compose configuration, images, and runtime settings;
- passive dynamic application security testing (DAST);
- manual API and negative testing;
- authentication and role-based authorization;
- object-level and function-level authorization;
- validation, deduplication, and risk assessment of findings.

## Tools

The assessment used a combination of automated tools and manual verification:

| Tool / technique | Purpose |
| --- | --- |
| Semgrep CE | Static analysis of frontend/backend source and configuration |
| Gitleaks | Secret scanning of Git history/source repositories |
| Trivy | Container image and dependency vulnerability analysis |
| npm audit | Frontend dependency/SCA analysis |
| OWASP ZAP | Passive DAST against the local frontend and backend API |
| curl | Reproducible API and authorization tests |
| jq | Filtering and sanitizing JSON results |
| Docker / Docker Compose | Reproducible local test environment |
| Manual source review | Security configuration, authentication, authorization, controllers, services, tokens, files, and logging |

Raw or unnecessarily sensitive output was not committed when a sanitized evidence artifact was sufficient.

## Assessment workflow

The work was divided into the following packages:

1. Environment and scope definition
2. Architecture and attack-surface analysis
3. CI/CD and development-process review
4. Secret scanning
5. Dependency and SBOM analysis
6. Source-code review and SAST
7. Container and configuration security
8. Dynamic application security testing
9. Manual negative and API testing
10. Authentication, session, and authorization testing
11. Finding verification and risk assessment
12. Final conclusions and remediation priorities

Evidence is stored under [`evidence/`](evidence/), grouped by assessment stage.

## Key confirmed findings

### 1. Broken Object Level Authorization (BOLA / IDOR)

A user order could be retrieved directly by its numeric identifier:

```http
GET /api/orders/{id}
```

Testing demonstrated that:

- the owner could retrieve the order;
- a different authenticated user could retrieve the same order;
- an unauthenticated client could also retrieve the order.

The response included owner information, including the owner's name and phone number.

This confirms a **Broken Object Level Authorization** vulnerability: knowledge or enumeration of an order identifier is sufficient to access another user's order without an ownership check.

**Classification:** CWE-639 / OWASP API1:2023 — Broken Object Level Authorization  
**CVSS 4.0:** **8.7 (High)**  
**Vector:** `CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:N/VA:N/SC:N/SI:N/SA:N`

### 2. Unauthenticated product deletion

Manual testing confirmed that a product could be deleted without authentication:

```http
DELETE /api/products/{id}
```

The request returned `200 OK`, and a subsequent `GET` returned `404 Not Found`, confirming that the object had actually been removed.

This is a function-level authorization failure that allows an unauthenticated client to modify application state and compromise catalogue integrity.

**Classification:** CWE-862 / OWASP API5:2023 — Broken Function Level Authorization  
**CVSS 4.0:** **8.7 (High)**  
**Vector:** `CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:N/VI:H/VA:N/SC:N/SI:N/SA:N`

### 3. Administrative credentials exposed in startup logs

Backend review and runtime verification showed that administrative credentials are generated during startup and written to application logs.

Credential values were deliberately excluded from committed evidence.

This creates a high-impact exposure if logs become accessible to another user, monitoring system, support process, container operator, or log aggregation platform.

**Classification:** CWE-532 — Insertion of Sensitive Information into Log File  
**CVSS 4.0:** **8.5 (High)**  
**Vector:** `CVSS:4.0/AV:L/AC:L/AT:N/PR:L/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N`

### 4. Authentication-token lifecycle weaknesses

Manual source review identified weaknesses in authentication-token generation/lifecycle management, including predictable generation characteristics and insufficient planned invalidation controls.

This finding was retained as an authentication-design issue rather than assigning an artificial aggregate CVSS score without a single fully demonstrated exploitation path.

### 5. Vulnerable frontend dependency tree

SCA identified a significant number of known advisories in the frontend dependency tree. `npm audit` reported:

- 204 total advisories;
- 21 critical;
- 60 high;
- 116 moderate;
- 7 low.

Direct vulnerable dependencies included `axios` and `react-scripts`; many additional findings were transitive dependencies.

These results require remediation and reachability triage. The presence of an advisory was not treated as proof that every affected package is exploitable in the running application.

### 6. Container and CI/CD hardening issues

Static and configuration review identified additional hardening concerns, including:

- backend container execution without an explicit non-root `USER`;
- mutable GitHub Actions references instead of full commit-SHA pinning;
- mutable container image references that do not guarantee byte-for-byte reproducibility after a future pull;
- services published more broadly than the local active-testing allowlist;
- missing Docker health checks, restart policies, resource limits, and other runtime hardening controls;
- excessive backend logging, including sensitive-field indicators.

These issues were consolidated rather than counted repeatedly for every individual scanner message or workflow line.

## Authorization results

The application does implement role-based controls on several routes. For example:

| Scenario | Result |
| --- | --- |
| Anonymous → `GET /api/orders` | `403 Forbidden` |
| Regular user → `GET /api/orders` | `403 Forbidden` |
| Manager → `GET /api/orders` | `200 OK` |
| Regular user → `GET /api/orders/my` | `200 OK` |
| Regular user attempts administrative user creation | `403 Forbidden` |
| Invalid authentication credentials | `400 Bad Request` |

However, these controls are inconsistent. Object-level and function-level tests demonstrated that selected endpoints bypass the otherwise present role model, which is why authorization was treated as the highest-priority application risk.

## DAST and manual verification

OWASP ZAP was used for passive testing of both the frontend and selected backend API endpoints in the local Docker environment. Automated results were treated as candidates rather than final vulnerabilities.

For example, a ZAP `Timestamp Disclosure - Unix` alert was manually reviewed and classified as non-security-relevant because the detected value was the application's expected public `published` field.

Manual negative tests also verified controlled handling of several malformed or unsupported requests, including:

- invalid object identifiers;
- malformed JSON;
- unsupported HTTP methods;
- unauthenticated file upload attempts.

Where the application returned expected `400`, `403`, `404`, or `405` responses without stack traces or internal implementation details, those cases were not promoted to findings.

## Risk assessment

Automated results were deduplicated and manually reviewed before inclusion in the final register. Duplicate scanner messages were consolidated, and false positives or purely informational observations were separated from confirmed security findings.

CVSS 4.0 scores were assigned only where the assessment produced a sufficiently concrete and reproducible vulnerability scenario. Aggregate dependency, process, and hardening observations were not given invented CVSS scores where doing so would imply more certainty than the evidence supports.

The highest remediation priority is authorization:

1. enforce authentication and ownership checks for `GET /api/orders/{id}`;
2. protect all state-changing catalogue operations, including `DELETE /api/products/{id}`;
3. remove credentials and other sensitive values from application logs;
4. redesign authentication-token generation, storage, expiration, and invalidation;
5. triage and update vulnerable dependencies;
6. harden containers and CI/CD dependencies;
7. add automated regression tests for BOLA/BFLA and the complete role matrix.

## Evidence

Reproducible and sanitized evidence is organized under [`evidence/`](evidence/). The evidence structure separates individual assessment stages and keeps large raw scanner output out of the main report where a filtered result is more useful.

Examples include:

- attack-surface and endpoint documentation;
- secret-scanning results;
- dependency-analysis summaries;
- Semgrep/SAST findings;
- container and configuration checks;
- ZAP reports and execution logs;
- manual negative-testing evidence;
- authorization test plans and results;
- the consolidated risk register.

Sensitive authentication tokens, passwords, and unnecessary personal data were not intentionally committed to evidence.

## Conclusion

The assessment found that Necommerce has several security controls that behave correctly in isolation, including role restrictions on selected endpoints and appropriate rejection of a number of malformed requests. However, the overall authorization model is inconsistent.

The most important issue is that object-level and function-level authorization checks are missing on selected API operations. This directly enables unauthorized access to order data and unauthenticated modification of catalogue content. Additional risks exist in credential logging, authentication-token lifecycle management, vulnerable dependencies, container hardening, and CI/CD supply-chain controls.

The project demonstrates why automated security scanners should not be treated as the final result of an application-security assessment: the highest-impact findings in this review required source-code analysis, explicit hypotheses, and manual reproduction against the running application.

## Repository languages

- **English:** this `README.md` — concise portfolio-oriented assessment summary
- **Russian:** [`README-rus.md`](README-rus.md) — full course report, methodology, commands, intermediate results, and detailed evidence references
