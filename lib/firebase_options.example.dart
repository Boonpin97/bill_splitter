// Example only. Do not import this file directly in production code.
//
// Generate a real firebase_options.dart locally with FlutterFire CLI:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// The generated lib/firebase_options.dart is intentionally gitignored in this
// repository.

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
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        throw UnsupportedError(
          'Generate lib/firebase_options.dart locally with FlutterFire CLI.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_FIREBASE_WEB_API_KEY',
    appId: 'YOUR_FIREBASE_WEB_APP_ID',
    messagingSenderId: 'YOUR_FIREBASE_SENDER_ID',
    projectId: 'YOUR_FIREBASE_PROJECT_ID',
    authDomain: 'YOUR_FIREBASE_AUTH_DOMAIN',
    storageBucket: 'YOUR_FIREBASE_STORAGE_BUCKET',
    measurementId: 'YOUR_FIREBASE_MEASUREMENT_ID',
  );
}
