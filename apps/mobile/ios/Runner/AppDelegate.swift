import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Ask iOS for the APNs device token on every launch.
    //
    // Firebase normally triggers this itself by swizzling the app delegate,
    // but with Flutter's implicit-engine delegate it never happened: the app
    // had notification permission granted and getAPNSToken() stayed null
    // forever, so getToken() failed with [firebase_messaging/apns-token-not-set]
    // and no device was ever registered for push. Registering here is the
    // documented behaviour anyway (Apple asks apps to register at each launch);
    // the token then reaches Firebase through its swizzled callback.
    //
    // Safe without permission: iOS simply does not deliver a token, and the
    // permission prompt is still owned by the Dart side.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
