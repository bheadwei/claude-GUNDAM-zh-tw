---
name: owasp-web-security
description: Use when the user asks for OWASP-aligned review, threat modeling against OWASP Top 10, secure design checklists, or mapping findings to OWASP categories (web and API). Complements security-review with explicit OWASP taxonomy and official references.
origin: project (OWASP.org)
---

# OWASP Web Security Skill

Structured guidance for **OWASP Top 10 (2021)** and related OWASP projects. Use alongside the project `security-review` skill for implementation patterns; use this skill to **classify** issues and **anchor** mitigations to OWASP terminology.

## When to Activate

- User mentions OWASP, Top 10, ASVS, SAMM, or CWE mapping
- Security assessment or design review should cite OWASP categories
- API security (pair with [OWASP API Security Top 10](https://owasp.org/API-Security/))

## OWASP Top 10 (2021) — Risk Categories

Use these **official category names** when reporting or triaging:

| ID | Category |
| :--- | :--- |
| A01:2021 | Broken Access Control |
| A02:2021 | Cryptographic Failures |
| A03:2021 | Injection |
| A04:2021 | Insecure Design |
| A05:2021 | Security Misconfiguration |
| A06:2021 | Vulnerable and Outdated Components |
| A07:2021 | Identification and Authentication Failures |
| A08:2021 | Software and Data Integrity Failures |
| A09:2021 | Security Logging and Monitoring Failures |
| A10:2021 | Server-Side Request Forgery (SSRF) |

## Workflow

1. **Scope** — Web UI, backend APIs, auth flows, file uploads, admin paths, third-party callbacks (SSRF), supply chain (dependencies, CI).
2. **Map findings** — For each issue, assign an A01–A10 label (and CWE when helpful). Note if multiple categories apply.
3. **Mitigations** — Prefer framework defaults, secure configs, least privilege, parameterized queries, validated redirects, centralized authz, patching, integrity controls (signing, pinning where appropriate), and actionable logging/alerts.
4. **Verification** — Tie recommendations to test types (unit, integration, SAST/DAST, dependency scan) without replacing org-specific tooling choices.

## Official References (read externally; do not invent control text)

- [OWASP Top 10 (2021)](https://owasp.org/Top10/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)
- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/) (requirements for verification)
- [OWASP API Security Top 10](https://owasp.org/API-Security/)

## Relationship to Other Skills

- **security-review** — Concrete code patterns, secrets, validation, checklist execution in-repo.
- **security-best-practices-openai** — Language/framework-oriented secure defaults and references bundle.
- **owasp-web-security** — Taxonomy, scoping, and OWASP-specific framing for reports and design discussions.
