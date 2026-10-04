import XCTest

/// How long a freshly launched app may take to show its first screen. A cold launch loads the
/// JavaScript bundle from Metro, and shared CI runners are several times slower than a local Mac.
let launchTimeout: TimeInterval = 120

extension XCUIApplication {
  /// Scrolls the page until `element` is hittable inside `band` (fractions of the screen height; the
  /// default only requires it to be on screen). Each drag moves the page by the distance from the
  /// element to the middle of the band, at most a third of the screen, and holds before lifting so no
  /// fling carries it past the band. Drags start mid-screen, clear of switches in either layout
  /// direction. It stops when two drags in a row leave the element where it was (the page is at its
  /// end; the retry starts elsewhere in case a control caught the first) and after `maxDrags` at
  /// most, so a test never keeps dragging a page that cannot move.
  @discardableResult
  func scrollIntoView(_ query: XCUIElement, band: ClosedRange<CGFloat> = 0.05...0.95, maxDrags: Int = 12) -> Bool {
    // React Native text can match twice (a text and its nested run); act on the first match.
    let element = query.firstMatch
    let height = frame.height
    let target = height * (band.lowerBound + band.upperBound) / 2
    var stalls = 0
    for _ in 0..<maxDrags {
      // One position read per step; each query is a round trip to the app.
      let position: CGRect? = element.exists ? element.frame : nil
      if let position, position.minY >= height * band.lowerBound, position.maxY <= height * band.upperBound,
        element.isHittable { return true }
      // Positive moves content up, revealing what is below. Unknown positions reveal downward.
      let wanted = position.map { $0.midY - target } ?? height / 3
      let distance = max(-height / 3, min(height / 3, abs(wanted) < 24 ? (wanted < 0 ? -24 : 24) : wanted))
      let x: CGFloat = stalls == 0 ? 0.5 : 0.35
      let start = CGVector(dx: x, dy: 0.5 + distance / height / 2)
      let end = CGVector(dx: x, dy: 0.5 - distance / height / 2)
      coordinate(withNormalizedOffset: start).press(forDuration: 0.05,
        thenDragTo: coordinate(withNormalizedOffset: end), withVelocity: .slow, thenHoldForDuration: 0.15)
      if let position, element.frame == position {
        stalls += 1
        if stalls >= 2 { break }
      } else {
        stalls = 0
      }
    }
    return element.exists && element.isHittable
  }
}
import UIKit

