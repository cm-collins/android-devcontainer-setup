#!/usr/bin/env bash

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

install_debug_in_current_project() {
  local serial
  serial="$(select_device)"
  info "Using device: ${serial}"
  ANDROID_SERIAL="${serial}" run_gradle installDebug
}

install_debug() {
  local project_root

  if [[ -x ./gradlew ]]; then
    install_debug_in_current_project
    return
  fi

  project_root="$(select_project_root)"
  info "Using project: ${project_root}"
  (
    cd "${project_root}" || exit
    install_debug_in_current_project
  )
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
    cd "${project_root}" || exit
    run_debug_in_current_project "${application_id}"
  )
}

pair_device() {
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
}

connect_device() {
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
}
