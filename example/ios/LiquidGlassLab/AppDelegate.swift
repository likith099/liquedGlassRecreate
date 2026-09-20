import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  var reactNativeDelegate: ReactNativeDelegate?
  var reactNativeFactory: RCTReactNativeFactory?
  private var launchOptions: [UIApplication.LaunchOptionsKey: Any]?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let delegate = ReactNativeDelegate()
    let factory = RCTReactNativeFactory(delegate: delegate)
    delegate.dependencyProvider = RCTAppDependencyProvider()

    reactNativeDelegate = delegate
    reactNativeFactory = factory
    self.launchOptions = launchOptions

    // The scene owns the window, so React Native starts in SceneDelegate instead of here.
    return true
  }

  fileprivate func startReactNative(in window: UIWindow) {
    reactNativeFactory?.startReactNative(
      withModuleName: "LiquidGlassLab",
      in: window,
      launchOptions: launchOptions
    )
  }
}

/// iOS 27 traps an app that has not adopted the UIScene lifecycle, during scene creation and
/// before any UI appears. iOS 26 only reported it as a runtime issue, so the app ran there.
/// The scene owns the window and starts React Native into it; `Info.plist` names this class.
@objc(SceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    self.window = window
    (UIApplication.shared.delegate as? AppDelegate)?.startReactNative(in: window)
  }
}

class ReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
  override func sourceURL(for bridge: RCTBridge) -> URL? {
    self.bundleURL()
  }

  override func bundleURL() -> URL? {
#if DEBUG
    RCTBundleURLProvider.sharedSettings().jsLocation = packagerLocation()
    return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
#else
    return Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }

#if DEBUG
  /// Where Metro is reachable from, on port 8093.
  ///
  /// The simulator shares the Mac's network stack, so localhost reaches Metro. A physical
  /// device does not: localhost there is the phone itself, so the bundle never arrives and
  /// the app sits on the splash screen. React Native's bundling build phase writes the Mac's
  /// address into `ip.txt` for Debug device builds, so prefer that. The Mac and the device
  /// must be on the same network.
  /// Set this to the Mac's LAN address, for example "192.168.1.50", to override the address
  /// React Native writes into the app at build time. Leave it empty to use that address.
  private static let packagerHostOverride = ""

  private func packagerLocation() -> String {
#if targetEnvironment(simulator)
    return "localhost:8093"
#else
    if !Self.packagerHostOverride.isEmpty { return "\(Self.packagerHostOverride):8093" }
    let host = Bundle.main.url(forResource: "ip", withExtension: "txt")
      .flatMap { try? String(contentsOf: $0, encoding: .utf8) }?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let host, !host.isEmpty { return "\(host):8093" }
    // Falling back to localhost on a device cannot reach Metro; say so rather than hang.
    NSLog("[LiquidGlassLab] No packager address: ip.txt is missing from the app bundle. "
      + "Set packagerHostOverride in AppDelegate.swift to this Mac's LAN IP.")
    return "localhost:8093"
#endif
  }
#endif
}
