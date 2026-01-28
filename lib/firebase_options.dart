
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
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDAcb2VVu4_DjBWdC7S6HkhVeSloPtT-3U',
    appId: '1:155906159926:web:afd038f8abd879e9002f97',
    messagingSenderId: '155906159926',
    projectId: 'cpdassignment-17477',
    authDomain: 'cpdassignment-17477.firebaseapp.com',
    storageBucket: 'cpdassignment-17477.firebasestorage.app',
    measurementId: 'G-11R3LSG2KP',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAZNbr54JvqF4bOKx84lPWi2qFg2HSEtn4',
    appId: '1:155906159926:android:8633e02c3c4841f4002f97',
    messagingSenderId: '155906159926',
    projectId: 'cpdassignment-17477',
    storageBucket: 'cpdassignment-17477.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDOn4t_kFFu3k3I1THE4QYw2SyDlSTgnE4',
    appId: '1:155906159926:ios:84170a0dcaf925b3002f97',
    messagingSenderId: '155906159926',
    projectId: 'cpdassignment-17477',
    storageBucket: 'cpdassignment-17477.firebasestorage.app',
    iosBundleId: 'com.example.cpdAssignment',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDOn4t_kFFu3k3I1THE4QYw2SyDlSTgnE4',
    appId: '1:155906159926:ios:84170a0dcaf925b3002f97',
    messagingSenderId: '155906159926',
    projectId: 'cpdassignment-17477',
    storageBucket: 'cpdassignment-17477.firebasestorage.app',
    iosBundleId: 'com.example.cpdAssignment',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDAcb2VVu4_DjBWdC7S6HkhVeSloPtT-3U',
    appId: '1:155906159926:web:17904bcd50057f90002f97',
    messagingSenderId: '155906159926',
    projectId: 'cpdassignment-17477',
    authDomain: 'cpdassignment-17477.firebaseapp.com',
    storageBucket: 'cpdassignment-17477.firebasestorage.app',
    measurementId: 'G-FEZS8XKWRE',
  );
}
