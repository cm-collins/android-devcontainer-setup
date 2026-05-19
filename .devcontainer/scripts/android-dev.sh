#!/usr/bin/env bash
set -euo pipefail

LOG_FILE=""
HANDLED_FAILURE=0

usage() {
  cat <<'EOF'
Usage: bash .devcontainer/scripts/android-dev.sh <command>

Commands:
  doctor         Check Java, Android SDK, ADB, installed packages, and visible devices
  build          Run ./gradlew build
  test           Run ./gradlew test
  lint           Run ./gradlew lint
  assemble-debug Run ./gradlew assembleDebug
  devices        List devices visible to ADB
  pair-device    Pair a wireless device: pair-device <ip:port>
  connect-device Connect to a paired wireless device: connect-device <ip:port>
  network-check  Check phone reachability: network-check <ip> [port]
  init           Interactively create and build a new Android app
  new-app        Create a basic Android app: new-app <directory> <application-id> [app-name]
  project        Run a command in a project: project <directory> <command> [args...]
  watch-gradle   Watch Gradle files and offer sync checks: watch-gradle [--auto]
  logs           Show command logs: logs [latest|tail]
  install-debug  Interactively choose a device and run ./gradlew installDebug
  run-debug      Install and launch the app: run-debug [application-id]
  tasks          Show Gradle tasks available in the current project
EOF
}

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log_slug() {
  printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

init_log() {
  local command_name="$1"
  local log_dir
  local log_name

  log_dir="$(pwd)/.android-dev/logs"
  mkdir -p "${log_dir}" || {
    echo "FATAL [ANDROID-LOG-001]" >&2
    echo "Area: Command logging" >&2
    echo "Problem: Could not create ${log_dir}." >&2
    echo "Why it matters: Command output cannot be captured for troubleshooting." >&2
    echo "Next step: Check directory permissions for the current workspace." >&2
    exit 1
  }

  log_name="$(log_slug "${command_name}")"
  LOG_FILE="${log_dir}/${log_name}-$(date '+%Y%m%d-%H%M%S').log"
  {
    echo "Command: bash .devcontainer/scripts/android-dev.sh ${command_name}"
    echo "Started: $(timestamp)"
    echo "Working directory: $(pwd)"
    echo
  } >"${LOG_FILE}"
  echo "Log: ${LOG_FILE}"
}

log_to_file() {
  if [[ -n "${LOG_FILE}" ]]; then
    printf '%s\n' "$*" >>"${LOG_FILE}"
  fi
}

info() {
  printf '%s\n' "$*"
  log_to_file "INFO $(timestamp) $*"
}

warn() {
  local code="$1"
  local message="$2"
  local next_step="${3:-}"

  {
    echo "WARNING [${code}]"
    echo "${message}"
    if [[ -n "${next_step}" ]]; then
      echo "Next step: ${next_step}"
    fi
  } >&2
  log_to_file "WARNING [${code}] ${message}"
  if [[ -n "${next_step}" ]]; then
    log_to_file "Next step: ${next_step}"
  fi
}

fatal() {
  local code="$1"
  local area="$2"
  local problem="$3"
  local why="$4"
  local next_step="$5"
  local exit_code="${6:-1}"

  HANDLED_FAILURE=1
  {
    echo "ERROR [${code}]"
    echo "Area: ${area}"
    echo "Problem: ${problem}"
    echo "Why it matters: ${why}"
    echo "Next step: ${next_step}"
    if [[ -n "${LOG_FILE}" ]]; then
      echo "Log: ${LOG_FILE}"
    fi
  } >&2
  log_to_file "ERROR [${code}]"
  log_to_file "Area: ${area}"
  log_to_file "Problem: ${problem}"
  log_to_file "Why it matters: ${why}"
  log_to_file "Next step: ${next_step}"
  exit "${exit_code}"
}

handle_unexpected_error() {
  local exit_code="$1"
  local command_text="$2"
  local line_number="$3"

  if [[ "${HANDLED_FAILURE}" == "1" ]]; then
    return
  fi

  {
    echo "FATAL [ANDROID-CONFIG-999]"
    echo "Area: Unexpected CLI failure"
    echo "Problem: Command failed at line ${line_number}: ${command_text}"
    echo "Why it matters: The CLI stopped before it could finish the requested workflow."
    echo "Next step: Review the log, then run 'bash .devcontainer/scripts/android-dev.sh doctor'."
    if [[ -n "${LOG_FILE}" ]]; then
      echo "Log: ${LOG_FILE}"
    fi
  } >&2
  log_to_file "FATAL [ANDROID-CONFIG-999] line ${line_number}: ${command_text} exited ${exit_code}"
  exit "${exit_code}"
}

run_logged() {
  local label="$1"
  shift

  info "Running ${label}..."
  log_to_file "\$ $*"
  set +e
  "$@" 2>&1 | tee -a "${LOG_FILE:-/dev/null}"
  local status
  status="${PIPESTATUS[0]}"
  set -e

  if [[ "${status}" -ne 0 ]]; then
    log_to_file "Command failed with exit code ${status}: $*"
  fi
  return "${status}"
}

require_gradle_wrapper() {
  if [[ ! -x ./gradlew ]]; then
    fatal \
      "ANDROID-PROJECT-001" \
      "Android project discovery" \
      "Missing executable Gradle wrapper at ./gradlew." \
      "Project commands must run from an Android project root that includes the Gradle wrapper." \
      "Run this command inside a generated Android project, or use 'bash .devcontainer/scripts/android-dev.sh project <directory> <command>'."
  fi
}

require_adb() {
  if ! command -v adb >/dev/null 2>&1; then
    fatal \
      "ANDROID-DEVICE-001" \
      "Android device tooling" \
      "ADB is not available in the current shell." \
      "Device and emulator commands require Android platform-tools." \
      "Run this command inside the Dev Container, or install Android platform-tools on the host."
  fi
}

run_gradle() {
  require_gradle_wrapper
  if ! run_logged "Gradle: ./gradlew $*" ./gradlew "$@"; then
    fatal \
      "ANDROID-GRADLE-001" \
      "Gradle execution" \
      "Gradle command failed: ./gradlew $*" \
      "The requested build, test, lint, install, or sync workflow did not complete." \
      "Review the Gradle output in the log and fix the reported project error."
  fi
}

latest_log_file() {
  if [[ ! -d .android-dev/logs ]]; then
    return 0
  fi
  find .android-dev/logs -maxdepth 1 -type f -name '*.log' -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | sed -n 's/^[^ ]* //p; q'
}

logs_command() {
  local mode="${2:-list}"
  local latest

  case "${mode}" in
    list)
      if [[ ! -d .android-dev/logs ]]; then
        warn \
          "ANDROID-LOG-002" \
          "No log directory exists yet." \
          "Run any major command such as doctor, build, devices, or run-debug to create logs."
        return
      fi
      find .android-dev/logs -maxdepth 1 -type f -name '*.log' | sort
      ;;
    latest)
      latest="$(latest_log_file)"
      if [[ -z "${latest}" ]]; then
        warn \
          "ANDROID-LOG-003" \
          "No command logs were found." \
          "Run a command such as doctor, build, devices, or run-debug first."
        return
      fi
      printf '%s\n' "${latest}"
      ;;
    tail)
      latest="$(latest_log_file)"
      if [[ -z "${latest}" ]]; then
        warn \
          "ANDROID-LOG-003" \
          "No command logs were found." \
          "Run a command such as doctor, build, devices, or run-debug first."
        return
      fi
      echo "Tailing ${latest}. Press Ctrl-C to stop."
      tail -f "${latest}"
      ;;
    *)
      fatal \
        "ANDROID-CONFIG-015" \
        "Command usage" \
        "Invalid logs option: ${mode}" \
        "The logs command supports list, latest, and tail." \
        "Run: bash .devcontainer/scripts/android-dev.sh logs [latest|tail]"
      ;;
  esac
}

