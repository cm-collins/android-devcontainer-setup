# Android Dev Container Environment

A reproducible Docker-based development environment for building Android and Kotlin Multiplatform Android applications on Windows, macOS, and Linux without installing the full Android toolchain directly on every host machine.

This project is designed to make Android development cleaner, portable, and easier to onboard by defining the development environment inside a `.devcontainer` directory.

---

## Purpose

Modern Android development requires many tools and SDKs, including Java, Gradle, Kotlin, Android SDK, Android build tools, platform tools, and emulator/device tooling.

Installing and maintaining these tools directly on every developer's machine can lead to inconsistent environments, version conflicts, and hard-to-debug setup issues.

This Dev Container setup solves that by moving most of the development environment into Docker.

The goal is simple:

> Define the Android development environment once, then allow any supported editor or terminal workflow to use the same environment consistently.

---

## What This Setup Provides

The Dev Container provides a ready-to-use Android development environment with:

* Java 17 Development Kit
* Android SDK command-line tools
* Android platform tools
* Android build tools
* Gradle support through the project wrapper
* Kotlin/Android project build support
* Jetpack Compose build support
* Kotlin Multiplatform Android target support
* ADB support for physical Android devices
* Optional access to host Android emulators
* Optional access to host USB devices
* Optional access to KVM/GPU/display resources when needed

This allows the project to be built, tested, and packaged inside a controlled Docker environment.

---

## What Problem This Solves

Without a Dev Container, every developer needs to manually install and configure:

* JDK
* Android SDK
* Android build tools
* Gradle
* Kotlin tooling
* Environment variables such as `ANDROID_HOME` and `JAVA_HOME`
* ADB/device tooling

This can cause issues such as:

* Different SDK versions across machines
* Broken builds after local upgrades
* Missing environment variables
* Gradle cache inconsistencies
* Hard onboarding for new developers
* Extra tools installed permanently on the host PC

With this setup, the host machine only needs the essentials:

* Docker
* A Dev Container-compatible editor or terminal workflow
* Optional Android Emulator or physical Android device

The Android build environment lives inside the container.

---

## Supported Workflows

This setup is intended to support the following workflows.

### 1. Build Android Apps Inside the Container

Developers can run Android builds inside the Dev Container:

```bash
./gradlew build
```

Generate a debug APK:

```bash
./gradlew assembleDebug
```

Run tests:

```bash
./gradlew test
```

Run Android lint:

```bash
./gradlew lint
```

---

### 2. Run the App on a Physical Android Device

A physical Android phone can be connected to the host machine using USB.

The container can access the device through ADB when USB access or host ADB access is configured.

Typical workflow:

```text
Android phone
   ↓ USB
Host machine
   ↓ ADB / USB forwarding
Dev Container
   ↓ Gradle install task
Installed Android app
```

Example command:

```bash
./gradlew installDebug
```

For Kotlin Multiplatform projects, the module name may be different:

```bash
./gradlew :composeApp:installDebug
```

or:

```bash
./gradlew :androidApp:installDebug
```

---

### 3. Run the App on a Host Android Emulator

The recommended emulator workflow is to run the Android Emulator on the host machine and build/install the app from inside the Dev Container.

Typical workflow:

```text
Host machine
   ├── Runs Android Emulator
   └── Provides KVM/GPU/display acceleration

Dev Container
   ├── Builds the Android app
   └── Installs the app using ADB
```

Inside the container:

```bash
adb devices
```

Then:

```bash
./gradlew installDebug
```

This approach keeps the development tools inside Docker while allowing the emulator to use the host machine's hardware acceleration.

---

## Editor Support

The setup is editor-independent in principle.

Any editor or IDE that can work with Dev Containers or a Docker-based terminal workflow can use this environment.

Examples include:

* VS Code
* Cursor
* IntelliJ IDEA with Dev Container support
* Terminal-only workflow

The editor is not the source of truth. The environment is defined by:

