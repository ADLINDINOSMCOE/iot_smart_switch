# Final APK/AAB Build and Test Guide

This guide covers the final build and testing process for the IoT Switch Android application.

## Prerequisites

- Flutter SDK 3.7.2 or higher
- Android SDK with API level 33 or higher
- Java Development Kit (JDK) 11 or higher
- Gradle 7.0 or higher
- Physical Android device or Android Emulator
- Firebase project configured for production

## Build Configuration

### 1. Verify Build Configuration

Check `android/app/build.gradle.kts`:
```kotlin
android {
    namespace = "com.example.iotswitch"
    compileSdk = 34
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.iotswitch"
        minSdk = 23
        targetSdk = 34
        versionCode = 3
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

### 2. Create Signing Configuration (Production)

For production, create a keystore:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Update `android/key.properties` (do not commit to version control):
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

Update `android/app/build.gradle.kts` for production signing:
```kotlin
def keystorePropertiesFile = rootProject.file("key.properties")
def keystoreProperties = new Properties()
keystoreProperties.load(new FileInputStream(keystorePropertiesFile))

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties["keyAlias"]
            keyPassword keystoreProperties["keyPassword"]
            storeFile keystoreProperties["storeFile"] ? file(keystoreProperties["storeFile"]) : null
            storePassword keystoreProperties["storePassword"]
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.release
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

## Build Process

### 1. Clean Build

```bash
cd "/Users/adlinthomas/flutter project/iotswitch"
flutter clean
flutter pub get
```

### 2. Debug APK Build

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### 3. Release APK Build

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### 4. App Bundle Build (Play Store)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### 5. Build Variants

Build for specific architectures:
```bash
flutter build apk --release --split-per-abi
```

This creates separate APKs for:
- app-armeabi-v7a-release.apk (32-bit ARM)
- app-arm64-v8a-release.apk (64-bit ARM)
- app-x86_64-release.apk (x86_64)

## Testing Checklist

### Pre-Build Tests

- [ ] All Flutter tests pass: `flutter test`
- [ ] Code analysis passes: `flutter analyze`
- [ ] No dependency conflicts: `flutter pub outdated`
- [ ] Firebase configuration is correct
- [ ] Security rules are deployed
- [ ] Firestore indexes are deployed
- [ ] Cloud Functions are deployed

### Post-Build Tests

#### Installation Tests
- [ ] APK installs successfully on device
- [ ] App icon appears correctly
- [ ] App launches without crashes
- [ ] First-time setup flow works

#### Authentication Tests
- [ ] Email/password login works
- [ ] Google Sign-In works
- [ ] Registration flow works
- [ ] Email verification works
- [ ] Password reset works
- [ ] Remember Me works
- [ ] Logout works

#### Device Control Tests
- [ ] Add device works
- [ ] Device list displays correctly
- [ ] Switch control works (ON/OFF)
- [ ] Real-time updates work
- [ ] Device sharing works
- [ ] Owner permissions work
- [ ] Editor permissions work
- [ ] Viewer permissions work

#### Scheduling Tests
- [ ] Create schedule works
- [ ] Edit schedule works
- [ ] Delete schedule works
- [ ] Schedule execution works
- [ ] Recurring schedules work
- [ ] Timezone handling works

#### Timer Tests
- [ ] Start timer works
- [ ] Timer countdown works
- [ ] Timer completion works
- [ ] Cancel timer works
- [ ] Timer history displays

#### Network Tests
- [ ] Offline handling works
- [ ] Network error messages display
- [ ] Reconnection works
- [ ] Cached state works

#### Notification Tests
- [ ] Notifications display
- [ ] Notification settings work
- [ ] Permission handling works
- [ ] Background notifications work

#### Performance Tests
- [ ] App starts in < 3 seconds
- [ ] No ANR (Application Not Responding) errors
- [ ] Memory usage is reasonable
- [ ] Battery usage is acceptable
- [ ] APK size is optimized

#### Security Tests
- [ ] Data encryption works
- [ ] Authentication persists securely
- [ ] No sensitive data in logs
- [ ] ProGuard obfuscation works
- [ ] Certificate pinning works

