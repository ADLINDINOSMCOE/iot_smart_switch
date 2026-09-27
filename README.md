# IoT Smart Switch

A production-ready IoT smart switch solution with Flutter mobile app, Firebase backend, and ESP32 hardware controller.

## 🚀 Features

### Mobile App
- **Cross-platform**: Flutter app for Android and iOS
- **Firebase Authentication**: Email/Password and Google Sign-In
- **Real-time Control**: Instant switch state updates via Cloud Firestore
- **Scheduling**: Advanced schedule automation with timezone support
- **Timer Functionality**: Count-up timers with energy tracking
- **Device Sharing**: Role-based access control (Owner, Editor, Viewer)
- **Notifications**: FCM push notifications for device events
- **Offline Support**: Network monitoring and error handling
- **Email Verification**: Secure user registration flow
- **Remember Me**: Persistent authentication with Firebase Auth

### Backend
- **Cloud Functions**: Schedule execution and device sync
- **Offline Detection**: Automatic device status monitoring
- **Account Cleanup**: Cascade deletion on account removal
- **Security**: RBAC, data validation, and audit logging

### Hardware
- **ESP32 Controller**: Secure TLS 1.3 communication
- **Anti-Replay Protection**: Command freshness and nonce validation
- **Idempotency**: Duplicate command detection
- **Device Registration**: Provisioning via Cloud Functions
- **Offline Recovery**: Automatic state synchronization
- **Energy Tracking**: Runtime and consumption monitoring

## 🏗️ Architecture

### Technology Stack
- **Frontend**: Flutter 3.x with Dart
- **Backend**: Firebase (Firestore, Functions, Auth, FCM)
- **Hardware**: ESP32 with Arduino framework
- **Security**: TLS 1.3, Firebase Auth, RBAC

### Security Architecture
- **Authentication**: Firebase Auth with email verification
- **Authorization**: Role-Based Access Control (Owner, Editor, Viewer)
- **Transport Security**: TLS 1.3 with certificate pinning
- **Anti-Replay**: Timestamp freshness and nonce validation
- **Zero-Trust**: No passwords or service account keys on hardware
- **Data Validation**: Strict Firestore security rules

## 📱 Setup Instructions

### Prerequisites
- Flutter SDK 3.7.2 or higher
- Android Studio / Xcode
- Firebase account
- ESP32 development board
- Relay module

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd iotswitch
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project at console.firebase.google.com
   - Add Android and iOS apps
   - Download `google-services.json` and `GoogleService-Info.plist`
   - Place them in `android/app/` and `ios/Runner/` respectively
   - Enable required Firebase services (Auth, Firestore, Functions, FCM)

4. **Hardware Setup**
   - Copy `esp32/secrets.h.template` to `esp32/secrets.h`
   - Configure Wi-Fi credentials and Firebase project details
   - Upload firmware to ESP32 using Arduino IDE

5. **Run the app**
   ```bash
   flutter run
   ```

## 🔧 Hardware Setup

### Components Required
- ESP32 development board
- Relay module (5V compatible)
- Power supply (5V for ESP32, 5V for relay)
- Jumper wires

### Wiring Diagram
```
ESP32 Pin 23 → Relay IN
ESP32 5V → Relay VCC
ESP32 GND → Relay GND
ESP32 3.3V → (Optional) Status LED
```

### Firmware Configuration
1. Install Arduino IDE with ESP32 board support
2. Install required libraries:
   - WiFi
   - WiFiClientSecure
   - HTTPClient
   - ArduinoJson
3. Configure `esp32/secrets.h` with your credentials
4. Upload `smart_switch_firmware.ino` to ESP32

## 🔒 Security Features

### Data Protection
- End-to-end encryption with TLS 1.3
- Firebase Authentication with email verification
- Role-based access control
- Audit logging for all device operations
- Anti-replay protection on hardware

### Firestore Security Rules
- Strict user authentication requirements
- Owner/Editor/Viewer permission model
- Device ownership validation
- Query constraint enforcement
- Immutable critical fields

### Firebase App Check
- Debug providers for development
- Play Integrity for Android production
- App Attest for iOS production
- Token validation for all requests

## 🚀 Deployment

### Firebase Deployment
```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Firestore indexes
firebase deploy --only firestore:indexes

# Deploy Cloud Functions
firebase deploy --only functions
```

### Android Release Build
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS Release Build
```bash
flutter build ios --release
```

## 📊 Monitoring

### Firebase Analytics
- User engagement tracking
- Device usage metrics
- Error reporting via Crashlytics

### Cloud Functions Monitoring
- Function execution logs
- Error alerts
- Performance metrics

### Health Checks
- Device heartbeat monitoring
- Offline detection alerts
- Energy consumption tracking

## 🛠️ Troubleshooting

### Common Issues

**Authentication Issues**
- Ensure Firebase project is properly configured
- Check that email verification is enabled
- Verify authentication providers are enabled

**Connection Issues**
- Check Wi-Fi credentials in ESP32 firmware
- Verify Firebase project ID is correct
- Ensure device secrets are properly configured

**Switch Not Responding**
- Check ESP32 serial monitor for errors
- Verify relay wiring is correct
- Ensure device is registered in Firebase

**Build Issues**
- Ensure Flutter SDK is up to date
- Run `flutter clean` and `flutter pub get`
- Check Firebase SDK compatibility

## 📝 Development Notes

### Adding New Features
- Follow the existing architecture patterns
- Update security rules when adding new collections
- Test with development Firebase project first
- Document security implications

### Security Considerations
- Never commit Firebase credentials to version control
- Use environment variables for sensitive data
- Regularly update Firebase SDK versions
- Monitor security advisories

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes following security best practices
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🔗 Links

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs/)
- [ESP32 Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/)
- [ArduinoJson Library](https://arduinojson.org/)

## 🆘 Support

For issues and questions:
- Create an issue in the repository
- Check existing documentation
- Review security best practices

---

**Version**: 1.0.0  
**Last Updated**: 2026-09-03  
**Status**: Production Ready