detect_application_id() {
  local explicit_application_id="${1:-}"
  local candidate_files=()
  local application_ids=()
  local file
  local detected_id

  if [[ -n "${explicit_application_id}" ]]; then
    require_valid_application_id "${explicit_application_id}"
    printf '%s\n' "${explicit_application_id}"
    return
  fi

  if [[ -f app/build.gradle.kts ]]; then
    candidate_files+=(app/build.gradle.kts)
  fi
  if [[ -f app/build.gradle ]]; then
    candidate_files+=(app/build.gradle)
  fi

  while IFS= read -r file; do
    case "${file}" in
      ./app/build.gradle.kts|./app/build.gradle)
        ;;
      *)
        candidate_files+=("${file#./}")
        ;;
    esac
  done < <(
    find . \
      -path './.gradle' -prune -o \
      -path './.git' -prune -o \
      \( -name 'build.gradle.kts' -o -name 'build.gradle' \) \
      -print
  )

  for file in "${candidate_files[@]}"; do
    while IFS= read -r detected_id; do
      if is_valid_application_id "${detected_id}"; then
        application_ids+=("${detected_id}")
      fi
    done < <(
      sed -nE \
        's/^[[:space:]]*applicationId[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p;
         s/^[[:space:]]*applicationId[[:space:]]+"([^"]+)".*/\1/p' \
        "${file}"
    )
  done

  if [[ "${#application_ids[@]}" -eq 0 ]]; then
    fatal \
      "ANDROID-PROJECT-002" \
      "Android application discovery" \
      "Could not detect an application ID from Gradle files." \
      "The app cannot be launched without a known application ID." \
      "Run 'bash .devcontainer/scripts/android-dev.sh run-debug <application-id>', or add project metadata in .android-dev/project.json later when that workflow exists."
  fi

  mapfile -t application_ids < <(printf '%s\n' "${application_ids[@]}" | sort -u)
  if [[ "${#application_ids[@]}" -gt 1 ]]; then
    echo "Multiple application IDs were found:" >&2
    printf '  %s\n' "${application_ids[@]}" >&2
    fatal \
      "ANDROID-PROJECT-003" \
      "Android application discovery" \
      "Multiple application IDs were found." \
      "The CLI will not guess which app should be launched." \
      "Run 'bash .devcontainer/scripts/android-dev.sh run-debug <application-id>' with the application ID you want."
  fi

  printf '%s\n' "${application_ids[0]}"
}

