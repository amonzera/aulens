# Aulens Development Runbook

This document is the practical step-by-step guide for developing, testing, building, and deploying Aulens from Fedora without polluting the host system.

Use this when setting up a new PC, starting a daily development session, or deploying the app directly to an Android phone over Wi-Fi.

Canonical project context:

- `AGENTS.md`: AI/developer rules and preservation constraints.
- `docs/ARCHITECTURE.md`: architecture map, technologies, workflows, and roadmap.
- `docs/DEVELOPMENT.md`: operational workflow for setup, validation, and deployment.

## Strategy

Recommended default: Fedora Toolbox backed by rootless Podman.

Why:

- Keeps Flutter, Android SDK, Gradle cache, Pub cache, Java, Chrome, and native build packages outside the host package database.
- Works better than a raw Podman container for interactive mobile development.
- Avoids Docker daemon assumptions.
- Still lets you use the editor on the host and the toolchain inside the toolbox.

Alternatives:

- Distrobox: also good, but adds another tool if Toolbox already works.
- Raw Podman: good later for CI-like checks, less ergonomic for ADB/mobile iteration.
- Dev Containers: good for team IDE reproducibility, still needs ADB/network handling.
- Host install: simpler, but intentionally avoided for this repository.

## First Setup On A Fedora PC

Clone or copy the repository first. In the commands below, replace `<repo-path>` with the local checkout path, for example `/path/to/aulens`.

Run these commands on the host:

```bash
cd <repo-path>
toolbox create --release 44 --container aulens-dev
toolbox enter aulens-dev
```

What this means:

- `toolbox create` creates a mutable Fedora development container.
- `--release 44` uses Fedora 44, matching the current host generation.
- `--container aulens-dev` gives the container a stable name.
- `toolbox enter` opens a shell inside the container.

If the container already exists, skip creation and run only:

```bash
toolbox enter aulens-dev
```

Inside the toolbox, go back to the repository:

```bash
cd <repo-path>
```

Install packages into the toolbox, not the host:

```bash
sudo dnf install -y git curl unzip zip xz tar which findutils clang cmake ninja-build gtk3-devel pkgconf-pkg-config chromium android-tools
```

What these packages do:

- `git`, `curl`, `unzip`, `zip`, `xz`, `tar`, `which`, `findutils`: basic development tools.
- `clang`, `cmake`, `ninja-build`, `gtk3-devel`, `pkgconf-pkg-config`: native toolchain for Linux desktop checks if needed.
- `chromium`: browser runtime for web testing if needed.
- `android-tools`: gives an early `adb`; the project-scoped SDK `platform-tools` installed later should be preferred.

Do not install or use `java-latest-openjdk-devel` for this project. On Fedora 44 it may resolve to Java 26, which is too new for the current Android Gradle toolchain.

## Project-Scoped Toolchain

All SDKs and caches should live under `.dev/aulens`, which is ignored by Git.

From the repository root inside the toolbox:

```bash
export AULENS_DEV_HOME="$PWD/.dev/aulens"
export PUB_CACHE="$AULENS_DEV_HOME/pub-cache"
export GRADLE_USER_HOME="$AULENS_DEV_HOME/gradle"
export JAVA_HOME="$AULENS_DEV_HOME/jdks/jdk-21"
export ANDROID_HOME="$AULENS_DEV_HOME/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$AULENS_DEV_HOME/android-user"
export PATH="$JAVA_HOME/bin:$AULENS_DEV_HOME/flutter/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
mkdir -p "$AULENS_DEV_HOME/downloads" "$AULENS_DEV_HOME/jdks" "$ANDROID_HOME/cmdline-tools"
```

Meaning:

- `AULENS_DEV_HOME`: local prefix for all development tools.
- `PUB_CACHE`: keeps Dart/Flutter packages out of `~/.pub-cache`.
- `GRADLE_USER_HOME`: keeps Gradle caches out of `~/.gradle`.
- `JAVA_HOME`: pins Android/Gradle to a project-scoped JDK 21.
- `ANDROID_HOME` and `ANDROID_SDK_ROOT`: point Android tooling to the isolated SDK.
- `ANDROID_USER_HOME`: keeps Android user state out of `~/.android`.
- `PATH`: makes isolated Flutter, `adb`, and `sdkmanager` available in this shell.

These exports last only for the current shell. For daily use, save them in `.dev/aulens/env.sh` and run `source .dev/aulens/env.sh` whenever you enter the toolbox.

Suggested `.dev/aulens/env.sh` content:

```bash
export AULENS_DEV_HOME="$PWD/.dev/aulens"
export PUB_CACHE="$AULENS_DEV_HOME/pub-cache"
export GRADLE_USER_HOME="$AULENS_DEV_HOME/gradle"
export JAVA_HOME="$AULENS_DEV_HOME/jdks/jdk-21"
export ANDROID_HOME="$AULENS_DEV_HOME/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$AULENS_DEV_HOME/android-user"
export PATH="$JAVA_HOME/bin:$AULENS_DEV_HOME/flutter/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
```

## Install JDK 21

