# Alisto

Alisto is a Flutter mobile application for family members and caregivers who look after elderly loved ones. It works together with the Alisto device, a Raspberry Pi based emergency unit, and the Alisto web platform. When the device raises an alert, the app notifies the family immediately with an audible alarm, shows the device's location, and keeps a history of past alerts.

## Features

- **Emergency alerts** - Real-time push notifications through Firebase Cloud Messaging. On Android, a native foreground service plays a loud alarm with continuous vibration, even when the app is in the background or closed. Alerts stay on screen until a family member acknowledges them.
- **Device registration** - Step-by-step onboarding that connects the device to home Wi-Fi through its setup hotspot, then links it to an account by scanning its QR code or entering its serial number.
- **Device status and location** - Live online/offline status and the device's last known GPS position, shown on an OpenStreetMap map.
- **Loved ones** - Profiles for each elderly family member, including personal details, photo, linked device, and emergency contacts.
- **Medicine reminders** - Scheduled medication reminders with daily or interval-based schedules.
- **Alert history** - A record of past alerts with their response status, with options to respond to or delete entries.
- **Account management** - Registration, sign-in, password reset, password change, and profile editing through Firebase Authentication.

## Tech Stack

| Area | Technology |
| --- | --- |
| Framework | Flutter (Dart SDK ^3.13.1) |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Notifications | Firebase Cloud Messaging, native Android services (Kotlin) |
| Maps | flutter_map with OpenStreetMap tiles |
| Device pairing | mobile_scanner (QR codes), HTTP requests to the device |

## Project Structure

```
lib/
  main.dart              App entry point and foreground notification handling
  models/                Data models for users, devices, alerts, and loved ones
  screens/               UI screens (auth, home, loved ones, history, settings, device setup)
  services/              Firebase, authentication, notification, and alarm services
  theme/                 Colors, typography, and shared theme configuration
  widgets/               Reusable UI components
android/app/src/main/kotlin/
  AlistoMessagingService.kt   Receives emergency push messages
  EmergencyAlarmService.kt    Foreground service that plays the alarm
assets/images/           App illustrations and logo
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) compatible with Dart 3.13 or later
- Android Studio or VS Code with the Flutter extension
- An Android device or emulator
- Access to the Alisto Firebase project, or your own Firebase project

### Firebase Configuration

Firebase configuration files are not included in this repository. Generate them before running the app:

1. Install the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup):
   ```bash
   dart pub global activate flutterfire_cli
   ```
2. Sign in to Firebase and configure the project:
   ```bash
   firebase login
   flutterfire configure
   ```

This creates `lib/firebase_options.dart` and `android/app/google-services.json`. For iOS, it also creates `ios/Runner/GoogleService-Info.plist`.

### Installation

```bash
git clone https://github.com/GelBellita/Alisto_App.git
cd Alisto_App
flutter pub get
flutter run
```

## Device Wi-Fi Setup

During registration, the phone connects to the device's temporary `Alisto-Setup` hotspot. The app then sends the home Wi-Fi credentials to the device at `http://10.42.0.1:5000`. Once the device is online, registration continues with the device's serial number.

## Related Components

Alisto has three parts:

- **Alisto App** (this repository) - Mobile app for families and caregivers
- **Alisto Device** - Raspberry Pi unit that detects emergencies and reports status and location
- **Alisto Web** - Web platform for administration and backend services
