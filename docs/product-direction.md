# Product Direction

This document is the source of truth for the next product shape. The migration
sequence lives in [Cutover Plan](cutover-plan.md), with detailed phase plans in
[docs/plans](plans/README.md).

## North Star

`android-dev` should become an installable open-source CLI that adds a
reproducible Android Dev Container and workflow commands to any Android or
Kotlin Android project.

Developers should not need to clone this repository to use the tool. The
intended user experience is:

```bash
android-dev init
android-dev doctor
android-dev build
android-dev devices
android-dev run-debug
```

The current repository is the implementation workspace while the product moves
from a template-first model to an installable CLI-first model.

## Product Layers

The project should be organized around three layers:

| Layer | Responsibility |
| --- | --- |
| `android-dev` CLI | The installed command developers run from any project |
| Dev Container generator | Writes `.devcontainer/` files and SDK package manifests into a project |
| Editor integrations | Optional wrappers such as a VS Code extension that call the CLI |

The CLI is the engine. Editor integrations should improve discoverability and
comfort, but they should not own core Android, Gradle, SDK, ADB, or logging
behavior.

## Target User Experience

### New Project

```bash
mkdir my-android-app
cd my-android-app
android-dev init
```

The wizard should offer to create an Android project, generate Dev Container
files, build the first project, and print the next useful command.

### Existing Project

```bash
cd existing-android-app
android-dev devcontainer init
```

This should add the reproducible Android development environment to the current
project without overwriting existing files.

### Inside the Dev Container

```bash
android-dev doctor
android-dev build
android-dev test
android-dev lint
android-dev devices
android-dev run-debug
android-dev logs
```

The same command name should work both before and after the container exists.
The CLI should detect whether it is running on the host or inside the container
and explain which checks are available in that context.

## Host CLI and Container CLI

The installed CLI has two operating contexts.

### Host Context

The host-side CLI should:

* detect Docker and Dev Container support
* inspect the current project
* generate `.devcontainer/` files
* explain how to reopen or rebuild the project in a Dev Container
* avoid requiring the Android SDK on the host

### Container Context

The container-side CLI should:

* check Java, Android SDK, SDK packages, Gradle, and ADB
* run project Gradle tasks
* manage device selection, wireless pairing, and debug installation
* write structured logs under `.android-dev/logs/`
* use `.android-dev/project.json` where available

## Command Shape

The stable command shape should move toward:

```bash
android-dev init
android-dev devcontainer init
android-dev doctor
android-dev templates
android-dev new app
android-dev build
android-dev test
android-dev lint
android-dev assemble-debug
android-dev devices
android-dev pair-device <ip:port>
android-dev connect-device <ip:port>
android-dev run-debug [application-id]
android-dev logs [latest|tail]
```

Future commands may include:

```bash
android-dev sdk
android-dev packs
android-dev emulators
android-dev emulator create
android-dev emulator start
android-dev summary
```

## Packaging Direction

The first packaged release can keep the current Bash implementation if it
provides a stable `android-dev` executable.

Possible distribution channels:

| Channel | Purpose |
| --- | --- |
| install script | fastest early adopter path |
| npm package | simple cross-platform CLI distribution |
| Homebrew tap | friendly macOS/Linux install path |
| GitHub Releases | versioned archives and checksums |
| VS Code extension | optional UI wrapper after CLI behavior stabilizes |

The project should not block on a language rewrite. A rewrite to Go, Rust,
Node, Kotlin, or another runtime should happen only when Bash becomes the main
constraint.

## Documentation Rule

Public docs should present the installed CLI as the product direction.

During the transition, docs may include a "current development workspace" note
that explains the repository-local command:

```bash
bash .devcontainer/scripts/android-dev.sh <command>
```

That command is an implementation detail, not the long-term product interface.

## Open Questions

These should become GitHub Discussions or roadmap issues:

* What should the install channel be for the first public CLI release?
* Should the first package be named `android-dev`, `android-dev-workstation`, or
  something else?
* Which host checks belong in `android-dev doctor` before a container exists?
* Should generated projects include the CLI script inside `.devcontainer/`, or
  rely on the installed host/container command?
* What is the minimum supported shell and host OS matrix for the first release?
* What should the VS Code extension do in v0, and what should remain CLI-only?
