# Changelog

All notable changes to this project will be documented in this file.

This project follows a lightweight changelog process inspired by
[Keep a Changelog](https://keepachangelog.com/). Versioning will remain
pre-1.0 until the workstation CLI, logging, security, and emulator workflows
stabilize.

## Unreleased

### Added

* Product direction for an installable `android-dev` CLI and future editor
  integrations.
* Deterministic cutover plan for moving from the template checkout to the
  installable CLI workflow.
* Dedicated phase plan documents under `docs/plans/` with dependencies,
  validation gates, rollback paths, and architecture diagrams.
* Transition notes for phone connection, troubleshooting, release, and feature
  request docs as the project moves toward `android-dev`.
* Open-source planning notes for roadmap issues and GitHub Discussions.
* Reusable Android Dev Container with Android SDK profiles.
* Helper CLI for doctor checks, builds, tests, lint, device listing, wireless
  pairing, app creation, and debug installation.
* Interactive project bootstrap flow with automatic first build.
* Android workstation CLI roadmap.
* Open-source project guardrails, including license, security policy,
  contributor guidance, issue templates, PR template, CODEOWNERS, Dependabot,
  CI, CodeQL, and image scanning.

### Security

* Documented secret handling and vulnerability reporting expectations.
* Added repository guardrail files for review ownership and contribution flow.
* Added CI checks for shell validation, documentation linting, Docker build,
  and container image scanning.
