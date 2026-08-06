import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('DefaultFirebaseOptions non-web platform');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  // تجلب هذه القيم من صفحة Project Settings في Firebase Console
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyChyVy2dHNnbz_BR7JWL-Zm3801a9v51Ik',
    appId: '1:188407086789:android:fdd3c2cc8fa39c3771baac',
    messagingSenderId: '188407086789',
    projectId: 'voucherapplicense',
    storageBucket: 'voucherapplicense.appspot.com',
  );
}