```text
.devcontainer/
├── Dockerfile.dev
├── android-sdk-packages.txt
├── android-sdk-packages.native.txt
├── android-sdk-packages.emulator-assets.txt
├── devcontainer.json
└── scripts/
    ├── android-dev.sh
    └── verify-android-env.sh
```

---

## Host Machine Responsibilities

The Dev Container defines the software environment, but the host machine still provides hardware and operating system capabilities.

The host may provide:

* USB access for physical Android devices
* KVM virtualization for emulator acceleration
* GPU access for emulator graphics acceleration
* Display server access for graphical tools
* Docker runtime

The container can request access to these resources, but it cannot create them if the host does not support them.

For example:

* If the host does not support KVM, the container cannot provide KVM acceleration.
* If the host has no working GPU drivers, the container cannot magically provide GPU acceleration.
* If the phone is not authorized for USB debugging, the container cannot access it through ADB.

---

## Android Support Scope

This setup is focused on Android development and Android builds.

Supported:

* Android app builds
* Kotlin Android projects
* Jetpack Compose projects
* Kotlin Multiplatform projects with Android target
* Unit tests
* Android lint
* APK generation
* Physical Android device installation
* Host emulator installation through ADB

Not the main focus:

* Running a full Android Studio GUI inside the container
* Running a heavy Android Emulator inside the container for daily development
* Replacing all host hardware-level requirements

---

## Project Positioning

This repository intentionally targets a generic Android development baseline for the widest number of Android developers.

The default image installs the tooling needed for ordinary Android and Kotlin Multiplatform Android builds, while leaving heavier or more specialized components out of the default path. That keeps the container useful across Windows, macOS, and Linux hosts instead of tailoring it too early to one developer's exact stack.

Not installed by default:

* Android Emulator packages
* System images
* Android NDK
* CMake

Those packages can be added later when a project actually needs native builds, emulator images, or other specialized workflows. Keeping the default image lean makes first-time setup faster and keeps the base environment useful across more Android projects.

---

## Cross-Platform Support

The containerized Android build environment is the same on every supported host OS. The host operating system still matters for Docker setup, USB access, and emulator acceleration.

The container intentionally uses a `linux/amd64` base image. Android's official Linux tooling does not currently support ARM-based Linux hosts, so forcing the container architecture keeps the Android SDK side on a supported Linux target even when Docker is running on an ARM-based desktop such as Apple silicon. On those hosts, Docker may use emulation for the container, while the recommended Android Emulator workflow still runs natively on the host.

| Host OS | Container workflow | Recommended emulator workflow | Device notes |
| --- | --- | --- | --- |
| Windows | Docker Desktop with the WSL 2 backend | Run the Android Emulator on the host | Windows may require OEM USB drivers for some devices |
| macOS | Docker Desktop | Run the Android Emulator on the host | No extra USB driver is usually required |
| Linux | Docker Engine or Docker Desktop | Run the Android Emulator on the host | USB access may require host udev rules and permissions |

Across all three systems:

* Build, test, lint, and package Android apps inside the container.
* Prefer running the Android Emulator on the host for better access to the host hypervisor, GPU, and display stack.
* Use physical devices through ADB when the host OS has already made the device available.

This keeps the project cross-platform without pretending that host-level hardware integration is identical on every operating system.

---

## Optional Capability Packs

The base template should stay small and broadly useful. Use a ready-made profile when one matches the project, and add extra SDK packages only when the target project needs something more specific.

| Need | Starting point |
| --- | --- |
| Ordinary Android builds | `base` profile |
| Native Android code | `native` profile |
| Emulator images managed from the container | `emulator-assets` profile |
| Older project compatibility | Add the required `platforms;android-<api>` or `build-tools;<version>` entries to the nearest matching manifest |

The package manifests are the extension point:

```text
.devcontainer/android-sdk-packages.txt
.devcontainer/android-sdk-packages.native.txt
.devcontainer/android-sdk-packages.emulator-assets.txt
```

For a reusable template, the best default is:

* essential Android build tooling in the base image
* documented optional additions for projects with special requirements
* host-run emulators as the normal workflow on every desktop OS

