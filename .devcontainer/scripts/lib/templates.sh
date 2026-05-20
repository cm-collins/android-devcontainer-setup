#!/usr/bin/env bash

available_templates() {
  cat <<'EOF'
basic-activity
empty-activity
no-activity
compose-activity
android-library
EOF
}

is_valid_template() {
  local template="$1"

  case "${template}" in
    basic-activity|empty-activity|no-activity|compose-activity|android-library)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

template_label() {
  case "$1" in
    basic-activity) echo "Basic Activity" ;;
    empty-activity) echo "Empty Activity" ;;
    no-activity) echo "No Activity" ;;
    compose-activity) echo "Compose Activity" ;;
    android-library) echo "Android Library" ;;
  esac
}

template_description() {
  case "$1" in
    basic-activity) echo "Kotlin app with a launch activity and simple centered text." ;;
    empty-activity) echo "Kotlin app with a launch activity and no UI content." ;;
    no-activity) echo "Android app module without a launcher activity." ;;
    compose-activity) echo "Jetpack Compose app with a Compose MainActivity." ;;
    android-library) echo "Android library module starter for reusable code." ;;
  esac
}

template_is_runnable() {
  case "$1" in
    basic-activity|empty-activity|compose-activity)
      return 0
      ;;
    no-activity|android-library)
      return 1
      ;;
  esac
}

require_valid_template() {
  local template="$1"

  if ! is_valid_template "${template}"; then
    fatal \
      "ANDROID-CONFIG-017" \
      "Template validation" \
      "Unknown project template: ${template}" \
      "Project creation must use one of the supported deterministic templates." \
      "Run: bash .devcontainer/scripts/android-dev.sh templates"
  fi
}

templates_command() {
  local template

  echo "Available Android project templates:"
  while IFS= read -r template; do
    printf '  %-17s %s\n' "${template}" "$(template_description "${template}")"
  done < <(available_templates)
}

select_template() {
  local templates=()
  local choice
  local index

  mapfile -t templates < <(available_templates)

  echo "Template:" >&2
  for index in "${!templates[@]}"; do
    printf '  %s. %-17s %s\n' "$((index + 1))" "${templates[$index]}" "$(template_description "${templates[$index]}")" >&2
  done

  while true; do
    read -r -p "Template number [1]: " choice
    choice="${choice:-1}"
    if [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#templates[@]} )); then
      printf '%s\n' "${templates[$((choice - 1))]}"
      return
    fi
    warn \
      "ANDROID-CONFIG-018" \
      "Invalid template selection: ${choice}" \
      "Choose one of the displayed template numbers."
  done
}

write_new_app_files() {
  local target_dir="$1"
  local application_id="$2"
  local app_name="$3"
  local template="$4"
  local package_path
  local escaped_app_name
  local escaped_json_app_name
  local runnable="true"
  local plugin_id="com.android.application"

  package_path="$(to_package_path "${application_id}")"
  escaped_app_name="$(escape_xml "${app_name}")"
  escaped_json_app_name="$(escape_json "${app_name}")"

  if ! template_is_runnable "${template}"; then
    runnable="false"
  fi
  if [[ "${template}" == "android-library" ]]; then
    plugin_id="com.android.library"
  fi

  mkdir -p \
    "${target_dir}/.android-dev" \
    "${target_dir}/app/src/main/res/values"

  if [[ "${template}" != "no-activity" ]]; then
    mkdir -p "${target_dir}/app/src/main/java/${package_path}"
  fi

  cat >"${target_dir}/settings.gradle.kts" <<EOF
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "${app_name}"
include(":app")
EOF

  if [[ "${template}" == "compose-activity" ]]; then
    cat >"${target_dir}/build.gradle.kts" <<'EOF'
plugins {
    id("com.android.application") version "9.2.0" apply false
    id("com.android.library") version "9.2.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.3.21" apply false
}
EOF
  else
    cat >"${target_dir}/build.gradle.kts" <<'EOF'
plugins {
    id("com.android.application") version "9.2.0" apply false
    id("com.android.library") version "9.2.0" apply false
}
EOF
  fi

  if [[ "${template}" == "android-library" ]]; then
    cat >"${target_dir}/app/build.gradle.kts" <<EOF
plugins {
    id("${plugin_id}")
}

android {
    namespace = "${application_id}"
    compileSdk = 36

    defaultConfig {
        minSdk = 23
    }
}
EOF
  elif [[ "${template}" == "compose-activity" ]]; then
    cat >"${target_dir}/app/build.gradle.kts" <<EOF
plugins {
    id("${plugin_id}")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "${application_id}"
    compileSdk = 36

    defaultConfig {
        applicationId = "${application_id}"
        minSdk = 23
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.05.00"))
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.compose.material3:material3")
}
EOF
  else
    cat >"${target_dir}/app/build.gradle.kts" <<EOF
plugins {
    id("${plugin_id}")
}

android {
    namespace = "${application_id}"
    compileSdk = 36

    defaultConfig {
        applicationId = "${application_id}"
        minSdk = 23
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }
}
EOF
  fi

  cat >"${target_dir}/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
EOF

  cat >"${target_dir}/.gitignore" <<'EOF'
.gradle/
local.properties
**/build/
EOF

  if [[ "${template}" == "android-library" ]]; then
    cat >"${target_dir}/app/src/main/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" />
EOF
  elif [[ "${template}" == "no-activity" ]]; then
    cat >"${target_dir}/app/src/main/AndroidManifest.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:allowBackup="true"
        android:label="@string/app_name"
        android:theme="@style/AppTheme" />
</manifest>
EOF
  else
    cat >"${target_dir}/app/src/main/AndroidManifest.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:allowBackup="true"
        android:label="@string/app_name"
        android:theme="@style/AppTheme">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF
  fi

  cat >"${target_dir}/app/src/main/res/values/strings.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">${escaped_app_name}</string>
</resources>
EOF

  cat >"${target_dir}/app/src/main/res/values/themes.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="@android:style/Theme.Material.Light.NoActionBar" />
</resources>
EOF

  case "${template}" in
    basic-activity)
      cat >"${target_dir}/app/src/main/java/${package_path}/MainActivity.kt" <<EOF
package ${application_id}

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.widget.TextView

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContentView(
            TextView(this).apply {
                text = "Hello Android"
                textSize = 24f
                gravity = Gravity.CENTER
            },
        )
    }
}
EOF
      ;;
    empty-activity)
      cat >"${target_dir}/app/src/main/java/${package_path}/MainActivity.kt" <<EOF
package ${application_id}

import android.app.Activity
import android.os.Bundle

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
}
EOF
      ;;
    compose-activity)
      cat >"${target_dir}/app/src/main/java/${package_path}/MainActivity.kt" <<EOF
package ${application_id}

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface {
                    Text("Hello Android")
                }
            }
        }
    }
}
EOF
      ;;
    android-library)
      cat >"${target_dir}/app/src/main/java/${package_path}/AndroidLibrary.kt" <<EOF
package ${application_id}

class AndroidLibrary {
    fun greeting(): String = "Hello Android"
}
EOF
      ;;
    no-activity)
      ;;
  esac

  cat >"${target_dir}/.android-dev/project.json" <<EOF
{
  "schemaVersion": 1,
  "projectName": "${escaped_json_app_name}",
  "template": "${template}",
  "applicationId": "${application_id}",
  "mainModule": "app",
  "runnable": ${runnable},
  "createdBy": "android-devcontainer"
}
EOF
}