Android Gradle builds should use JDK 21 for this repository. Do not use Fedora's `java-latest-openjdk-devel` package here; it can install Java 26 and fail Gradle with a terse `26.0.1` error.

Install a project-scoped JDK 21 inside `.dev/aulens`:

```bash
mkdir -p "$AULENS_DEV_HOME/downloads" "$AULENS_DEV_HOME/jdks"
curl -L -o "$AULENS_DEV_HOME/downloads/temurin-21-jdk.tar.gz" "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse"
tar -xzf "$AULENS_DEV_HOME/downloads/temurin-21-jdk.tar.gz" -C "$AULENS_DEV_HOME/jdks"
JDK21_DIR="$(find "$AULENS_DEV_HOME/jdks" -maxdepth 1 -type d -name 'jdk-21*' | sort | tail -n 1)"
rm -rf "$AULENS_DEV_HOME/jdks/jdk-21"
ln -s "$JDK21_DIR" "$AULENS_DEV_HOME/jdks/jdk-21"
source .dev/aulens/env.sh
java -version
```

Expected result: `java -version` should print Java 21, not Java 25 or Java 26.

## Install Flutter

Inside the toolbox:

```bash
git clone https://github.com/flutter/flutter.git "$AULENS_DEV_HOME/flutter"
git -C "$AULENS_DEV_HOME/flutter" checkout stable
flutter --version
```

What this does:

- Installs Flutter inside `.dev/aulens/flutter`.
- Uses the stable channel, which is the right default for app development.
- Warms the Flutter cache and verifies the binary works.

If Flutter already exists, update it later with:

```bash
git -C "$AULENS_DEV_HOME/flutter" pull
flutter doctor -v
```

## Install Android SDK

Install Android command-line tools into:

```text
.dev/aulens/android-sdk/cmdline-tools/latest
```

As of 2026-05-11, the official Linux command-line tools ZIP is:

```text
https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip
```

When setting up a different PC later, check the official Android Studio "Command line tools only" page and replace the URL if Google has published a newer package.

Inside the toolbox:

```bash
mkdir -p "$AULENS_DEV_HOME/downloads" "$ANDROID_HOME/cmdline-tools/latest"
curl -L -o "$AULENS_DEV_HOME/downloads/commandlinetools-linux_latest.zip" "https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip"
unzip -q "$AULENS_DEV_HOME/downloads/commandlinetools-linux_latest.zip" -d "$AULENS_DEV_HOME/downloads/android-cmdline-tools"
mv "$AULENS_DEV_HOME/downloads/android-cmdline-tools/cmdline-tools/"* "$ANDROID_HOME/cmdline-tools/latest/"
```

Then install SDK packages:

```bash
sdkmanager --sdk_root="$ANDROID_HOME" "cmdline-tools;latest" "platform-tools" "platforms;android-36" "build-tools;36.0.0"
sdkmanager --sdk_root="$ANDROID_HOME" --licenses
flutter config --android-sdk "$ANDROID_HOME"
flutter doctor -v
```

What this means:

- `platform-tools`: installs project-scoped `adb`.
- `platforms;android-36`: installs Android API 36, matching the current Flutter Gradle defaults.
- `build-tools;36.0.0`: installs Android build tools for API 36.
- `--licenses`: accepts required Android SDK licenses.
- `flutter config --android-sdk`: tells Flutter to use the isolated SDK.
- `flutter doctor -v`: reports whether Android, web, and desktop toolchains are ready.

If Gradle previously ran with Java 25/26, stop old daemons before rebuilding:

```bash
cd android
./gradlew --stop
cd ..
```

## Daily Development Start

Each time you start development:

```bash
cd <repo-path>
toolbox enter aulens-dev
cd <repo-path>
source .dev/aulens/env.sh
flutter doctor -v
```

Before building, verify the shell is using the isolated toolchain:

```bash
which java
java -version
echo "$GRADLE_USER_HOME"
```

Expected:

- `which java` points under `.dev/aulens/jdks/jdk-21`.
- `java -version` prints Java 21.
- `GRADLE_USER_HOME` points under `.dev/aulens/gradle`, not `~/.gradle`.

Then run:

```bash
flutter pub get
flutter analyze
flutter test
```

