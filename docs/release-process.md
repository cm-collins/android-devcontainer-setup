# Release Process

This project is currently pre-1.0. Releases should remain conservative until
the installed `android-dev` CLI, structured logging, project templates,
generated Dev Container workflow, and emulator workflows are stable.

## Versioning

Use semantic versioning once public releases begin:

```text
MAJOR.MINOR.PATCH
```

Before `1.0.0`, use `0.x.y` versions:

* `0.x.0` for notable feature milestones
* `0.x.y` patch releases for fixes and documentation updates

## Release Checklist

1. Confirm the working tree is clean.
2. Confirm CI passes on `main`.
3. Review open Dependabot and security-related pull requests.
4. Update `CHANGELOG.md`.
5. Confirm README quick start still matches the current workflow.
6. Confirm product direction, cutover plan, and phase plans are current.
7. Tag the release.
8. Publish GitHub release notes.

## CLI Package Release Checklist

Use this checklist once Phase 5 introduces packaged CLI releases.

1. Build the `android-dev` release artifact.
2. Install the artifact into a clean temporary environment.
3. Run:

```bash
android-dev --help
android-dev version
android-dev devcontainer init --dry-run
```

4. Confirm the package includes only required runtime files.
5. Confirm install, update, and uninstall instructions work.
6. Confirm release notes identify the package channel.
7. Confirm checksums or artifact integrity notes are published when available.

## Tagging

Use annotated tags:

```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

Signed tags are recommended once the project has regular external users.

## Pre-1.0 Cutover Milestones

Suggested release milestones:

| Version | Focus |
| --- | --- |
| `0.1.0` | Repository-local Dev Container workstation and templates |
| `0.2.0` | `android-dev` entry point and host/container doctor split |
| `0.3.0` | `android-dev devcontainer init` generator |
| `0.4.0` | Project-local workflows and packaging preview |
| `0.5.0` | JSON output for editor integrations |
| `0.6.0` | Optional VS Code extension preview |
