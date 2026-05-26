# Cutover Plan

This plan describes how to move from the current cloneable Android Dev
Container template to the target installable `android-dev` CLI without breaking
the working repository-local workflows. Detailed phase execution plans live in
[docs/plans](plans/README.md).

## Cutover Goal

The final user experience should be:

```bash
android-dev init
android-dev devcontainer init
android-dev doctor
android-dev build
android-dev run-debug
```

Developers should be able to install `android-dev`, run it inside any Android
project or empty project folder, generate Dev Container files when needed, and
continue using the same command name inside the Dev Container.

## Current Operating Model

The current implementation works as a Dev Container template and workstation
checkout.

| Area | Current behavior |
| --- | --- |
| Public command | `bash .devcontainer/scripts/android-dev.sh <command>` |
| Command router | `.devcontainer/scripts/android-dev.sh` |
| Shared implementation | `.devcontainer/scripts/lib/*.sh` |
| Dev Container files | Stored directly in this repository under `.devcontainer/` |
| Project creation | `init` and `new-app` create child projects inside the checkout |
| Project selection | The CLI detects child projects by looking for executable `gradlew` files |
| Dev Container export | `export-devcontainer <directory>` copies this repository's `.devcontainer/` |
| Workspace metadata | `sync-workspace` writes `android-devcontainer.code-workspace` |
| Diagnostics | `doctor` assumes Android SDK and ADB are available in the current shell |
| Logs | Major commands write `.android-dev/logs/*.log` under the current directory |

This model is useful today, but it still asks developers to clone this
repository or copy files manually.

## Target Operating Model

The target implementation should work as an installed tool.

| Area | Target behavior |
| --- | --- |
| Public command | `android-dev <command>` |
| Host setup | `android-dev devcontainer init` generates project-local Dev Container files |
| Container setup | The same `android-dev` command works inside the Dev Container |
| Existing projects | The CLI can inspect and support an existing Gradle Android project |
| New projects | The CLI can create a new Android project and Dev Container together |
| Diagnostics | `doctor` has host and container modes |
| Editor support | VS Code or Cursor extensions call the CLI instead of owning core behavior |
| Distribution | Install script, npm package, Homebrew, or GitHub Release archive |

## Non-Negotiable Rules

These rules keep the cutover deterministic and safe.

* Do not remove the repository-local script until the installed command is
  proven in CI and docs.
* Do not overwrite an existing `.devcontainer/` directory without explicit
  confirmation.
* Do not require the Android SDK on the host for setup commands.
* Do not hide generated file changes. Preview or list every file that will be
  written.
* Do not let the VS Code extension become the source of truth for Android,
  Gradle, ADB, SDK, or logging behavior.
* Do not replace working Bash internals just to change language. Rewrite only
  when the current implementation blocks the product.
* Every phase must keep structured errors, logs, and CI validation.

## Phase 0: Stabilize the Source of Truth

Purpose: make sure contributors understand the new product shape before code
movement starts.

Detailed plan: [Phase 0: Source of Truth](plans/phase-0-source-of-truth.md).

### Work

* Keep `docs/product-direction.md` as the source of truth.
* Keep this cutover plan linked from the README and planning docs.
* Keep `docs/open-source-planning.md` as the issue and discussion staging area.
* Open GitHub Discussions for product direction, VS Code extension scope, and
  Dev Container generator safety.
* Open roadmap issues for installed CLI, `devcontainer init`, host/container
  `doctor`, JSON output, and packaging.

### Acceptance Criteria

* README points to product direction and cutover plan.
* Roadmap docs agree that `android-dev` is the target public command.
* Community templates exist for roadmap and product discussions.
* No behavior changes are required in this phase.

### Rollback

Revert only the docs if the direction changes. No runtime behavior is affected.

## Phase 1: Add the `android-dev` Entry Point

Purpose: introduce the target public command while preserving the current
repository-local script.

Detailed plan: [Phase 1: `android-dev` Entry Point](plans/phase-1-cli-entrypoint.md).

### Work

* Add a top-level executable, for example `bin/android-dev`.
* Make it locate the implementation modules deterministically.
* Route existing commands through the same implementation used by
  `.devcontainer/scripts/android-dev.sh`.
* Keep `.devcontainer/scripts/android-dev.sh` as a compatibility wrapper.
* Update help text to show `android-dev <command>` as the target public shape
  and the repository-local command as the development fallback.

### Acceptance Criteria

* `android-dev --help` works from the repository checkout.
* `android-dev doctor`, `android-dev templates`, and `android-dev logs` route to
  the same behavior as the current script where applicable.
* Existing CI still runs the repository-local command.
* New CI also runs the `android-dev` entry point.
* No documented current command is removed.

### Rollback

Remove the new entry point and CI checks. The current script remains untouched.

