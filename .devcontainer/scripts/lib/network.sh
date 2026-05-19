#!/usr/bin/env bash

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
