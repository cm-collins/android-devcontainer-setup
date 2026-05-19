# Android Workstation CLI Plan

This plan describes the next phase of the Dev Container: turning the current helper script into a fuller Android workstation CLI for terminal-first developers, while still supporting developers who prefer Android Studio, IntelliJ, VS Code, Cursor, or a mixed workflow.

## Product Goal

Provide a guided Android development experience inside the Dev Container that feels close to Android Studio's common workflows:

* create a project from a template
* install optional SDK packages and Gradle tooling
* manage physical devices and emulators
* run, build, lint, test, and watch project changes
* keep readable logs for every meaningful operation

The tool should stay portable across Linux, macOS, and Windows hosts. The container-owned workflow should behave the same on every host. When a workflow depends on host capabilities, the CLI should detect the boundary, explain the tradeoff, and guide the developer toward the most reliable supported option.

## Guiding Principles

* Default to a working path with the fewest required arguments.
* Ask questions only when the tool cannot safely infer the answer.
* Prefer official Android SDK command-line tools over custom low-level behavior.
* Keep the base image lean, and install large optional packages only when requested.
* Make logs easy to find, tail, and share.
* Treat host emulators, physical devices, and container-managed emulators as first-class but different workflows.
* Keep advanced features opt-in so first-time setup stays fast.
* Use deterministic workflows: every generated file, installed package, and command decision must come from explicit inputs, validated defaults, or a documented project metadata file.
* Separate portable container behavior from host-specific behavior so macOS, Windows, and Linux users get the same core experience with clear host-specific guidance.

## Deterministic Workflow Standard

This feature must avoid trial-and-error behavior. The CLI should never guess by running a series of commands and hoping one succeeds. Instead, it should follow a deterministic pattern for every workflow.

### Required Pattern

1. Discover current state.
2. Validate required tools, files, SDK packages, devices, and project metadata.
3. Present choices only from known valid options.
4. Preview planned actions before making changes.
5. Execute the exact mapped command or file operation.
6. Stream output to the terminal and write the same output to a log file.
7. Verify the expected result.
8. Print the next useful command.

### Deterministic Inputs

The CLI should rely on these sources, in this order:

1. explicit command arguments
2. project metadata in `.android-dev/project.json`
3. Gradle files for known Android properties such as `applicationId`
4. installed SDK package lists from `sdkmanager`
5. available AVD/device lists from `avdmanager`, `emulator`, and `adb`
6. interactive user selection from validated options

If the tool cannot determine a value from those sources, it should stop with a clear message instead of trying unrelated fallbacks.

### Command Mapping

Every high-level workflow should map to a known lower-level command.

| Workflow | Deterministic source | Lower-level command |
| --- | --- | --- |
| Build app | selected project root | `./gradlew build` |
| Install debug app | selected device and project root | `./gradlew installDebug` with `ANDROID_SERIAL` |
| Launch app | detected or selected application ID | `adb shell monkey -p <application-id> 1` |
| Install SDK packages | selected package IDs | `sdkmanager --install <packages>` |
| Create AVD | selected device, package, name | `avdmanager create avd` |
| Start emulator | selected AVD name | `emulator @<name>` |
| List emulators | Android SDK state | `emulator -list-avds` and `adb devices` |

### Project Metadata

Generated projects should include a metadata file:

```text
.android-dev/project.json
```

Suggested fields:

```json
{
  "schemaVersion": 1,
  "projectName": "Collins Android",
  "template": "basic-activity",
  "applicationId": "com.example.collinsandroid",
  "mainModule": "app",
  "runnable": true,
  "createdBy": "android-devcontainer"
}
```

This metadata should make future commands predictable. For example, `run-debug` should prefer `applicationId` from this file, then fall back to Gradle parsing only when metadata is absent.

### No Trial-And-Error Rules

The CLI must not:

* try multiple Gradle tasks until one works
* install broad SDK package groups without showing exact package IDs
* silently change Gradle files without a preview
* choose a random AVD, device, package, or module when there are multiple choices
* continue after a required validation fails
* hide command output unless it is also written to a log

### Phase Gate

Before each phase is considered complete, it must include:

* deterministic input sources
* validation checks
* exact command mappings
* structured errors and warnings
* log file coverage
* success verification
* failure messages with the next suggested command

## Error and Warning Experience

Error handling is a core feature of the workstation CLI. It must be designed before broad testing starts, because clear failures are part of the developer experience.

The CLI should never leave developers guessing whether the problem is their project, the container, the Android SDK, Gradle, ADB, the host OS, or a connected device. Every warning or error should identify the failing area and point to the next useful action.