## Phase 2: Separate Host and Container Context

Purpose: make one command useful before and after the Dev Container exists.

Detailed plan: [Phase 2: Host and Container Context](plans/phase-2-host-container-context.md).

### Work

* Add deterministic context detection.
* Define host context as a shell outside the Android Dev Container.
* Define container context as a shell with expected Android SDK environment,
  Dev Container markers, or generated project metadata.
* Split `doctor` into host checks and container checks.
* Keep host checks focused on Docker, Dev Container config, project structure,
  and next steps.
* Keep container checks focused on Java, Android SDK, SDK packages, ADB, Gradle,
  devices, and project metadata.

### Acceptance Criteria

* `android-dev doctor` does not fail on the host just because ADB is missing.
* Host `doctor` clearly says which checks require the Dev Container.
* Container `doctor` keeps the current Android SDK and ADB checks.
* Errors keep stable `ANDROID-*` codes.
* Logs identify whether the command ran in host or container context.

### Rollback

Route `doctor` back to the current container-only implementation and keep the
new context helpers unused.

## Phase 3: Introduce Dev Container Generation

Purpose: replace manual copying and `export-devcontainer` with a project-local
generator.

Detailed plan: [Phase 3: Dev Container Generator](plans/phase-3-devcontainer-generator.md).

### Work

* Add `android-dev devcontainer init`.
* Move Dev Container file content into reusable templates or generator
  functions.
* Generate these files into the current project:
  * `.devcontainer/devcontainer.json`
  * `.devcontainer/Dockerfile.dev`
  * SDK package manifests
  * required helper scripts or bootstrap files
* Add `--dry-run` or an equivalent preview mode.
* Detect existing `.devcontainer/` and stop unless the user explicitly chooses
  a safe path.
* Print editor-specific next steps without requiring a specific editor.

### Acceptance Criteria

* Running in an empty project writes a complete `.devcontainer/`.
* Running in an existing Android Gradle project writes a complete
  `.devcontainer/` without changing Gradle files.
* Running where `.devcontainer/` already exists refuses to overwrite by default.
* Dry run lists every file that would be written.
* Generated Dev Container can build the project in CI or smoke tests.
* `export-devcontainer` is marked as a transition command, not the preferred
  workflow.

### Rollback

Disable `devcontainer init` and keep `export-devcontainer` as the only export
path.

## Phase 4: Make Project Workflows Project-Local

Purpose: shift from workstation-root child project detection to normal
project-root operation.

Detailed plan: [Phase 4: Project-Local Workflows](plans/phase-4-project-local-workflows.md).

### Work

* Make project-root detection prefer the current directory when it contains
  `gradlew`, `settings.gradle*`, or `.android-dev/project.json`.
* Keep child project selection only as a compatibility path for this repository.
* Make logs consistently write under the selected project root.
* Make `run-debug` prefer `.android-dev/project.json`, then Gradle files, then
  explicit arguments.
* Update next-step messages from `bash .devcontainer/scripts/android-dev.sh` to
  `android-dev` once the entry point is stable.

### Acceptance Criteria

* In a normal Android project, `android-dev build` runs the local `./gradlew`.
* In this implementation checkout, existing child-project selection still works.
* Multiple project candidates still trigger a prompt instead of guessing.
* Logs land in the project being acted on.
* No current smoke template behavior regresses.

### Rollback

Keep the new project-root helpers but route command selection back through the
current `select_project_root` behavior.

## Phase 5: Package for Early Adopters

Purpose: let developers install the CLI without cloning the implementation
workspace manually.

Detailed plan: [Phase 5: Packaging](plans/phase-5-packaging.md).

### Work

* Choose the first install channel.
* Recommended first path: GitHub Release archive plus install script.
* Optional next path: npm package for easier cross-platform CLI discovery.
* Add `android-dev version`.
* Document install, update, and uninstall.
* Add release checks that install the package into a clean environment and run
  `android-dev --help`.

### Acceptance Criteria

* A developer can install `android-dev` without cloning the repository.
* `android-dev --help` works after installation.
* `android-dev devcontainer init --dry-run` works in a temporary directory.
* Release artifacts are versioned.
* The package includes only necessary runtime files.

### Rollback

Unpublish or mark the release as pre-release. Keep repository-local development
unchanged.

## Phase 6: Add Machine-Readable Output

Purpose: prepare for editor integrations and safer automation.

Detailed plan: [Phase 6: Machine-Readable Output](plans/phase-6-machine-readable-output.md).

### Work

* Add JSON output to selected commands:
  * `android-dev doctor --json`
  * `android-dev devices --json`
  * `android-dev templates --json`
  * `android-dev logs latest --json`
