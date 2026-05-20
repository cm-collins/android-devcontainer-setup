#!/usr/bin/env bash

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
    fatal \
      "ANDROID-CONFIG-001" \
      "Application ID validation" \
      "Invalid application ID: ${application_id}" \
      "Android application IDs must be stable, valid package-style identifiers." \
      "Use a lowercase reverse-domain ID such as com.example.myapp."
  fi
}

is_valid_app_name() {
  local app_name="$1"
  [[ "${app_name}" =~ ^[A-Za-z][A-Za-z0-9[:space:]_-]*$ ]]
}

require_valid_app_name() {
  local app_name="$1"
  if ! is_valid_app_name "${app_name}"; then
    fatal \
      "ANDROID-CONFIG-003" \
      "App name validation" \
      "Invalid app name: ${app_name}" \
      "The generated project needs a valid display name and Gradle project name." \
      "Use letters, numbers, spaces, underscores, or hyphens, starting with a letter."
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

escape_xml() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  printf '%s\n' "${value}"
}

escape_json() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s\n' "${value}"
}
