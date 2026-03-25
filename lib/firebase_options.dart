// File generated for CI / local builds. Replace with `flutterfire configure` for production FCM.
// ignore_for_file: lines_longer_than_80_chars

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
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError('Firebase not configured for Linux');
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo',
    appId: '1:demo:web:demo',
    messagingSenderId: '000000000000',
    projectId: 'waste-bridge-placeholder',
    storageBucket: 'waste-bridge-placeholder.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'demo',
    appId: '1:demo:android:demo',
    messagingSenderId: '000000000000',
    projectId: 'waste-bridge-placeholder',
    storageBucket: 'waste-bridge-placeholder.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'demo',
    appId: '1:demo:ios:demo',
    messagingSenderId: '000000000000',
    projectId: 'waste-bridge-placeholder',
    storageBucket: 'waste-bridge-placeholder.appspot.com',
    iosBundleId: 'com.example.wasteBridge',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'demo',
    appId: '1:demo:windows:demo',
    messagingSenderId: '000000000000',
    projectId: 'waste-bridge-placeholder',
    storageBucket: 'waste-bridge-placeholder.appspot.com',
  );
}
