#!/usr/bin/env bash
set -euo pipefail

echo "Java:"
java -version

echo
echo "Android SDK:"
sdkmanager --version

echo
echo "ADB:"
adb version

echo
echo "Installed SDK packages:"
sdkmanager --list_installed