### Severity Levels

| Level | Meaning | Behavior |
| --- | --- | --- |
| `info` | Normal progress or detected state | Print concise status and continue |
| `warning` | Something may affect the workflow, but the command can continue | Print warning, log it, and continue |
| `error` | The command cannot safely continue | Print error, log it, suggest a fix, and exit non-zero |
| `fatal` | The environment is inconsistent or a required tool is unavailable | Print high-signal failure, log diagnostics, and exit non-zero |

### Message Format

Every error should follow the same shape:

```text
ERROR [ANDROID-DEVICE-001]
Area: Android device connection
Problem: No authorized Android devices are visible to this container.
Why it matters: The app cannot be installed without a connected device or emulator.
Next step: Run `bash .devcontainer/scripts/android-dev.sh devices` and follow the pairing guidance.
Log: .android-dev/logs/run-debug-20260519-101500.log
```

Warnings should be shorter but still actionable:

```text
WARNING [ANDROID-EMU-002]
Container-managed emulator support is not enabled in this SDK profile.
Next step: Rebuild the Dev Container with `ANDROID_SDK_PROFILE=emulator-assets`, or use a host emulator.
```

### Error Areas

Use stable error code prefixes so users can search docs and issues:

| Prefix | Area |
| --- | --- |
| `ANDROID-PROJECT` | project discovery, metadata, templates, Gradle wrapper |
| `ANDROID-GRADLE` | build, test, lint, Gradle sync checks |
| `ANDROID-SDK` | SDK manager, package installation, missing tools |
| `ANDROID-DEVICE` | ADB, physical phones, wireless pairing, USB visibility |
| `ANDROID-EMU` | emulator binary, AVDs, system images, runtime support |
| `ANDROID-HOST` | host OS capabilities, Docker runtime, USB, KVM/GPU |
| `ANDROID-CONFIG` | invalid CLI input, unsupported options, malformed metadata |
| `ANDROID-LOG` | log creation, permissions, log discovery |

### Error Handling Requirements

* All command failures should exit with a non-zero code.
* Every major command should create or attach to a log file before doing meaningful work.
* Errors must include area, problem, why it matters, next step, and log path.
* Warnings must include area, warning, and next step when action is useful.
* Commands must validate prerequisites before making changes.
* Commands must not hide raw tool output; raw output belongs in the log even when the terminal prints a cleaner summary.
* Repeated known failures should map to known messages instead of dumping confusing raw output only.
* Unknown failures should still include command, exit code, log path, and a next diagnostic command.

### Warning Examples

| Scenario | Warning |
| --- | --- |
| Host emulator is visible but no physical phone is connected | Continue and tell the user which emulator will be used |
| Wireless phone is paired but offline | Suggest reconnecting with the current phone connection port |
| Multiple devices are visible | Prompt for selection instead of guessing |
| Emulator packages are missing | Offer exact packages to install |
| Running from template root with multiple child projects | Prompt for project selection |
| `run-debug` finds no runnable application ID | Explain whether the project is `no-activity`, library-only, or missing metadata |

### Error Examples

| Scenario | Error |
| --- | --- |
| Missing `./gradlew` in selected project | `ANDROID-PROJECT-001` with project-root guidance |
| Invalid application ID | `ANDROID-CONFIG-001` with expected reverse-domain format |
| `adb` unavailable | `ANDROID-DEVICE-001` with Dev Container/platform-tools guidance |
| No authorized devices | `ANDROID-DEVICE-002` with wireless pairing guidance |
| Missing SDK package | `ANDROID-SDK-001` with exact `sdkmanager --install` package ID |
| Emulator runtime unsupported | `ANDROID-HOST-001` with host-emulator alternative |
| Build failed | `ANDROID-GRADLE-001` with log path and failing Gradle task |

### Implementation Stages Before Broad Testing

These stages must be completed before testing the larger template, plugin, and emulator features end to end.

1. **Create shared output helpers**
   * `info`, `warn`, `error`, and `fatal` helper functions.
   * Consistent formatting for all messages.
   * Stable error code support.

2. **Create shared logging helpers**
   * Create `.android-dev/logs/` automatically.
   * Generate timestamped log files per command.
   * Stream command output to terminal and log.
   * Print the active log path at command start and on failure.

3. **Create command execution wrapper**
   * Wrap Gradle, ADB, SDK manager, AVD manager, and emulator commands.
   * Capture command, exit code, duration, and log output.
   * Convert known failures into friendly messages while preserving raw output in logs.

4. **Create validation layer**
   * Validate project root, Gradle wrapper, SDK tools, SDK packages, metadata, devices, and emulator prerequisites before execution.
   * Stop early when required state is missing.
   * Avoid corrective action unless the user confirms it.

