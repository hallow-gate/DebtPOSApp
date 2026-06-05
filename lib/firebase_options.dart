import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDfmTStSffKTDb8pPQrgBbNADK8jQq6s38',
    authDomain: 'arbify-ce847.firebaseapp.com',
    projectId: 'arbify-ce847',
    storageBucket: 'arbify-ce847.firebasestorage.app',
    messagingSenderId: '917500508857',
    appId: '1:917500508857:web:290a8b2de00934b8cfb968',
    measurementId: 'G-8M416W4MY2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDfmTStSffKTDb8pPQrgBbNADK8jQq6s38',
    appId: '1:917500508857:android:290a8b2de00934b8cfb968',
    messagingSenderId: '917500508857',
    projectId: 'arbify-ce847',
    authDomain: 'arbify-ce847.firebaseapp.com',
    storageBucket: 'arbify-ce847.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDfmTStSffKTDb8pPQrgBbNADK8jQq6s38',
    appId: '1:917500508857:ios:290a8b2de00934b8cfb968',
    messagingSenderId: '917500508857',
    projectId: 'arbify-ce847',
    authDomain: 'arbify-ce847.firebaseapp.com',
    storageBucket: 'arbify-ce847.firebasestorage.app',
    iosClientId: '917500508857-xxxxxxxx.apps.googleusercontent.com',
    iosBundleId: 'com.marnie.pos',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDfmTStSffKTDb8pPQrgBbNADK8jQq6s38',
    appId: '1:917500508857:ios:290a8b2de00934b8cfb968',
    messagingSenderId: '917500508857',
    projectId: 'arbify-ce847',
    authDomain: 'arbify-ce847.firebaseapp.com',
    storageBucket: 'arbify-ce847.firebasestorage.app',
  );
}
