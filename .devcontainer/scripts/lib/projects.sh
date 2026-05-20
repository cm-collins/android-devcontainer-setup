#!/usr/bin/env bash

: "${ANDROID_DEV_SCRIPT:?}"
: "${ANDROID_DEV_WORKSTATION_ROOT:?}"

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

metadata_value() {
  local key="$1"
  local file=".android-dev/project.json"

  if [[ ! -f "${file}" ]]; then
    return 1
  fi

  sed -nE 's/^[[:space:]]*"'"${key}"'"[[:space:]]*:[[:space:]]*"?([^",]+)"?,?[[:space:]]*$/\1/p' "${file}" | head -n 1
}

detect_application_id() {
  local explicit_application_id="${1:-}"
  local candidate_files=()
  local application_ids=()
  local file
  local detected_id
  local metadata_runnable
  local metadata_application_id

  if [[ -n "${explicit_application_id}" ]]; then
    require_valid_application_id "${explicit_application_id}"
    printf '%s\n' "${explicit_application_id}"
    return
  fi

  metadata_runnable="$(metadata_value runnable || true)"
  if [[ "${metadata_runnable}" == "false" ]]; then
    fatal \
      "ANDROID-PROJECT-009" \
      "Android application discovery" \
      "This project is marked as non-runnable in .android-dev/project.json." \
      "No Activity and Android Library templates do not install or launch an app directly." \
      "Create a runnable app template, or run build/test/lint for this project instead."
  fi

  metadata_application_id="$(metadata_value applicationId || true)"
  if [[ -n "${metadata_application_id}" ]]; then
    require_valid_application_id "${metadata_application_id}"
    printf '%s\n' "${metadata_application_id}"
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

require_project_creation_tools() {
  local missing_tools=()
  local tool

  for tool in curl unzip java; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      missing_tools+=("${tool}")
    fi
  done

  if [[ "${#missing_tools[@]}" -gt 0 ]]; then
    fatal \
      "ANDROID-GRADLE-005" \
      "Project creation prerequisites" \
      "Missing required tool(s): ${missing_tools[*]}" \
      "Project creation downloads Gradle, extracts it, and runs Java to generate the wrapper." \
      "Run project creation inside the Dev Container, or install the missing tool(s) in the current shell."
  fi
}

export_devcontainer() {
  if [[ $# -ne 2 ]]; then
    fatal \
      "ANDROID-CONFIG-016" \
      "Command usage" \
      "Invalid export-devcontainer arguments." \
      "The export workflow needs the project directory that should become standalone." \
      "Run: bash .devcontainer/scripts/android-dev.sh export-devcontainer <directory>"
  fi

  local target_dir="$2"

  if [[ ! -d "${target_dir}" ]]; then
    fatal \
      "ANDROID-PROJECT-007" \
      "Dev Container export" \
      "Project directory does not exist: ${target_dir}" \
      "The CLI cannot export a devcontainer into a missing project." \
      "Check the directory name or create a project with 'bash .devcontainer/scripts/android-dev.sh init'."
  fi
  if [[ -e "${target_dir}/.devcontainer" ]]; then
    fatal \
      "ANDROID-PROJECT-008" \
      "Dev Container export" \
      "Target project already has a .devcontainer directory: ${target_dir}/.devcontainer" \
      "Export should not overwrite an existing environment definition." \
      "Remove or back up the existing .devcontainer directory yourself, then retry."
  fi

  cp -R "${ANDROID_DEV_WORKSTATION_ROOT}/.devcontainer" "${target_dir}/.devcontainer"
  info "Exported Dev Container files to ${target_dir}/.devcontainer"
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
    cd "${target_dir}" || exit
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

  if [[ ! -x "${target_dir}/gradlew" ]]; then
    rm -rf "${temp_dir}"
    fatal \
      "ANDROID-GRADLE-004" \
      "Gradle wrapper generation" \
      "Gradle wrapper generation did not create an executable gradlew file." \
      "The generated project cannot build without wrapper files." \
      "Run project creation inside the Dev Container so Java is available, then retry. If it fails again, remove the incomplete target directory and check the log."
  fi

  rm -rf "${temp_dir}"
}

build_generated_app() {
  local target_dir="$1"

  echo
  info "Building ${target_dir}..."
  (
    cd "${target_dir}" || exit
    run_gradle build
  )
}

create_app() {
  local target_dir="$1"
  local application_id="$2"
  local app_name="$3"
  local template="$4"
  local next_steps

  require_valid_application_id "${application_id}"
  require_valid_app_name "${app_name}"
  require_valid_template "${template}"
  require_project_creation_tools

  if [[ -e "${target_dir}" ]] && [[ -n "$(find "${target_dir}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    fatal \
      "ANDROID-PROJECT-004" \
      "Project creation" \
      "Target directory already exists and is not empty: ${target_dir}" \
      "Project creation must not overwrite existing files." \
      "Choose an empty directory, remove the existing directory yourself, or run init again with a different project directory."
  fi

  mkdir -p "${target_dir}"
  write_new_app_files "${target_dir}" "${application_id}" "${app_name}" "${template}"
  generate_gradle_wrapper "${target_dir}"
  build_generated_app "${target_dir}"

  if [[ "${ANDROID_DEV_SKIP_WORKSPACE_SYNC:-0}" == "1" ]]; then
    warn \
      "ANDROID-PROJECT-011" \
      "Skipped editor workspace sync because ANDROID_DEV_SKIP_WORKSPACE_SYNC=1." \
      "Run 'bash .devcontainer/scripts/android-dev.sh sync-workspace' later if editor workspace metadata is needed."
  else
    sync_workspace sync-workspace
  fi

  if template_is_runnable "${template}"; then
    next_steps="  bash .devcontainer/scripts/android-dev.sh devices
  bash .devcontainer/scripts/android-dev.sh run-debug"
  else
    next_steps="  bash .devcontainer/scripts/android-dev.sh build
  bash .devcontainer/scripts/android-dev.sh lint"
  fi

  cat <<EOF

Created Android project in ${target_dir}
Template: ${template}
Build completed successfully.
Editor workspace metadata was refreshed.

Next steps:
${next_steps}

For VS Code or Cursor indexing, open:
  android-devcontainer.code-workspace

To make the generated app a standalone repo with its own Dev Container:
  bash .devcontainer/scripts/android-dev.sh export-devcontainer ${target_dir}
EOF
}

new_app() {
  local template="basic-activity"
  local args=()
  local target_dir
  local application_id
  local app_name

  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --template)
        if [[ $# -lt 2 ]]; then
          fatal \
            "ANDROID-CONFIG-019" \
            "Command usage" \
            "Missing template name after --template." \
            "The non-interactive project creation workflow needs an explicit template value." \
            "Run: bash .devcontainer/scripts/android-dev.sh new-app --template basic-activity <directory> <application-id> [app-name]"
        fi
        template="$2"
        shift 2
        ;;
      --template=*)
        template="${1#--template=}"
        shift
        ;;
      --help|-h)
        fatal \
          "ANDROID-CONFIG-004" \
          "Command usage" \
          "new-app creates and builds an Android project." \
          "The non-interactive app creation workflow requires a directory and application ID." \
          "Run: bash .devcontainer/scripts/android-dev.sh new-app [--template <name>] <directory> <application-id> [app-name]"
        ;;
      --*)
        fatal \
          "ANDROID-CONFIG-020" \
          "Command usage" \
          "Unknown new-app option: $1" \
          "The new-app command only supports the --template option." \
          "Run: bash .devcontainer/scripts/android-dev.sh new-app [--template <name>] <directory> <application-id> [app-name]"
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  if [[ "${#args[@]}" -lt 2 || "${#args[@]}" -gt 3 ]]; then
    fatal \
      "ANDROID-CONFIG-004" \
      "Command usage" \
      "Invalid new-app arguments." \
      "The non-interactive app creation workflow requires a directory and application ID." \
      "Run: bash .devcontainer/scripts/android-dev.sh new-app [--template <name>] <directory> <application-id> [app-name]"
  fi

  target_dir="${args[0]}"
  application_id="${args[1]}"
  app_name="${args[2]:-$(basename "${target_dir}")}"

  create_app "${target_dir}" "${application_id}" "${app_name}" "${template}"
}

init_app() {
  local app_name
  local target_dir
  local application_id
  local suggested_dir
  local suggested_application_id
  local template

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

  template="$(select_template)"

  cat <<EOF

Project summary:
  App name:       ${app_name}
  Directory:      ${target_dir}
  Application ID: ${application_id}
  Template:       ${template} ($(template_label "${template}"))
EOF

  if ! confirm "Create and build this project?"; then
    echo "Canceled."
    exit 0
  fi

  create_app "${target_dir}" "${application_id}" "${app_name}" "${template}"
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
    cd "${target_dir}" || exit
    bash "${ANDROID_DEV_SCRIPT}" "$@"
  )
}
