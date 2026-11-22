import Flutter
import UIKit

// H1 of the 21 Nov 2026 pre-launch audit — iOS app-switcher snapshot
// masking. iOS has no screenshot-prevention API; Apple's recommendation
// is to cover sensitive UI before the system takes the app-switcher
// snapshot. We add an opaque navy view on applicationWillResignActive
// (which fires right before the snapshot), and tear it down on
// applicationDidBecomeActive. The Flutter side also runs its own cover
// via TroskyPrivacyCover; this Swift one is the earlier layer that
// catches the OS snapshot even before Flutter is told the lifecycle
// changed.

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let privacyViewTag = 1_729_364_215
  private let privacyBackground = UIColor(
    red: 0.039, green: 0.102, blue: 0.169, alpha: 1.0
  )

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    attachPrivacyCover()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    removePrivacyCover()
  }

  private func attachPrivacyCover() {
    guard let window = self.window else { return }
    if window.viewWithTag(privacyViewTag) != nil { return }
    let cover = UIView(frame: window.bounds)
    cover.backgroundColor = privacyBackground
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.tag = privacyViewTag
    cover.isUserInteractionEnabled = false
    window.addSubview(cover)
  }

  private func removePrivacyCover() {
    guard let window = self.window else { return }
    window.viewWithTag(privacyViewTag)?.removeFromSuperview()
  }
}