---

## iOS Support Scope

This setup does not replace macOS or Xcode.

For Kotlin Multiplatform projects, the shared Kotlin code can be edited and tested inside the Dev Container, but iOS builds and the iOS Simulator still require macOS and Xcode.

Supported inside this Linux-based Dev Container:

* Shared Kotlin Multiplatform code
* Android target builds
* Common module development
* Common tests where supported

Not supported on Linux Docker:

* iOS Simulator
* Xcode
* iOS signing
* Full iOS app builds

For iOS development, a Mac or remote macOS environment is required.

Possible options:

* MacBook
* Mac mini
* Remote Mac
* GitHub Actions macOS runner
* Codemagic
* Bitrise
* Xcode Cloud

---

## Expected Project Structure

The recommended project structure is:

```text
project-root/
├── .devcontainer/
│   ├── Dockerfile.dev
│   ├── android-sdk-packages.txt
│   ├── android-sdk-packages.native.txt
│   ├── android-sdk-packages.emulator-assets.txt
│   ├── devcontainer.json
│   └── scripts/
│       ├── android-dev.sh
│       └── verify-android-env.sh
├── gradlew
├── gradlew.bat
├── settings.gradle.kts
├── build.gradle.kts
├── app/
│   └── build.gradle.kts
└── README.md
```

For a Kotlin Multiplatform project, the structure may look like:

```text
project-root/
├── .devcontainer/
│   ├── Dockerfile.dev
│   ├── android-sdk-packages.txt
│   ├── android-sdk-packages.native.txt
│   ├── android-sdk-packages.emulator-assets.txt
│   ├── devcontainer.json
│   └── scripts/
│       ├── android-dev.sh
│       └── verify-android-env.sh
├── composeApp/
├── shared/
├── iosApp/
├── gradlew
├── settings.gradle.kts
└── build.gradle.kts
```

The `iosApp` module may exist in the repository, but it requires macOS/Xcode for full iOS execution.

---

## Included SDK Packages

The default `base` profile installs:

* Android SDK platform tools
* Android platform API 36
* Android build tools 36.0.0

That profile is declared in:

```text
.devcontainer/android-sdk-packages.txt
```

`platform-tools` intentionally uses the rolling stable package name, so `sdkmanager` installs the current stable release when the image is built. The Android platform and build-tools versions stay explicit so project rebuilds are easier to reason about.

When a project needs a different platform or build-tools version, update that file and rebuild the Dev Container.

---

## SDK Profiles

Three ready-made SDK profiles are included:

| Profile | Manifest | Intended use |
| --- | --- | --- |
| `base` | `.devcontainer/android-sdk-packages.txt` | ordinary Android and Kotlin Multiplatform Android builds |
| `native` | `.devcontainer/android-sdk-packages.native.txt` | projects that need NDK and CMake |
| `emulator-assets` | `.devcontainer/android-sdk-packages.emulator-assets.txt` | teams that intentionally manage emulator packages inside the image |

Choose the profile in `.devcontainer/devcontainer.json`:

```json
"args": {
  "ANDROID_SDK_PROFILE": "base"
}
```

Available values are:

```text
base
native
emulator-assets
```

After changing the profile, rebuild the Dev Container.

The `native` profile currently includes NDK `29.0.14206865` and CMake `3.31.6`. The `emulator-assets` profile currently includes the Android Emulator plus the Android 36 Google APIs x86_64 system image.

---

## Java Version

This container uses Java 17 on purpose.

Current Android Gradle Plugin releases use JDK 17 as both the minimum and default Gradle JDK, so Java 17 is the safest baseline for a reusable Android environment. Using the newest Java release is not automatically better for Android builds; it can reduce compatibility with existing projects without giving this container a meaningful benefit.

Projects that intentionally require a newer JDK can change the base image in `.devcontainer/Dockerfile.dev`, but Java 17 is the right default for the shared template.

---

## Editor Extensions