5. **Create warning registry**
   * Define known warnings and their next steps.
   * Ensure warnings are visible in the terminal and logs.
   * Ensure warnings do not silently become ignored noise.

6. **Add trap-based failure handling**
   * Catch unexpected shell failures.
   * Print the failing command, exit code, and log path.
   * Keep the raw failure details in the log.

7. **Document troubleshooting by error code**
   * Add a docs page or README section for common error codes.
   * Link each error to the most useful next command.

8. **Only then start broad workflow testing**
   * Test project creation templates.
   * Test plugin/package installation.
   * Test phone pairing and reconnect.
   * Test host emulator flow.
   * Test container emulator flow where supported.
   * Test failure cases intentionally, not only happy paths.

## Cross-Operating-System Contract

The goal is not to make every low-level Android workflow identical on every host. Some parts of Android development, especially USB access and emulator acceleration, are controlled by the host operating system. The goal is to make the CLI deterministic about those differences.

### Portable Core

These workflows should behave the same inside the Dev Container on Linux, macOS, and Windows:

| Workflow | Expected portability |
| --- | --- |
| Project creation | Same prompts, same generated files, same metadata |
| Gradle build/test/lint | Same commands through the project Gradle wrapper |
| Gradle file watching | Same behavior inside the container |
| Wireless phone pairing | Same ADB commands when the phone is reachable over the network |
| SDK package installation | Same package IDs through `sdkmanager` |
| Logs | Same log directory and naming convention |

### Host-Specific Boundaries

These workflows require explicit host capability checks:

| Workflow | Host dependency | Required behavior |
| --- | --- | --- |
| USB debugging | host USB forwarding, drivers, and permissions | explain host setup and recommend wireless debugging when unavailable |
| Host emulator | host Android Studio or emulator installation | detect through `adb devices`; do not assume the host emulator exists |
| Container-managed emulator | KVM, graphics, Docker runtime flags, SDK profile | validate before offering start/create actions |
| File opening/reopen in container | editor-specific commands | document the action; avoid pretending there is one universal command |

### OS Support Matrix

| Host OS | Supported default path | Advanced path |
| --- | --- | --- |
| Windows | Dev Container builds plus wireless phone or host emulator through ADB | USB after driver/setup; container emulator only if runtime supports it |
| macOS | Dev Container builds plus wireless phone or host emulator through ADB | USB after host authorization; container emulator is not the recommended default |
| Linux | Dev Container builds plus wireless phone or host emulator through ADB | USB with udev rules; container emulator when KVM/GPU/runtime checks pass |

### Deterministic OS Rules

* The CLI should not infer host OS from vague failures. It should use explicit checks where possible.
* A command should say whether it is running a portable container workflow or a host-dependent workflow.
* If a host-dependent requirement is missing, the command should stop with a clear message and a recommended portable alternative.
* Emulator creation should be offered only after confirming the emulator binary, selected system image, and runtime prerequisites.
* Device selection must come from `adb devices`, not from cached assumptions.
* The same command should produce the same generated files for the same inputs on every host.

## Proposed CLI Surface

```bash
bash .devcontainer/scripts/android-dev.sh init
bash .devcontainer/scripts/android-dev.sh templates
bash .devcontainer/scripts/android-dev.sh plugins
bash .devcontainer/scripts/android-dev.sh sdk
bash .devcontainer/scripts/android-dev.sh emulators
bash .devcontainer/scripts/android-dev.sh emulator-create
bash .devcontainer/scripts/android-dev.sh emulator-start
bash .devcontainer/scripts/android-dev.sh emulator-stop
bash .devcontainer/scripts/android-dev.sh logs
```

Existing commands such as `doctor`, `devices`, `run-debug`, `watch-gradle`, `pair-device`, and `connect-device` should remain stable.

## Foundation: CLI Separation and Workspace Model

Before adding more Android Studio-like workflows, the CLI should keep one stable public entry point while separating implementation details into focused modules.

### Internal Structure

```text
.devcontainer/scripts/
├── android-dev.sh
└── lib/
    ├── core.sh
    ├── devices.sh
    ├── editor.sh
    ├── gradle.sh
    ├── network.sh
    ├── projects.sh
    ├── validation.sh
    └── watch.sh
```

### Design Rules

