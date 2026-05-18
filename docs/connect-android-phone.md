# Connect an Android Phone

This guide explains how to make a physical Android phone available to the Dev Container.

## Recommended Path: Wireless Debugging

Wireless debugging is the most portable path across Windows, macOS, Linux, and containerized development.

### Requirements

* Android 11 or newer on the phone
* Phone and workstation on the same Wi-Fi network
* Developer options enabled on the phone
* Wireless debugging enabled on the phone

### Pair the Device with the Dev Container

1. On the phone, open **Developer options**.
2. Open **Wireless debugging**.
3. Choose **Pair device with pairing code**.
4. Note the IP address, pairing port, and pairing code shown on the phone.
5. From inside the Dev Container, run:

```bash
bash .devcontainer/scripts/android-dev.sh pair-device <ip:pairing-port>
```

6. Enter the pairing code when prompted.
7. Use the IP address and connection port shown by the phone to connect:

```bash
bash .devcontainer/scripts/android-dev.sh connect-device <ip:connect-port>
```

8. Verify the device:

```bash
bash .devcontainer/scripts/android-dev.sh devices
```

If the phone was paired but does not reconnect automatically later, run `connect-device` again with the current connection port shown by the phone.

The wireless debugging connection port can change between sessions. Always use the current main port shown on the phone, and treat `devices` output as the source of truth after connection.

If pairing fails, check whether the Dev Container can reach the phone:

```bash
bash .devcontainer/scripts/android-dev.sh network-check <ip>
bash .devcontainer/scripts/android-dev.sh network-check <ip> <pairing-port>
```

`network-check` can also be run from the host shell because it only needs network tools. Commands such as `pair-device`, `connect-device`, and `devices` require ADB, so run them inside the Dev Container unless Android platform-tools are installed on the host too.

## Android Studio QR Flow

If Android Studio on the host will manage the device connection:

1. In Android Studio, choose **Pair Devices Using Wi-Fi**.
2. On the phone, choose **Pair device with QR code**.
3. Scan the QR code shown by Android Studio.

This pairs the phone with the host-side Android Studio/ADB workflow. It does not automatically pair the Dev Container's own ADB server.

## USB Notes

USB can still be useful, especially for older devices, but it is host-dependent.

### Windows

* Enable USB debugging on the phone.
* Install the OEM USB driver when the device vendor requires one.

### macOS

* Enable USB debugging on the phone.
* No extra USB driver is usually required.

### Linux

* Enable USB debugging on the phone.
* Configure host-side `udev` rules or install the distro package that provides Android device rules.
* Confirm that the host user has permission to access the device.

## Common Checks

Run:

```bash
bash .devcontainer/scripts/android-dev.sh devices
```

If no authorized device appears:

* confirm that debugging is enabled on the phone
* unlock the phone and accept any RSA authorization prompt
* for wireless debugging, confirm that the phone and workstation are on the same Wi-Fi network
* for wireless debugging, reconnect with the current phone connection port if needed
