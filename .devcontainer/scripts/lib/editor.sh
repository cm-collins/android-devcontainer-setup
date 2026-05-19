#!/usr/bin/env bash

: "${ANDROID_DEV_WORKSTATION_ROOT:?}"

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "${value}"
}

workspace_project_roots() {
  (
    cd "${ANDROID_DEV_WORKSTATION_ROOT}" || exit
    child_project_roots
  )
}

write_code_workspace() {
  local workspace_file="$1"
  local projects=()
  local project
  local folder_count
  local folder_index=0

  mapfile -t projects < <(workspace_project_roots)
  folder_count=$(( ${#projects[@]} + 1 ))

  {
    printf '{\n'
    printf '  "folders": [\n'
    printf '    {\n'
    printf '      "name": "Android Workstation",\n'
    printf '      "path": "."\n'
    printf '    }'
    folder_index=$((folder_index + 1))

    for project in "${projects[@]}"; do
      printf ',\n'
      printf '    {\n'
      printf '      "name": "%s",\n' "$(json_escape "${project}")"
      printf '      "path": "%s"\n' "$(json_escape "${project}")"
      printf '    }'
      folder_index=$((folder_index + 1))
    done

    if [[ "${folder_index}" -ne "${folder_count}" ]]; then
      fatal \
        "ANDROID-CONFIG-018" \
        "Editor workspace sync" \
        "Workspace folder generation produced an unexpected folder count." \
        "The editor workspace file may be incomplete." \
        "Run sync-workspace again and check the command log."
    fi

    cat <<'EOF'

  ],
  "settings": {
    "kotlin.diagnostics.enabled": false,
    "java.configuration.updateBuildConfiguration": "automatic",
    "java.import.gradle.enabled": true,
    "java.import.gradle.wrapper.enabled": true,
    "gradle.nestedProjects": true
  }
}
EOF
  } >"${workspace_file}"
}

sync_workspace() {
  if [[ $# -gt 2 ]]; then
    fatal \
      "ANDROID-CONFIG-017" \
      "Command usage" \
      "Invalid sync-workspace arguments." \
      "The workspace sync command accepts zero arguments or one optional workspace file path." \
      "Run: bash .devcontainer/scripts/android-dev.sh sync-workspace [workspace-file]"
  fi

  local workspace_file="${2:-${ANDROID_DEV_WORKSTATION_ROOT}/android-devcontainer.code-workspace}"
  local workspace_dir

  workspace_dir="$(dirname "${workspace_file}")"
  if [[ ! -d "${workspace_dir}" ]]; then
    fatal \
      "ANDROID-PROJECT-009" \
      "Editor workspace sync" \
      "Workspace directory does not exist: ${workspace_dir}" \
      "The CLI cannot write editor workspace metadata into a missing directory." \
      "Create the directory or run sync-workspace without a custom path."
  fi

  write_code_workspace "${workspace_file}"
  info "Synced editor workspace: ${workspace_file}"

  if [[ -n "$(workspace_project_roots)" ]]; then
    info "Editor workspace projects:"
    workspace_project_roots | sed 's/^/  - /'
  else
    warn \
      "ANDROID-PROJECT-010" \
      "No generated child projects were found for the editor workspace." \
      "Create a project with 'bash .devcontainer/scripts/android-dev.sh init' or 'new-app'."
  fi
}
