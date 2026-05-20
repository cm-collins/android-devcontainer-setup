#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
work_dir="${1:-/tmp/android-dev-template-smoke}"

templates=(
  basic-activity
  empty-activity
  no-activity
  compose-activity
  android-library
)

rm -rf "${work_dir}"
mkdir -p "${work_dir}"

for template in "${templates[@]}"; do
  app_dir="smoke-${template}"
  application_id="com.example.smoke${template//-/}"
  app_name="Smoke ${template}"

  echo
  echo "==> Creating ${template}"
  (
    cd "${work_dir}"
    ANDROID_DEV_SKIP_WORKSPACE_SYNC=1 bash "${repo_root}/.devcontainer/scripts/android-dev.sh" new-app \
      --template "${template}" \
      "${app_dir}" \
      "${application_id}" \
      "${app_name}"
  )

  project_file="${work_dir}/${app_dir}/.android-dev/project.json"
  if [[ ! -f "${project_file}" ]]; then
    echo "Missing generated metadata: ${project_file}" >&2
    exit 1
  fi

  echo "Generated metadata:"
  sed -n '1,40p' "${project_file}"
done

echo
echo "All template smoke builds completed successfully."