* Add machine-readable error fields:
  * `code`
  * `area`
  * `problem`
  * `why`
  * `nextStep`
  * `log`
* Keep human-readable output as the default.

### Acceptance Criteria

* JSON output is valid and documented.
* JSON fields are stable enough for a VS Code extension.
* Human output remains unchanged unless intentionally updated.
* CI validates representative JSON output.

### Rollback

Hide JSON flags from docs and keep the human CLI unchanged.

## Phase 7: Build Editor Integration

Purpose: make the workflow easier in VS Code and Cursor without moving core
logic out of the CLI.

Detailed plan: [Phase 7: Editor Integration](plans/phase-7-editor-integration.md).

### Work

* Create a VS Code extension only after the CLI entry point and JSON output are
  stable.
* Extension features should call `android-dev`.
* Start with command palette actions:
  * Doctor
  * Build
  * Run debug
  * View latest log
  * Add Dev Container
* Add device and template UI later.

### Acceptance Criteria

* Extension can find or guide installation of `android-dev`.
* Extension commands call CLI commands and show CLI output or JSON-derived UI.
* Extension does not duplicate Android SDK, Gradle, ADB, or Dev Container
  behavior.
* CLI remains fully usable without the extension.

### Rollback

Keep the extension unpublished or experimental. CLI workflows remain the
supported product.

## Phase 8: Deprecate Template-First Usage

Purpose: finish the cutover once installed usage is proven.

Detailed plan: [Phase 8: Deprecate Template-First Usage](plans/phase-8-deprecate-template-first.md).

### Work

* Move README quick start from repository-local setup to installed CLI setup.
* Keep a contributor setup section for people hacking on this repository.
* Deprecate `export-devcontainer` after `android-dev devcontainer init` is
  stable.
* Decide whether `sync-workspace` remains a contributor-only command or becomes
  a supported multi-root workflow.
* Update issue templates and docs to assume installed CLI usage.

### Acceptance Criteria

* New users can follow the README without cloning this repository.
* Contributors still have clear local development instructions.
* Old repository-local commands either continue as compatibility wrappers or
  have documented replacements.
* CI validates both installed CLI usage and contributor checkout usage.

### Rollback

Restore clone-first README instructions and keep installed CLI docs as
experimental.

## Compatibility Matrix

| Workflow | During cutover | Final state |
| --- | --- | --- |
| Clone repo and run script | Supported | Contributor workflow |
| Install `android-dev` and run commands | Added gradually | Primary workflow |
| Copy `.devcontainer/` manually | Supported but discouraged | Replaced by generator |
| `export-devcontainer` | Transition command | Deprecated or hidden |
| `sync-workspace` | Supported for workstation checkout | Contributor or advanced workflow |
| VS Code extension | Not required | Optional wrapper |

## Greenfield Cleanup Inventory

This section identifies files and workflows that can be removed, moved, or
reframed after the installed CLI path is working. Nothing in this list should be
deleted before the matching replacement exists and passes CI.

### Keep as Core Product

These files remain central to the product, though some may move into a package
layout later.

| Path | Greenfield role |
| --- | --- |
| `.devcontainer/scripts/lib/core.sh` | Shared logging, command output, and structured error helpers |
| `.devcontainer/scripts/lib/validation.sh` | Input validation helpers |
| `.devcontainer/scripts/lib/templates.sh` | Android project template generation until templates are externalized |
| `.devcontainer/scripts/lib/projects.sh` | Project discovery, metadata, and project workflow logic |
| `.devcontainer/scripts/lib/gradle.sh` | Gradle execution and build workflow helpers |
| `.devcontainer/scripts/lib/devices.sh` | ADB, device selection, install, and run-debug workflows |
| `.devcontainer/scripts/lib/network.sh` | Wireless debugging reachability checks |
| `.devcontainer/scripts/lib/watch.sh` | Gradle file watcher if the command remains supported |
| `.devcontainer/Dockerfile.dev` | Source template for generated Dev Container images |
| `.devcontainer/devcontainer.json` | Source template for generated Dev Container config |
| `.devcontainer/android-sdk-packages*.txt` | SDK profile templates |
| `docs/product-direction.md` | Product source of truth |
| `docs/cutover-plan.md` | Migration source of truth |
| `docs/open-source-planning.md` | Community planning and issue staging |

### Move or Reframe

These should probably stay, but their role should change once the installed CLI
is primary.