* `android-dev.sh` should stay a thin command router.
* Logging, structured errors, validation, project creation, Gradle execution, device handling, network checks, and file watching should each live in focused modules.
* Shared behavior should be reused through helper functions instead of duplicated command branches.
* Public commands should remain stable even when internal files move.
* Commands should auto-detect the active generated project where that is deterministic.
* Editor indexing should be supported through generated workspace metadata instead of requiring a second Dev Container by default.
* Editor-only diagnostics that conflict with successful Gradle Android builds should be handled explicitly, with Gradle build/test/lint remaining the source of truth.

### Workspace Model

Generated projects should live inside the current Android workstation by default:

```text
android-devcontainer/
├── .devcontainer/
├── docs/
└── my-android-app/
    ├── app/
    ├── gradlew
    └── settings.gradle.kts
```

This avoids forcing developers to rebuild a second Dev Container immediately after creating a project.

Standalone project export should be explicit:

```bash
bash .devcontainer/scripts/android-dev.sh export-devcontainer my-android-app
```

Editor workspace sync should also be explicit and repeatable:

```bash
bash .devcontainer/scripts/android-dev.sh sync-workspace
```

`new-app` and `init` should run workspace sync automatically after a successful first build.

### Acceptance Criteria

* The public CLI entry point remains `bash .devcontainer/scripts/android-dev.sh <command>`.
* The entry point sources focused modules from `.devcontainer/scripts/lib/`.
* `new-app` and `init` create generated projects without copying `.devcontainer/` by default.
* Generated projects build automatically after creation.
* `build`, `test`, `lint`, `assemble-debug`, `install-debug`, `run-debug`, and `tasks` can run from the workstation root when exactly one generated child project exists.
* If multiple child projects exist, the CLI prompts for a project selection instead of guessing.
* `sync-workspace` generates `android-devcontainer.code-workspace` with the workstation root and detected generated Gradle projects.
* The generated workspace disables noisy Kotlin language-server diagnostics when they conflict with Android Gradle Plugin 9 built-in Kotlin projects.
* The generated workspace file is ignored by Git because it reflects local project choices.
* `export-devcontainer <directory>` copies the workstation `.devcontainer/` into a project only when requested.

## Phase 1: Project Templates

Upgrade `init` from a single starter scaffold into a project wizard.

### Templates

Initial templates:

| Template | Purpose |
| --- | --- |
| `basic-activity` | Current Kotlin `MainActivity` starter |
| `empty-activity` | Minimal Android app with an empty launch activity |
| `no-activity` | App module with manifest and resources, but no launch activity |
| `compose-activity` | Jetpack Compose starter with a Compose `MainActivity` |
| `android-library` | Android library module starter |

Later templates:

| Template | Purpose |
| --- | --- |
| `kmp-app` | Kotlin Multiplatform app starter |
| `wear-app` | Wear OS starter |
| `tv-app` | Android TV starter |
| `native-app` | Android app with NDK/CMake enabled |

### Expected Flow

```text
Project name: Collins Android
Package name [com.example.collinsandroid]:
Template:
  1. Basic Activity
  2. Empty Activity
  3. No Activity
  4. Compose Activity
  5. Android Library
Create and build this project? [Y/n]
```

### Acceptance Criteria

* `init` supports template selection.
* `new-app` accepts a `--template` option for non-interactive use.
* Every template creates a valid Gradle project.
* Every app template runs a first build automatically.
* `run-debug` works without an application ID for runnable app templates.
* `no-activity` and `android-library` explain why `run-debug` does not apply.

## Phase 2: Centralized Logging

Create one logging convention for all workflow commands.

### Log Directory

```text
.android-dev/logs/
```

### Log Files

```text
create-project-YYYYMMDD-HHMMSS.log
build-YYYYMMDD-HHMMSS.log
run-debug-YYYYMMDD-HHMMSS.log
watch-gradle-YYYYMMDD-HHMMSS.log
plugins-YYYYMMDD-HHMMSS.log
sdk-YYYYMMDD-HHMMSS.log
emulator-YYYYMMDD-HHMMSS.log
doctor-YYYYMMDD-HHMMSS.log
```

### Commands

```bash
bash .devcontainer/scripts/android-dev.sh logs
bash .devcontainer/scripts/android-dev.sh logs latest
bash .devcontainer/scripts/android-dev.sh logs tail
```

### Acceptance Criteria

* Long-running commands stream output to the terminal and write the same output to a log file.
* Failures print the log path before exiting.
* `logs latest` prints the most recent log path and summary.
* `logs tail` follows the most recent log.

## Phase 3: Optional Plugin and Package Installer

Add an interactive installer for common Android development packs.

### Categories

| Category | Examples |
| --- | --- |
| Android SDK packages | platforms, build-tools, NDK, CMake, emulator, system images |
| Gradle plugins | Compose, Kotlin serialization, KSP, Room, Hilt, Detekt, ktlint |
| Editor recommendations | VS Code/Cursor extensions through `devcontainer.json` |

