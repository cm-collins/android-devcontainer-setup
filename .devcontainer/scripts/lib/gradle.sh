#!/usr/bin/env bash

require_gradle_wrapper() {
  if [[ ! -x ./gradlew ]]; then
    fatal \
      "ANDROID-PROJECT-001" \
      "Android project discovery" \
      "Missing executable Gradle wrapper at ./gradlew." \
      "Project commands must run from an Android project root that includes the Gradle wrapper." \
      "Run this command inside a generated Android project, or create one with 'bash .devcontainer/scripts/android-dev.sh init'."
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

run_gradle_in_project() {
  local project_root

  if [[ -x ./gradlew ]]; then
    run_gradle "$@"
    return
  fi

  project_root="$(select_project_root)"
  info "Using project: ${project_root}"
  (
    cd "${project_root}" || exit
    run_gradle "$@"
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
