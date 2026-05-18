#!/usr/bin/env bash
set -euo pipefail

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
  install-debug  Interactively choose a device and run ./gradlew installDebug
  run-debug      Install and launch an app: run-debug <application-id>
  tasks          Show Gradle tasks available in the current project
EOF
}

require_gradle_wrapper() {
  if [[ ! -x ./gradlew ]]; then
    echo "Missing executable Gradle wrapper at ./gradlew." >&2
    echo "Run this command from an Android project root that includes the Gradle wrapper." >&2
    echo "This template repository does not include an app project by itself." >&2
    exit 1
  fi
}

require_adb() {
  if ! command -v adb >/dev/null 2>&1; then
    echo "ADB is not available in the current shell." >&2
    echo "Run this command inside the Dev Container, or install Android platform-tools on the host." >&2
    exit 1
  fi
}

run_gradle() {
  require_gradle_wrapper
  ./gradlew "$@"
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
    echo "Invalid application ID: ${application_id}" >&2
    echo "Use a lowercase reverse-domain ID such as com.example.myapp." >&2
    exit 1
  fi
}

is_valid_app_name() {
  local app_name="$1"
  [[ "${app_name}" =~ ^[A-Za-z][A-Za-z0-9[:space:]_-]*$ ]]
}

require_valid_app_name() {
  local app_name="$1"
  if ! is_valid_app_name "${app_name}"; then
    echo "Invalid app name: ${app_name}" >&2
    echo "Use letters, numbers, spaces, underscores, or hyphens, starting with a letter." >&2
    exit 1
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

  echo "Downloading Gradle ${gradle_version} to generate the wrapper..."
  curl -fsSLo "${temp_dir}/gradle.zip" "https://services.gradle.org/distributions/gradle-${gradle_version}-bin.zip"
  unzip -q "${temp_dir}/gradle.zip" -d "${temp_dir}"

  (
    cd "${target_dir}"
    "${temp_dir}/gradle-${gradle_version}/bin/gradle" --no-daemon wrapper \
      --gradle-version "${gradle_version}" \
      --distribution-type bin
  )

  rm -rf "${temp_dir}"
}

build_generated_app() {
  local target_dir="$1"

  echo
  echo "Building ${target_dir}..."
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
    echo "Target directory already exists and is not empty: ${target_dir}" >&2
    exit 1
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
  bash .devcontainer/scripts/android-dev.sh run-debug ${application_id}

Or, from the current directory:
  bash .devcontainer/scripts/android-dev.sh project ${target_dir} devices
  bash .devcontainer/scripts/android-dev.sh project ${target_dir} run-debug ${application_id}
EOF
}