### Expected Flow

```text
Choose optional packs:
  1. Compose app tooling
  2. Native development: NDK + CMake
  3. Emulator assets
  4. Quality tools: ktlint + Detekt
  5. Persistence: Room + KSP
```

### Design Notes

* SDK packages should be installed with `sdkmanager`.
* Gradle plugin changes should modify project Gradle files only after confirmation.
* Editor extensions should be recommendations, not hard requirements.
* Each installation should be logged.

### Acceptance Criteria

* The CLI can list available packs.
* The CLI can install selected SDK packages.
* The CLI can update generated projects with selected Gradle plugins.
* The CLI shows exactly which files and packages will change before applying changes.

## Phase 4: Emulator Manager

Add an Android Studio-like terminal flow for AVD discovery, creation, and startup.

### Commands

```bash
bash .devcontainer/scripts/android-dev.sh emulators
bash .devcontainer/scripts/android-dev.sh emulator-create
bash .devcontainer/scripts/android-dev.sh emulator-start
bash .devcontainer/scripts/android-dev.sh emulator-stop
```

### Supported Workflows

| Workflow | Default Recommendation |
| --- | --- |
| Physical phone | Best portable workflow |
| Host emulator | Recommended for macOS, Windows, and many Linux desktops |
| Container-managed emulator | Advanced workflow for Linux or controlled CI/dev environments |

### Creation Flow

```text
AVD name [Pixel_8_API_36]:
Device profile:
  1. Pixel 8
  2. Pixel 8 Pro
  3. Pixel Tablet
Android API:
  1. API 36
  2. API 35
System image:
  1. Google APIs
  2. Google Play
  3. AOSP
Architecture:
  1. x86_64
  2. arm64-v8a
Download missing packages? [Y/n]
Create AVD? [Y/n]
Start now? [Y/n]
```

### Design Notes

* Use `avdmanager` for creating and listing AVDs.
* Use `emulator -list-avds` and `emulator @name` for startup.
* Detect whether the emulator binary and selected system image are installed.
* Explain host limitations clearly, especially around graphics and virtualization.
* Prefer host emulators by default when container-managed emulation is unlikely to be smooth.

### Acceptance Criteria

* The CLI can list existing AVDs.
* The CLI can detect running emulators through `adb devices`.
* The CLI can start an existing AVD and log emulator output.
* The CLI can create an AVD after interactively selecting device, API, image type, and architecture.
* If required packages are missing, the CLI can offer to install them.
* If emulator support is not available in the current container profile, the CLI explains how to rebuild with the `emulator-assets` SDK profile.

## Phase 5: Developer Experience Polish

Add the small details that make the tool feel reliable and pleasant.

### Ideas

* `doctor --fix` for safe automated checks.
* `run` alias for `run-debug`.
* `open-logs` or `logs latest` convenience.
* Better command suggestions for typos.
* Persistent project metadata in `.android-dev/project.json`.
* A `summary` command that prints project, SDK, device, and last build status.
* Faster repeated builds by recommending Gradle configuration cache when safe.

### Acceptance Criteria

* New developers can create, build, connect a device, and run an app without reading the whole README.
* Terminal-only users get a complete workflow.
* IDE users can still use Android Studio or IntelliJ without fighting the container.
* Every major failure includes the next suggested command.

## Risks and Constraints

| Risk | Mitigation |
| --- | --- |
| Emulator acceleration differs by host OS | Keep host emulator as the recommended default |
| Container images become too large | Keep emulator/NDK/CMake in opt-in profiles |
| Gradle plugin edits can break existing apps | Preview file changes and require confirmation |
| Android templates change over time | Own a small set of stable templates and document their scope |
| Multiple app modules create ambiguity | Prompt for project/module/application ID only when needed |

## Suggested Implementation Order

1. Add centralized logging helpers.
2. Refactor project generation into template functions or template files.
3. Add `templates` and upgrade `init` with template selection.
4. Add `--template` support to `new-app`.
5. Add SDK/plugin pack installer.
6. Add emulator list/start support.
7. Add emulator creation support.
8. Add final README and docs updates.

## Definition of Done

This feature is ready when a developer can:

1. Open the Dev Container.
2. Run one guided command to create a project from a chosen template.
3. See the first build happen automatically with logs.
4. Connect a phone or start an emulator from the CLI.
5. Run the app without manually passing the application ID.
6. Inspect logs when something fails.
7. Add optional SDK packages or Gradle tooling through guided commands.
