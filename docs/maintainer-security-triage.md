# Maintainer Security Triage

This document describes how maintainers should handle security-sensitive reports
and repository guardrails.

## Security Report Flow

1. Acknowledge the report privately when possible.
2. Confirm whether the report affects the Dev Container, helper CLI, generated
   templates, CI, device/emulator workflows, or documentation.
3. Reproduce the issue in a safe local environment.
4. Avoid posting exploit details, secrets, tokens, or private reporter details
   in public issues.
5. Prepare a fix on a private branch or minimally disclosed pull request when
   possible.
6. Run the relevant validation checks.
7. Merge after maintainer review and passing CI.
8. Publish a short public note after the fix if disclosure is appropriate.

## Severity Guide

| Severity | Examples | Response |
| --- | --- | --- |
| Critical | secret exposure, unsafe workflow token permissions, malicious command execution path | prioritize immediately |
| High | Docker or CI behavior that could run untrusted code with elevated permissions | fix before feature work |
| Medium | confusing logs that may expose local paths or sensitive metadata | schedule soon |
| Low | documentation gaps or low-risk hardening improvements | track in normal backlog |

## Repository Guardrails

Maintainers should configure the GitHub repository to enforce:

* pull requests before merging to `main`
* at least one approving review
* CODEOWNERS review for protected paths
* passing CI checks before merge
* stale approval dismissal after new commits
* blocked force pushes and branch deletion on `main`
* secret scanning and push protection when available
* conversation resolution before merge where practical

## Review Checklist

For security-sensitive changes, confirm:

* CI permissions are least-privilege.
* Workflows do not expose secrets to untrusted pull requests.
* New downloads use HTTPS and fail closed.
* Optional SDK or emulator packages are shown before installation.
* Logs avoid secrets, tokens, signing keys, and local credential files.
* Generated projects ignore local files such as `local.properties`, keystores,
  logs, Gradle caches, and build outputs.

## Vulnerability Exceptions

Container image scan exceptions must be narrow and documented in `.trivyignore`.
Only ignore findings when they are in upstream tooling that the project does
not patch directly, the affected component is not used as an application
runtime dependency, and a follow-up hardening issue remains open.

Review `.trivyignore` whenever Android command-line tools, the base image, or
SDK package versions change.
