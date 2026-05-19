# Contributing

Thanks for considering a contribution. This project aims to provide a
deterministic Android Dev Container and workstation CLI that works across
Linux, macOS, and Windows host workflows.

## Before You Start

Please read:

* [README.md](README.md)
* [Security Policy](SECURITY.md)
* [Android Workstation CLI Plan](docs/android-workstation-cli-plan.md)
* [Connect an Android Phone](docs/connect-android-phone.md)

## Development Setup

1. Fork or clone the repository.
2. Open it in a Dev Container-compatible editor.
3. Reopen or build the workspace inside the Dev Container.
4. Run:

```bash
bash .devcontainer/scripts/android-dev.sh doctor
```

## Validation

Before opening a pull request, run the checks that match your change:

```bash
bash -n .devcontainer/scripts/*.sh
bash .devcontainer/scripts/android-dev.sh --help
```

For Docker or SDK changes, rebuild the Dev Container or run the Docker build
used by CI.

## Pull Request Expectations

Pull requests should:

* explain the reason for the change
* keep unrelated refactors separate
* update docs when behavior changes
* include validation steps and results
* call out security-sensitive changes
* avoid committing local secrets, SDK caches, build outputs, or logs

Security-sensitive areas such as `.devcontainer/`, `.github/`, scripts, and
security policy files require maintainer review.

## Repository Guardrails

The repository is expected to use branch protection on `main` once CI and
CODEOWNERS are merged. Maintainers should require pull requests, passing CI,
and CODEOWNERS review for sensitive paths before merging changes.

## Deterministic Behavior

The CLI should avoid trial-and-error behavior. Prefer explicit inputs,
validated defaults, project metadata, and clear prompts. When a command cannot
determine a safe action, it should stop with a clear error and next step.

## Reporting Bugs

Use the bug report issue template and include:

* host OS
* editor or terminal workflow
* Docker version if relevant
* Android SDK profile
* command run
* log path or relevant output
* whether the issue involves a phone, host emulator, or container emulator