The Dev Container does not require editor extensions to build Android projects from the terminal, but the VS Code configuration installs a small useful set:

* Kotlin language support
* Java language support
* Gradle task support

These improve editing and project navigation while keeping the environment usable from other editors and terminal-only workflows.

---

## Shared Developer Commands

The project includes one IDE-neutral command entry point:

```bash
bash .devcontainer/scripts/android-dev.sh <command>
```

Available commands:

| Command | Purpose |
| --- | --- |
| `doctor` | Check Java, Android SDK, ADB, installed packages, and visible devices |
| `build` | Run the project build |
| `test` | Run unit tests |
| `lint` | Run Android lint |
| `assemble-debug` | Build a debug APK |
| `devices` | List devices visible to ADB |
| `pair-device` | Pair a phone for wireless debugging |
| `connect-device` | Connect to a paired wireless phone |
| `network-check` | Check whether the container can reach a phone IP and optional port |
| `install-debug` | Interactively choose a device and install the debug build |
| `run-debug` | Interactively choose a device, install the debug build, and launch an application ID |
| `tasks` | Show Gradle tasks for the current project |

These commands wrap the same Gradle wrapper and ADB workflows used by Android projects, so terminal users and IDE users can share one vocabulary.

---

## Workflow by Editor

### Terminal-Only

Use the Dev Container terminal as the main interface:

```bash
bash .devcontainer/scripts/android-dev.sh doctor
bash .devcontainer/scripts/android-dev.sh build
bash .devcontainer/scripts/android-dev.sh test
```

### VS Code or Cursor

Open the project in the Dev Container, use the installed Kotlin/Java/Gradle extensions for editing, and run the same shared commands from the integrated terminal.

### Android Studio or IntelliJ IDEA

Open or create the Dev Container from the JetBrains IDE, then use either the IDE UI or the shared commands from the terminal. The editor can change, but Gradle, ADB, and the containerized toolchain stay the same.

---

## Getting Started

1. Install Docker for the host operating system.
2. Open this project in a Dev Container-compatible editor.
3. Reopen the project in the container.
4. Wait for the image build to finish.
5. Confirm the environment using the automatic verification output or run:

```bash
bash .devcontainer/scripts/android-dev.sh doctor
```

After the container is ready, open or copy an Android project into the workspace and use the normal Gradle wrapper commands:

```bash
./gradlew build
./gradlew test
./gradlew assembleDebug
```

Host setup differs slightly by operating system:

* Windows: use Docker Desktop with the WSL 2 backend.
* macOS: use Docker Desktop.
* Linux: use Docker Engine or Docker Desktop.

---

## Use This in an Android Project

To reuse this setup in an existing Android repository:

1. Copy the `.devcontainer/` directory into the project root.
2. Confirm that the project uses the Gradle wrapper (`gradlew` and `gradlew.bat`).
3. Reopen the project in the Dev Container.
4. Run the health check:

```bash
bash .devcontainer/scripts/android-dev.sh doctor
```

5. Build the project with its normal Gradle tasks:

```bash
bash .devcontainer/scripts/android-dev.sh build
bash .devcontainer/scripts/android-dev.sh test
bash .devcontainer/scripts/android-dev.sh lint
```

If the project targets a different Android API level or build-tools version, update `.devcontainer/android-sdk-packages.txt` before rebuilding the container.

If you run `build`, `test`, `lint`, `assemble-debug`, `install-debug`, or `tasks` inside this template repository itself, the command will stop because the template intentionally does not include an Android app project or Gradle wrapper.

---

## Add Native Build Support

Projects with C or C++ code may need the Android NDK and CMake.

For a standard starting point, switch `ANDROID_SDK_PROFILE` from `base` to `native` in `.devcontainer/devcontainer.json`, then rebuild the Dev Container.

For reproducible native builds, prefer the NDK and CMake versions required by the project rather than a vague "latest" choice. Android Gradle Plugin can install compatible defaults automatically in some cases after licenses are accepted, but explicit versions are clearer for shared development environments.

