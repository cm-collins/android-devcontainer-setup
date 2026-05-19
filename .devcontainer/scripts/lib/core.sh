#!/usr/bin/env bash

LOG_FILE="${LOG_FILE:-}"
HANDLED_FAILURE="${HANDLED_FAILURE:-0}"

usage() {
  cat <<'EOF'
Usage: bash .devcontainer/scripts/android-dev.sh <command>

Commands:
  doctor              Check Java, Android SDK, ADB, installed packages, and visible devices
  build               Run ./gradlew build in the detected Android project
  test                Run ./gradlew test in the detected Android project
  lint                Run ./gradlew lint in the detected Android project
  assemble-debug      Run ./gradlew assembleDebug in the detected Android project
  devices             List devices visible to ADB
  pair-device         Pair a wireless device: pair-device <ip:port>
  connect-device      Connect to a paired wireless device: connect-device <ip:port>
  network-check       Check phone reachability: network-check <ip> [port]
  init                Interactively create and build a new Android app
  new-app             Create and build an Android app: new-app <directory> <application-id> [app-name]
  project             Run a command in a project: project <directory> <command> [args...]
  export-devcontainer Copy this workstation devcontainer into a project: export-devcontainer <directory>
  sync-workspace      Generate a multi-root editor workspace for nested Android projects
  watch-gradle        Watch Gradle files and offer sync checks: watch-gradle [--auto]
  logs                Show command logs: logs [latest|tail]
  install-debug       Interactively choose a device and run ./gradlew installDebug
  run-debug           Install and launch the app: run-debug [application-id]
  tasks               Show Gradle tasks available in the detected Android project
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
  local status
  shift

  info "Running ${label}..."
  log_to_file "\$ $*"
  set +e
  "$@" 2>&1 | tee -a "${LOG_FILE:-/dev/null}"
  status="${PIPESTATUS[0]}"
  set -e

  if [[ "${status}" -ne 0 ]]; then
    log_to_file "Command failed with exit code ${status}: $*"
  fi
  return "${status}"
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