## Automated Testing

### UI Tests with Flutter Driver

Create `test_driver/app_test.dart`:
```dart
import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart' as test;

void main() {
  group('IoT Switch App Tests', () {
    FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      await driver?.close();
    });

    test('Login flow', () async {
      await driver.tap(find.byValueKey('email_field'));
      await driver.enterText('test@example.com');
      await driver.tap(find.byValueKey('password_field'));
      await driver.enterText('password123');
      await driver.tap(find.byValueKey('login_button'));
      await driver.waitFor(find.byValueKey('home_screen'));
    });

    test('Device control', () async {
      await driver.tap(find.byValueKey('device_1'));
      await driver.waitFor(find.byValueKey('device_detail'));
      await driver.tap(find.byValueKey('toggle_switch'));
      await driver.waitFor(find.text('ON'));
    });
  });
}
```

Run UI tests:
```bash
flutter drive --target=test_driver/app.dart
```

### Integration Tests

Run all tests:
```bash
flutter test
```

Run specific test file:
```bash
flutter test test/unit_tests.dart
flutter test test/widget_tests.dart
```

## Performance Profiling

### Build Size Analysis

```bash
flutter build apk --analyze-size
```

### Code Obfuscation

ProGuard obfuscation is enabled in release builds. To verify:
```bash
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep classes.dex
```

### Memory Profiling

Use Android Studio Profiler:
1. Run app in profile mode: `flutter run --profile`
2. Open Android Studio Profiler
3. Monitor memory usage, CPU, and network

## Deployment

### Internal Testing

Upload to Firebase App Distribution:
```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app 1:1234567890:android:abcdef123456 \
  --groups "internal-testers"
```

### Play Store Upload

Upload AAB to Google Play Console:
```bash
# Manual upload via Google Play Console
# or use command-line tools
```

## Troubleshooting

### Common Build Issues

**1. Gradle dependency resolution errors**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

**2. Dex Overflow Error**
Add `multiDexEnabled = true` to build.gradle.kts (already included)

**3. ProGuard obfuscation issues**
Check `proguard-rules.pro` for missing keep rules

**4. Signing configuration errors**
Verify `key.properties` exists and has correct values

### Common Runtime Issues

**1. Firebase initialization failure**
- Check `google-services.json` is present
- Verify Firebase project configuration
- Check internet connectivity

**2. Authentication failures**
- Verify Firebase Auth is enabled
- Check email verification settings
- Review authentication provider configuration

**3. Firestore permission errors**
- Verify security rules are deployed
- Check user has proper permissions
- Review collection structure

## Continuous Integration

### GitHub Actions Workflow

Create `.github/workflows/build.yml`:
```yaml
name: Build and Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.7.2'
      - run: flutter pub get
      - run: flutter test
      - run: flutter analyze
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v3
        with:
          name: release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

## Release Notes Template

```markdown
## Version 1.0.0 (Build 3)

### Features
- Real-time device control
- Scheduling automation
- Timer functionality
- Device sharing with RBAC
- Push notifications
- Offline support

### Improvements
- Enhanced security with TLS 1.3
- Anti-replay protection
- Energy tracking
- Network error handling

### Bug Fixes
- Fixed authentication persistence
- Fixed scheduling timezone issues
- Fixed notification permissions

### Known Issues
- iOS build requires manual codesigning
- ESP32 requires manual provisioning

### Installation
- Download APK from release page
- Enable "Unknown sources" in settings
- Install APK
```

## Final Verification

Before release, verify:
- [ ] All tests pass
- [ ] APK size is optimized (< 50MB)
- [ ] No critical security vulnerabilities
- [ ] Performance benchmarks met
- [ ] User documentation is complete
- [ ] Privacy policy is updated
- [ ] Terms of service are updated
- [ ] Firebase console is configured
- [ ] Analytics are configured
- [ ] Crashlytics is configured

---

**Status**: Ready for testing  
**Build Number**: 3  
**Version**: 1.0.0