child_project_roots() {
  local gradle_wrapper

  while IFS= read -r gradle_wrapper; do
    if [[ -x "${gradle_wrapper}" ]]; then
      dirname "${gradle_wrapper#./}"
    fi
  done < <(find . -mindepth 2 -maxdepth 2 -name gradlew -type f -print)
}

select_project_root() {
  local projects=()
  local choice

  mapfile -t projects < <(child_project_roots)

  case "${#projects[@]}" in
    0)
      require_gradle_wrapper
      ;;
    1)
      printf '%s\n' "${projects[0]}"
      ;;
    *)
      echo "Select a project:" >&2
      local index
      for index in "${!projects[@]}"; do
        printf '  %s) %s\n' "$((index + 1))" "${projects[$index]}" >&2
      done
      read -r -p "Project number: " choice
      if [[ ! "${choice}" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#projects[@]} )); then
        fatal \
          "ANDROID-CONFIG-002" \
          "Project selection" \
          "Invalid project selection: ${choice}" \
          "The CLI can only run a command in one of the listed project directories." \
          "Run the command again and choose one of the displayed project numbers."
      fi
      printf '%s\n' "${projects[$((choice - 1))]}"
      ;;
  esac
}

to_package_path() {
  printf '%s\n' "${1//./\/}"
}

is_valid_application_id() {
  local application_id="$1"
  [[ "${application_id}" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]]
}

require_valid_application_id() {
  local application_id="$1"
  if ! is_valid_application_id "${application_id}"; then
    fatal \
      "ANDROID-CONFIG-001" \
      "Application ID validation" \
      "Invalid application ID: ${application_id}" \
      "Android application IDs must be stable, valid package-style identifiers." \
      "Use a lowercase reverse-domain ID such as com.example.myapp."
  fi
}

is_valid_app_name() {
  local app_name="$1"
  [[ "${app_name}" =~ ^[A-Za-z][A-Za-z0-9[:space:]_-]*$ ]]
}

require_valid_app_name() {
  local app_name="$1"
  if ! is_valid_app_name "${app_name}"; then
    fatal \
      "ANDROID-CONFIG-003" \
      "App name validation" \
      "Invalid app name: ${app_name}" \
      "The generated project needs a valid display name and Gradle project name." \
      "Use letters, numbers, spaces, underscores, or hyphens, starting with a letter."
  fi
}

slugify() {
  printf '%s\n' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

to_application_segment() {
  local segment
  segment="$(printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+//g')"
  if [[ ! "${segment}" =~ ^[a-z] ]]; then
    segment="app${segment}"
  fi
  printf '%s\n' "${segment}"
}

confirm() {
  local prompt="$1"
  local default_answer="${2:-Y}"
  local response
  local suffix="[y/N]"

  if [[ "${default_answer}" == "Y" ]]; then
    suffix="[Y/n]"
  fi

  read -r -p "${prompt} ${suffix} " response
  response="${response:-${default_answer}}"
  [[ "${response}" =~ ^[Yy]$ ]]
}

escape_xml() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  printf '%s\n' "${value}"
}

write_new_app_files() {
  local target_dir="$1"
  local application_id="$2"
  local app_name="$3"
  local package_path
  local escaped_app_name

  package_path="$(to_package_path "${application_id}")"
  escaped_app_name="$(escape_xml "${app_name}")"

  mkdir -p \
    "${target_dir}/app/src/main/java/${package_path}" \
    "${target_dir}/app/src/main/res/values"

  cat >"${target_dir}/settings.gradle.kts" <<EOF
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "${app_name}"
include(":app")
EOF

  cat >"${target_dir}/build.gradle.kts" <<'EOF'
plugins {
    id("com.android.application") version "9.2.0" apply false
}
EOF

  cat >"${target_dir}/app/build.gradle.kts" <<EOF
plugins {
    id("com.android.application")
}

android {
    namespace = "${application_id}"
    compileSdk = 36

    defaultConfig {
        applicationId = "${application_id}"
        minSdk = 23
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }
}
EOF

  cat >"${target_dir}/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
EOF

  cat >"${target_dir}/.gitignore" <<'EOF'
.gradle/
local.properties
**/build/
EOF

  cat >"${target_dir}/app/src/main/AndroidManifest.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:allowBackup="true"
        android:label="@string/app_name"
        android:theme="@style/AppTheme">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

  cat >"${target_dir}/app/src/main/res/values/strings.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">${escaped_app_name}</string>
</resources>
EOF

  cat >"${target_dir}/app/src/main/res/values/themes.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="@android:style/Theme.Material.Light.NoActionBar" />
</resources>
EOF

  cat >"${target_dir}/app/src/main/java/${package_path}/MainActivity.kt" <<EOF
package ${application_id}

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.widget.TextView

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContentView(
            TextView(this).apply {
                text = "Hello Android"
                textSize = 24f
                gravity = Gravity.CENTER
            },
        )
    }
}
EOF
}

