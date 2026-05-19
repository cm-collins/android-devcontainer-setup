# Security Policy

## Supported Versions

This project is currently pre-1.0. Security fixes are applied to the `main`
branch until a formal release process is introduced.

## Reporting a Vulnerability

Please do not open a public issue for vulnerabilities or sensitive reports.

Use GitHub private vulnerability reporting if it is enabled for this
repository. If it is not enabled, contact the maintainer privately and include:

* a clear description of the issue
* affected files, commands, or workflows
* reproduction steps
* expected impact
* any safe mitigation you have already identified

The maintainer will acknowledge valid reports, investigate the issue, and
coordinate a fix before public disclosure when appropriate.

## Security Scope

Security-sensitive areas include:

* `.devcontainer/` Docker and Dev Container configuration
* `.devcontainer/scripts/` helper CLI behavior
* `.github/workflows/` CI and repository automation
* generated Android project templates
* SDK package installation flows
* emulator and device management flows
* handling of logs, secrets, signing files, and local machine configuration

## Secrets and Local Files

Do not commit secrets, API keys, signing keys, keystores, generated tokens,
or machine-specific Android configuration. Android projects should keep files
such as `local.properties`, build outputs, Gradle caches, and local logs out
of version control.

When adding new workflows, avoid printing secrets in terminal output or logs.
If a command must mention a sensitive value, mask it or print only the safe
metadata needed for debugging.

## Dependency and Tooling Updates

Dependency, Docker image, Gradle, Android SDK, and GitHub Actions updates should
be reviewed before merge. Prefer pinned or documented versions where practical,
and keep optional heavy tooling behind explicit profiles or user confirmation.
