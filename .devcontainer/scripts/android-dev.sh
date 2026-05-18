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
  run_gradle -Pandroid.injected.device.serial="${serial}" installDebug
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
  run_gradle -Pandroid.injected.device.serial="${serial}" installDebug
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