copy_devcontainer_files() {
  local target_dir="$1"
  local script_dir
  local source_devcontainer_dir

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source_devcontainer_dir="$(cd "${script_dir}/.." && pwd)"

  cp -R "${source_devcontainer_dir}" "${target_dir}/.devcontainer"
}

generate_gradle_wrapper() {
  local target_dir="$1"
  local gradle_version="9.4.1"
  local temp_dir

  temp_dir="$(mktemp -d)"

  info "Downloading Gradle ${gradle_version} to generate the wrapper..."
  if ! run_logged "Download Gradle ${gradle_version}" curl -fsSLo "${temp_dir}/gradle.zip" "https://services.gradle.org/distributions/gradle-${gradle_version}-bin.zip"; then
    rm -rf "${temp_dir}"
    fatal \
      "ANDROID-GRADLE-002" \
      "Gradle wrapper generation" \
      "Could not download Gradle ${gradle_version}." \
      "A generated project needs a Gradle wrapper before it can build consistently." \
      "Check network access to services.gradle.org and retry the project creation command."
  fi
  if ! run_logged "Extract Gradle ${gradle_version}" unzip -q "${temp_dir}/gradle.zip" -d "${temp_dir}"; then
    rm -rf "${temp_dir}"
    fatal \
      "ANDROID-GRADLE-003" \
      "Gradle wrapper generation" \
      "Could not extract Gradle ${gradle_version}." \
      "The Gradle wrapper cannot be generated from an incomplete or invalid distribution archive." \
      "Retry the project creation command; if it fails again, remove the target directory and check the log."
  fi

  (
    cd "${target_dir}"
    run_logged "Generate Gradle wrapper" "${temp_dir}/gradle-${gradle_version}/bin/gradle" --no-daemon wrapper \
      --gradle-version "${gradle_version}" \
      --distribution-type bin
  ) || {
    rm -rf "${temp_dir}"
    fatal \
      "ANDROID-GRADLE-004" \
      "Gradle wrapper generation" \
      "Gradle wrapper generation failed." \
      "The generated project cannot build without wrapper files." \
      "Review the log, remove the incomplete target directory if needed, and retry."
  }

  rm -rf "${temp_dir}"
}

