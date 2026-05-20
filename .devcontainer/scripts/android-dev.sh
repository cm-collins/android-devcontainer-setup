#!/usr/bin/env bash
set -euo pipefail

ANDROID_DEV_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
ANDROID_DEV_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DEV_WORKSTATION_ROOT="$(cd "${ANDROID_DEV_SCRIPT_DIR}/../.." && pwd)"

# The public CLI stays in this file; implementation lives in lib/*.sh so command
# groups can evolve independently.
# shellcheck source=.devcontainer/scripts/lib/core.sh
source "${ANDROID_DEV_SCRIPT_DIR}/lib/core.sh"
# shellcheck source=.devcontainer/scripts/lib/validation.sh
source "${ANDROID_DEV_SCRIPT_DIR}/lib/validation.sh"
# shellcheck source=.devcontainer/scripts/lib/templates.sh
source "${ANDROID_DEV_SCRIPT_DIR}/lib/templates.sh"
# shellcheck source=.devcontainer/scripts/lib/projects.sh
source "${ANDROID_DEV_SCRIPT_DIR}/lib/projects.sh"
# shellcheck source=.devcontainer/scripts/lib/editor.sh
source "${ANDROID_DEV_SCRIPT_DIR}/lib/editor.sh"
# shellcheck source=.devcontainer/scripts/lib/gradle.sh
source "${ANDROID_DEV_SCRIPT_DIR}/lib/gradle.sh"
# shellcheck source=.devcontainer/scripts/lib/devices.sh
source "${ANDROID_DEV_SCRIPT_DIR}/lib/devices.sh"
# shellcheck source=.devcontainer/scripts/lib/network.sh
source "${ANDROID_DEV_SCRIPT_DIR}/lib/network.sh"
# shellcheck source=.devcontainer/scripts/lib/watch.sh
source "${ANDROID_DEV_SCRIPT_DIR}/lib/watch.sh"

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
    run_gradle_in_project build
    ;;
  test)
    run_gradle_in_project test
    ;;
  lint)
    run_gradle_in_project lint
    ;;
  assemble-debug)
    run_gradle_in_project assembleDebug
    ;;
  devices)
    show_devices
    ;;
  pair-device)
    pair_device "$@"
    ;;
  connect-device)
    connect_device "$@"
    ;;
  network-check)
    network_check "$@"
    ;;
  templates)
    templates_command
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
  export-devcontainer)
    export_devcontainer "$@"
    ;;
  sync-workspace)
    sync_workspace "$@"
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
    run_gradle_in_project tasks
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