Use this before committing broader changes:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```

For Android-specific changes, also run the debug APK build in the phone deployment section below.

## Test On Xiaomi Redmi Note 14 Pro Over Wi-Fi

Use a physical Android device for Aulens. Camera, permissions, gallery save, and ML Kit OCR cannot be trusted from web/Linux-only checks.

Phone preparation:

1. Connect the phone and computer to the same trusted Wi-Fi network.
2. On the phone, open Settings.
3. Open About phone.
4. Tap the OS/build version entry repeatedly until Developer options are enabled.
5. Open Developer options.
6. Enable Wireless debugging.
7. On Xiaomi/HyperOS/MIUI, also enable USB debugging, Install via USB, and USB debugging security settings if those options exist and installation is blocked.

Pair the phone:

1. On the phone, open Wireless debugging.
2. Tap "Pair device with pairing code".
3. Android will show an IP, a pairing port, and a pairing code.
4. Inside the toolbox, run:

```bash
adb kill-server
adb start-server
adb pair <phone-ip>:<pairing-port>
```

Enter the pairing code shown on the phone.

Connect for debugging:

1. Go back to the Wireless debugging screen.
2. Use the IP and debugging port shown there. This is not always the same as the pairing port.
3. Inside the toolbox:

```bash
adb connect <phone-ip>:<debug-port>
adb devices
flutter devices
```

Expected result:

- `adb devices` should show the phone as `device`.
- `flutter devices` should show the Redmi as an Android device.

If the phone appears as `unauthorized`, unlock the phone and accept the debugging prompt.

If pairing works but Flutter does not see the device:

```bash
adb kill-server
adb start-server
adb connect <phone-ip>:<debug-port>
flutter devices
```

## Run The App On The Phone

Use this for normal development:

```bash
flutter run -d <device-id>
```

What it does:

- Builds a debug version.
- Installs it directly on the phone through ADB Wi-Fi.
- Starts the app.
- Enables hot reload while the command keeps running.

Useful Flutter run commands:

```text
r  hot reload
R  hot restart
q  quit run session
```

If you only want to build and install without a live run session:

```bash
flutter build apk --debug
flutter install -d <device-id>
```

No manual APK copy is needed in either flow.

## Manual Test Checklist On Device

Run this checklist after deploying to the phone:

1. Open the app.
2. Create a subject.
3. Create a schedule entry for the current day/time.
4. Confirm class detection opens or offers class mode when inside the time window.
5. Capture a whiteboard/photo note.
6. Confirm the note is saved immediately.
7. Wait for OCR to finish.
8. Search for a word from the captured image.
9. Open the note detail screen.
10. Test a manual text note.
11. Test subject timeline grouping.
12. Test PDF export if the touched change affects export.
13. Test deleting a note only removes managed app-storage images.

## Development Deploy Scope

Debug deploy is enough for:

- Feature development.
- Camera/OCR testing.
- Permission validation.
- Local data flow validation.
- UI iteration with hot reload.

## Release Build And Production Deploy

Do not publish a production build until these items are fixed:

- Replace Android package ID `com.example.aulens`.
- Configure release signing with a real keystore.
- Review Android app name, icons, permissions, and Play Store target requirements.
- Validate camera, storage, gallery save, OCR, search, and export on a physical Android device.
- Decide whether web/desktop are supported products or compile-only targets.

After release identity/signing is configured, production-style builds should use:

```bash
flutter build appbundle
```

For local APK release smoke tests:

```bash
flutter build apk --release
flutter install -d <device-id>
```

## Troubleshooting

ADB device is missing:

```bash
adb kill-server
adb start-server
adb devices
```

Phone is paired but disconnected:

```bash
adb connect <phone-ip>:<debug-port>
```

Phone is unauthorized:

- Unlock the phone.
- Accept the debug prompt.
- Disable and re-enable Wireless debugging.
- Pair again if needed.

Install fails on Xiaomi/HyperOS:

- Enable USB debugging.
- Enable Install via USB if available.
- Enable USB debugging security settings if available.
- Remove any old debug install of Aulens from the phone.
- Try `flutter clean`, then `flutter pub get`, then `flutter run`.

Gradle fails with `26.0.1`:

- Cause: the toolbox is using Java 26 from `java-latest-openjdk-devel`.
- If the error path mentions `/home/<user>/.gradle`, the isolated environment was not sourced.
- Fix: source `.dev/aulens/env.sh`, confirm Java 21, stop old Gradle daemons, and rebuild.

```bash
source .dev/aulens/env.sh
which java
java -version
echo "$GRADLE_USER_HOME"
cd android
./gradlew --stop
cd ..
flutter clean
flutter pub get
flutter build apk --debug
```

Gradle daemon disappears unexpectedly:

- Cause: the daemon may have been killed by memory pressure.
- This project keeps Gradle memory bounded in `android/gradle.properties` with a small heap, no persistent daemon, no parallel Gradle execution, one worker, and Jetifier disabled.
- If this returns after changing Gradle settings, stop daemons and retry from a fresh shell with `.dev/aulens/env.sh` sourced.

Flutter cannot find Android SDK:

```bash
source .dev/aulens/env.sh
flutter config --android-sdk "$ANDROID_HOME"
flutter doctor -v
```

Gradle or Pub downloads go to the wrong place:

```bash
echo "$PUB_CACHE"
echo "$GRADLE_USER_HOME"
echo "$ANDROID_HOME"
```

They should all point under:

```text
<repo-path>/.dev/aulens
```

## Official References

- Flutter Android setup: <https://docs.flutter.dev/platform-integration/android/setup>
- Flutter Android build/release: <https://docs.flutter.dev/deployment/android>
- Android physical device and wireless debugging: <https://developer.android.com/studio/run/device>
- Android Debug Bridge: <https://developer.android.com/tools/adb>
- Android SDK Manager: <https://developer.android.com/tools/sdkmanager>
- Toolbx project overview: <https://containertoolbx.org/>