build_generated_app() {
  local target_dir="$1"

  echo
  info "Building ${target_dir}..."
  (
    cd "${target_dir}"
    ./gradlew build
  )
}

create_app() {
  local target_dir="$1"
  local application_id="$2"
  local app_name="$3"

  require_valid_application_id "${application_id}"
  require_valid_app_name "${app_name}"

  if [[ -e "${target_dir}" ]] && [[ -n "$(find "${target_dir}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    fatal \
      "ANDROID-PROJECT-004" \
      "Project creation" \
      "Target directory already exists and is not empty: ${target_dir}" \
      "Project creation must not overwrite existing files." \
      "Choose an empty directory, remove the existing directory yourself, or run init again with a different project directory."
  fi

  mkdir -p "${target_dir}"
  write_new_app_files "${target_dir}" "${application_id}" "${app_name}"
  copy_devcontainer_files "${target_dir}"
  generate_gradle_wrapper "${target_dir}"
  build_generated_app "${target_dir}"

  cat <<EOF

Created Android app in ${target_dir}
Build completed successfully.

Next steps:
  cd ${target_dir}
  bash .devcontainer/scripts/android-dev.sh devices
  bash .devcontainer/scripts/android-dev.sh run-debug

Or, from the current directory:
  bash .devcontainer/scripts/android-dev.sh devices
  bash .devcontainer/scripts/android-dev.sh run-debug
EOF
}

new_app() {
  if [[ $# -lt 3 || $# -gt 4 ]]; then
    fatal \
      "ANDROID-CONFIG-004" \
      "Command usage" \
      "Invalid new-app arguments." \
      "The non-interactive app creation workflow requires a directory and application ID." \
      "Run: bash .devcontainer/scripts/android-dev.sh new-app <directory> <application-id> [app-name]"
  fi

  local target_dir="$2"
  local application_id="$3"
  local app_name="${4:-$(basename "${target_dir}")}"

  create_app "${target_dir}" "${application_id}" "${app_name}"
}

init_app() {
  local app_name
  local target_dir
  local application_id
  local suggested_dir
  local suggested_application_id

  while true; do
    read -r -p "App name: " app_name
    if is_valid_app_name "${app_name}"; then
      break
    fi
    warn \
      "ANDROID-CONFIG-005" \
      "Invalid app name: ${app_name}" \
      "Use letters, numbers, spaces, underscores, or hyphens, starting with a letter."
  done

  suggested_dir="$(slugify "${app_name}")"
  suggested_application_id="com.example.$(to_application_segment "${app_name}")"

  read -r -p "Project directory [${suggested_dir}]: " target_dir
  target_dir="${target_dir:-${suggested_dir}}"

  while true; do
    read -r -p "Application ID [${suggested_application_id}]: " application_id
    application_id="${application_id:-${suggested_application_id}}"
    if is_valid_application_id "${application_id}"; then
      break
    fi
    warn \
      "ANDROID-CONFIG-006" \
      "Invalid application ID: ${application_id}" \
      "Use a lowercase reverse-domain ID such as com.example.myapp."
  done

  cat <<EOF

Project summary:
  App name:       ${app_name}
  Directory:      ${target_dir}
  Application ID: ${application_id}
EOF

  if ! confirm "Create and build this project?"; then
    echo "Canceled."
    exit 0
  fi

  create_app "${target_dir}" "${application_id}" "${app_name}"
}

run_in_project() {
  if [[ $# -lt 3 ]]; then
    fatal \
      "ANDROID-CONFIG-007" \
      "Command usage" \
      "Invalid project command arguments." \
      "The project helper needs a target directory and a command to run." \
      "Run: bash .devcontainer/scripts/android-dev.sh project <directory> <command> [args...]"
  fi

  local target_dir="$2"
  shift 2

  if [[ ! -d "${target_dir}" ]]; then
    fatal \
      "ANDROID-PROJECT-005" \
      "Project selection" \
      "Project directory does not exist: ${target_dir}" \
      "The CLI cannot run project commands in a missing directory." \
      "Check the directory name or create a project with 'bash .devcontainer/scripts/android-dev.sh init'."
  fi

  (
    cd "${target_dir}"
    bash .devcontainer/scripts/android-dev.sh "$@"
  )
}

network_check() {
  if [[ $# -lt 2 || $# -gt 3 ]]; then
    fatal \
      "ANDROID-CONFIG-008" \
      "Command usage" \
      "Invalid network-check arguments." \
      "Network checks need a phone IP address and optionally a TCP port." \
      "Run: bash .devcontainer/scripts/android-dev.sh network-check <ip> [port]"
  fi

  local ip="$2"
  local port="${3:-}"

  info "Pinging ${ip}..."
  if ! ping -c 1 "${ip}"; then
    echo
    warn \
      "ANDROID-DEVICE-003" \
      "Ping failed. Some phones or networks block ICMP, so this is not definitive by itself." \
      "If wireless debugging still fails, confirm the phone and workstation are on the same Wi-Fi network."
  fi

  if [[ -n "${port}" ]]; then
    echo
    info "Checking TCP port ${port}..."
    if ! run_logged "Check TCP port ${port}" nc -vz "${ip}" "${port}"; then
      fatal \
        "ANDROID-DEVICE-004" \
        "Wireless device connectivity" \
        "Could not connect to ${ip}:${port}." \
        "ADB pairing or connection cannot work until the TCP port is reachable." \
        "Use the current pairing or connection port shown on the phone and keep the Wireless debugging screen open."
    fi
  fi
}

gradle_watch_paths() {
  find . \
    -path './.gradle' -prune -o \
    -path './.git' -prune -o \
    \( -name 'settings.gradle.kts' -o -name 'settings.gradle' -o -name 'build.gradle.kts' -o -name 'build.gradle' -o -name 'gradle.properties' -o -name 'libs.versions.toml' \) \
    -print
}

sync_check() {
  info "Running Gradle sync check..."
  run_gradle help
}

watch_gradle() {
  require_gradle_wrapper

  if ! command -v inotifywait >/dev/null 2>&1; then
    fatal \
      "ANDROID-SDK-002" \
      "Gradle file watching" \
      "inotifywait is not available in the current shell." \
      "The Gradle watcher depends on inotify-tools to detect file changes." \
      "Rebuild the Dev Container so inotify-tools is installed."
  fi

  local mode="${2:-}"
  if [[ -n "${mode}" && "${mode}" != "--auto" ]]; then
    fatal \
      "ANDROID-CONFIG-009" \
      "Command usage" \
      "Invalid watch-gradle option: ${mode}" \
      "The Gradle watcher only supports manual prompts or --auto mode." \
      "Run: bash .devcontainer/scripts/android-dev.sh watch-gradle [--auto]"
  fi

  mkdir -p .android-dev/logs
  local log_file=".android-dev/logs/gradle-watch.log"
  local watched_files=()
  mapfile -t watched_files < <(gradle_watch_paths)

  if [[ "${#watched_files[@]}" -eq 0 ]]; then
    fatal \
      "ANDROID-PROJECT-006" \
      "Gradle file watching" \
      "No Gradle configuration files found to watch." \
      "The watcher needs known Gradle files such as settings.gradle.kts, build.gradle.kts, or gradle.properties." \
      "Run this command from an Android project root."
  fi

  info "Watching Gradle files. Press Ctrl-C to stop."
  printf '  %s\n' "${watched_files[@]}"

  while true; do
    local changed_file
    changed_file="$(inotifywait -q -e close_write,move,create --format '%w%f' "${watched_files[@]}")"
    printf '%s Gradle file changed: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${changed_file}" | tee -a "${log_file}"

    if [[ "${mode}" == "--auto" ]] || confirm "Run Gradle sync check now?"; then
      sync_check 2>&1 | tee -a "${log_file}"
    fi

    mapfile -t watched_files < <(gradle_watch_paths)
  done
}

show_devices() {
  local output
  require_adb
  output="$(adb devices)"
  log_to_file "$ adb devices"
  log_to_file "${output}"
  printf '%s\n' "${output}"

  if ! grep -q $'\tdevice$' <<<"${output}"; then
    warn \
      "ANDROID-DEVICE-002" \
      "No authorized Android devices are visible to this container." \
      "Use wireless debugging: enable it on the phone, run pair-device with the pairing port, then run connect-device with the current connection port."
  fi
}

connected_device_serials() {
  require_adb
  adb devices | awk 'NR > 1 && $2 == "device" { print $1 }'
}

select_device() {
  local devices=()
  local choice

  mapfile -t devices < <(connected_device_serials)

  case "${#devices[@]}" in
    0)
      fatal \
        "ANDROID-DEVICE-002" \
        "Android device selection" \
        "No authorized Android devices are available." \
        "The app cannot be installed without a connected physical device or emulator." \
        "Run 'bash .devcontainer/scripts/android-dev.sh devices' for pairing guidance."
      ;;
    1)
      printf '%s\n' "${devices[0]}"
      ;;
    *)
      echo "Select a device:" >&2
      local index
      for index in "${!devices[@]}"; do
        printf '  %s) %s\n' "$((index + 1))" "${devices[$index]}" >&2
      done
      read -r -p "Device number: " choice
      if [[ ! "${choice}" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#devices[@]} )); then
        fatal \
          "ANDROID-CONFIG-010" \
          "Android device selection" \
          "Invalid device selection: ${choice}" \
          "The CLI can only install to one of the listed authorized devices." \
          "Run the command again and choose one of the displayed device numbers."
      fi
      printf '%s\n' "${devices[$((choice - 1))]}"
      ;;
  esac
}

install_debug() {
  local serial
  serial="$(select_device)"
  info "Using device: ${serial}"
  ANDROID_SERIAL="${serial}" run_gradle installDebug
}

run_debug_in_current_project() {
  local application_id="$1"
  local serial
  application_id="$(detect_application_id "${application_id}")"
  serial="$(select_device)"
  info "Using device: ${serial}"
  info "Using application ID: ${application_id}"
  ANDROID_SERIAL="${serial}" run_gradle installDebug
  if ! run_logged "Launch app ${application_id}" adb -s "${serial}" shell monkey -p "${application_id}" 1; then
    fatal \
      "ANDROID-DEVICE-005" \
      "Android app launch" \
      "ADB could not launch application ID ${application_id} on ${serial}." \
      "The install may have failed, the application ID may be wrong, or the device may no longer be available." \
      "Run 'bash .devcontainer/scripts/android-dev.sh devices', then retry run-debug."
  fi
}

run_debug() {
  if [[ $# -gt 2 ]]; then
    fatal \
      "ANDROID-CONFIG-011" \
      "Command usage" \
      "Invalid run-debug arguments." \
      "run-debug accepts zero arguments or one optional application ID." \
      "Run: bash .devcontainer/scripts/android-dev.sh run-debug [application-id]"
  fi

  local application_id="${2:-}"
  local project_root

  if [[ -x ./gradlew ]]; then
    run_debug_in_current_project "${application_id}"
    return
  fi

  project_root="$(select_project_root)"
  info "Using project: ${project_root}"
  (
    cd "${project_root}"
    run_debug_in_current_project "${application_id}"
  )
}

doctor() {
  require_adb

  info "Profile:"
  info "${ANDROID_SDK_PROFILE:-unknown}"

  echo
  info "Java:"
  run_logged "Java version" java -version

  echo
  info "Android SDK:"
  run_logged "Android SDK manager version" sdkmanager --version

  echo
  info "ADB:"
  run_logged "ADB version" adb version

  echo
  info "Installed SDK packages:"
  run_logged "Installed SDK packages" sdkmanager --list_installed

  echo
  info "Connected devices:"
  show_devices
}

command="${1:-help}"

if [[ "${command}" != "help" && "${command}" != "-h" && "${command}" != "--help" && "${command}" != "logs" ]]; then
  init_log "${command}"
  trap 'handle_unexpected_error $? "$BASH_COMMAND" "$LINENO"' ERR
fi

case "${command}" in
  doctor)
    doctor
    ;;
  build)
    run_gradle build
    ;;
  test)
    run_gradle test
    ;;
  lint)
    run_gradle lint
    ;;
  assemble-debug)
    run_gradle assembleDebug
    ;;
  devices)
    show_devices
    ;;
  pair-device)
    require_adb
    if [[ $# -ne 2 ]]; then
      fatal \
        "ANDROID-CONFIG-012" \
        "Command usage" \
        "Invalid pair-device arguments." \
        "ADB pairing requires the phone pairing address and pairing port." \
        "Run: bash .devcontainer/scripts/android-dev.sh pair-device <ip:pairing-port>"
    fi
    if ! run_logged "ADB pair ${2}" adb pair "$2"; then
      fatal \
        "ANDROID-DEVICE-006" \
        "Wireless device pairing" \
        "ADB pairing failed for ${2}." \
        "The container cannot trust or connect to the phone until pairing succeeds." \
        "Use the pairing port from 'Pair device with pairing code', keep the pairing-code screen open, generate a fresh code if needed, and confirm both devices are on the same Wi-Fi network."
    fi
    ;;
  connect-device)
    require_adb
    if [[ $# -ne 2 ]]; then
      fatal \
        "ANDROID-CONFIG-013" \
        "Command usage" \
        "Invalid connect-device arguments." \
        "ADB wireless connection requires the phone connection address and current connection port." \
        "Run: bash .devcontainer/scripts/android-dev.sh connect-device <ip:connect-port>"
    fi
    if ! run_logged "ADB connect ${2}" adb connect "$2"; then
      fatal \
        "ANDROID-DEVICE-007" \
        "Wireless device connection" \
        "ADB could not connect to ${2}." \
        "The device will not be available for install or run commands." \
        "Use the current connection port shown on the Wireless debugging screen and confirm network reachability with network-check."
    fi
    ;;
  network-check)
    network_check "$@"
    ;;
  init)
    init_app
    ;;
  new-app)
    new_app "$@"
    ;;
  project)
    run_in_project "$@"
    ;;
  watch-gradle)
    watch_gradle "$@"
    ;;
  logs)
    logs_command "$@"
    ;;
  install-debug)
    install_debug
    ;;
  run-debug)
    run_debug "$@"
    ;;
  tasks)
    run_gradle tasks
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo >&2
    usage >&2
    fatal \
      "ANDROID-CONFIG-014" \
      "Command usage" \
      "Unknown command: ${command}" \
      "The CLI can only run one of its documented commands." \
      "Run: bash .devcontainer/scripts/android-dev.sh --help"
    ;;
esac