If the project requires different native versions, edit `.devcontainer/android-sdk-packages.native.txt` before rebuilding.

---

## Physical Device Access

The container includes ADB, but a USB cable plugged into the host does not automatically make the phone visible inside the container.

For the most portable workflow across Windows, macOS, Linux, and containerized development, prefer Android wireless debugging when the device supports it.

For a focused walkthrough, see:

```text
docs/connect-android-phone.md
```

### Recommended: Wireless Debugging

1. Put the workstation and phone on the same Wi-Fi network.
2. Enable developer options and Wireless debugging on the phone.
3. Choose the pairing method that matches the workflow:

#### Android Studio QR Flow

Use this when Android Studio on the host is the tool that will manage the device connection.

1. In Android Studio, choose **Pair Devices Using Wi-Fi**.
2. On the phone, choose **Pair device with QR code**.
3. Scan the QR code shown by Android Studio.

This is convenient for Android Studio users, but it pairs the phone with the host-side Android Studio/ADB workflow. It does not automatically pair the container's own ADB server.

#### Dev Container Pairing-Code Flow

Use this when the container should manage the device connection.

1. On the phone, choose the pairing-code option and note the shown IP address, pairing port, and code.
2. From the Dev Container, run:

```bash
bash .devcontainer/scripts/android-dev.sh pair-device <ip:pairing-port>
```

3. After pairing, connect to the device endpoint shown by the phone:

```bash
bash .devcontainer/scripts/android-dev.sh connect-device <ip:connect-port>
```

4. Confirm visibility:

```bash
bash .devcontainer/scripts/android-dev.sh devices
```

If automatic discovery does not reconnect the phone after pairing, use `connect-device` again with the IP and connection port shown by the phone.

The wireless debugging connection port can change between sessions. Always use the current main port shown on the phone, and treat `devices` output as the source of truth after connection.

If pairing fails, check whether the container can reach the phone:

```bash
bash .devcontainer/scripts/android-dev.sh network-check <ip>
bash .devcontainer/scripts/android-dev.sh network-check <ip> <pairing-port>
```

`network-check` can also be useful from the host shell because it only needs network tools. Commands such as `pair-device`, `connect-device`, and `devices` require ADB, so run them inside the Dev Container unless Android platform-tools are installed on the host too.

### USB Notes by Host OS

USB remains useful, especially for older devices, but it is host-dependent.

### Windows

1. Enable USB debugging on the Android device.
2. Install the OEM USB driver when the device vendor requires one.
3. Confirm that the device is visible to host ADB.
4. Use the container-side build/install commands after the host recognizes the device.

### macOS

1. Enable USB debugging on the Android device.
2. Connect the device and approve the debugging prompt.
3. No extra USB driver is usually required.

### Linux

1. Enable USB debugging on the Android device.
2. Configure host-side `udev` rules or install the distro package that provides Android device rules.
3. Confirm that the user has permission to access the device from the host.

After host setup, verify from the container:

```bash
bash .devcontainer/scripts/android-dev.sh devices
```

Then install an app with the project task that matches the project layout:

```bash
bash .devcontainer/scripts/android-dev.sh install-debug
```

or, for some Kotlin Multiplatform projects:

```bash
./gradlew :composeApp:installDebug
```

If multiple authorized devices are available, `install-debug` asks which device to target. To install and launch a standard Android app in one step, use the package/application ID:

```bash
bash .devcontainer/scripts/android-dev.sh run-debug com.example.myapp
```

---

## Host Emulator Workflow

The recommended default is to run the Android Emulator on the host OS and use the container only for building and installing apps.

Why:

* the host has direct access to the hypervisor and GPU
* emulator acceleration is OS-specific
* keeping GUI emulation outside the container makes the base image smaller and simpler

Suggested flow:

1. Start an Android Emulator on the host machine.
2. Make sure it is visible through ADB.
3. From inside the Dev Container, run:

```bash
bash .devcontainer/scripts/android-dev.sh devices
bash .devcontainer/scripts/android-dev.sh install-debug
```