final class GlassInteractionTests: XCTestCase {
  func testConversationMenuAppearance() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    defer { app.terminate() }
    let open = app.buttons["open-context-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
    let chat = app.buttons["open-chat-menu-demo"]
    XCTAssertTrue(app.scrollIntoView(chat)); chat.tap()
    app.buttons["chat-latest"].tap()
    let message = app.descendants(matching: .any)["chat-message-29"].firstMatch
    XCTAssertTrue(message.waitForExistence(timeout: 5))
    for scheme in ["system", "dark", "light"] {
      if scheme != "system" { app.buttons["chat-theme"].tap() }
      let original = message.frame
      let before = XCTAttachment(screenshot: app.screenshot())
      before.name = "Appearance \(scheme) before"; before.lifetime = .keepAlways; add(before)
      message.press(forDuration: 1)
      XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5))
      let capture = XCTAttachment(screenshot: app.screenshot())
      capture.name = "Appearance \(scheme) open"; capture.lifetime = .keepAlways; add(capture)
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.35)).tap()
      XCTAssertTrue(app.buttons["Copy"].waitForNonExistence(timeout: 5))
      XCTAssertEqual(message.frame, original)
    }
  }

  func testConversationMenuTransitions() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    defer { app.terminate() }
    let open = app.buttons["open-context-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
    let chat = app.buttons["open-chat-menu-demo"]
    XCTAssertTrue(app.scrollIntoView(chat)); chat.tap()
    let message = app.descendants(matching: .any)["chat-message-29"].firstMatch
    let status = app.staticTexts["chat-status"]
    app.buttons["chat-latest"].tap()
    XCTAssertTrue(message.waitForExistence(timeout: 5))
    let original = message.frame
    for index in 1...3 {
      message.press(forDuration: 1)
      XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5))
      XCTAssertFalse(app.buttons["Unavailable"].isEnabled)
      let preview = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Preview'")).firstMatch
      XCTAssertTrue(preview.exists)
      XCTAssertGreaterThan(app.buttons["Reply"].frame.minY, preview.frame.maxY,
        "The menu must not cover this bottom message's preview")
      let capture = XCTAttachment(screenshot: app.screenshot())
      capture.name = "Conversation preview \(index)"; capture.lifetime = .keepAlways; add(capture)
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.35)).tap()
      XCTAssertTrue(app.buttons["Copy"].waitForNonExistence(timeout: 5))
      let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "closed \(index)"), object: status)
      XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed, "Close must follow UIKit's dismissal")
      XCTAssertEqual(message.frame, original)
    }
    // Apply the action after the native close, then test image layout and deletion separately.
    message.press(forDuration: 1)
    XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5))
    app.buttons["Copy"].tap()
    expectation(for: NSPredicate(format: "label CONTAINS 'copy 29'"), evaluatedWith: status)
    waitForExpectations(timeout: 5)
    XCTAssertTrue(app.buttons["Copy"].waitForNonExistence(timeout: 5))
    // Exercise a real Image child and source removal after the return animation.
    app.buttons["chat-image"].tap(); app.buttons["chat-latest"].tap()
    message.press(forDuration: 1)
    XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5))
    let preview = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Preview'")).firstMatch
    XCTAssertTrue(preview.exists)
    XCTAssertGreaterThan(app.buttons["Reply"].frame.minY, preview.frame.maxY, "Menu must not cover this image preview")
    let capture = XCTAttachment(screenshot: app.screenshot())
    capture.name = "Conversation image preview"; capture.lifetime = .keepAlways; add(capture)
    app.buttons["Delete"].tap()
    XCTAssertTrue(message.waitForNonExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Copy"].waitForNonExistence(timeout: 5))
  }

  func testLongPressContextMenu() throws { exerciseContextMenu(fallback: false) }
  func testLongPressContextMenuFallback() throws { exerciseContextMenu(fallback: true) }

  private func exerciseContextMenu(fallback: Bool) {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    defer { app.terminate() }
    let open = app.buttons["open-context-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
    if fallback { app.switches["context-fallback"].tap() }
    func action(_ title: String) -> XCUIElement {
      if fallback { return app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch }
      return app.buttons[title]
    }
    let message = app.descendants(matching: .any).matching(identifier: "message-context").firstMatch
    XCTAssertTrue(message.waitForExistence(timeout: 5))
    let originalFrame = message.frame
    XCTAssertGreaterThan(originalFrame.height, 80, "React children determine native host size")
    message.tap()
    XCTAssertFalse(action("Edit message").exists, "A regular tap must not open the menu")
    message.press(forDuration: 1)
    XCTAssertTrue(action("Edit message").waitForExistence(timeout: 5))
    XCTAssertFalse(action("Unavailable message action").isEnabled)
    XCTAssertTrue(app.staticTexts["Context menu open: yes"].waitForExistence(timeout: 3), "onOpen reports the menu")
    let capture = XCTAttachment(screenshot: app.screenshot())
    capture.name = fallback ? "Plain context menu with stationary message" : "Context menu with retained message preview"; capture.lifetime = .keepAlways; add(capture)
    action("Edit message").tap()
    XCTAssertTrue(app.staticTexts["Context selected: edit"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Context menu open: no"].waitForExistence(timeout: 3), "onClose follows the dismissal")
    XCTAssertEqual(message.frame, originalFrame, "Dismissal restores the original content layout")
    message.press(forDuration: 1); action("Save message").tap()
    XCTAssertTrue(app.staticTexts["Message saved: on"].waitForExistence(timeout: 5))
    message.press(forDuration: 1); action("More message actions").tap()
    let copy = action("Copy message")
    XCTAssertTrue(copy.waitForExistence(timeout: 5)); copy.tap()
    XCTAssertTrue(app.staticTexts["Context selected: copy"].waitForExistence(timeout: 5))
    message.press(forDuration: 1)
    if fallback { app.buttons["message-context-dismiss"].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.85)).tap() }
    else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.85)).tap() }
    XCTAssertTrue(action("Edit message").waitForNonExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Context actions: 3"].exists)
    app.switches["context-disabled"].tap(); message.press(forDuration: 1)
    XCTAssertFalse(action("Edit message").exists)
    app.switches["context-disabled"].tap()
    app.buttons["context-replace"].tap(); message.press(forDuration: 1)
    XCTAssertTrue(action("Edit message").waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Context items replaced"].waitForExistence(timeout: 12))
    XCTAssertTrue(action("Edit message").waitForNonExistence(timeout: 5))
    message.press(forDuration: 1)
    let newAction = action("New action")
    XCTAssertTrue(newAction.waitForExistence(timeout: 5)); newAction.tap()
    XCTAssertTrue(app.staticTexts["Context actions: 4"].waitForExistence(timeout: 5))
    app.buttons["context-unmount"].tap(); message.press(forDuration: 1)
    XCTAssertTrue(newAction.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Message removed"].waitForExistence(timeout: 12))
    XCTAssertTrue(newAction.waitForNonExistence(timeout: 5))
    XCTAssertFalse(message.exists)
    XCTAssertTrue(app.staticTexts["Context actions: 4"].exists)
  }

  // Deferred with the rest of candidate execution; covers the Fabric host swap.
  func testActionClusterImplementationSwitch() throws {
    guard glassEra else { throw XCTSkip("SwiftUI glass requires iOS 26") }
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    defer { app.terminate() }
    let toggle = app.buttons["glass-cluster-toggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: launchTimeout)); toggle.tap()
    let favorite = app.buttons["glass-action-heart"]
    XCTAssertTrue(favorite.waitForExistence(timeout: 5))
    let setting = app.switches["swiftui-cluster-toggle"]
    // Short drags settle on the target; full swipes overshoot as the page grows.
    func bringIntoView(_ element: XCUIElement) { app.scrollIntoView(element) }
    for implementation in ["SwiftUI", "UIKit"] {
      bringIntoView(setting)
      XCTAssertTrue(setting.isHittable); setting.tap()
      bringIntoView(favorite)
      XCTAssertTrue(favorite.isHittable)
      // Let the replacement cluster finish expanding before tapping one of its buttons.
      Thread.sleep(forTimeInterval: 0.8)
      let capture = XCTAttachment(screenshot: app.screenshot())
      capture.name = "\(implementation) action cluster expanded"; capture.lifetime = .keepAlways; add(capture)
      favorite.tap()
      XCTAssertTrue(app.staticTexts["Favorite selected"].waitForExistence(timeout: 5))
      toggle.tap()
      XCTAssertTrue(favorite.waitForNonExistence(timeout: 5))
      toggle.tap()
      XCTAssertTrue(favorite.waitForExistence(timeout: 5))
    }
  }

  @MainActor func testActionClusterMirrorsLayoutDirection() throws {
    guard #available(iOS 26.0, *) else { throw XCTSkip("Native action cluster requires glass") }
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
    let controller = UIViewController(); window.rootViewController = controller
    let cluster = ALGActionClusterView(frame: CGRect(x: 0, y: 0, width: 400, height: 88))
    controller.view.addSubview(cluster); window.isHidden = false
    defer { window.isHidden = true }
    let actions = #"[{"id":"first","title":"First"},{"id":"last","title":"Last"}]"#
    cluster.configure(actions, expanded: true, mergingEnabled: false, spacing: 20,
      tint: nil, material: "regular", interactive: true, duration: 0, toggleLabel: "Actions")
    func find(_ view: UIView, _ id: String) -> UIView? {
      if view.accessibilityIdentifier == id { return view }
      return view.subviews.compactMap { find($0, id) }.first
    }
    cluster.semanticContentAttribute = .forceLeftToRight
    cluster.setNeedsLayout(); cluster.layoutIfNeeded()
    let toggle = try XCTUnwrap(find(cluster, "glass-cluster-toggle"))
    let first = try XCTUnwrap(find(cluster, "glass-action-first"))
    let last = try XCTUnwrap(find(cluster, "glass-action-last"))
    let ltrFrames = [toggle.frame, first.frame, last.frame]
    XCTAssertLessThan(first.frame.midX, last.frame.midX)
    XCTAssertLessThan(last.frame.midX, toggle.frame.midX)
    cluster.semanticContentAttribute = .forceRightToLeft
    cluster.setNeedsLayout(); cluster.layoutIfNeeded()
    XCTAssertLessThan(toggle.frame.midX, last.frame.midX)
    XCTAssertLessThan(last.frame.midX, first.frame.midX)
    for (item, ltr) in zip([toggle, first, last], ltrFrames) {
      XCTAssertEqual(item.frame.minX, cluster.bounds.width - ltr.maxX, accuracy: 0.5)
      XCTAssertTrue(cluster.bounds.contains(item.frame))
    }
    XCTAssertTrue(find(cluster, "glass-action-first") === first)
    cluster.semanticContentAttribute = .forceLeftToRight
    cluster.setNeedsLayout(); cluster.layoutIfNeeded()
    XCTAssertEqual([toggle.frame, first.frame, last.frame], ltrFrames)
  }

  func testArabicLocaleLayoutAndSelection() throws {
    guard glassEra else { throw XCTSkip("Native RTL controls") }
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]
    app.launch()
    defer { app.terminate() }
    let toggle = app.buttons["glass-cluster-toggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: launchTimeout)); toggle.tap()
    let favorite = app.buttons["glass-action-heart"]
    XCTAssertTrue(favorite.waitForExistence(timeout: 5))
    XCTAssertGreaterThan(favorite.frame.midX, toggle.frame.midX)
    favorite.tap()
    XCTAssertTrue(app.staticTexts["Favorite selected"].waitForExistence(timeout: 5))
    toggle.tap()
    app.buttons["open-accessibility-demo"].tap()
    let environment = app.staticTexts["adaptive-environment"]
    XCTAssertTrue(environment.waitForExistence(timeout: 15))
    XCTAssertTrue(environment.label.contains("RTL"), "Must exercise real RTL, not an LTR app with a locale flag")
    let segments = app.segmentedControls["adaptive-segments"]
    XCTAssertTrue(segments.waitForExistence(timeout: 5))
    XCTAssertGreaterThan(segments.buttons["All"].frame.midX, segments.buttons["Shared"].frame.midX)
    segments.buttons["Saved"].tap()
    XCTAssertTrue(app.staticTexts["Selected: saved"].waitForExistence(timeout: 5))
    let capture = XCTAttachment(screenshot: app.screenshot())
    capture.name = "Arabic locale RTL controls"; capture.lifetime = .keepAlways; add(capture)
  }

  func testIPadRotationAndTabLayout() throws {
    guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad acceptance") }
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let originalOrientation = XCUIDevice.shared.orientation
    defer { XCUIDevice.shared.orientation = originalOrientation }
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
    for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
      XCUIDevice.shared.orientation = orientation
      let home = app.buttons["Home tab"]
      let library = app.buttons["Library tab"]
      XCTAssertTrue(home.waitForExistence(timeout: 8))
      XCTAssertTrue(home.isHittable); XCTAssertTrue(library.isHittable)
      XCTAssertTrue(app.frame.contains(home.frame)); XCTAssertTrue(app.frame.contains(library.frame))
      library.tap()
      XCTAssertTrue(app.staticTexts["Library screen"].waitForExistence(timeout: 8))
      home.tap()
      XCTAssertTrue(app.staticTexts["Home screen"].waitForExistence(timeout: 8))
      let capture = XCTAttachment(screenshot: app.screenshot())
      capture.name = "iPad tabs \(orientation.rawValue)"; capture.lifetime = .keepAlways; add(capture)
    }
  }

  func testPhysicalReleaseInteractionProfile() throws {
#if targetEnvironment(simulator) || DEBUG
    throw XCTSkip("Performance acceptance requires a physical Release build")
#else
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let toggle = app.buttons["glass-cluster-toggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: launchTimeout))
    toggle.tap(); app.buttons["glass-action-heart"].tap(); toggle.tap()
    let context = XCTAttachment(string: "Device: \(UIDevice.current.model); OS: \(UIDevice.current.systemVersion); "
      + "thermal: \(ProcessInfo.processInfo.thermalState.rawValue); maximumFPS: \(UIScreen.main.maximumFramesPerSecond); configuration: Release")
    context.name = "Physical profiling context"; context.lifetime = .keepAlways; add(context)
    var metrics: [XCTMetric] = [XCTCPUMetric(application: app), XCTMemoryMetric(application: app)]
    if #available(iOS 26.0, *) { metrics.append(XCTHitchMetric(application: app)) }
    let options = XCTMeasureOptions(); options.iterationCount = 3
    measure(metrics: metrics, options: options) {
      toggle.tap()
      app.buttons["glass-action-heart"].tap()
      toggle.tap()
    }
    // Raw metrics are a repeatable baseline, not a pass/fail frame-rate budget.
    XCTAssertFalse(app.buttons["glass-action-heart"].exists)
#endif
  }

  /// Glass and the native UIKit selector only exist from iOS 26. Below it the package
  /// renders its React counterparts, which are ordinary views rather than UIKit controls,
  /// so element types and accessibility values differ and the checks branch accordingly.
  private var glassEra: Bool {
    ProcessInfo.processInfo.isOperatingSystemAtLeast(
      OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0))
  }

  @MainActor func testOlderIOSBlurMaterialAndReuse() throws {
    guard !glassEra else { throw XCTSkip("Exercises the pre-26 material") }
    guard !UIAccessibility.isReduceTransparencyEnabled else { throw XCTSkip("Blur disabled by accessibility") }
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
    let controller = UIViewController()
    window.rootViewController = controller
    let surface = ALGSurfaceView(frame: CGRect(x: 20, y: 20, width: 240, height: 100))
    controller.view.addSubview(surface)
    let child = UIButton(type: .system)
    child.frame = CGRect(x: 10, y: 10, width: 100, height: 44)
    surface.reactContentView.addSubview(child)
    window.isHidden = false
    defer { window.isHidden = true }
    func configure(_ material: String = "regular", container: Bool = false) {
      surface.configure(material, interactive: true, tint: nil, radius: 18,
        container: container, mergingEnabled: false, spacing: 20, duration: 0, scheme: "system")
      surface.layoutIfNeeded()
    }
    configure()
    let effectView = try XCTUnwrap(surface.subviews.first as? UIVisualEffectView)
    XCTAssertTrue(effectView.effect is UIBlurEffect)
    XCTAssertTrue(child.superview === effectView.contentView)
    XCTAssertTrue(try XCTUnwrap(surface.hitTest(CGPoint(x: 30, y: 30), with: nil)).isDescendant(of: child))
    var changes = 0
    let observation = effectView.observe(\.effect) { _, _ in changes += 1 }
    for _ in 0..<100 { configure() }
    XCTAssertEqual(changes, 0, "Unchanged props/layout must reuse the existing blur")
    configure("clear")
    XCTAssertTrue(effectView.effect is UIBlurEffect)
    XCTAssertGreaterThan(changes, 0, "A material change must update the effect")
    observation.invalidate()
    configure("none")
    XCTAssertFalse(effectView.effect is UIBlurEffect)
    configure(container: true)
    XCTAssertFalse(effectView.effect is UIBlurEffect, "Layout containers must not stack blur effects")
    XCTAssertTrue(child.superview === effectView.contentView)
  }

  func testOlderIOSSurfaceInteraction() throws {
    guard !glassEra else { throw XCTSkip("Exercises the pre-26 surface") }
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let button = app.buttons["glass-counter"]
    XCTAssertTrue(button.waitForExistence(timeout: launchTimeout))
    button.tap()
    XCTAssertTrue(app.staticTexts["React button pressed"].waitForExistence(timeout: 5))
    let capture = XCTAttachment(screenshot: app.screenshot())
    capture.name = "Older iOS native blur surface"; capture.lifetime = .keepAlways; add(capture)
  }

  @MainActor func testActionVisualFeedbackConfiguration() throws {
    guard #available(iOS 26.0, *) else { throw XCTSkip("Requires native glass") }
    guard !UIAccessibility.isReduceTransparencyEnabled else { throw XCTSkip("Glass disabled by accessibility") }
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
    let controller = UIViewController()
    window.rootViewController = controller
    let cluster = ALGActionClusterView(frame: CGRect(x: 0, y: 0, width: 400, height: 88))
    controller.view.addSubview(cluster)
    window.isHidden = false
    defer { window.isHidden = true }
    let actions = #"[{"id":"heart","title":"Favorite","systemImage":"heart"}]"#
    func configure(interactive: Bool = true, tint: UIColor? = nil) {
      cluster.configure(actions, expanded: true, mergingEnabled: false, spacing: 20,
        tint: tint, material: "regular", interactive: interactive,
        duration: 0, toggleLabel: "Actions")
    }
    func layout(_ view: UIView) {
      view.setNeedsLayout(); view.layoutIfNeeded()
      view.subviews.forEach(layout)
    }
    func find(_ view: UIView, id: String) -> UIView? {
      if view.accessibilityIdentifier == id { return view }
      return view.subviews.compactMap { find($0, id: id) }.first
    }
    func descendants(_ view: UIView) -> [UIView] {
      view.subviews.flatMap { [$0] + descendants($0) }
    }
    // The reference uses the same host/props as the demo's Native surface.
    let reference = ALGSurfaceView(frame: CGRect(x: 0, y: 100, width: 160, height: 52))
    reference.configure("regular", interactive: true, tint: nil, radius: 25,
      container: false, mergingEnabled: false, spacing: 0, duration: 0, scheme: "system")
    controller.view.addSubview(reference)
    configure(); layout(window)
    let referenceEffect = try XCTUnwrap(descendants(reference).compactMap {
      ($0 as? UIVisualEffectView)?.effect as? UIGlassEffect
    }.first)
    for id in ["glass-cluster-toggle", "glass-action-heart"] {
      let item = try XCTUnwrap(find(cluster, id: id))
      let surface = try XCTUnwrap(descendants(item).compactMap { $0 as? UIVisualEffectView }.first)
      let glass = try XCTUnwrap(surface.effect as? UIGlassEffect)
      XCTAssertEqual(glass.isInteractive, referenceEffect.isInteractive)
      let tint = try XCTUnwrap(glass.tintColor)
      XCTAssertEqual(tint.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)), UIColor(white: 0, alpha: 0.65))
      XCTAssertEqual(tint.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).cgColor.alpha, 0)

      let icon = try XCTUnwrap(surface.contentView.subviews.compactMap { $0 as? UIImageView }.first)
      XCTAssertTrue(icon.superview === surface.contentView, "Glyph must deform with native glass content")
      XCTAssertFalse(descendants(item).contains { $0 is UIControl }, "No separate control inside glass")
      XCTAssertEqual(icon.layer.shadowOpacity, 0, "No replacement contrast effect")
      let target = item.hitTest(CGPoint(x: item.bounds.midX, y: item.bounds.midY), with: nil)
      XCTAssertTrue(try XCTUnwrap(target).isDescendant(of: surface), "Touches must enter UIKit's glass hierarchy")
      var effectChanges = 0
      let observation = surface.observe(\.effect) { _, _ in effectChanges += 1 }
      configure(); layout(window)
      XCTAssertEqual(effectChanges, 0, "Unchanged props must not replace the material")
      XCTAssertEqual(icon.alpha, 1)
      XCTAssertEqual(surface.superview?.transform, .identity, "No custom press transform")
      configure(interactive: false); layout(window)
      XCTAssertFalse(try XCTUnwrap(surface.effect as? UIGlassEffect).isInteractive)
      XCTAssertGreaterThan(effectChanges, 0)
      observation.invalidate()
      configure(); layout(window)
      XCTAssertTrue(try XCTUnwrap(surface.effect as? UIGlassEffect).isInteractive)
      configure(tint: .systemPurple); layout(window)
      XCTAssertEqual((surface.effect as? UIGlassEffect)?.tintColor, .systemPurple, "Respect explicit material tints")
      configure(); layout(window)
    }
    var requestedExpansion: Bool?
    cluster.onExpandedChange = { requestedExpansion = $0 }
    configure(interactive: false)
    XCTAssertTrue(try XCTUnwrap(find(cluster, id: "glass-cluster-toggle")).accessibilityActivate())
    XCTAssertEqual(requestedExpansion, false, "Disabling touch visuals must not disable activation")
  }

  func testNativeMenuActionsAndFallback() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let button = app.buttons["native-menu"]
    XCTAssertTrue(button.waitForExistence(timeout: launchTimeout))
    app.scrollIntoView(button)
    XCTAssertTrue(button.isHittable)
    for standard in [false, true] {
      if standard {
        let setting = app.switches["menu-fallback-toggle"]
        app.scrollIntoView(setting)
        setting.tap()
        app.scrollIntoView(button)
      }
      button.tap()
      let favorite = app.buttons["Favorite item"]
      XCTAssertTrue(favorite.waitForExistence(timeout: 5))
      XCTAssertFalse(app.buttons["Unavailable action"].isEnabled)
      let capture = XCTAttachment(screenshot: app.screenshot())
      capture.name = standard ? "Standard native menu" : "Glass native menu"
      capture.lifetime = .keepAlways
      add(capture)
      favorite.tap()
      XCTAssertTrue(app.staticTexts["Menu selected: favorite"].waitForExistence(timeout: 5))
      XCTAssertTrue(app.staticTexts[standard ? "Favorite: off" : "Favorite: on"].exists)
      button.tap()
      XCTAssertTrue(app.buttons["Share item"].waitForExistence(timeout: 5))
      app.buttons["Share item"].tap()
      XCTAssertTrue(app.staticTexts["Menu selected: share"].waitForExistence(timeout: 5))
      button.tap()
      XCTAssertTrue(app.buttons["Remove item"].waitForExistence(timeout: 5))
      app.buttons["Remove item"].tap()
      XCTAssertTrue(app.staticTexts["Menu selected: remove"].waitForExistence(timeout: 5))
    }
    button.tap()
    XCTAssertTrue(app.buttons["Share item"].waitForExistence(timeout: 5))
    // On iPad the centered React content has wide non-interactive margins.
    // Dismiss through the content above the menu, not through that margin.
    let outsideMenu = UIDevice.current.userInterfaceIdiom == .pad
      ? CGVector(dx: 0.5, dy: 0.2) : CGVector(dx: 0.05, dy: 0.12)
    app.coordinate(withNormalizedOffset: outsideMenu).tap()
    XCTAssertTrue(app.buttons["Share item"].waitForNonExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Menu selected: remove"].exists, "Dismissal must not emit an action")
    let disable = app.switches["menu-disabled-toggle"]
    app.scrollIntoView(disable)
    disable.tap()
    XCTAssertFalse(button.isEnabled)
    disable.tap()
    XCTAssertTrue(button.isEnabled)
  }

  // Drives each toolbar menu through open and dismissal in individual and
  // shared-glass modes. XCUITest waits for idle, so screenshots miss the
  // transient; record the simulator and run scripts/measure-dismissal-video.py
  // on the ALG-FRAME lines to measure the glass after each dismissal.
  func testToolbarDismissalMaterial() throws {
    guard glassEra else { throw XCTSkip("Glass toolbar requires iOS 26") }
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let sort = app.buttons["native-toolbar-sort"]
    XCTAssertTrue(sort.waitForExistence(timeout: launchTimeout))
    func bringIntoBand(_ element: XCUIElement) {
      app.scrollIntoView(element, band: 0.2...0.7)
      XCTAssertTrue(element.isHittable)
    }
    func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: app.screenshot())
      attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func exercise(_ mode: String, _ controls: [(String, String)]) {
      bringIntoBand(sort)
      for (id, title) in controls {
        let control = app.buttons[id]
        // The capsule menu button is sampled at a circular patch near its leading edge.
        let frame = control.frame
        let probeX = frame.width > 80 ? frame.minX + 30 : frame.midX
        print("ALG-FRAME \(mode)-\(id) \(probeX) \(frame.midY) \(min(frame.width, 48))")
        control.tap()
        XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.15)).tap()
        XCTAssertTrue(app.buttons[title].waitForNonExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 3)
        capture("\(mode)-\(id)-settled")
        XCTAssertTrue(control.isHittable)
        XCTAssertTrue(app.staticTexts["No toolbar action"].exists)
      }
    }
    exercise("individual", [("native-toolbar-sort", "By name"), ("native-toolbar-overflow", "Export entire collection"),
      ("hierarchy-menu", "Order options")])
    let shared = app.switches["toolbar-merging-toggle"]
    bringIntoBand(shared); shared.tap()
    exercise("shared", [("native-toolbar-sort", "By name"), ("native-toolbar-overflow", "Export entire collection")])
  }

  // GlassIconButton: square native icon host, plain press, menu with typed open/close
  // events, programmatic open (iOS 17.4+), and disabled state.
  func testIconButtonsAndProgrammaticMenu() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let close = app.buttons["icon-close"]
    let more = app.buttons["icon-more"]
    XCTAssertTrue(close.waitForExistence(timeout: launchTimeout))
    app.scrollIntoView(more, band: 0.2...0.7)
    XCTAssertEqual(close.frame.width, 40, accuracy: 1)
    XCTAssertEqual(close.frame.height, 40, accuracy: 1)
    XCTAssertEqual(close.label, "Close")
    func status(_ text: String) { XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 5), text) }
    func events(_ opened: Int, _ closed: Int) { status("Menu opened \(opened), closed \(closed)") }
    close.tap(); status("Icon pressed: close")
    // Tap opens the menu; an outside tap closes it without an action.
    more.tap()
    XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 5)); events(1, 0)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.15)).tap()
    XCTAssertTrue(app.buttons["Share"].waitForNonExistence(timeout: 5)); events(1, 1)
    status("Icon pressed: close")
    Thread.sleep(forTimeInterval: 2)
    let settled = XCTAttachment(screenshot: app.screenshot())
    settled.name = "Icon buttons settled after menu dismissal"; settled.lifetime = .keepAlways; add(settled)
    // Opening from code presents the same native menu; choosing an action closes it.
    let fromCode = app.buttons["icon-open-from-code"]
    fromCode.tap()
    XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 5)); events(2, 1)
    app.buttons["Share"].tap()
    status("Toolbar selected: share"); events(2, 2)
    // Disabled icon buttons neither press nor open, including from code.
    let disable = app.switches["toolbar-disabled-toggle"]
    app.scrollIntoView(disable)
    disable.tap()
    XCTAssertFalse(close.isEnabled); XCTAssertFalse(more.isEnabled)
    app.scrollIntoView(fromCode)
    fromCode.tap()
    XCTAssertFalse(app.buttons["Share"].waitForExistence(timeout: 2))
    events(2, 2)
  }

  // GlassBadge over imagery, the prominent FAB, and segment counts with per-segment colours.
  func testBadgesSegmentsAndFab() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    XCTAssertTrue(app.buttons["glass-counter"].waitForExistence(timeout: launchTimeout))
    func bringIntoView(_ element: XCUIElement) { app.scrollIntoView(element, band: 0.15...0.8) }
    // Counts and colours on the existing All/Saved/Shared control.
    let counts = app.switches["segment-counts-toggle"]
    bringIntoView(counts); counts.tap()
    let saved = app.descendants(matching: .any)["Saved 3"].firstMatch
    bringIntoView(saved)
    XCTAssertTrue(saved.exists)
    saved.tap()
    XCTAssertTrue(app.staticTexts["Showing: saved"].waitForExistence(timeout: 5))
    let segments = XCTAttachment(screenshot: app.screenshot())
    segments.name = "Saved segment selected with counts"; segments.lifetime = .keepAlways; add(segments)
    let fab = app.buttons["fab"]
    bringIntoView(fab)
    XCTAssertEqual(fab.frame.width, 56, accuracy: 1)
    XCTAssertTrue(app.staticTexts["New"].exists)
    XCTAssertTrue(app.staticTexts["Updating…"].exists)
    let capture = XCTAttachment(screenshot: app.screenshot())
    capture.name = "Badges and FAB"; capture.lifetime = .keepAlways; add(capture)
    fab.tap()
    XCTAssertTrue(app.staticTexts["FAB pressed"].waitForExistence(timeout: 5))
  }

  // GlassSearchField (controlled, fast typing, submit, clear, focus from code), GlassToast and the
  // scroll-edge container over a list. The toast and edge effect are checked in captures.
  func testSearchToastAndScrollEdge() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: app.screenshot())
      attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    let open = app.buttons["open-search-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
    let field = app.descendants(matching: .any)["item-search"].firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["20 results"].exists)
    field.tap()
    field.typeText("ec")
    XCTAssertTrue(app.staticTexts["2 results"].waitForExistence(timeout: 5))
    field.typeText("h\n")
    XCTAssertTrue(app.staticTexts["Submitted: ech"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["1 results"].exists)
    // Clear, then type quickly: React's echoed values must not drop characters typed meanwhile.
    field.tap()
    let clear = field.buttons.firstMatch
    XCTAssertTrue(clear.waitForExistence(timeout: 5)); clear.tap()
    XCTAssertTrue(app.staticTexts["20 results"].waitForExistence(timeout: 5))
    field.typeText("november")
    XCTAssertTrue(app.staticTexts["1 results"].waitForExistence(timeout: 5))
    XCTAssertEqual(field.value as? String, "november")
    capture("Search field with results")
    field.typeText("\n")
    for _ in 0..<5 { if app.keyboards.count == 0 { break }; Thread.sleep(forTimeInterval: 0.5) }
    // Clear the query through the search field so the list is long enough to scroll under the bar.
    field.tap()
    XCTAssertTrue(field.buttons.firstMatch.waitForExistence(timeout: 5)); field.buttons.firstMatch.tap()
    field.typeText("\n")
    XCTAssertTrue(app.staticTexts["20 results"].waitForExistence(timeout: 5))
    app.descendants(matching: .any)["search-results"].firstMatch.swipeUp()
    Thread.sleep(forTimeInterval: 1)
    capture("List scrolled under the scroll-edge bar")
    app.buttons["copy-action"].tap()
    Thread.sleep(forTimeInterval: 0.6)
    capture("Toast after copy")
    app.buttons["search-focus"].tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "focus() did not raise the keyboard")
  }

  // GlassExpandingTabs: controlled selection, the selected pill opening, and every label exposed.
  func testExpandingTabs() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let selection = app.staticTexts["Filter: overview"]
    XCTAssertTrue(app.buttons["glass-counter"].waitForExistence(timeout: launchTimeout))
    app.scrollIntoView(selection, band: 0.15...0.8)
    func pill(_ value: String) -> XCUIElement { app.buttons["filter-tabs-\(value)"] }
    // Collapsed pills still expose their labels to accessibility.
    XCTAssertEqual(pill("recent").label, "Recent")
    XCTAssertTrue(pill("overview").isSelected)
    let collapsedWidth = pill("recent").frame.width
    let capture = XCTAttachment(screenshot: app.screenshot())
    capture.name = "Expanding tabs, Overview selected"; capture.lifetime = .keepAlways; add(capture)
    pill("recent").tap()
    XCTAssertTrue(app.staticTexts["Filter: recent"].waitForExistence(timeout: 5))
    Thread.sleep(forTimeInterval: 0.6)
    XCTAssertTrue(pill("recent").isSelected)
    XCTAssertGreaterThan(pill("recent").frame.width, collapsedWidth + 20, "The selected pill did not open")
    XCTAssertFalse(pill("overview").isSelected)
    let selected = XCTAttachment(screenshot: app.screenshot())
    selected.name = "Expanding tabs, Recent selected"; selected.lifetime = .keepAlways; add(selected)
    let row = pill("overview").frame
    print("ALG-PILLROW \(row.minY) \(row.maxY)")
    // Step through the rest; the recording is checked for labels left behind by a closing pill.
    for value in ["favorites", "shared", "archive", "overview"] {
      print("ALG-PILL tap \(value)")
      pill(value).tap()
      XCTAssertTrue(app.staticTexts["Filter: \(value)"].waitForExistence(timeout: 5))
      Thread.sleep(forTimeInterval: 1)
    }
  }

  func testToolbarAndMenuBatch() throws {
    // The shared menu host changed; include its existing flat-menu regression.
    try testNativeMenuActionsAndFallback()
    let app = XCUIApplication(); app.launch()
    func reveal(_ element: XCUIElement) {
      app.scrollIntoView(element)
      XCTAssertTrue(element.isHittable)
    }
    func select(_ title: String) {
      let item = app.buttons[title]
      XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
    }
    func expectStatus(_ id: String) {
      XCTAssertTrue(app.staticTexts["Toolbar selected: \(id)"].waitForExistence(timeout: 5))
    }
    let save = app.buttons["native-toolbar-save"]
    XCTAssertTrue(save.waitForExistence(timeout: launchTimeout)); reveal(save); save.tap(); expectStatus("save")
    let sort = app.buttons["native-toolbar-sort"]
    sort.tap(); select("Most recent"); expectStatus("recent")
    XCTAssertTrue(app.staticTexts["Order: recent"].exists)
    sort.tap()
    XCTAssertTrue(app.buttons["Most recent"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Locked action"].isEnabled)
    let checked = XCTAttachment(screenshot: app.screenshot()); checked.name = "Toolbar grouped checked menu"; checked.lifetime = .keepAlways; add(checked)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.12)).tap()
    expectStatus("recent")
    let overflow = app.buttons["native-toolbar-overflow"]
    overflow.tap()
    XCTAssertFalse(app.buttons["Unavailable toolbar action"].isEnabled)
    select("Export entire collection"); expectStatus("export")
    let hierarchy = app.buttons["hierarchy-menu"]
    hierarchy.tap()
    XCTAssertFalse(app.buttons["Locked group"].isEnabled)
    select("Order options"); select("By name"); expectStatus("name")
    let disable = app.switches["toolbar-disabled-toggle"]
    reveal(disable); disable.tap()
    XCTAssertFalse(save.isEnabled); XCTAssertFalse(hierarchy.isEnabled)
    disable.tap()
    let narrow = app.switches["toolbar-narrow-toggle"]
    reveal(narrow); narrow.tap(); reveal(overflow); overflow.tap()
    select("Save"); expectStatus("save")
    let narrowCapture = XCTAttachment(screenshot: app.screenshot()); narrowCapture.name = "Narrow native toolbar"; narrowCapture.lifetime = .keepAlways; add(narrowCapture)
    reveal(narrow); narrow.tap()
    let replace = app.switches["toolbar-replace-toggle"]
    reveal(replace); replace.tap()
    let archive = app.buttons["native-toolbar-archive"]
    reveal(archive); archive.tap(); expectStatus("archive")
    XCTAssertFalse(save.exists)
    let standard = app.switches["toolbar-fallback-toggle"]
    reveal(standard); standard.tap(); reveal(archive); archive.tap(); expectStatus("archive")
    sort.tap(); select("Most recent"); expectStatus("recent")
    let timed = app.buttons["toolbar-timed-replace"]
    reveal(timed); timed.tap(); reveal(sort); sort.tap()
    XCTAssertTrue(app.buttons["Most recent"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Most recent"].waitForNonExistence(timeout: 25), "Replacing items must dismiss the open toolbar menu")
    XCTAssertTrue(save.waitForExistence(timeout: 5))
    expectStatus("recent")
  }

  // Lifecycle regressions from consumer review: selection on a controller that is not yet
  // attached asserted inside UIKit's tab model, a tab kept its selected image after UIKit
  // wrote it into tabBarItem, and the first tap on a fresh controller could be dropped.
  func testTabBarLifecycleAndFirstTap() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    func tab(_ name: String) -> XCUIElement { app.buttons["\(name) tab"] }
    func screen(_ name: String) { XCTAssertTrue(app.staticTexts["\(name) screen"].waitForExistence(timeout: 8)) }
    func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: app.screenshot())
      attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func reveal(_ element: XCUIElement) {
      app.scrollIntoView(element)
      XCTAssertTrue(element.isHittable)
    }
    // First tap on a freshly built controller after each cold launch must reach JavaScript.
    for launch in 0..<3 {
      app.launch()
      let open = app.buttons["open-tabs-demo"]
      XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
      screen("Home")
      XCTAssertTrue(tab("Library").waitForExistence(timeout: 5))
      tab("Library").tap()
      screen("Library")
      XCTAssertTrue(app.staticTexts["Tab pressed: Library"].exists, "First tap after cold launch \(launch) was dropped")
      XCTAssertTrue(tab("Library").isSelected)
      if launch == 0 {
        // Home was selected when UIKit built the tabs; it must now show its unselected image.
        capture("Home unselected after first switch")
      }
    }
    // Rebuild before attach and reorder after attach, each with a selection change in the same commit.
    for round in 0..<3 {
      let expected = round % 2 == 0 ? "Settings" : "Home"
      let rebuild = app.buttons["tabs-rebuild"]
      reveal(rebuild); rebuild.tap()
      screen(expected)
      XCTAssertTrue(tab(expected).waitForExistence(timeout: 5))
      XCTAssertTrue(tab(expected).isSelected, "Rebuilt tab bar did not select \(expected)")
    }
    let reorder = app.buttons["tabs-reorder-select"]
    reveal(reorder); reorder.tap()
    screen("Home")
    XCTAssertTrue(tab("Home").isSelected)
    reveal(reorder); reorder.tap()
    screen("Settings")
    XCTAssertTrue(tab("Settings").isSelected)
    // Taps still reach JavaScript after rebuilds.
    tab("Inbox").tap(); screen("Inbox")
    XCTAssertTrue(app.staticTexts["Tab pressed: Inbox"].exists)
    capture("Tabs after rebuilds")
  }

  // Per-tab colours and an asset-catalog image. Colours are checked in the captures.
  func testTabBarArtworkAndTints() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    func tab(_ name: String) -> XCUIElement { app.buttons["\(name) tab"] }
    func screen(_ name: String) { XCTAssertTrue(app.staticTexts["\(name) screen"].waitForExistence(timeout: 8)) }
    func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: app.screenshot())
      attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
    screen("Home")
    let brand = app.switches["tabs-brand-toggle"]
    app.scrollIntoView(brand)
    brand.tap()
    capture("Brand tabs, Home selected")
    tab("Library").tap(); screen("Library")
    XCTAssertTrue(tab("Library").isSelected)
    // Library's artwork is a require() image pair, loaded at runtime: the filled diamond in the tab's
    // colour while selected, the outline in the bar-wide inactive gray otherwise.
    let library = tab("Library").frame
    let iconBand = CGRect(x: library.minX, y: library.minY, width: library.width, height: library.height * 0.55)
    let selectedPixels = waitForPixels(app, in: iconBand, near: (0x2E, 0x7D, 0x32), atLeast: 40)
    capture("Brand tabs, Library selected")
    tab("Settings").tap(); screen("Settings")
    XCTAssertTrue(tab("Settings").isSelected)
    let inactivePixels = waitForPixels(app, in: iconBand, near: (0x8A, 0x8F, 0x98), atLeast: 20)
    XCTAssertGreaterThan(Double(selectedPixels), Double(inactivePixels) * 1.3,
      "The selected image source (filled) should cover more than the outline (\(selectedPixels) vs \(inactivePixels))")
    capture("Brand tabs, Settings selected with asset image")
  }
  /// Waits up to 5 s for `rect` to hold at least `minimum` pixels near `color`, and returns the count.
  @discardableResult
  private func waitForPixels(_ app: XCUIApplication, in rect: CGRect, near color: (Int, Int, Int), atLeast minimum: Int) -> Int {
    var count = 0
    for _ in 0..<10 {
      count = pixels(app.screenshot(), in: rect, near: color)
      if count >= minimum { return count }
      Thread.sleep(forTimeInterval: 0.5)
    }
    XCTFail("Expected \(minimum) pixels near \(color) in \(rect), found \(count)")
    return count
  }
  /// Pixels within `rect` (points) whose colour is within a small distance of `color`.
  private func pixels(_ screenshot: XCUIScreenshot, in rect: CGRect, near color: (Int, Int, Int)) -> Int {
    let image = screenshot.image
    let area = CGRect(x: rect.minX * image.scale, y: rect.minY * image.scale,
      width: rect.width * image.scale, height: rect.height * image.scale).integral
    guard let crop = image.cgImage?.cropping(to: area) else { return 0 }
    let width = crop.width, height = crop.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    let drawn: Bool = data.withUnsafeMutableBytes { buffer in
      guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
      context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else { return 0 }
    var count = 0
    for index in stride(from: 0, to: data.count, by: 4) {
      let red = Int(data[index]) - color.0, green = Int(data[index + 1]) - color.1, blue = Int(data[index + 2]) - color.2
      if red * red + green * green + blue * blue < 40 * 40 { count += 1 }
    }
    return count
  }

  // iOS 26 drag lens with per-tab colours. The lens exists only while a finger is down, so the
  // holds below are inspected in a simulator recording, not in XCTest screenshots.
  func testTabBarLensDrag() throws {
    guard glassEra else { throw XCTSkip("The drag lens requires iOS 26") }
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    func tab(_ name: String) -> XCUIElement { app.buttons["\(name) tab"] }
    func screen(_ name: String) { XCTAssertTrue(app.staticTexts["\(name) screen"].waitForExistence(timeout: 8)) }
    func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: app.screenshot())
      attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func drag(_ from: String, to: String) {
      let start = tab(from).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      let end = tab(to).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      print("ALG-LENS \(from)->\(to) hold begins")
      start.press(forDuration: 0.6, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 3)
      print("ALG-LENS \(from)->\(to) released")
    }
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
    screen("Home")
    // Default colours: UIKit swaps in the selected image (house.circle.fill) by itself.
    capture("Default tabs, Home selected")
    let brand = app.switches["tabs-brand-toggle"]
    app.scrollIntoView(brand)
    brand.tap()
    tab("Inbox").tap(); screen("Inbox")
    capture("Brand tabs, Inbox selected")
    drag("Inbox", to: "Library"); screen("Library")
    XCTAssertTrue(tab("Library").isSelected)
    capture("Brand tabs, Library selected after lens")
    drag("Library", to: "Home"); screen("Home")
    XCTAssertTrue(tab("Home").isSelected)
    capture("Brand tabs, Home selected after lens")
    drag("Home", to: "Settings"); screen("Settings")
    XCTAssertTrue(tab("Settings").isSelected)
    capture("Brand tabs, Settings selected after lens")
  }

  // Tab bar placement: host above the home indicator versus extended to the bottom edge.
  func testTabBarBottomPlacement() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
    XCTAssertTrue(app.staticTexts["Home screen"].waitForExistence(timeout: 8))
    func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: app.screenshot())
      attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    let home = app.buttons["Home tab"]
    print("ALG-TAB above-indicator \(home.frame.maxY) of \(app.frame.height)")
    capture("Tab host above the home indicator")
    let edge = app.switches["tabs-edge-toggle"]
    app.scrollIntoView(edge)
    edge.tap()
    Thread.sleep(forTimeInterval: 1)
    print("ALG-TAB bottom-edge \(home.frame.maxY) of \(app.frame.height)")
    capture("Tab host extended to the bottom edge")
    home.tap(); XCTAssertTrue(app.staticTexts["Home screen"].waitForExistence(timeout: 5))
    app.buttons["Inbox tab"].tap(); XCTAssertTrue(app.staticTexts["Inbox screen"].waitForExistence(timeout: 5))
  }

  func testNativeTabNavigationBatch() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
    func tab(_ name: String) -> XCUIElement { app.buttons["\(name) tab"] }
    func screen(_ name: String) { XCTAssertTrue(app.staticTexts["\(name) screen"].waitForExistence(timeout: 8)) }
    func toggle(_ id: String) {
      let control = app.switches[id]
      app.scrollIntoView(control)
      XCTAssertTrue(control.isHittable); control.tap()
    }
    screen("Home")
    XCTAssertTrue(tab("Home").isSelected)
    app.buttons["screen-increment"].tap()
    XCTAssertTrue(app.staticTexts["Home count: 1"].exists)
    tab("Library").tap(); screen("Library")
    XCTAssertTrue(tab("Library").isSelected)
    tab("Home").tap(); screen("Home")
    XCTAssertTrue(app.staticTexts["Home count: 1"].exists)
    tab("Home").tap()
    XCTAssertTrue(app.staticTexts["Tab events: 3"].waitForExistence(timeout: 5))
    toggle("tabs-reject-toggle")
    tab("Inbox").tap()
    XCTAssertTrue(app.staticTexts["Prevented: Inbox"].waitForExistence(timeout: 5)); screen("Home")
    XCTAssertTrue(tab("Home").isSelected); XCTAssertFalse(tab("Inbox").isSelected)
    toggle("tabs-reject-toggle")
    toggle("tabs-inbox-disabled-toggle")
    XCTAssertEqual(app.switches["tabs-inbox-disabled-toggle"].value as? String, "1")
    let disabledCapture = XCTAttachment(screenshot: app.screenshot())
    disabledCapture.name = "Native disabled tab"; disabledCapture.lifetime = .keepAlways; add(disabledCapture)
    tab("Inbox").tap(); screen("Home")
    // UIKit 26.5 exposes isEnabled=true in XCTest even for its dimmed,
    // disabled tabs. Assert actual activation and event behavior instead.
    XCTAssertTrue(tab("Home").isSelected)
    XCTAssertTrue(app.staticTexts["Tab events: 4"].exists)
    toggle("tabs-inbox-disabled-toggle")
    toggle("tabs-disabled-toggle")
    tab("Library").tap(); screen("Home")
    XCTAssertTrue(app.staticTexts["Tab events: 4"].exists)
    // Programmatic navigation remains available while user taps are disabled.
    let jump = app.buttons["tabs-go-inbox"]
    app.scrollIntoView(jump)
    jump.tap(); screen("Inbox"); XCTAssertTrue(tab("Inbox").isSelected)
    XCTAssertTrue(app.staticTexts["Tab events: 4"].exists)
    toggle("tabs-disabled-toggle")
    let oldHomeX = tab("Home").frame.midX
    toggle("tabs-reverse-toggle")
    XCTAssertGreaterThan(tab("Home").frame.midX, oldHomeX)
    XCTAssertTrue(tab("Inbox").isSelected)
    toggle("tabs-replace-toggle")
    XCTAssertFalse(tab("Library").exists)
    XCTAssertTrue(tab("Search").exists)
    tab("Search").tap(); screen("Search")
    let badgeCapture = XCTAttachment(screenshot: app.screenshot())
    badgeCapture.name = "Native tabs with numeric and dot badges"; badgeCapture.lifetime = .keepAlways; add(badgeCapture)
    toggle("tabs-badges-toggle")
    let clearCapture = XCTAttachment(screenshot: app.screenshot())
    clearCapture.name = "Native tabs badges cleared"; clearCapture.lifetime = .keepAlways; add(clearCapture)
    XCTAssertTrue(tab("Search").isSelected)
    app.buttons["close-tabs-demo"].tap()
    XCTAssertTrue(open.waitForExistence(timeout: 5)); open.tap(); screen("Home")
    XCTAssertTrue(tab("Home").isSelected)
  }

  func testAdaptiveControlAccessibility() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let open = app.buttons["open-accessibility-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
    // The demo screen must finish mounting before scrolling; an early probe followed by
    // one-directional swipes scrolls past controls near the top of the scroll view.
    XCTAssertTrue(app.staticTexts["Added: 0"].waitForExistence(timeout: 30))
    // isHittable is false for a disabled control, so this checks the frame instead; the
    // test deliberately scrolls to controls that report a disabled accessibility state.
    func onScreen(_ element: XCUIElement) -> Bool {
      guard element.exists else { return false }
      let frame = element.frame
      guard frame.height > 0 else { return false }
      // Tapping targets the centre, so require that rather than full containment: the pre-26
      // fallbacks are different heights from the native controls and a stricter test never
      // settles on some layouts.
      return app.frame.insetBy(dx: 0, dy: 40).contains(CGPoint(x: frame.midX, y: frame.midY))
    }
    func reveal(_ element: XCUIElement, up: Bool = true) {
      if onScreen(element) { return }
      app.scrollIntoView(element)
      if onScreen(element) { return }
      let hierarchy = XCTAttachment(string: app.debugDescription)
      hierarchy.name = "Hierarchy when an element could not be revealed"
      hierarchy.lifetime = .keepAlways; add(hierarchy)
      XCTAssertTrue(onScreen(element))
    }
    let button = app.buttons["adaptive-button"]
    reveal(button); button.tap()
    XCTAssertTrue(app.staticTexts["Added: 1"].exists)
    let loading = app.switches["adaptive-loading"]
    reveal(loading, up: false); loading.tap(); reveal(button)
    XCTAssertFalse(button.isEnabled)
    // SwiftUI publishes an accessibilityValue; the React fallback reports the busy state.
    XCTAssertEqual(button.value as? String, glassEra ? "Loading" : "busy")
    reveal(loading, up: false); loading.tap()
    if glassEra {
      let segments = app.segmentedControls["adaptive-segments"]
      reveal(segments); XCTAssertFalse(segments.buttons["Shared"].isEnabled)
      segments.buttons["Saved"].tap()
    } else {
      let saved = app.descendants(matching: .any)["adaptive-segments-saved"].firstMatch
      reveal(saved)
      XCTAssertFalse(app.descendants(matching: .any)["adaptive-segments-shared"].firstMatch.isEnabled)
      saved.tap()
    }
    XCTAssertTrue(app.staticTexts["Selected: saved"].exists)
    let toggle = app.buttons["glass-cluster-toggle"]
    reveal(toggle); toggle.tap()
    let locked = app.buttons["glass-action-locked"]
    XCTAssertFalse(locked.isEnabled)
    app.buttons["glass-action-save"].tap()
    XCTAssertTrue(app.staticTexts["Action: save"].exists)
    toggle.tap(); XCTAssertTrue(locked.waitForNonExistence(timeout: 5))
    let lockedTab = app.buttons["adaptive-tabs-locked"]
    let home = app.buttons["adaptive-tabs-home"]
    let inbox = app.buttons["adaptive-tabs-inbox"]
    reveal(lockedTab)
    let tabTree = XCTAttachment(string: app.debugDescription)
    tabTree.name = "Native tab bar accessibility hierarchy"
    tabTree.lifetime = .keepAlways; add(tabTree)
    // UIKit exposes each tab as a labelled button and reports the selected trait itself.
    // UITab.isEnabled dims a disabled tab and blocks its selection, but neither UITab nor
    // UITabBarItem declares a public accessibilityTraits property, so a disabled tab still
    // reports isEnabled here. Assert the observable guarantee and keep the trait reporting
    // as a recorded platform gap rather than asserting behaviour UIKit does not provide.
    XCTAssertEqual(lockedTab.label, "Locked")
    XCTAssertTrue(home.isSelected)
    lockedTab.tap()
    XCTAssertFalse(lockedTab.isSelected, "A disabled tab must not become selected")
    XCTAssertTrue(home.isSelected, "Selection must stay on the previous tab")
    inbox.tap(); XCTAssertTrue(inbox.isSelected)
    let capture = XCTAttachment(screenshot: app.screenshot())
    capture.name = "B3 native adaptive controls"; capture.lifetime = .keepAlways; add(capture)
  }

  func testAdaptiveLargeText() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    app.launch()
    let open = app.buttons["open-accessibility-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
    let all = app.descendants(matching: .any)["adaptive-segments-all"].firstMatch
    let saved = app.descendants(matching: .any)["adaptive-segments-saved"].firstMatch
    XCTAssertTrue(app.staticTexts["Selected: all"].waitForExistence(timeout: 30))
    app.scrollIntoView(saved)
    XCTAssertTrue(saved.isHittable)
    // Options stay side by side at the largest text size. Compare with a tolerance because
    // UIKit reports subpixel frame origins that make exact edge comparisons unreliable.
    XCTAssertEqual(saved.frame.minY, all.frame.minY, accuracy: 1)
    XCTAssertGreaterThanOrEqual(saved.frame.minX, all.frame.maxX - 1)
    XCTAssertEqual(saved.frame.width, all.frame.width, accuracy: 1)
    saved.tap()
    XCTAssertTrue(app.staticTexts["Selected: saved"].waitForExistence(timeout: 5))
    let capture = XCTAttachment(screenshot: app.screenshot())
    capture.name = "B3 largest accessibility text selector"; capture.lifetime = .keepAlways; add(capture)
  }

  func testNativeTabsBadgeRemovalSnapshot() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
    let badges = app.switches["tabs-badges-toggle"]
    XCTAssertTrue(badges.waitForExistence(timeout: 8)); badges.tap()
    XCTAssertEqual(badges.value as? String, "0")
    XCTAssertTrue(app.staticTexts["Home screen"].exists)
    let capture = XCTAttachment(screenshot: app.screenshot())
    capture.name = "Native tabs cleared badges fresh capture"; capture.lifetime = .keepAlways; add(capture)
  }

  // GlassMenuPanel: the menu with no trigger, placed by the app. Placements are checked from frames.
  // Menu panel (0.1.6): the message is a context menu with menuPlacement "below". Apple's own menu
  // opens below the lifted message, 20 pt from it, and the message moves only vertically (UIKit lifts
  // a low message just enough for the menu). Frame-by-frame motion was checked from recordings.
  func testGlassMenuPanel() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let open = app.buttons["open-context-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); open.tap()
    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    let longPress = app.switches["panel-longpress"]
    XCTAssertTrue(app.scrollIntoView(longPress)); longPress.tap()
    let message = element("panel-message")
    // The native segmented control (iOS 26) exposes buttons by label; the fallback has test IDs.
    func side(_ label: String, _ value: String) -> XCUIElement {
      let fallback = element("panel-side-\(value)")
      return fallback.exists ? fallback : app.buttons[label]
    }
    for (label, value) in [("Received", "received"), ("Sent", "sent")] {
      let control = side(label, value)
      XCTAssertTrue(app.scrollIntoView(control)); control.tap()
      for band in [0.12...0.22, 0.45...0.55, 0.8...0.9] as [ClosedRange<CGFloat>] {
        XCTAssertTrue(app.scrollIntoView(message, band: band))
        let original = message.frame
        message.press(forDuration: 1.0)
        let forward = app.buttons["Forward"], delete = app.buttons["Delete"]
        XCTAssertTrue(forward.waitForExistence(timeout: 5), "menu did not open (\(value), \(band))")
        Thread.sleep(forTimeInterval: 0.8)
        let preview = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Preview'")).firstMatch
        XCTAssertTrue(preview.exists)
        // On iOS 26 the lifted preview's container has a clear margin (5 pt for 20 pt corners) that keeps
        // UIKit's corner clip off the bubble; the bubble itself is inset by it. Earlier iOS has none.
        let margin: CGFloat = glassEra ? 5 : 0
        let lifted = preview.frame.insetBy(dx: margin, dy: margin), menuTop = forward.frame.minY - 10
        // Below the message, at the system's own spacing (iOS 26: 20 pt from the copy's container; iOS 18
        // is tighter).
        let gap = menuTop - lifted.maxY
        XCTAssertTrue((5...30).contains(gap), "menu not below the message (\(value), \(band)): gap \(gap)")
        XCTAssertEqual(lifted.minX, original.minX, accuracy: 1.5)
        XCTAssertLessThanOrEqual(lifted.minY, original.minY + 1)
        XCTAssertLessThanOrEqual(delete.frame.maxY, app.frame.maxY)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Menu below \(value) \(band)"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["Copy"].tap()
        XCTAssertTrue(app.staticTexts["Panel selected: copy"].waitForExistence(timeout: 5))
        XCTAssertTrue(forward.waitForNonExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.8)
      }
    }
  }

  // Visual tiers (R18): the native tier (glass on 26, blur below) and the standard opaque surface, in
  // light and dark. Screenshots are kept for review. The checks are that every tier follows the
  // appearance and that the standard surface keeps its documented default colours. The appearance
  // is pinned per launch with `-ALGAppearance` (see example/index.js); XCUIDevice.appearance did
  // not reach the app on the iOS 18.6 simulator.
  func testVisualTiers() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    let native = glassEra ? "glass" : "blur"
    var samples: [String: CGFloat] = [:]
    for appearance in ["light", "dark"] {
      app.launchArguments = ["-ALGAppearance", appearance]
      app.launch()
      let surface = app.descendants(matching: .any).matching(identifier: "adaptive-surface").firstMatch
      XCTAssertTrue(surface.waitForExistence(timeout: launchTimeout))
      let fallback = app.switches["fallback-toggle"]
      for tier in [native, "standard"] {
        if tier == "standard" {
          XCTAssertTrue(app.scrollIntoView(fallback))
          fallback.tap()
        }
        XCTAssertTrue(app.scrollIntoView(surface, band: 0.1...0.9))
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Tier \(tier) \(appearance)"; attachment.lifetime = .keepAlways; add(attachment)
        samples["\(tier) \(appearance)"] = meanLuminance(screenshot, in: surface.frame.insetBy(dx: 3, dy: 3))
      }
    }
    app.launchArguments = []
    for tier in [native, "standard"] {
      let light = try XCTUnwrap(samples["\(tier) light"]), dark = try XCTUnwrap(samples["\(tier) dark"])
      XCTAssertLessThan(dark + 0.1, light, "The \(tier) surface must follow the appearance (light \(light), dark \(dark))")
    }
    // The standard surface is opaque #F0F1F5 / #25272D; its label lowers or raises the mean a little.
    XCTAssertGreaterThan(try XCTUnwrap(samples["standard light"]), 0.8)
    XCTAssertLessThan(try XCTUnwrap(samples["standard dark"]), 0.3)
  }
  /// Mean relative luminance, 0 to 1, of a rectangle in points of a screenshot.
  private func meanLuminance(_ screenshot: XCUIScreenshot, in rect: CGRect) -> CGFloat {
    let image = screenshot.image
    let pixels = CGRect(x: rect.minX * image.scale, y: rect.minY * image.scale,
      width: rect.width * image.scale, height: rect.height * image.scale)
    guard let crop = image.cgImage?.cropping(to: pixels.integral) else { return -1 }
    let side = 8
    var data = [UInt8](repeating: 0, count: side * side * 4)
    let drawn: Bool = data.withUnsafeMutableBytes { buffer in
      guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
        bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
      context.interpolationQuality = .high
      context.draw(crop, in: CGRect(x: 0, y: 0, width: side, height: side))
      return true
    }
    guard drawn else { return -1 }
    var total: CGFloat = 0
    for index in stride(from: 0, to: data.count, by: 4) {
      total += 0.2126 * CGFloat(data[index]) + 0.7152 * CGFloat(data[index + 1]) + 0.0722 * CGFloat(data[index + 2])
    }
    return total / CGFloat(side * side) / 255
  }

  func testGlassHighlightComparison() throws {
    let app = XCUIApplication()
    app.launch()
    let toggle = app.buttons["glass-cluster-toggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: launchTimeout))
    let reference = app.descendants(matching: .any).matching(identifier: "adaptive-surface").firstMatch
    XCTAssertTrue(reference.exists)
    // Long holds expose peak lighting for the companion simulator recording.
    reference.press(forDuration: 3)
    toggle.press(forDuration: 3)
    reference.press(forDuration: 3)
    toggle.press(forDuration: 3)
  }

  func testActionInteractionToggle() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launch()
    let toggle = app.buttons["glass-cluster-toggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: launchTimeout))
    let setting = app.switches["interactive-toggle"]
    for expected in ["1", "0"] {
      app.scrollIntoView(setting)
      XCTAssertEqual(setting.value as? String, expected)
      setting.tap()
      XCTAssertEqual(setting.value as? String, expected == "0" ? "1" : "0")
      app.scrollIntoView(toggle)
      toggle.press(forDuration: 0.5)
      XCTAssertTrue(app.buttons["glass-action-heart"].waitForExistence(timeout: 5))
      app.buttons["glass-action-heart"].tap()
      XCTAssertTrue(app.staticTexts["Favorite selected"].waitForExistence(timeout: 5))
      toggle.tap()
      XCTAssertTrue(app.buttons["glass-action-heart"].waitForNonExistence(timeout: 5))
    }
  }

  func testActionClusterCancelledPressAndHitches() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launch()
    let toggle = app.buttons["glass-cluster-toggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: launchTimeout))
    let origin = toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let outside = origin.withOffset(CGVector(dx: 0, dy: -100))
    origin.press(forDuration: 0.5, thenDragTo: outside)
    XCTAssertEqual(toggle.value as? String, "Collapsed")
    XCTAssertFalse(app.buttons["glass-action-heart"].exists)
    // Isolate repeated native press/release work in the target app. This metric
    // measures hitches, not highlight intensity or the display's actual refresh rate.
    if #available(iOS 26.0, *) {
      let options = XCTMeasureOptions()
      options.iterationCount = 3
      measure(metrics: [XCTHitchMetric(application: app)], options: options) {
        toggle.press(forDuration: 0.35)
        app.buttons["glass-action-heart"].press(forDuration: 0.35)
        toggle.press(forDuration: 0.35)
      }
    }
    XCTAssertEqual(toggle.value as? String, "Collapsed")
  }

  func testActionClusterRepeatedPressAndRelease() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launch()
    let toggle = app.buttons["glass-cluster-toggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: launchTimeout))
    // Exercise native press/release and React callback updates in both rendering modes.
    // These assertions verify behavior, not frame rate or optical smoothness.
    for merging in [false, true] {
      if merging {
        let setting = app.switches["merging-enabled-toggle"]
        app.scrollIntoView(setting)
        XCTAssertTrue(setting.isHittable)
        XCTAssertEqual(setting.value as? String, "0")
        setting.tap()
        app.scrollIntoView(toggle)
      }
      for _ in 0..<2 {
        toggle.press(forDuration: 0.25)
        let favorite = app.buttons["glass-action-heart"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "Expanded")
        for (id, title) in [("heart", "Favorite"), ("bookmark", "Save"), ("share", "Share")] {
          app.buttons["glass-action-" + id].press(forDuration: 0.2)
          XCTAssertTrue(app.staticTexts[title + " selected"].waitForExistence(timeout: 5))
        }
        toggle.press(forDuration: 0.25)
        XCTAssertTrue(favorite.waitForNonExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "Collapsed")
      }
    }
  }

  func testSliderStepsControlledReconciliationAndDisabledState() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.buttons["glass-counter"].waitForExistence(timeout: launchTimeout))
    let slider = app.sliders["native-slider"]
    app.scrollIntoView(slider)
    XCTAssertTrue(slider.isHittable, app.debugDescription)
    XCTAssertEqual(slider.value as? String, "40")
    slider.adjust(toNormalizedSliderPosition: 0.81)
    let completed = NSPredicate(format: "label BEGINSWITH %@", "Completed:")
    expectation(for: completed, evaluatedWith: app.staticTexts["slider-event"])
    waitForExpectations(timeout: 5)
    let stepped = Double(slider.value as? String ?? "") ?? -1
    XCTAssertGreaterThan(stepped, 40)
    XCTAssertEqual(stepped.truncatingRemainder(dividingBy: 10), 0)
    app.buttons["slider-reset"].tap()
    XCTAssertEqual(slider.value as? String, "40")
    app.switches["slider-lock-toggle"].tap()
    slider.adjust(toNormalizedSliderPosition: 0.9)
    let restored = NSPredicate(format: "value == %@", "40")
    expectation(for: restored, evaluatedWith: slider)
    waitForExpectations(timeout: 5)
    XCTAssertTrue(app.staticTexts["Level: 40"].exists)
    app.switches["slider-lock-toggle"].tap()
    app.switches["slider-disabled-toggle"].tap()
    XCTAssertFalse(slider.isEnabled)
    app.switches["slider-disabled-toggle"].tap()
    app.switches["slider-step-toggle"].tap()
    slider.adjust(toNormalizedSliderPosition: 0.63)
    let continuous = Double(slider.value as? String ?? "") ?? -1
    XCTAssertGreaterThan(continuous, 40)
    XCTAssertLessThan(continuous, 100)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Native slider continuous interaction"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  func testNativeButtonAndSegmentedControl() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.buttons["glass-counter"].waitForExistence(timeout: launchTimeout))
    if glassEra {
      let segments = app.segmentedControls["native-segments"]
      app.scrollIntoView(segments)
      XCTAssertTrue(segments.isHittable, app.debugDescription)
      XCTAssertFalse(segments.buttons["Shared"].isEnabled)
      segments.buttons["Saved"].tap()
    } else {
      let saved = app.descendants(matching: .any)["native-segments-saved"].firstMatch
      app.scrollIntoView(saved)
      XCTAssertTrue(saved.isHittable, app.debugDescription)
      XCTAssertFalse(app.descendants(matching: .any)["native-segments-shared"].firstMatch.isEnabled)
      saved.tap()
    }
    XCTAssertTrue(app.staticTexts["Showing: saved"].waitForExistence(timeout: 5))
    let primary = app.buttons["native-primary-button"]
    primary.tap()
    XCTAssertTrue(app.staticTexts["Added: 1"].waitForExistence(timeout: 5))
    app.buttons["native-reset-button"].tap()
    XCTAssertTrue(app.staticTexts["Showing: all"].waitForExistence(timeout: 5))
    let native = XCTAttachment(screenshot: app.screenshot())
    native.name = "Native button and segmented control"
    native.lifetime = .keepAlways
    add(native)
    app.switches["controls-disabled-toggle"].tap()
    XCTAssertFalse(primary.isEnabled)
    // The disabled selected option is a UIKit segment on iOS 26 and a radio view below it.
    if glassEra {
      XCTAssertFalse(app.segmentedControls["native-segments"].buttons["Saved"].isEnabled)
    } else {
      XCTAssertFalse(app.descendants(matching: .any)["native-segments-saved"].firstMatch.isEnabled)
    }
    app.switches["controls-disabled-toggle"].tap()
    app.switches["button-loading-toggle"].tap()
    XCTAssertFalse(primary.isEnabled)
    app.switches["button-loading-toggle"].tap()
    XCTAssertTrue(primary.isEnabled)
    app.switches["controls-fallback-toggle"].tap()
    let saved = app.descendants(matching: .any)["native-segments-saved"].firstMatch
    XCTAssertTrue(saved.waitForExistence(timeout: 5))
    saved.tap()
    XCTAssertTrue(app.staticTexts["Showing: saved"].waitForExistence(timeout: 5))
    app.buttons["native-primary-button"].tap()
    XCTAssertTrue(app.staticTexts["Added: 2"].waitForExistence(timeout: 5))
    let fallback = XCTAttachment(screenshot: app.screenshot())
    fallback.name = "Standard button and segmented control"
    fallback.lifetime = .keepAlways
    add(fallback)
  }

  func testNativeEventsLivePropsAndFallback() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.buttons["glass-counter"].waitForExistence(timeout: launchTimeout), app.debugDescription)
    app.buttons["glass-counter"].tap()
    XCTAssertTrue(app.staticTexts["React button pressed"].waitForExistence(timeout: 5))
    let toggle = app.buttons["glass-cluster-toggle"]
    XCTAssertTrue(toggle.exists)
    toggle.tap()
    let favorite = app.buttons["glass-action-heart"]
    XCTAssertTrue(favorite.waitForExistence(timeout: 5), app.debugDescription)
    favorite.tap()
    XCTAssertTrue(app.staticTexts["Favorite selected"].waitForExistence(timeout: 5))
    let expanded = XCTAttachment(screenshot: app.screenshot())
    expanded.name = "Native glass expanded"
    expanded.lifetime = .keepAlways
    add(expanded)
    toggle.tap()
    XCTAssertTrue(favorite.waitForNonExistence(timeout: 5))
    app.swipeUp()
    for identifier in ["interactive-toggle", "clear-toggle", "tint-toggle"] {
      let control = app.switches[identifier]
      XCTAssertTrue(control.waitForExistence(timeout: 5), app.debugDescription)
      control.tap()
    }
    let mergingSwitch = app.switches["merging-enabled-toggle"]
    XCTAssertEqual(mergingSwitch.value as? String, "0")
    app.buttons["merge-toggle"].tap()
    let separated = NSPredicate(format: "label CONTAINS %@", "Separate surfaces")
    expectation(for: separated, evaluatedWith: app.buttons["merge-toggle"])
    waitForExpectations(timeout: 5)
    let independent = XCTAttachment(screenshot: app.screenshot())
    independent.name = "Close surfaces merging off by default"
    independent.lifetime = .keepAlways
    add(independent)
    mergingSwitch.tap()
    XCTAssertEqual(mergingSwitch.value as? String, "1")
    let merging = XCTAttachment(screenshot: app.screenshot())
    merging.name = "Native merging surfaces"
    merging.lifetime = .keepAlways
    add(merging)
    mergingSwitch.tap()
    XCTAssertEqual(mergingSwitch.value as? String, "0")
    let unmerged = XCTAttachment(screenshot: app.screenshot())
    unmerged.name = "Close surfaces merging disabled again"
    unmerged.lifetime = .keepAlways
    add(unmerged)
    app.switches["fallback-toggle"].tap()
    app.swipeDown()
    XCTAssertTrue(app.staticTexts["Standard component preview"].waitForExistence(timeout: 5))
    app.buttons["glass-counter"].tap()
    app.buttons["glass-cluster-toggle"].tap()
    app.buttons["glass-action-bookmark"].tap()
    XCTAssertTrue(app.staticTexts["Save selected"].waitForExistence(timeout: 5))
    let fallback = XCTAttachment(screenshot: app.screenshot())
    fallback.name = "Standard fallback components"
    fallback.lifetime = .keepAlways
    add(fallback)
  }
  func testSwiftUIClusterMergingAndRTL() throws {
    guard glassEra else { throw XCTSkip("SwiftUI glass requires iOS 26") }
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]
    app.launch()
    defer { app.terminate() }
    let toggle = app.buttons["glass-cluster-toggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: launchTimeout))
    func reveal(_ element: XCUIElement, up: Bool) {
      app.scrollIntoView(element)
      XCTAssertTrue(element.isHittable)
    }
    let implementation = app.switches["swiftui-cluster-toggle"]
    reveal(implementation, up: true); implementation.tap()
    let merging = app.switches["merging-enabled-toggle"]
    reveal(merging, up: true); merging.tap()
    reveal(toggle, up: false)
    for _ in 0..<2 {
      toggle.tap()
      let favorite = app.buttons["glass-action-heart"]
      XCTAssertTrue(favorite.waitForExistence(timeout: 5))
      XCTAssertGreaterThan(favorite.frame.midX, toggle.frame.midX)
      for (id, title) in [("heart", "Favorite"), ("bookmark", "Save"), ("share", "Share")] {
        let action = app.buttons["glass-action-" + id]
        XCTAssertTrue(action.isHittable)
        XCTAssertGreaterThanOrEqual(action.frame.width, 44)
        XCTAssertGreaterThanOrEqual(action.frame.height, 44)
        action.tap()
        XCTAssertTrue(app.staticTexts[title + " selected"].waitForExistence(timeout: 5))
      }
      let capture = XCTAttachment(screenshot: app.screenshot())
      capture.name = "SwiftUI merged RTL cluster"; capture.lifetime = .keepAlways; add(capture)
      toggle.tap()
      XCTAssertTrue(favorite.waitForNonExistence(timeout: 5))
    }
  }

}
