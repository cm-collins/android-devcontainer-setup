#!/usr/bin/env bash

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

watch_gradle_in_current_project() {
  require_gradle_wrapper

  if ! command -v inotifywait >/dev/null 2>&1; then
    fatal \
      "ANDROID-SDK-002" \
      "Gradle file watching" \
      "inotifywait is not available in the current shell." \
      "The Gradle watcher depends on inotify-tools to detect file changes." \
      "Rebuild the Dev Container so inotify-tools is installed."
  fi

  local mode="${1:-}"
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

watch_gradle() {
  local mode="${2:-}"
  local project_root

  if [[ -x ./gradlew ]]; then
    watch_gradle_in_current_project "${mode}"
    return
  fi

  project_root="$(select_project_root)"
  info "Using project: ${project_root}"
  (
    cd "${project_root}" || exit
    watch_gradle_in_current_project "${mode}"
  )
}