Use emulator packages inside the container only when a team has a specific reason to manage AVD assets there.

---

## Start a New Android Project

Android's official project-creation flow is still centered on Android Studio. The Dev Container is strongest once a project already exists and includes the Gradle wrapper that Android command-line builds use.

### Option 1: Create with Android Studio, Then Use the Container

1. Create the Android project in Android Studio.
2. Close the project after generation.
3. Copy this repository's `.devcontainer/` directory into the new project root.
4. Open the new project in the Dev Container.
5. From inside the container, run:

```bash
bash .devcontainer/scripts/android-dev.sh doctor
bash .devcontainer/scripts/android-dev.sh tasks
bash .devcontainer/scripts/android-dev.sh build
```

### Option 2: Start from an Existing Repository or Template

From inside the Dev Container workspace, clone the project or starter template you want to use:

```bash
git clone <repository-url> my-android-app
cd my-android-app
```

Then copy the Dev Container files into that project if they are not already present and run:

```bash
bash .devcontainer/scripts/android-dev.sh doctor
bash .devcontainer/scripts/android-dev.sh build
```

### Why There Is No Built-In `new-project` Command Yet

The Android command-line workflow officially starts from an Android project that already has its Gradle wrapper. A future version of this repository could add its own starter-template generator, but that would be a project-specific scaffold maintained here rather than an official Android CLI feature.

For a CLI-created project that feels as complete as Android Studio's Empty Activity template, this repository should eventually provide and maintain a versioned starter template containing:

* Gradle wrapper files
* Android Gradle Plugin and Kotlin setup
* app module structure
* `AndroidManifest.xml`
* a starter `MainActivity`
* resources and theme files

Until that template exists, the most reliable documented path is still to create the first project with Android Studio or start from an existing maintained template, then continue all daily work inside the Dev Container.

---

## Development Philosophy

This setup follows a simple engineering principle:

> Keep the host machine minimal and move repeatable development tooling into version-controlled infrastructure.

The `.devcontainer` directory becomes part of the codebase and acts as documentation for the required development environment.

This improves:

* Developer onboarding
* Build reproducibility
* Environment consistency
* CI alignment
* Tooling transparency
* Long-term maintainability

---

## High-Level Architecture

```text
Developer Machine
│
├── Docker
│   └── Dev Container
│       ├── JDK
│       ├── Android SDK
│       ├── Android build tools
│       ├── Gradle wrapper execution
│       ├── Kotlin/Compose build support
│       └── ADB client
│
├── Optional Android Phone
│   └── Connected through USB debugging
│
├── Optional Android Emulator
│   └── Runs on host for better KVM/GPU/display support
│
└── Optional Remote Mac
    └── Required for iOS Simulator and Xcode builds
```

---

## Typical Commands

Check Java:

```bash
java -version
```

Check Android SDK manager:

```bash
sdkmanager --list
```

Check ADB:

```bash
adb version
```

List connected devices:

```bash
adb devices
```

Build project:

```bash
./gradlew build
```

Build debug APK:

```bash
./gradlew assembleDebug
```

Install on connected device or emulator:

```bash
./gradlew installDebug
```

Run tests:

```bash
./gradlew test
```

Run lint:

```bash
./gradlew lint
```

---

## Success Criteria

This setup is successful when a developer can:

1. Clone the repository.
2. Open it in a Dev Container-compatible environment.
3. Build the Android project without installing the Android SDK manually on the host.
4. Run tests from inside the container.
5. Install the app on a connected Android phone or host emulator.
6. Reproduce the same environment across different machines.

---

## Final Goal

The final goal is to create a clean, professional, and reproducible Android development environment where the project defines its own tooling.

The host machine remains lightweight, while Docker provides the controlled environment needed to build and test Android applications.

This is especially useful for:

* Android engineers
* Kotlin Multiplatform teams
* Open-source Android projects
* CI-aligned development workflows
* Teams that want consistent local environments
* Developers who prefer not to install many SDKs directly on their machines