| Path | Current role | Greenfield role |
| --- | --- | --- |
| `.devcontainer/scripts/android-dev.sh` | Current public command router | Compatibility wrapper or contributor-only entry point |
| `.devcontainer/scripts/verify-android-env.sh` | Dev Container post-create doctor script | Wrapper around `android-dev doctor` |
| `.devcontainer/scripts/ci-template-smoke.sh` | Template smoke test script | Package/CLI smoke test that uses `android-dev` |
| `.devcontainer/scripts/lib/editor.sh` | Multi-root workspace sync for generated child projects | Contributor or optional multi-root workflow |
| `android-devcontainer.code-workspace` | Local generated editor workspace | Remove from repo if present; keep ignored/generated only |
| `README.md` | Template-first and product docs mixed together | Product-first README plus contributor setup section |
| `docs/android-workstation-cli-plan.md` | Feature plan for workstation CLI | Implementation plan under the product direction and cutover plan |
| `docs/connect-android-phone.md` | Repo-local command examples | Update examples to `android-dev` after entry point exists |
| `docs/troubleshooting-errors.md` | Repo-local command examples | Update examples to `android-dev` after entry point exists |
| `CONTRIBUTING.md` | Contributor setup for this checkout | Keep as repository development guide |
| `docs/release-process.md` | Repository release notes | Expand for CLI package releases |

### Deprecate After Replacement

These commands or behaviors should be phased out once the new path is proven.

| Item | Replacement | Removal gate |
| --- | --- | --- |
| `export-devcontainer <directory>` | `android-dev devcontainer init` | Generator supports dry run, existing project setup, and CI smoke tests |
| Workstation-root child project default | Project-local command execution | `android-dev build` works in normal Android project roots |
| README clone-first quick start | Install-first quick start | First package install path exists |
| Manual `.devcontainer/` copy instructions | `android-dev devcontainer init` | Generator refuses overwrites and prints next steps |
| Repo-local command in user docs | `android-dev <command>` | `android-dev` entry point is stable and packaged |

### Remove Only After Cutover

These are candidates for removal from the public product path after the final
cutover, but not necessarily from the repository.

| Path or behavior | Reason | Safe removal condition |
| --- | --- | --- |
| `android-devcontainer.code-workspace` in Git | It is local generated editor state | Confirm it is ignored and no longer tracked |
| Template-only README sections | They reinforce clone-first usage | Installed CLI quick start is validated |
| `export-devcontainer` command help | It points to old mental model | Replacement command is documented and stable |
| Parent-script instructions like `bash ../.devcontainer/scripts/android-dev.sh` | They only apply to child projects in this checkout | Project-local `android-dev` works from generated projects |
| CI steps that only validate repo-local command | They miss installed CLI behavior | Package install tests are in CI |

### Do Not Remove

These should stay because they are open-source project infrastructure.

| Path | Reason |
| --- | --- |
| `.github/workflows/ci.yml` | Required validation |
| `.github/workflows/codeql.yml` | Security analysis |
| `.github/ISSUE_TEMPLATE/*` | Contributor intake |
| `.github/DISCUSSION_TEMPLATE/*` | Product and community planning |
| `.github/CODEOWNERS` | Review ownership |
| `LICENSE` | Open-source license |
| `SECURITY.md` | Vulnerability reporting |
| `CODE_OF_CONDUCT.md` | Community safety |
| `CONTRIBUTING.md` | Contributor workflow |
| `CHANGELOG.md` | Release history |

## Deterministic Test Gates

Each phase should pass the relevant checks before moving forward.

| Gate | Command or check |
| --- | --- |
| Shell syntax | `bash -n .devcontainer/scripts/*.sh .devcontainer/scripts/lib/*.sh` |
| Current help | `bash .devcontainer/scripts/android-dev.sh --help` |
| New help | `android-dev --help` once added |
| Template smoke | `.devcontainer/scripts/ci-template-smoke.sh` in the Dev Container image |
| Dev Container generation | `android-dev devcontainer init --dry-run` in an empty temp directory |
| Existing project support | `android-dev devcontainer init --dry-run` in a real Gradle Android project |
| Host doctor | `android-dev doctor` without Android SDK installed on host |
| Container doctor | `android-dev doctor` inside the Dev Container |
| JSON output | Validate selected `--json` commands with a JSON parser |
| Release install | Install from artifact and run `android-dev --help` |

## First Implementation Issues

Open or track these first:

1. Introduce installed CLI entry point.
2. Define host vs container context detection.
3. Add `android-dev devcontainer init --dry-run`.
4. Move Dev Container files into reusable generator templates.
5. Make project detection prefer the current project root.
6. Add packaging spike for GitHub Release archive and install script.
7. Add JSON output for `doctor`, `devices`, `templates`, and `logs latest`.

## Cutover Completion Definition

The cutover is complete when:

* the README primary quick start uses installed `android-dev`
* a developer can add Dev Container support to an existing Android project
  without cloning this repository
* a developer can create a new Android project through `android-dev init`
* host and container `doctor` both provide useful deterministic checks
* CI validates installed CLI behavior
* repository-local commands are compatibility or contributor workflows, not the
  public product interface
