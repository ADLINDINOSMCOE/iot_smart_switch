# Firebase App Check Setup Guide

## Overview
Firebase App Check provides additional security by ensuring that your app traffic is coming from your legitimate app and not from unauthorized sources or scripts.

## Current Configuration
The app is currently configured with **debug providers** for development purposes. This is suitable for development and testing but should be replaced with production providers before release.

## Development Setup (Current)
```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.debug,
  appleProvider: AppleProvider.debug,
);
```

## Production Setup

### Android (Play Integrity)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to App Check section
4. Select your Android app
5. Enable Play Integrity API
6. Update the code:
```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.playIntegrity,
);
```

### iOS (App Attest)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to App Check section
4. Select your iOS app
5. Enable App Attest
6. Update the code:
```dart
await FirebaseAppCheck.instance.activate(
  appleProvider: AppleProvider.appAttest,
);
```

### Web (reCAPTCHA v3)
For web applications, enable reCAPTCHA v3 in the Firebase Console and configure accordingly.

## Firestore Security Rules Integration
The current Firestore security rules should be updated to enforce App Check tokens in production. Add this to your firestore.rules:

```javascript
// Add this helper function
function isAppCheckValid() {
  return request.appCheck != null && request.appCheck.token != null;
}

// Update your rules to require App Check
allow read, write: if isAppCheckValid() && isAuthenticated();
```

## Testing
To test App Check in development:
1. Use the debug providers (currently configured)
2. For Android: Use the debug secret from Firebase Console
3. For iOS: Use the debug secret from Firebase Console

## Important Notes
- Debug providers should NEVER be used in production
- Always test App Check enforcement in a staging environment first
- Monitor your Firebase Console for App Check metrics
- Keep your debug secrets secure and rotate them regularly

## Security Benefits
- Prevents unauthorized API calls
- Protects against abuse and scraping
- Ensures traffic comes from your genuine app
- Adds an additional layer of security beyond Firebase Auth

## Rollout Strategy
1. Enable App Check in audit mode (monitor only)
2. Monitor for legitimate traffic patterns
3. Gradually increase enforcement percentage
4. Full enforcement once confident in setup