new_app() {
  if [[ $# -lt 3 || $# -gt 4 ]]; then
    echo "Usage: bash .devcontainer/scripts/android-dev.sh new-app <directory> <application-id> [app-name]" >&2
    exit 1
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
    echo "Invalid app name: ${app_name}" >&2
    echo "Use letters, numbers, spaces, underscores, or hyphens, starting with a letter." >&2
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
    echo "Invalid application ID: ${application_id}" >&2
    echo "Use a lowercase reverse-domain ID such as com.example.myapp." >&2
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
    echo "Usage: bash .devcontainer/scripts/android-dev.sh project <directory> <command> [args...]" >&2
    exit 1
  fi

  local target_dir="$2"
  shift 2

  if [[ ! -d "${target_dir}" ]]; then
    echo "Project directory does not exist: ${target_dir}" >&2
    exit 1
  fi

  (
    cd "${target_dir}"
    bash .devcontainer/scripts/android-dev.sh "$@"
  )
}

network_check() {
  if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Usage: bash .devcontainer/scripts/android-dev.sh network-check <ip> [port]" >&2
    exit 1
  fi

  local ip="$2"
  local port="${3:-}"

  echo "Pinging ${ip}..."
  if ! ping -c 1 "${ip}"; then
    echo
    echo "Ping failed. Some phones or networks block ICMP, so a failed ping is not definitive by itself."
  fi

  if [[ -n "${port}" ]]; then
    echo
    echo "Checking TCP port ${port}..."
    nc -vz "${ip}" "${port}"
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
  echo "Running Gradle sync check..."
  run_gradle help
}

watch_gradle() {
  require_gradle_wrapper

  if ! command -v inotifywait >/dev/null 2>&1; then
    echo "inotifywait is not available in the current shell." >&2
    echo "Rebuild the Dev Container so inotify-tools is installed." >&2
    exit 1
  fi

  local mode="${2:-}"
  if [[ -n "${mode}" && "${mode}" != "--auto" ]]; then
    echo "Usage: bash .devcontainer/scripts/android-dev.sh watch-gradle [--auto]" >&2
    exit 1
  fi

  mkdir -p .android-dev/logs
  local log_file=".android-dev/logs/gradle-watch.log"
  local watched_files=()
  mapfile -t watched_files < <(gradle_watch_paths)

  if [[ "${#watched_files[@]}" -eq 0 ]]; then
    echo "No Gradle configuration files found to watch." >&2
    exit 1
  fi

  echo "Watching Gradle files. Press Ctrl-C to stop."
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
  printf '%s\n' "${output}"

  if ! grep -q $'\tdevice$' <<<"${output}"; then
    cat <<'EOF'

No authorized Android devices are visible to this container.
For the most portable workflow, use Android wireless debugging:
  1. Enable Wireless debugging on the phone.
  2. Run: bash .devcontainer/scripts/android-dev.sh pair-device <ip:pairing-port>
  3. Run: bash .devcontainer/scripts/android-dev.sh connect-device <ip:connect-port>
EOF
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
      echo "No authorized Android devices are available." >&2
      echo "Run 'bash .devcontainer/scripts/android-dev.sh devices' for pairing guidance." >&2
      exit 1
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
        echo "Invalid device selection." >&2
        exit 1
      fi
      printf '%s\n' "${devices[$((choice - 1))]}"
      ;;
  esac
}

install_debug() {
  local serial
  serial="$(select_device)"
  echo "Using device: ${serial}"
  ANDROID_SERIAL="${serial}" run_gradle installDebug
}

run_debug() {
  if [[ $# -ne 2 ]]; then
    echo "Usage: bash .devcontainer/scripts/android-dev.sh run-debug <application-id>" >&2
    exit 1
  fi

  local application_id="$2"
  local serial
  serial="$(select_device)"
  echo "Using device: ${serial}"
  ANDROID_SERIAL="${serial}" run_gradle installDebug
  adb -s "${serial}" shell monkey -p "${application_id}" 1 >/dev/null
}

doctor() {
  require_adb

  echo "Profile:"
  echo "${ANDROID_SDK_PROFILE:-unknown}"

  echo
  echo "Java:"
  java -version

  echo
  echo "Android SDK:"
  sdkmanager --version

  echo
  echo "ADB:"
  adb version

  echo
  echo "Installed SDK packages:"
  sdkmanager --list_installed

  echo
  echo "Connected devices:"
  show_devices
}

command="${1:-help}"

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
      echo "Usage: bash .devcontainer/scripts/android-dev.sh pair-device <ip:port>" >&2
      exit 1
    fi
    if ! adb pair "$2"; then
      cat >&2 <<'EOF'

Pairing failed.
Check these common causes:
  1. Use the pairing port from "Pair device with pairing code", not the later connection port.
  2. Keep the pairing-code screen open on the phone until pairing completes.
  3. If the code/session expired, generate a fresh pairing code and retry.
  4. Confirm the phone and workstation are still on the same Wi-Fi network.
EOF
      exit 1
    fi
    ;;
  connect-device)
    require_adb
    if [[ $# -ne 2 ]]; then
      echo "Usage: bash .devcontainer/scripts/android-dev.sh connect-device <ip:port>" >&2
      exit 1
    fi
    adb connect "$2"
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
    echo "Unknown command: ${command}" >&2
    echo >&2
    usage >&2
    exit 1
    ;;
esac
