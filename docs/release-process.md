# Release Process

This project is currently pre-1.0. Releases should remain conservative until
the workstation CLI, structured logging, project templates, and emulator
workflows are stable.

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
6. Tag the release.
7. Publish GitHub release notes.

## Tagging

Use annotated tags:

```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

Signed tags are recommended once the project has regular external users.
