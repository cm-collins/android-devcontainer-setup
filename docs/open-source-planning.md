# Open Source Planning

This file collects the discussions and issues that should be opened as the
project shifts from a cloneable template to an installable CLI. The migration
sequence is tracked in [Cutover Plan](cutover-plan.md), with detailed phase
plans in [docs/plans](plans/README.md).

## Recommended Discussions

### Product Direction: Installable `android-dev` CLI

Category: Ideas

Prompt:

```text
We are moving the project from a cloneable Android Dev Container template toward
an installable `android-dev` CLI.

The intended flow is:

  android-dev init
  android-dev devcontainer init
  android-dev doctor
  android-dev build
  android-dev run-debug

The CLI should be usable from any Android project, while this repository remains
the implementation workspace.

Questions:
- Does this product shape solve a real onboarding or environment problem for you?
- Would you prefer npm, Homebrew, curl installer, GitHub Releases, or another
  install path?
- Which command should exist first for existing Android projects?
- What would make you trust this tool enough to run it in a project?
```

### VS Code Extension Scope

Category: Ideas

Prompt:

```text
The core product direction is CLI-first, with a possible VS Code extension later.

The extension would call the `android-dev` CLI instead of reimplementing Android
SDK, Gradle, ADB, or Dev Container logic.

Possible v0 features:
- command palette actions for doctor/build/run-debug
- sidebar for devices and logs
- guided Dev Container setup
- template picker

Questions:
- Which extension feature would be most useful first?
- Should the extension require the CLI to be installed, or install/use a bundled
  CLI?
- Which workflows should remain terminal-only?
```

### Dev Container Generator Safety

Category: Ideas

Prompt:

```text
The planned `android-dev devcontainer init` command will write `.devcontainer/`
files into an existing Android project.

Safety goals:
- never overwrite existing files without confirmation
- preview planned file changes
- explain host vs container responsibilities
- keep SDK package choices explicit
- write logs for generated files and follow-up checks

Questions:
- What files should the command generate by default?
- How should it behave when a project already has `.devcontainer/`?
- Should there be a dry-run mode from the beginning?
```

## Recommended Issues

Recommended labels:

| Label | Use |
| --- | --- |
| `product-direction` | Product shape and strategic direction |
| `cli` | Installed command and command behavior |
| `devcontainer` | Generated Dev Container files and Docker behavior |
| `distribution` | Packaging, releases, install, update, and uninstall |
| `editor-integration` | VS Code, Cursor, and future editor wrappers |
| `diagnostics` | Doctor checks, structured errors, and logs |
| `roadmap` | Phase-level implementation tracking |

### Issue: Introduce Installed CLI Entry Point

Labels: `enhancement`, `cli`, `product-direction`

```text
Create a stable `android-dev` executable that wraps the current repository-local
CLI implementation.

Acceptance criteria:
- `android-dev --help` works from the repository checkout
- existing commands can be called through `android-dev`
- help text describes `android-dev` as the public interface
- repository-local `bash .devcontainer/scripts/android-dev.sh` remains available
  during the transition
- docs explain the transition clearly
```

### Issue: Add `android-dev devcontainer init`

Labels: `enhancement`, `devcontainer`, `cli`

```text
Add a command that writes Android Dev Container files into the current project.

Acceptance criteria:
- detects whether `.devcontainer/` already exists
- refuses to overwrite existing files by default
- supports a dry-run or preview mode
- writes `devcontainer.json`, `Dockerfile.dev`, SDK package manifests, and any
  required helper scripts
- prints next steps for VS Code, Cursor, JetBrains, and terminal-only users
- logs generated files and command decisions
```

### Issue: Define Host vs Container `doctor`

Labels: `enhancement`, `diagnostics`, `cli`

```text
Split `doctor` behavior by execution context.

Host context should check Docker, Dev Container support, project structure, and
whether `.devcontainer/` exists.

Container context should check Java, Android SDK, SDK packages, Gradle wrapper,
ADB, devices, and project metadata.

Acceptance criteria:
- detects host vs container context deterministically
- never requires Android SDK on the host for normal setup checks
- prints clear next steps for missing host and container prerequisites
- keeps structured `ANDROID-*` error codes
```

### Issue: Add Machine-Readable Output for Editor Integrations

Labels: `enhancement`, `vscode`, `cli`

```text
Add JSON output for commands that a future VS Code extension will need.

Candidate commands:
- `android-dev doctor --json`
- `android-dev devices --json`
- `android-dev templates --json`
- `android-dev logs latest --json`

Acceptance criteria:
- JSON output is stable and documented
- human-readable output remains the default
- errors have machine-readable code, area, problem, nextStep, and log fields
```

### Issue: Package the CLI for Early Adopters

Labels: `enhancement`, `distribution`, `release`

```text
Choose and implement the first public install path for `android-dev`.

Options:
- install script
- npm package
- Homebrew tap
- GitHub Release archive

Acceptance criteria:
- install path is documented
- installed command can run `android-dev --help`
- release includes version information
- uninstall/update path is documented
- package does not require cloning the repository manually
```
