# SplitFast: Developer Setup Guide

A comprehensive reference for setting up the development environment from scratch — covering prerequisites, API keys, Android toolchain, wireless debugging, and daily dev workflow.

---

## Table of Contents
1. [Prerequisites](#1-prerequisites)
2. [Clone & Install Dependencies](#2-clone--install-dependencies)
3. [API Key Setup (.env)](#3-api-key-setup-env)
4. [Ubuntu & Java Setup (Fixing Gradle Issues)](#4-ubuntu--java-setup-fixing-gradle-issues)
5. [Android Wireless Debugging (No USB Cable)](#5-android-wireless-debugging-no-usb-cable)
6. [Running the App](#6-running-the-app)
7. [Daily Dev Loop](#7-daily-dev-loop)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Prerequisites

Before anything else, make sure the following are installed on your machine:

| Tool | Version Required | Check Command |
|---|---|---|
| Flutter SDK | >= 3.16.0 | `flutter --version` |
| Dart SDK | >= 3.2.0 | `dart --version` |
| Java (JDK) | 17 (required for Gradle) | `java -version` |
| Android SDK | via Android Studio or CLI | `adb version` |
| ADB | Any recent version | `adb version` |

> **Physical device required.** This app uses the native camera (ML Kit), UPI deep links, and WhatsApp intents — none of which work on web, desktop, or most emulators. Always run on a real Android phone.

---

## 2. Clone & Install Dependencies

```bash
git clone https://github.com/Aditya0908/splitfast.git
cd splitfast
flutter pub get
```

> **Note:** If you've just added or changed anything in `pubspec.yaml`, always run `flutter pub get` before running the app. Hot Reload will not pick up new packages.

---

## 3. API Key Setup (.env)

This app calls the **Gemini API** for bill parsing. The key is loaded at runtime from a `.env` file using `flutter_dotenv`.

**Step 1:** Create a `.env` file in the project root (same level as `pubspec.yaml`):

```bash
touch .env
```

**Step 2:** Add your Gemini API key:

```env
GEMINI_API_KEY=your_gemini_api_key_here
```

Get a free key at: https://aistudio.google.com/app/apikey

> **Security:** `.env` is listed in `.gitignore` and will never be committed. The `.env.example` file is a safe template committed to the repo.

> **Important:** The `.env` file is declared as a Flutter asset in `pubspec.yaml`. Do **not** rename it or move it out of the root directory or the app will crash on startup.

---

## 4. Ubuntu & Java Setup (Fixing Gradle Issues)

Flutter Android builds require **Java 17**. If you see Gradle errors like `Unsupported class file major version` or `Could not determine Java version`, follow these steps.

**Install Java 17:**

```bash
sudo apt update
sudo apt install openjdk-17-jdk
```

**Set JAVA_HOME** (if Gradle can't find Java):

Open your bash profile:
```bash
nano ~/.bashrc
```

Add these lines at the bottom:
```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
```

Apply immediately:
```bash
source ~/.bashrc
```

Verify:
```bash
java -version
# Should print: openjdk version "17.x.x"
```

---

## 5. Android Wireless Debugging (No USB Cable)

Connect your Android phone to the development machine over Wi-Fi. Both devices must be on the **same Wi-Fi network**.

### Step A: On the Android Phone

1. Go to **Settings → Developer Options**
2. Enable **Wireless Debugging**
3. Tap on **"Wireless Debugging"** to open its submenu
4. Tap **"Pair device with pairing code"**
5. Note the **IP address**, **pairing port**, and **6-digit code** shown (e.g., `192.168.1.5:43567`, Code: `123456`)

> If Developer Options is not visible: go to **Settings → About Phone** and tap **Build Number** 7 times.

### Step B: On the Ubuntu Terminal

**Pair the device** (use the IP:port from the pairing screen):
```bash
adb pair 192.168.1.5:43567
# Enter the 6-digit code when prompted
```

**Connect ADB** (after pairing, go back to the main Wireless Debugging screen — it shows a *different* connection port):
```bash
adb connect 192.168.1.5:38000
```

**Verify Flutter sees the device:**
```bash
flutter devices
# Your phone should appear in the list
```

---

## 6. Running the App

Once your device is connected:

```bash
flutter run
```

For a release build (faster, no debug overhead):
```bash
flutter run --release
```

To target a specific device if multiple are connected:
```bash
flutter devices          # list device IDs
flutter run -d <device-id>
```

---

## 7. Daily Dev Loop

### Hot Reload vs Hot Restart

Once the app is running in the terminal, keep it open and use keyboard shortcuts:

| Key | Action | When to use |
|---|---|---|
| `r` | **Hot Reload** | UI changes, widget tweaks (~1 sec, keeps state) |
| `R` | **Hot Restart** | Logic changes, provider state changes (~3 sec, clears state) |
| `h` | Help | List all available commands |
| `q` | Quit | Stop the app |

### After Adding a New Package

Hot Reload does **not** pick up new native dependencies. You must:

```bash
# Press q to quit first, then:
flutter pub get
flutter run
```

### After Changing AndroidManifest.xml

A full restart is required:
```bash
flutter run
```

---

## 8. Troubleshooting

### ADB Device Disconnects / Hangs

```bash
adb kill-server
adb start-server
adb connect <YOUR_PHONE_IP>:<PORT>
```

### `flutter pub get` Fails / Package Version Conflict

```bash
flutter clean
flutter pub get
```

### Gradle Build Fails

```bash
cd android
./gradlew clean
cd ..
flutter run
```

If it still fails, check that `JAVA_HOME` is pointing to Java 17 (see Section 4).

### `.env` File Not Found / App Crashes on Startup

- Make sure `.env` exists in the project **root** directory (same level as `pubspec.yaml`)
- Make sure it contains a valid `GEMINI_API_KEY=...` line
- Run `flutter pub get` after creating it — Flutter needs to register it as an asset

### Contacts or Camera Permission Denied

The app requests permissions at runtime. If you denied them previously:
- Go to **Phone Settings → Apps → SplitFast → Permissions**
- Enable Camera and Contacts manually

### UPI Link Shows "Banking Name Not Found" in GPay

This is expected behavior when you click your **own** UPI link on the **same device/account** that the UPI ID belongs to. GPay blocks self-payment via deep links.

**To test correctly:** Send the WhatsApp message to a friend and have them tap the link, or use a secondary device with a different bank account.

### WhatsApp Intent Does Nothing

- Make sure WhatsApp is installed on the device
- Check that the phone number in the contact is a 10-digit Indian number (the app auto-prepends `+91`)
- Verify the `<queries>` block in `AndroidManifest.xml` includes `<package android:name="com.whatsapp" />`
