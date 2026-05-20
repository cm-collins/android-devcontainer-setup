# Troubleshooting Errors and Logs

The Android workstation CLI prints structured warnings and errors so developers
can identify the failing area quickly.

## Log Commands

List command logs:

```bash
bash .devcontainer/scripts/android-dev.sh logs
```

Print the latest log path:

```bash
bash .devcontainer/scripts/android-dev.sh logs latest
```

Tail the latest log:

```bash
bash .devcontainer/scripts/android-dev.sh logs tail
```

Logs are written under:

```text
.android-dev/logs/
```

## Error Format

Errors follow this shape:

```text
ERROR [ANDROID-DEVICE-002]
Area: Android device selection
Problem: No authorized Android devices are available.
Why it matters: The app cannot be installed without a connected physical device or emulator.
Next step: Run 'bash .devcontainer/scripts/android-dev.sh devices' for pairing guidance.
Log: /workspace/.android-dev/logs/run-debug-20260519-101500.log
```

## Error Areas

| Prefix | Area |
| --- | --- |
| `ANDROID-PROJECT` | project discovery, Gradle wrapper, app metadata |
| `ANDROID-GRADLE` | Gradle wrapper generation, build, test, lint, install |
| `ANDROID-SDK` | SDK tools and helper binaries |
| `ANDROID-DEVICE` | ADB, phones, pairing, connection, launch |
| `ANDROID-CONFIG` | command usage, invalid input, ambiguous selection |
| `ANDROID-LOG` | log directory creation and log discovery |

## Common Errors

| Code | Meaning | Next step |
| --- | --- | --- |
| `ANDROID-PROJECT-001` | Missing executable `./gradlew` | Run from a generated Android project or use `project <directory> <command>` |
| `ANDROID-PROJECT-002` | Application ID could not be detected | Pass the application ID explicitly to `run-debug` |
| `ANDROID-PROJECT-003` | Multiple application IDs were found | Choose the application ID explicitly |
| `ANDROID-PROJECT-004` | Target project directory is not empty | Pick a new directory or clean it manually |
| `ANDROID-PROJECT-009` | Project metadata marks the template as non-runnable | Use build, test, or lint instead of `run-debug`, or create a runnable app template |
| `ANDROID-DEVICE-001` | ADB is not available | Run inside the Dev Container or install platform-tools on the host |
| `ANDROID-DEVICE-002` | No authorized device is visible | Run `devices` and follow wireless pairing guidance |
| `ANDROID-DEVICE-004` | Phone TCP port is unreachable | Check Wi-Fi, phone port, and wireless debugging state |
| `ANDROID-GRADLE-001` | Gradle command failed | Read the log and fix the Gradle-reported project issue |
| `ANDROID-GRADLE-002` | Gradle distribution download failed | Check network access to `services.gradle.org` |
| `ANDROID-CONFIG-001` | Invalid application ID | Use a lowercase reverse-domain ID such as `com.example.myapp` |
| `ANDROID-CONFIG-017` | Unknown project template | Run `templates` and choose one of the listed template names |

## Deterministic Failure Rule

When the CLI cannot determine a safe value from explicit arguments, project
metadata, Gradle files, SDK package lists, AVD/device lists, or validated user
selection, it stops with a structured error instead of guessing.
