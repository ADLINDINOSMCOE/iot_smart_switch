# Production Firebase Configuration Guide

## Overview
This guide explains how to configure Firebase for production deployment of the IoT Switch application.

## Current Configuration Status
- **Development**: Currently configured with development Firebase SDKs
- **Firebase App Check**: Temporarily disabled due to dependency conflicts
- **Firebase SDK Versions**: Using compatible versions for Flutter 3.x

## Production Setup Steps

### 1. Firebase Console Configuration

#### Firebase Project Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new Firebase project or use existing one
3. Enable the following services:
   - Authentication (Email/Password, Google Sign-In)
   - Cloud Firestore
   - Cloud Functions
   - Firebase Cloud Messaging (FCM)
   - Firebase Crashlytics (optional but recommended)

#### Authentication Setup
1. Enable Email/Password authentication
2. Enable Google Sign-In
3. Configure OAuth consent screen
4. Set up authorized domains for your app

#### Cloud Firestore Setup
1. Create Firestore database
2. Choose production location (choose region closest to your users)
3. Start in production mode (not test mode)
4. Deploy security rules from `firestore.rules`

#### Cloud Functions Setup
1. Deploy Cloud Functions using Firebase CLI:
   ```bash
   firebase deploy --only functions
   ```
2. Configure environment variables:
   ```bash
   firebase functions:config:set DEVICE_SECRETS='{"esp32_relay_01":"your_secret_here"}'
   ```

#### FCM Setup
1. Upload APNs certificate for iOS (if needed)
2. Set up FCM API keys
3. Configure notification channels in the app

### 2. Production Firebase Configuration Files

#### Android Configuration
Update `android/app/google-services.json` with production Firebase config:
- Replace the current file with production configuration from Firebase Console
- Ensure `google-services.json` is excluded from version control
- Never commit production Firebase config to public repositories

#### iOS Configuration
Update `ios/Runner/GoogleService-Info.plist` with production Firebase config:
- Replace the current file with production configuration from Firebase Console
- Ensure `GoogleService-Info.plist` is excluded from version control
- Never commit production Firebase config to public repositories

### 3. Firebase App Check (Production)

#### Android Setup
1. In Firebase Console, go to App Check section
2. Select your Android app
3. Enable Play Integrity API
4. Update code in `lib/main.dart`:
   ```dart
   await FirebaseAppCheck.instance.activate(
     androidProvider: AndroidProvider.playIntegrity,
   );
   ```

#### iOS Setup
1. In Firebase Console, go to App Check section
2. Select your iOS app
3. Enable App Attest
4. Update code in `lib/main.dart`:
   ```dart
   await FirebaseAppCheck.instance.activate(
     appleProvider: AppleProvider.appAttest,
   );
   ```

### 4. Security Rules Deployment

Deploy the production security rules:
```bash
firebase deploy --only firestore:rules
```

### 5. Firestore Indexes Deployment

Deploy the production indexes:
```bash
firebase deploy --only firestore:indexes
```

### 6. Environment Variables

Create a `.env.production` file with production values:
```env
FIREBASE_PROJECT_ID=your-production-project-id
FIREBASE_API_KEY=your-production-api-key
```

### 7. Build Configuration

#### Android Release Build
```bash
flutter build apk --release
flutter build appbundle --release
```

#### iOS Release Build
```bash
flutter build ios --release
```

## Production Security Checklist

- [ ] Replace development Firebase config with production config
- [ ] Deploy production Firestore security rules
- [ ] Deploy production Firestore indexes
- [ ] Enable Firebase App Check with production providers
- [ ] Enable Firebase Crashlytics
- [ ] Set up Firebase Analytics
- [ ] Configure Firebase Cloud Messaging for production
- [ ] Set up proper API key restrictions in Google Cloud Console
- [ ] Enable Firebase Authentication with proper email verification
- [ ] Set up Firebase Cloud Functions with production environment variables
- [ ] Test all functionality with production Firebase project
- [ ] Remove debug logging from production builds
- [ ] Enable code obfuscation (ProGuard/R8)
- [ ] Set up proper SSL certificate pinning

## Monitoring and Analytics

### Firebase Crashlytics
- Enable crash reporting for both Android and iOS
- Set up custom crash reporting keys
- Configure alerts for high crash rates

### Firebase Analytics
- Enable event tracking for key user actions
- Set up conversion tracking
- Monitor user engagement metrics

### Cloud Functions Monitoring
- Enable Cloud Functions logging
- Set up error reporting alerts
- Monitor function execution times and costs

## Rollback Plan

In case of production issues:
1. Revert to previous version of the app
2. Rollback Cloud Functions deployment
3. Restore previous Firestore security rules
4. Monitor Firebase Analytics for user impact

## Contact Information

For Firebase configuration issues:
- Firebase Support: https://firebase.google.com/support/
- Firebase Documentation: https://firebase.google.com/docs/
