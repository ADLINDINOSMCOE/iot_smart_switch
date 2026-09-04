// File generated / configured for Firebase configuration.
// Replace placeholders with your Firebase project credentials or use FlutterFire CLI.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Configuration options (Fill in with your actual Firebase Project credentials)

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCNajonGGxmQdjw3ZeJRPl4aHzpME5e1gg',
    appId: '1:853694975111:web:ad8cd820df43e604d73c22',
    messagingSenderId: '853694975111',
    projectId: 'iot-switch-23826',
    authDomain: 'iot-switch-23826.firebaseapp.com',
    storageBucket: 'iot-switch-23826.firebasestorage.app',
    measurementId: 'G-4DFNVLQ8KX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAcAa9VA30WefSE6ApM-KdMyj-Wyprv-2g',
    appId: '1:853694975111:android:faeb9cb1eea2102bd73c22',
    messagingSenderId: '853694975111',
    projectId: 'iot-switch-23826',
    storageBucket: 'iot-switch-23826.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBP6i0s8a1b1lETTD9jY1NQ10otP08fZEM',
    appId: '1:853694975111:ios:7ffb1cc8ce65864ed73c22',
    messagingSenderId: '853694975111',
    projectId: 'iot-switch-23826',
    storageBucket: 'iot-switch-23826.firebasestorage.app',
    androidClientId: '853694975111-7t386mcho0pd1dptguf552hvlg60dq6v.apps.googleusercontent.com',
    iosClientId: '853694975111-oqmmegt428e7uk8mlhsj51qnrnb4fc4i.apps.googleusercontent.com',
    iosBundleId: 'com.iotsmartswitch.iotSmartSwitch',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBP6i0s8a1b1lETTD9jY1NQ10otP08fZEM',
    appId: '1:853694975111:ios:7ffb1cc8ce65864ed73c22',
    messagingSenderId: '853694975111',
    projectId: 'iot-switch-23826',
    storageBucket: 'iot-switch-23826.firebasestorage.app',
    androidClientId: '853694975111-7t386mcho0pd1dptguf552hvlg60dq6v.apps.googleusercontent.com',
    iosClientId: '853694975111-oqmmegt428e7uk8mlhsj51qnrnb4fc4i.apps.googleusercontent.com',
    iosBundleId: 'com.iotsmartswitch.iotSmartSwitch',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCNajonGGxmQdjw3ZeJRPl4aHzpME5e1gg',
    appId: '1:853694975111:web:b5c4859c206dcae9d73c22',
    messagingSenderId: '853694975111',
    projectId: 'iot-switch-23826',
    authDomain: 'iot-switch-23826.firebaseapp.com',
    storageBucket: 'iot-switch-23826.firebasestorage.app',
    measurementId: 'G-7EMNHQ0B22',
  );
}
