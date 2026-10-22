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
  func testUpgradeSurfaceReattach() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch(); defer { app.terminate() }
    let open = app.buttons["open-upgrade-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
    let toggle = app.buttons["upgrade-toggle-surfaces"]
    XCTAssertTrue(app.scrollIntoView(toggle, band: 0.1...0.5))
    let surfaces = app.otherElements["upgrade-surfaces"]
    XCTAssertTrue(surfaces.waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1)
    let first = surfaces.screenshot().image
    let controls = app.otherElements["upgrade-control-buttons"], untinted = app.otherElements["upgrade-untinted-surfaces"]
    let controlFirst = controls.screenshot().image, untintedFirst = untinted.screenshot().image
    // Warm-up cycle: the comparison below is between two returns to the same state.
    // Device glass keeps adapting for 1.5–3 s after a re-attach; compare settled states only.
    toggle.tap(); Thread.sleep(forTimeInterval: 0.3); toggle.tap(); Thread.sleep(forTimeInterval: 3.5)
    let before = surfaces.screenshot().image
    // Noise floor: the same surfaces captured again with no action in between.
    Thread.sleep(forTimeInterval: 1); let still = surfaces.screenshot().image
    toggle.tap(); Thread.sleep(forTimeInterval: 0.3); toggle.tap(); Thread.sleep(forTimeInterval: 1)
    let early = surfaces.screenshot().image
    Thread.sleep(forTimeInterval: 2.5)
    let after = surfaces.screenshot().image
    Thread.sleep(forTimeInterval: 1); let afterStill = surfaces.screenshot().image
    let controlAfter = controls.screenshot().image, untintedAfter = untinted.screenshot().image
    for (name, image) in [("reattach-before", before), ("reattach-after", after)] {
      let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func pixels(_ image: UIImage) -> [UInt8] {
      guard let cg = image.cgImage else { return [] }
      var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
      bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8,
          bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
      }
      return bytes
    }
    let a = pixels(before), b = pixels(after), n = pixels(still), e = pixels(early), f = pixels(first)
    print("ALG-INFO reattach-first-vs-warm max=\(zip(f, a).map { abs(Int($0.0) - Int($0.1)) }.max() ?? 0) over2=\(zip(f, a).filter { abs(Int($0.0) - Int($0.1)) > 2 }.count)")
    print("ALG-INFO reattach-early max=\(zip(a, e).map { abs(Int($0.0) - Int($0.1)) }.max() ?? 0)")
    XCTAssertFalse(a.isEmpty); XCTAssertEqual(a.count, b.count)
    let noise = zip(a, n).map { abs(Int($0.0) - Int($0.1)) }.max() ?? 0
    let delta = zip(a, b).map { abs(Int($0.0) - Int($0.1)) }.max() ?? 0
    print("ALG-INFO reattach noiseFloor=\(noise) reattachMax=\(delta) changedOver2=\(zip(a, b).filter { abs(Int($0.0) - Int($0.1)) > 2 }.count) noiseOver2=\(zip(a, n).filter { abs(Int($0.0) - Int($0.1)) > 2 }.count)")
    // G1. Re-attached glass must be settled, not drifting (keeping the old effect drifts by
    // 16/255 within a second on device). Simulator: UIKit regenerates the rim highlight, 6
    // channels at 3/255. Device: each fresh effect lands within 17/255 of the earlier look
    // (iPhone 13 Pro, iOS 26.7.1); recorded in docs/upgrade-0.2.0.md.
    let settled = zip(b, pixels(afterStill)).map { abs(Int($0.0) - Int($0.1)) }.max() ?? 0
    // Control: UIKit-owned UIButton glass, re-attached by the same screen swap (first state vs final).
    let cf = pixels(controlFirst), ca = pixels(controlAfter)
    let uf = pixels(untintedFirst), ua = pixels(untintedAfter)
    print("ALG-INFO reattach-untinted-glass max=\(zip(uf, ua).map { abs(Int($0.0) - Int($0.1)) }.max() ?? 0) over2=\(zip(uf, ua).filter { abs(Int($0.0) - Int($0.1)) > 2 }.count) of=\(uf.count)")
    print("ALG-INFO reattach-uikit-control max=\(zip(cf, ca).map { abs(Int($0.0) - Int($0.1)) }.max() ?? 0) over2=\(zip(cf, ca).filter { abs(Int($0.0) - Int($0.1)) > 2 }.count) of=\(cf.count) surfaceFirstVsAfter=\(zip(f, b).map { abs(Int($0.0) - Int($0.1)) }.max() ?? 0)")
    print("ALG-INFO reattach settled=\(settled)")
    XCTAssertEqual(noise, 0, "identical captures")
    XCTAssertLessThanOrEqual(settled, 2, "re-attached glass keeps changing")
    #if targetEnvironment(simulator)
    XCTAssertLessThanOrEqual(delta, 3, "re-attach differs beyond UIKit's rim regeneration")
    XCTAssertLessThanOrEqual(zip(a, b).filter { abs(Int($0.0) - Int($0.1)) > 2 }.count, 6)
    #else
    XCTAssertLessThanOrEqual(delta, 20, "re-attach far outside the measured device range")
    #endif
    let changed = zip(a, b).filter { abs(Int($0.0) - Int($0.1)) > 2 }.count
    // On this simulator the original clear+assign path also changes six rim channels by 3.
    // Its after image and the optimized path's after image are byte-identical (B19Baseline).
    // Keep a strict maximum and sparse-noise cap; this is a baseline regression test, not a
    // claim that the request's literal +/-2 criterion passes on the reference implementation.
    let maximum = zip(a, b).map { abs(Int($0.0) - Int($0.1)) }.max() ?? 0
    XCTAssertLessThanOrEqual(maximum, 3)
    XCTAssertLessThanOrEqual(changed, max(6, a.count / 100_000))
  }

  /// G1 profiling: idles while scripts/profile-reattach.sh attaches Time Profiler, then runs
  /// marked re-attach cycles of 20 glass surfaces.
  func testAcceptanceSurfaceProfile() throws {
    let app = XCUIApplication(); app.launch(); defer { app.terminate() }
    let open = app.buttons["open-upgrade-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
    let toggle = app.buttons["upgrade-toggle-surfaces"]
    XCTAssertTrue(app.scrollIntoView(toggle, band: 0.1...0.5))
    print("ALG-MARK profile-ready \(String(format: "%.4f", Date().timeIntervalSince1970))")
    Thread.sleep(forTimeInterval: 8)
    for cycle in 0..<10 {
      toggle.tap(); Thread.sleep(forTimeInterval: 0.4)
      mark("reattach-\(cycle)"); toggle.tap(); Thread.sleep(forTimeInterval: 0.6)
    }
    XCTAssertTrue(app.otherElements["upgrade-surfaces"].exists)
  }

  func testUpgradeBadgeDrag() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    let open = app.buttons["open-upgrade-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
    // Press-drag-hold the badge-bearing favourite button and the Saved pill in every direction,
    // including up and down. The badge rides the glass swell (following the proxy scale, which
    // stays enlarged through a drag even though the button's press flags drop), leans toward the
    // finger, and springs back to rest; it must survive every drag and a multi-second hold.
    for id in ["upgrade-badge", "upgrade-pill-saved"] {
      let button = app.buttons[id]
      XCTAssertTrue(button.waitForExistence(timeout: 5))
      let value = button.value as? String
      for offset in [CGVector(dx: 36, dy: 0), CGVector(dx: -36, dy: 0), CGVector(dx: 0, dy: 30), CGVector(dx: 0, dy: -30)] {
        let start = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.8, thenDragTo: start.withOffset(offset),
          withVelocity: XCUIGestureVelocity(rawValue: 35), thenHoldForDuration: 1.0)
        Thread.sleep(forTimeInterval: 0.7)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "\(id) must remain after a \(offset) drag")
      }
      // A multi-second hold must not drop the badge or its control.
      button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 3.0)
      XCTAssertTrue(button.waitForExistence(timeout: 5), "\(id) must survive a long hold")
      XCTAssertEqual(button.value as? String, value, "\(id) badge value must be unchanged after drags")
      let capture = XCTAttachment(screenshot: app.screenshot())
      capture.name = "badge-drag-\(id)"; capture.lifetime = .keepAlways; add(capture)
    }
  }

  func testUpgradeMorphBadge() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    let open = app.buttons["open-upgrade-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
    let morph = app.buttons["upgrade-morph"]
    XCTAssertTrue(morph.waitForExistence(timeout: 5))
    let initial = morph.frame

    // Accessibility values alone cannot detect a badge that balloons or flies away.
    // Check its rendered size and anchor at rest; inspect the companion recording
    // with verify-ios-pill-badge.py for transient size/position discontinuities.
    func checkBadge(_ name: String) {
      Thread.sleep(forTimeInterval: 0.8)
      let frame = morph.frame
      let screenshot = app.screenshot()
      let image = screenshot.image
      let capture = XCTAttachment(screenshot: screenshot)
      capture.name = name; capture.lifetime = .keepAlways; add(capture)
      guard let cg = image.cgImage else { return XCTFail("Missing screenshot pixels") }
      let scale = CGFloat(cg.width) / app.frame.width
      let region = frame.insetBy(dx: -30, dy: -30)
      guard let crop = cg.cropping(to: CGRect(x: region.minX * scale, y: region.minY * scale,
        width: region.width * scale, height: region.height * scale).integral) else {
        return XCTFail("Missing morph region")
      }
      var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
      pixels.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: crop.width, height: crop.height,
          bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
      }
      var minX = crop.width, minY = crop.height, maxX = -1, maxY = -1
      for y in 0..<crop.height { for x in 0..<crop.width {
        let i = (y * crop.width + x) * 4
        if pixels[i] > 170 && pixels[i + 1] < 115 && pixels[i + 2] < 130 {
          minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
      } }
      XCTAssertGreaterThanOrEqual(maxX, minX, "Badge must remain visible")
      guard maxX >= minX else { return }
      XCTAssertEqual(CGFloat(maxY - minY + 1) / scale, 18, accuracy: 2)
      XCTAssertLessThan(CGFloat(maxX - minX + 1) / scale, 24)
      XCTAssertEqual(CGFloat(minX + maxX) / (2 * scale), 30 + frame.width * 0.854, accuracy: 2)
      XCTAssertEqual(CGFloat(minY + maxY) / (2 * scale), 30 + frame.height * 0.146, accuracy: 2)
      XCTAssertEqual(morph.value as? String, "5 new")
    }
    checkBadge("morph-initial")
    for i in 0..<3 {
      morph.tap(); XCTAssertEqual(morph.label, "Done")
      checkBadge("morph-expanded-\(i)")
      XCTAssertGreaterThan(morph.frame.width, initial.width + 5)
      morph.tap(); XCTAssertEqual(morph.label, "Edit")
      checkBadge("morph-collapsed-\(i)")
      XCTAssertEqual(morph.frame.width, initial.width, accuracy: 1)
      XCTAssertEqual(morph.frame.maxX, initial.maxX, accuracy: 1)
    }
    // Two taps inside a single gesture can interrupt the first width animation.
    morph.doubleTap()
    checkBadge("morph-interrupted")
    morph.press(forDuration: 3)
    checkBadge("morph-after-hold")
  }

  /// Bounding box (points, relative to the element) of pixels matching `match` around an element.
  private func badgeBox(_ app: XCUIApplication, _ element: XCUIElement, name: String, margin: CGFloat = 20,
    match: (UInt8, UInt8, UInt8) -> Bool) -> CGRect? {
    let frame = element.frame
    let screenshot = app.screenshot()
    let capture = XCTAttachment(screenshot: screenshot); capture.name = name; capture.lifetime = .keepAlways; add(capture)
    guard let cg = screenshot.image.cgImage else { return nil }
    let scale = CGFloat(cg.width) / app.frame.width
    let region = frame.insetBy(dx: -margin, dy: -margin)
    guard let crop = cg.cropping(to: CGRect(x: region.minX * scale, y: region.minY * scale,
      width: region.width * scale, height: region.height * scale).integral) else { return nil }
    var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
    pixels.withUnsafeMutableBytes { buffer in
      CGContext(data: buffer.baseAddress, width: crop.width, height: crop.height, bitsPerComponent: 8,
        bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
    }
    var minX = crop.width, minY = crop.height, maxX = -1, maxY = -1
    for y in 0..<crop.height { for x in 0..<crop.width {
      let i = (y * crop.width + x) * 4
      if match(pixels[i], pixels[i + 1], pixels[i + 2]) { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
    } }
    guard maxX >= minX else { return nil }
    return CGRect(x: CGFloat(minX) / scale - margin, y: CGFloat(minY) / scale - margin,
      width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale)
  }

  // Opt-in reference capture, excluded from the normal focused package checks.
  func testSystemHeaderReferences() throws {
    for (bundle, name) in [("com.apple.MobileAddressBook", "contacts"), ("com.apple.MobileSMS", "messages"), ("com.apple.shortcuts", "shortcuts")] {
      let app = XCUIApplication(bundleIdentifier: bundle)
      app.launch()
      Thread.sleep(forTimeInterval: 1)
      if name == "shortcuts", app.tabBars.buttons["Library"].firstMatch.exists { app.tabBars.buttons["Library"].firstMatch.tap() }
      let scroll = app.scrollViews.firstMatch.exists ? app.scrollViews.firstMatch
        : app.tables.firstMatch.exists ? app.tables.firstMatch : app.collectionViews.firstMatch
      if scroll.exists { scroll.swipeUp() }
      let capture = XCTAttachment(screenshot: app.screenshot())
      capture.name = "system-header-\(name)"; capture.lifetime = .keepAlways; add(capture)
      app.terminate()
    }
  }

  func testProgressiveScrollHeader() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openNavigation(app)
    let open = app.buttons["nav-blur-only"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
    let title = app.staticTexts["contacts-title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5)); let frame = title.frame
    app.buttons["header-scroll"].tap(); Thread.sleep(forTimeInterval: 0.8)
    XCTAssertEqual(title.frame, frame)
    let screenshot = app.screenshot()
    let capture = XCTAttachment(screenshot: screenshot); capture.name = "progressive-header-scrolled"; capture.lifetime = .keepAlways; add(capture)
    let header = app.otherElements["contacts-header"].frame
    let image = try XCTUnwrap(screenshot.image.cgImage)
    let scale = CGFloat(image.width) / app.frame.width
    func meanColor(_ rect: CGRect) throws -> [Double] {
      let area = CGRect(x: (header.minX + rect.minX) * scale, y: (header.minY + rect.minY) * scale,
        width: rect.width * scale, height: rect.height * scale)
      let cg = try XCTUnwrap(image.cropping(to: area))
      var data = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
      data.withUnsafeMutableBytes { buffer in
        CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8,
          bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
      }
      return (0..<3).map { channel in
        stride(from: channel, to: data.count, by: 4).reduce(0.0) { $0 + Double(data[$1]) } / Double(cg.width * cg.height)
      }
    }
    // A uniform material made this empty region grey (39/39/42). The native
    // soft edge preserves the backdrop while progressively softening list ink.
    let background = try meanColor(CGRect(x: 250, y: 10, width: 30, height: 20))
    let avatar = try meanColor(CGRect(x: 38, y: 52, width: 8, height: 8))
    XCTAssertLessThan(avatar[0], 130, "Unprocessed scrolling content must not overlap header text")
    if #available(iOS 26.0, *) {
      for (actual, expected) in zip(background, [18.0, 20.0, 26.0]) { XCTAssertEqual(actual, expected, accuracy: 8) }
      XCTAssertGreaterThan(avatar[0], 30, "The effect must preserve underlying content, not paint an opaque panel")
    } else {
      // Older iOS has no scroll edge effect: the documented fallback is a uniform material or fill.
      XCTAssertLessThan(background.max()! - background.min()!, 12, "Older iOS: a uniform fallback panel, not tinted content")
    }
    app.buttons["header-add"].tap()
    XCTAssertTrue(app.staticTexts["header-added"].label.contains("21"))
    app.buttons["header-reset"].tap()
    app.buttons["close-scroll-header"].tap()
    app.buttons["nav-blur-only"].tap()
    XCTAssertTrue(app.staticTexts["contacts-title"].waitForExistence(timeout: 5))
  }

  func testNativeNavigationHeader() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openNavigation(app)
    app.buttons["open-scroll-header"].tap()
    let bar = app.navigationBars.firstMatch
    XCTAssertTrue(bar.waitForExistence(timeout: 5))
    func title() -> XCUIElement { bar.staticTexts.matching(identifier: "Contacts").allElementsBoundByIndex.first(where: { $0.isHittable }) ?? bar.staticTexts["Contacts"].firstMatch }
    let expanded = title().frame
    XCTAssertGreaterThan(expanded.height, 30, "Initial title should use the native large style")
    app.otherElements["navigation-contacts"].scrollViews.firstMatch.swipeUp()
    let collapsed = title().frame
    XCTAssertLessThan(collapsed.height, expanded.height - 5)
    XCTAssertEqual(collapsed.midX, app.frame.midX, accuracy: 4)
    let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "native-navigation-collapsed"; capture.lifetime = .keepAlways; add(capture)
    app.buttons["nav-add"].tap(); app.buttons["nav-top"].tap()
    XCTAssertTrue(app.staticTexts["nav-status"].label.contains("21"))
    XCTAssertGreaterThan(title().frame.height, collapsed.height + 5)
    XCTAssertGreaterThanOrEqual(app.staticTexts["nav-status"].frame.minY, bar.frame.maxY - 1)
    app.buttons["nav-more"].tap(); app.buttons["Mark all read"].tap()
    XCTAssertTrue(app.staticTexts["nav-status"].label.contains("All marked read"))
    app.buttons["nav-search-toggle"].tap()
    let field = app.searchFields["navigation-search"]
    XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("Maya")
    XCTAssertTrue(app.buttons["Maya Chen"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Noah Williams"].exists)
    let closeSearch = app.buttons.matching(NSPredicate(format: "label == 'Close' OR label == 'Cancel'")).firstMatch
    closeSearch.tap()
    XCTAssertTrue(app.buttons["Noah Williams"].waitForExistence(timeout: 5), "Closing search clears the controlled filter")
    app.buttons["navigation-back"].tap()
    XCTAssertTrue(app.buttons["open-scroll-header"].waitForExistence(timeout: 5))
    app.buttons["open-scroll-header"].tap(); XCTAssertTrue(app.buttons["nav-add"].waitForExistence(timeout: 5))
  }

  func testNativeTitleAboveHeaderBlur() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openNavigation(app)
    app.buttons["nav-review"].tap()
    func option(_ label: String) {
      app.buttons["review-options"].tap(); app.buttons[label].tap()
    }
    func title() -> XCUIElement {
      app.navigationBars.firstMatch.staticTexts.matching(identifier: "Contacts").allElementsBoundByIndex.first(where: { $0.isHittable })
        ?? app.navigationBars.firstMatch.staticTexts["Contacts"].firstMatch
    }
    func assertSharpTitle(_ state: String) throws {
      let element = title()
      XCTAssertTrue(element.exists, state)
      // Accessibility still finds a title that is behind a backdrop blur. Check
      // actual white glyph pixels, not just the label's presence or bounds.
      let screenshot = app.screenshot().image
      let full = try XCTUnwrap(screenshot.cgImage)
      let scale = CGFloat(full.width) / app.frame.width
      let frame = element.frame
      let cg = try XCTUnwrap(full.cropping(to: CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale)))
      var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
      bytes.withUnsafeMutableBytes {
        CGContext(data: $0.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8,
          bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
      }
      let white = stride(from: 0, to: bytes.count, by: 4).filter { bytes[$0] > 200 && bytes[$0 + 1] > 200 && bytes[$0 + 2] > 200 }.count
      if Double(white) / Double(cg.width * cg.height) <= 0.06 {
        let attachment = XCTAttachment(image: UIImage(cgImage: cg)); attachment.name = "native-title-contrast-failure"; attachment.lifetime = .keepAlways; add(attachment)
      }
      XCTAssertGreaterThan(Double(white) / Double(cg.width * cg.height), 0.06, "\(state): native title must remain above the blur")
    }
    option("Native title transition"); option("Soft edge")
    let list = app.otherElements["review-list"].scrollViews.firstMatch
    for pinned in [true, false] {
      option(pinned ? "Show pinned filter" : "Hide pinned filter")
      for hard in [false, true] {
        if hard { option("Hard edge") }
        app.buttons["review-top"].tap()
        XCTAssertGreaterThan(title().frame.height, 30, "Verify the expanded native title")
        try assertSharpTitle("expanded \(hard ? "hard" : "soft"), filter \(pinned)")
        list.swipeUp()
        XCTAssertLessThan(title().frame.height, 30, "Verify the collapsed native title")
        try assertSharpTitle("collapsed \(hard ? "hard" : "soft"), filter \(pinned)")
      }
      option("Soft edge")
    }
    app.buttons["review-top"].tap()
    try assertSharpTitle("restored after repeated collapse")
    app.buttons["review-close"].tap()
  }

  func testHeaderSearchToggleLayout() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openNavigation(app)
    app.buttons["open-scroll-header"].tap()
    let close = app.buttons.matching(NSPredicate(format: "label == 'Close' OR label == 'Cancel'")).firstMatch
    func settle() { Thread.sleep(forTimeInterval: 0.7) }

    // Toggled stacked search (no `active`): the bar pushes content down and gives the space back.
    let status = app.staticTexts["nav-status"], contacts = app.otherElements["navigation-contacts"].scrollViews.firstMatch
    XCTAssertTrue(status.waitForExistence(timeout: 5)); settle()
    let resting = status.frame
    app.buttons["nav-search-toggle"].tap(); settle()
    let stacked = app.searchFields.firstMatch
    XCTAssertTrue(stacked.waitForExistence(timeout: 5))
    XCTAssertGreaterThanOrEqual(status.frame.minY, stacked.frame.maxY - 1, "A shown search bar must push content down, not cover it")
    app.buttons["nav-search-toggle"].tap(); settle()
    XCTAssertFalse(stacked.exists)
    XCTAssertEqual(status.frame.minY, resting.minY, accuracy: 1, "Removing search must return the header and content to their resting position")
    contacts.swipeUp(); settle()
    app.buttons["nav-search-toggle"].tap(); settle(); app.buttons["nav-search-toggle"].tap(); settle()
    app.buttons["nav-top"].tap(); settle()
    XCTAssertEqual(status.frame.minY, resting.minY, accuracy: 1, "Search toggled while scrolled must not leave a stale header height")

    // Icon-activated search (`active: true`) in both title transitions.
    app.buttons["navigation-back"].tap(); app.buttons["nav-review"].tap()
    XCTAssertTrue(app.buttons["review-options"].waitForExistence(timeout: 5))
    let state = app.staticTexts["review-state"], list = app.otherElements["review-list"].scrollViews.firstMatch
    for transition in ["morph", "native"] {
      if transition == "native" { app.buttons["review-options"].tap(); app.buttons["Native title transition"].tap() }
      app.buttons["review-top"].tap(); settle()
      let top = state.frame
      app.buttons["review-search"].tap()
      let field = app.searchFields["review-search-field"]
      XCTAssertTrue(field.waitForExistence(timeout: 5))
      XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "\(transition): the icon opens search ready to type")
      settle()
      XCTAssertGreaterThanOrEqual(state.frame.minY, field.frame.maxY - 1, "\(transition): search must not cover the list")
      for title in app.staticTexts.matching(identifier: "Contacts").allElementsBoundByIndex where title.isHittable {
        XCTAssertFalse(title.frame.intersects(field.frame.insetBy(dx: 0, dy: 4)), "\(transition): the title must not draw over the search field")
      }
      field.typeText("Contact 1"); close.tap(); settle()
      XCTAssertFalse(field.exists)
      XCTAssertEqual(state.frame.minY, top.minY, accuracy: 1, "\(transition): dismissal restores the header exactly")
      list.swipeUp(); settle()
      let scrolled = app.buttons["Contact 10"].frame
      app.buttons["review-search"].tap(); XCTAssertTrue(field.waitForExistence(timeout: 5)); settle()
      close.tap(); settle()
      XCTAssertEqual(app.buttons["Contact 10"].frame.minY, scrolled.minY, accuracy: 2, "\(transition): dismissal keeps the scroll position")
    }
    app.buttons["review-top"].tap(); settle()
    XCTAssertGreaterThan(app.navigationBars.firstMatch.staticTexts["Contacts"].frame.height, 30, "The native large title expands again at the top")
  }

  // MARK: 0.2.0 acceptance (PACKAGE_REQUESTS_0_2_0). Frames and marks are printed for the
  // recording analysis in scripts/trace-glass.py; geometry asserts the request's numbers.
  private func openNavigation(_ app: XCUIApplication) {
    let category = app.descendants(matching: .any).matching(NSPredicate(format:
      "identifier == %@ OR label == %@", "demo-categories-navigation", "Navigation & headers")).firstMatch
    XCTAssertTrue(category.waitForExistence(timeout: launchTimeout))
    category.tap()
  }

  private func openAcceptance(_ app: XCUIApplication) {
    XCTAssertTrue(app.buttons["open-acceptance-demo"].waitForExistence(timeout: launchTimeout))
    app.buttons["open-acceptance-demo"].tap()
    XCTAssertTrue(app.otherElements["acc-root"].waitForExistence(timeout: 5) || app.scrollViews["acc-root"].waitForExistence(timeout: 5))
  }
  private func mark(_ name: String) { print("ALG-MARK \(name) \(String(format: "%.4f", Date().timeIntervalSince1970))") }
  private func rect(_ name: String, _ frame: CGRect) {
    print("ALG-RECT \(name) \(frame.minX) \(frame.minY) \(frame.width) \(frame.height)")
  }
  private func reveal(_ app: XCUIApplication, _ element: XCUIElement) {
    // Sections share a persistent gallery header. Reveal in either direction and
    // keep the target below it, including when returning to an earlier control.
    XCTAssertTrue(app.scrollIntoView(element, band: 0.35...0.85))
  }

  func testAcceptanceGeometry() throws {
    continueAfterFailure = true
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openAcceptance(app)
    // G8: exported control sizes, measured as laid out (±0.5 pt).
    let sizes: [(String, CGFloat)] = [("mini", 28), ("small", 36), ("regular", 44), ("large", 50), ("extraLarge", 56)]
    for (name, side) in sizes {
      let button = app.buttons["acc-size-\(name)"]; reveal(app, button)
      rect("size-\(name)", button.frame)
      XCTAssertEqual(button.frame.height, side, accuracy: 0.5, "controlSize \(name) height")
      XCTAssertEqual(button.frame.width, side, accuracy: 0.5, "controlSize \(name) width")
    }
    // G3: Calendar (list/search/+) 162.7 pt and Wallet (search/⋯) 101.7 pt, 44 pt tall (±1 pt).
    for (id, width) in [("acc-group3", 162.7), ("acc-group2", 101.7)] as [(String, CGFloat)] {
      let group = app.otherElements[id]; reveal(app, group)
      rect(id, group.frame)
      XCTAssertEqual(group.frame.width, width, accuracy: 1, "\(id) width")
      XCTAssertEqual(group.frame.height, 44, accuracy: 1, "\(id) height")
    }
    // Each group item is its own accessible, separately hittable button.
    for id in ["acc-group3-list", "acc-group3-search", "acc-group3-add", "acc-group2-search", "acc-group2-more"] {
      XCTAssertTrue(app.buttons[id].isHittable, "\(id) is addressable")
      rect(id, app.buttons[id].frame)
    }
    app.buttons["acc-group3-search"].tap()
    XCTAssertTrue(app.staticTexts["acc-status"].label.contains("Group search"))
    app.buttons["acc-group2-more"].tap()
    XCTAssertTrue(app.buttons["Sort"].waitForExistence(timeout: 3), "A group item opens its own menu")
    app.buttons["Sort"].tap()
    XCTAssertTrue(app.staticTexts["acc-status"].label.contains("Menu sort"))
    // G4: Fitness+ pill geometry (±1 pt), position values, overflow scrolling.
    let pills: [(String, CGFloat)] = [("forYou", 87), ("explore", 87), ("plans", 71), ("library", 84)]
    var previous: CGRect?
    for (index, (id, width)) in pills.enumerated() {
      let pill = app.buttons["acc-pill-\(id)"]; reveal(app, pill)
      rect("pill-\(id)", pill.frame)
      XCTAssertEqual(pill.frame.width, width, accuracy: 1, "\(id) width")
      XCTAssertEqual(pill.frame.height, 42, accuracy: 1, "\(id) height")
      // Page margin: 20 pt on phones 414 pt and wider, 16 pt below (§2.4).
      if index == 0 { XCTAssertEqual(pill.frame.minX, app.frame.width >= 414 ? 20 : 16, accuracy: 1, "leading inset") }
      if let previous { XCTAssertEqual(pill.frame.minX - previous.maxX, 10, accuracy: 1, "gap before \(id)") }
      previous = pill.frame
      XCTAssertEqual(pill.value as? String, "\(index + 1) of 4", "VoiceOver position for \(id)")
    }
    XCTAssertTrue(app.buttons["acc-pill-forYou"].isSelected, "selected trait")
    let search = app.buttons["acc-pill-search"]
    rect("pill-search", search.frame)
    XCTAssertEqual(search.frame.width, 49, accuracy: 1); XCTAssertEqual(search.frame.height, 42, accuracy: 1)
    app.buttons["acc-pill-library"].tap()
    XCTAssertTrue(app.staticTexts["acc-scope"].label.contains("library"))
    XCTAssertTrue(app.buttons["acc-pill-library"].isSelected)
    XCTAssertFalse(app.buttons["acc-pill-forYou"].isSelected)
    // G11 / G2 elements for the image analysis.
    for id in ["acc-bell", "acc-chevron", "acc-chevron-large", "acc-chevron-medium-large", "acc-heart", "acc-morph"] { let e = app.buttons[id]; reveal(app, e); rect(id, e.frame) }
    let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "acceptance-geometry"; shot.lifetime = .keepAlways; add(shot)
  }

  func testAcceptanceMotion() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark", "-ALGBadgeProbe"]
    app.launch(); defer { app.terminate() }
    openAcceptance(app)
    let morph = app.buttons["acc-morph"]
    rect("morph-start", morph.frame)
    // G5: ⋯ → Select → ⋯, then the same with JS blocked for 500 ms right after each change.
    for stalled in [false, true] {
      if stalled { app.switches["acc-stall"].tap() }
      for step in 0..<2 {
        // Trigger from a separate control, as in Passwords, so press swell is not measured.
        mark("morph-\(stalled ? "stall" : "free")-\(step)"); app.buttons["acc-morph-trigger"].tap()
        Thread.sleep(forTimeInterval: 1.4)
        rect("morph-\(stalled ? "stall" : "free")-\(step)-end", morph.frame)
      }
    }
    XCTAssertTrue(app.staticTexts["acc-morph-count"].label.contains("4"))
    // G2: heart → heart.fill replace transition, recorded.
    let heart = app.buttons["acc-heart"]; reveal(app, heart); rect("heart", heart.frame)
    mark("heart-0"); heart.tap(); Thread.sleep(forTimeInterval: 0.8)
    mark("heart-1"); heart.tap(); Thread.sleep(forTimeInterval: 0.8)
    // G11: hold the bell; the badge rides the swelling glass.
    let bell = app.buttons["acc-bell"]; reveal(app, bell); rect("bell", bell.frame)
    mark("bell-hold"); bell.press(forDuration: 1.2); Thread.sleep(forTimeInterval: 0.8)
    // G6: exit and enter; exit fires onExited once; unmount mid-exit fires it once too.
    let item = app.buttons["acc-presence-item"]; reveal(app, item); rect("presence", item.frame)
    mark("presence-exit"); app.buttons["acc-presence-toggle"].tap(); Thread.sleep(forTimeInterval: 0.8)
    XCTAssertTrue(app.staticTexts["acc-exits"].label.contains("1"), "onExited fires once")
    mark("presence-enter"); app.buttons["acc-presence-toggle"].tap(); Thread.sleep(forTimeInterval: 0.8)
    XCTAssertTrue(item.waitForExistence(timeout: 2))
    app.buttons["acc-presence-remount"].tap(); Thread.sleep(forTimeInterval: 0.5)
    app.buttons["acc-presence-unmount"].tap(); Thread.sleep(forTimeInterval: 0.8)
    XCTAssertTrue(app.staticTexts["acc-exits"].label.hasSuffix(" 1"), "Unmounting mid-exit still reports exactly once: \(app.staticTexts["acc-exits"].label)")
  }

  func testAcceptanceHeaderStack() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openAcceptance(app)
    let open = app.buttons["acc-open-stack"]; reveal(app, open); open.tap()
    // iOS 26: UIKit bar items in the stack's navigation bar (found by label; bar items carry no
    // test ID). Elsewhere: the host overlay's buttons (test IDs).
    let native = false  // the acceptance stack uses the host overlay (SwiftUI glass morph on iOS 26)
    let bar = app.navigationBars.firstMatch
    var primary: XCUIElement { native ? bar.buttons.matching(NSPredicate(format: "label == 'More' OR label == 'Select'")).firstMatch : app.buttons["acc-header-primary"] }
    var back: XCUIElement { native ? bar.buttons["Back"] : app.buttons["acc-header-back"] }
    XCTAssertTrue(primary.waitForExistence(timeout: 5)); XCTAssertEqual(primary.label, "More")
    XCTAssertFalse(back.exists)
    Thread.sleep(forTimeInterval: 0.6); rect("header-home", primary.frame)
    // Second trailing slot: left of the first, 12 pt apart; its menu reaches the screen.
    let sort = app.buttons["acc-header-sort"]
    XCTAssertTrue(sort.exists); rect("header-sort", sort.frame)
    XCTAssertEqual(sort.frame.maxX, primary.frame.minX - 12, accuracy: 1, "First trailing item is outermost")
    sort.tap(); let date = app.buttons["Date"]; XCTAssertTrue(date.waitForExistence(timeout: 3)); date.tap()
    XCTAssertTrue(app.staticTexts["acc-home-state"].label.contains("Sort date"), "Header menu action reaches Home: \(app.staticTexts["acc-home-state"].label)")
    Thread.sleep(forTimeInterval: 0.6)
    for stalled in [false, true] {
      if stalled { app.switches["acc-stall-push"].tap() }
      mark("push-\(stalled ? "stall" : "free")"); app.buttons["acc-row-All"].tap()
      XCTAssertTrue(app.staticTexts["acc-all-title"].waitForExistence(timeout: 5))
      Thread.sleep(forTimeInterval: 1.0)
      XCTAssertEqual(primary.label, "Select"); XCTAssertTrue(back.isHittable)
      XCTAssertFalse(app.buttons["acc-header-sort"].exists && app.buttons["acc-header-sort"].isHittable, "All has no sort slot")
      rect("header-all-\(stalled ? "stall" : "free")", primary.frame); rect("header-back", back.frame)
      primary.tap(); XCTAssertTrue(app.staticTexts["acc-all-state"].label.contains("Selecting"), "Select reaches the All screen")
      mark("pop-\(stalled ? "stall" : "free")"); back.tap()
      XCTAssertTrue(app.buttons["acc-row-All"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
      XCTAssertEqual(primary.label, "More"); XCTAssertFalse(back.exists)
    }
    // Interactive swipe back: cancelled halfway, the header returns to All's controls.
    app.switches["acc-stall-push"].tap()
    app.buttons["acc-row-All"].tap(); XCTAssertTrue(app.staticTexts["acc-all-title"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
    mark("swipe-cancel"); edge.press(forDuration: 0.01, thenDragTo: edge.withOffset(CGVector(dx: 120, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.4)
    Thread.sleep(forTimeInterval: 1.0)
    XCTAssertTrue(app.staticTexts["acc-all-title"].exists, "Cancelled swipe stays on All")
    XCTAssertEqual(primary.label, "Select", "Cancelled swipe restores All's header")
    XCTAssertTrue(back.isHittable)
    // Held further across, then released short of half way: the swipe cancels. All's controls
    // stay for the whole swipe (the recording shows no change while held).
    mark("swipe-cross"); edge.press(forDuration: 0.01, thenDragTo: edge.withOffset(CGVector(dx: 190, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.8)
    Thread.sleep(forTimeInterval: 1.0)
    XCTAssertTrue(app.staticTexts["acc-all-title"].exists, "Released short of half way, the swipe cancels")
    XCTAssertEqual(primary.label, "Select", "A longer cancelled swipe keeps All's header")
    mark("swipe-complete"); edge.press(forDuration: 0.01, thenDragTo: edge.withOffset(CGVector(dx: 330, dy: 0)), withVelocity: .default, thenHoldForDuration: 0)
    XCTAssertTrue(app.buttons["acc-row-All"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    XCTAssertEqual(primary.label, "More", "Completed swipe shows Home's header")
    XCTAssertFalse(back.exists)
    primary.tap(); XCTAssertTrue(app.staticTexts["acc-home-state"].label.contains("More"), "Home's ⋯ reaches Home")
    // UIKit's own back indicator, for the G2 glyph comparison.
    app.buttons["acc-row-System"].tap()
    let systemBar = app.navigationBars["Reference"]
    XCTAssertTrue(systemBar.waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    XCTAssertFalse(primary.exists && primary.isHittable, "A screen without items has no header controls")
    rect("uikit-back", systemBar.buttons.firstMatch.frame)
    let reference = XCTAttachment(screenshot: app.screenshot()); reference.name = "uikit-back"; reference.lifetime = .keepAlways; add(reference)
    systemBar.buttons.firstMatch.tap(); XCTAssertTrue(app.buttons["acc-row-All"].waitForExistence(timeout: 5))
    app.buttons["acc-stack-close"].tap()
  }

  /// A screen with a back button pushed from a screen with one (Contacts' list → detail): the back
  /// button and Share, present on both, keep their glass and stay still while Select morphs into
  /// Edit. Item names its slots differently from All, so only content pairing keeps them. The
  /// frames are asserted here; stillness during each transition comes from the recording
  /// (`scripts/verify-static-header-video.py`, marks `push-from-home` = back appears, a positive
  /// control, then `push-item` / `swipe-item` = must stay still).
  func testAcceptanceSharedHeaderControls() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openAcceptance(app)
    let open = app.buttons["acc-open-stack"]; reveal(app, open); open.tap()
    XCTAssertTrue(app.buttons["acc-row-All"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 0.8)
    mark("push-from-home"); app.buttons["acc-row-All"].tap()
    XCTAssertTrue(app.staticTexts["acc-all-title"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    let back = app.buttons["acc-header-back"], share = app.buttons["acc-header-share"]
    XCTAssertTrue(back.isHittable); XCTAssertTrue(share.isHittable)
    let backFrame = back.frame, shareFrame = share.frame
    rect("shared-back-all", backFrame); rect("shared-share-all", shareFrame)
    rect("shared-primary-all", app.buttons["acc-header-primary"].frame)
    XCTAssertEqual(shareFrame.maxX, app.buttons["acc-header-primary"].frame.minX - 12, accuracy: 1, "Share sits inside Select")
    for (index, how) in ["tap", "swipe"].enumerated() {
      mark("push-item\(index == 0 ? "" : "-2")"); app.buttons["acc-row-Item\(index + 1)"].tap()
      XCTAssertTrue(app.staticTexts["acc-item-title"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
      let itemBack = app.buttons["acc-item-back"], edit = app.buttons["acc-item-primary"], itemShare = app.buttons["acc-item-share"]
      XCTAssertEqual(edit.label, "Edit"); XCTAssertTrue(itemBack.isHittable); XCTAssertTrue(itemShare.isHittable)
      XCTAssertFalse(back.exists, "All's back button became Item's (one glass)")
      XCTAssertEqual(itemBack.frame, backFrame, "The back button does not move")
      XCTAssertEqual(itemShare.frame.maxX, edit.frame.minX - 12, accuracy: 1, "Share follows Edit's width")
      rect("shared-share-item", itemShare.frame)
      rect("shared-primary-item", edit.frame)
      itemShare.tap(); XCTAssertEqual(app.staticTexts["acc-item-state"].label, "Shared", "Carried Share reaches Item")
      if how == "tap" {
        mark("pop-item"); itemBack.tap()
      } else {
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 8, dy: 0))
        // Settle past the completion threshold before lifting. A zero-hold synthesized swipe
        // can reverse its release velocity on a physical phone and cancel an otherwise full drag.
        mark("swipe-item"); edge.press(forDuration: 0.05, thenDragTo: edge.withOffset(CGVector(dx: app.frame.width * 0.8, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.2)
      }
      XCTAssertTrue(app.staticTexts["acc-all-title"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
      XCTAssertEqual(app.buttons["acc-header-primary"].label, "Select")
      XCTAssertEqual(back.frame, backFrame, "\(how) back: the back button does not move"); XCTAssertEqual(share.frame, shareFrame)
    }
    share.tap(); XCTAssertTrue(app.staticTexts["acc-all-state"].label.hasSuffix("shared 1"), "Share reaches All again")
    back.tap(); XCTAssertTrue(app.buttons["acc-row-All"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    XCTAssertFalse(back.exists); XCTAssertEqual(app.buttons["acc-header-primary"].label, "More")
    app.buttons["acc-stack-close"].tap()
  }

  /// Header pairing beyond shared controls (owner, Oct 21): within a screen, back ⇄ Cancel and
  /// Edit ⇄ Done morph in place while Share leaves and returns; across screens with different
  /// controls and counts (Item [back | Share, Edit] → Details [Close | ⋯]) controls morph by
  /// position and the extra one leaves; a shared control keeps its glass while its badge changes;
  /// a cancelled swipe keeps the pairing. Each slot keeps its edge; presses reach the right screen.
  func testAcceptanceHeaderPairingScenarios() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openAcceptance(app)
    let open = app.buttons["acc-open-stack"]; reveal(app, open); open.tap()
    XCTAssertTrue(app.buttons["acc-row-All"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 0.8)
    app.buttons["acc-row-All"].tap(); XCTAssertTrue(app.staticTexts["acc-all-title"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    // Badge on a shared control: All's Share counts shares; Item's has none.
    let allShare = app.buttons["acc-header-share"]
    allShare.tap(); Thread.sleep(forTimeInterval: 0.6)
    XCTAssertEqual(allShare.value as? String, "1 new", "All's Share shows its badge (spoken as \"1 new\")")
    app.buttons["acc-row-Item1"].tap(); XCTAssertTrue(app.staticTexts["acc-item-title"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    let back = app.buttons["acc-item-back"], primary = app.buttons["acc-item-primary"], share = app.buttons["acc-item-share"]
    let cancel = app.buttons["acc-item-cancel"], state = app.staticTexts["acc-item-state"]
    XCTAssertTrue(back.isHittable); XCTAssertTrue(share.isHittable)
    XCTAssertEqual(share.value as? String ?? "", "", "Item's Share has no badge")
    let backFrame = back.frame, primaryFrame = primary.frame, shareFrame = share.frame
    rect("pair-leading", backFrame); rect("pair-primary", primaryFrame)

    // Within a screen: back → Cancel and Edit → Done in place; Share leaves.
    for exit in ["Done", "Cancel"] {
      mark("edit-on-\(exit)"); primary.tap(); Thread.sleep(forTimeInterval: 1.0)
      XCTAssertEqual(state.label, "Editing")
      XCTAssertTrue(cancel.isHittable, "Back became Cancel"); XCTAssertFalse(back.exists)
      XCTAssertEqual(cancel.frame.minX, backFrame.minX, accuracy: 1, "Cancel keeps the leading edge")
      XCTAssertEqual(primary.label, "Done"); XCTAssertEqual(primary.frame.maxX, primaryFrame.maxX, accuracy: 1, "Done keeps the trailing edge")
      XCTAssertFalse(share.exists, "Share leaves in edit mode")
      mark("edit-off-\(exit)"); (exit == "Done" ? primary : cancel).tap(); Thread.sleep(forTimeInterval: 1.0)
      XCTAssertEqual(state.label, exit == "Done" ? "Saved" : "Cancelled")
      XCTAssertTrue(back.isHittable); XCTAssertFalse(cancel.exists)
      XCTAssertEqual(back.frame, backFrame, "Back returns to its place"); XCTAssertEqual(primary.frame, primaryFrame)
      XCTAssertEqual(primary.label, "Edit"); XCTAssertEqual(share.frame, shareFrame, "Share returns to its place")
    }

    // Across screens with different controls and counts.
    let close = app.buttons["acc-details-close"], more = app.buttons["acc-details-more"]
    mark("push-details"); app.buttons["acc-item-details"].tap()
    XCTAssertTrue(app.staticTexts["acc-details-title"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    XCTAssertTrue(close.isHittable); XCTAssertEqual(close.label, "Close"); XCTAssertFalse(back.exists)
    XCTAssertEqual(close.frame.minX, backFrame.minX, accuracy: 1, "Close takes the back button's place")
    XCTAssertEqual(more.frame.maxX, primaryFrame.maxX, accuracy: 1, "⋯ takes Edit's place at the trailing edge")
    XCTAssertFalse(share.exists, "Details has no Share")
    more.tap(); XCTAssertEqual(app.staticTexts["acc-details-state"].label, "More", "⋯ reaches Details")
    mark("pop-details"); close.tap()
    XCTAssertTrue(app.staticTexts["acc-item-title"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    XCTAssertEqual(back.frame, backFrame); XCTAssertEqual(primary.frame, primaryFrame); XCTAssertEqual(share.frame, shareFrame)
    share.tap(); XCTAssertEqual(state.label, "Shared", "Share reaches Item after Details")

    // A cancelled swipe back keeps the pairing: edit mode still morphs in place afterwards.
    let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
    mark("swipe-cancel-item"); edge.press(forDuration: 0.01, thenDragTo: edge.withOffset(CGVector(dx: 120, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.4)
    Thread.sleep(forTimeInterval: 1.0)
    XCTAssertTrue(app.staticTexts["acc-item-title"].exists, "Cancelled swipe stays on Item")
    XCTAssertEqual(back.frame, backFrame); XCTAssertEqual(share.frame, shareFrame)
    primary.tap(); Thread.sleep(forTimeInterval: 1.0)
    XCTAssertEqual(cancel.frame.minX, backFrame.minX, accuracy: 1); XCTAssertEqual(primary.label, "Done")
    cancel.tap(); Thread.sleep(forTimeInterval: 1.0)
    // Back to All: its Share still carries the badge.
    back.tap(); XCTAssertTrue(app.staticTexts["acc-all-title"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    XCTAssertEqual(allShare.value as? String, "1 new", "All's badge is back with its Share")
    app.buttons["acc-header-back"].tap(); XCTAssertTrue(app.buttons["acc-row-All"].waitForExistence(timeout: 5))
    app.buttons["acc-stack-close"].tap()
  }

  func testAcceptanceTabMinimize() throws {
    continueAfterFailure = false
    guard #available(iOS 26.0, *) else { throw XCTSkip("Tab bar minimization is an iOS 26 UIKit behaviour; older iOS keeps a fixed bar.") }
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openAcceptance(app)
    let open = app.buttons["acc-open-tabs"]; reveal(app, open); open.tap()
    let tabs = app.tabBars.firstMatch
    XCTAssertTrue(tabs.waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 0.8)
    let resting = tabs.frame; rect("tabs-resting", resting)
    let before = XCTAttachment(screenshot: app.screenshot()); before.name = "tabs-resting"; before.lifetime = .keepAlways; add(before)
    let list = app.otherElements["acc-tabs-list"].exists ? app.otherElements["acc-tabs-list"] : app.scrollViews.firstMatch
    list.swipeUp(); list.swipeUp(); Thread.sleep(forTimeInterval: 1.0)
    let minimized = tabs.frame; rect("tabs-minimized", minimized)
    let after = XCTAttachment(screenshot: app.screenshot()); after.name = "tabs-scrolled"; after.lifetime = .keepAlways; add(after)
    // UIKit keeps the bar's accessibility frame; minimized, only the selected tab remains visible.
    XCTAssertTrue(tabs.buttons["Saved"].exists && !tabs.buttons["Saved"].isHittable || !tabs.buttons["Saved"].exists, "onScrollDown minimizes the tab bar")
    _ = minimized
    // Scroll back up the way a person does: a slow drag.
    let middle = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
    middle.press(forDuration: 0.05, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: 300)), withVelocity: .slow, thenHoldForDuration: 0.2)
    Thread.sleep(forTimeInterval: 1.0)
    rect("tabs-restored", tabs.frame)
    let restored = XCTAttachment(screenshot: app.screenshot()); restored.name = "tabs-restored"; restored.lifetime = .keepAlways; add(restored)
    print("ALG-INFO tabs-expanded-after-scroll-up \(tabs.buttons["Saved"].isHittable)")
    if !tabs.buttons["Saved"].isHittable {
      // UIKit expands a minimized tab bar when it is tapped.
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.09, dy: 0.945)).tap(); Thread.sleep(forTimeInterval: 1.0)
    }
    let expanded = XCTAttachment(screenshot: app.screenshot()); expanded.name = "tabs-expanded"; expanded.lifetime = .keepAlways; add(expanded)
    XCTAssertTrue(tabs.buttons["Saved"].isHittable, "the full tab bar returns")
    app.buttons["acc-tabs-close"].tap()
  }

  func testHeaderAccessoryContinuity() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openNavigation(app)
    app.buttons["nav-review"].tap()
    func option(_ label: String) {
      app.buttons["review-options"].tap(); app.buttons[label].tap()
    }
    option("Show pinned filter")
    let accessory = app.otherElements["review-accessory"]
    XCTAssertTrue(accessory.waitForExistence(timeout: 5))
    let list = app.otherElements["review-list"].scrollViews.firstMatch
    list.swipeUp()
    XCTAssertTrue(app.buttons["Filter: all"].isHittable)
    XCTAssertGreaterThanOrEqual(accessory.frame.minY, app.navigationBars.firstMatch.frame.maxY - 1)

    // Check the rendered boundary, not just the existence of a separator view.
    let shot = app.screenshot().image
    let cg = try XCTUnwrap(shot.cgImage), scale = CGFloat(cg.width) / app.frame.width
    var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
    bytes.withUnsafeMutableBytes {
      CGContext(data: $0.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8,
        bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
    }
    func brightness(_ y: Int) -> Double {
      let xs = Int(0.3 * CGFloat(cg.width))..<Int(0.7 * CGFloat(cg.width))
      return xs.reduce(0.0) { value, x in
        let i = (min(cg.height - 1, max(0, y)) * cg.width + x) * 4
        return value + (Double(bytes[i]) + Double(bytes[i + 1]) + Double(bytes[i + 2])) / 3
      } / Double(xs.count)
    }
    let bottom = Int((accessory.frame.maxY * scale).rounded())
    let line = ((bottom - 2)...bottom).map(brightness).max()!
    XCTAssertGreaterThan(line, (brightness(bottom - 5) + brightness(bottom + 5)) / 2 + 5, "Hard edge needs a visible hairline at the bottom of the entire header")
    option("Soft edge")
    let soft = app.screenshot().image
    if let crop = soft.cgImage?.cropping(to: CGRect(x: 0, y: 0, width: CGFloat(cg.width), height: (accessory.frame.maxY + 35) * scale)) {
      let attachment = XCTAttachment(image: UIImage(cgImage: crop)); attachment.name = "continuous-soft-header"; attachment.lifetime = .keepAlways; add(attachment)
    }
    for cycle in 0..<2 {
      if cycle == 1 { app.buttons["review-top"].tap() }
      app.buttons["review-search"].tap()
      let field = app.searchFields["review-search-field"]
      XCTAssertTrue(field.waitForExistence(timeout: 5))
      field.tap(); field.typeText("Contact 1")
      XCTAssertGreaterThanOrEqual(accessory.frame.minY, field.frame.maxY, "Search must not cover the pinned filter")
      let nearbyScope = app.buttons["Nearby"]
      XCTAssertTrue(nearbyScope.waitForExistence(timeout: 3))
      XCTAssertGreaterThanOrEqual(accessory.frame.minY, nearbyScope.frame.maxY, "Search scopes need their own space above the filter")
      XCTAssertTrue(app.buttons["Filter: all"].isHittable)
      app.buttons["Filter: all"].tap()
      XCTAssertTrue(app.buttons["Filter: nearby"].isHittable, "The filter must remain interactive during search")
      app.buttons["Filter: nearby"].tap()
      app.buttons.matching(NSPredicate(format: "label == 'Close' OR label == 'Cancel'")).firstMatch.tap()
      XCTAssertTrue(app.buttons["review-options"].waitForExistence(timeout: 5))
      XCTAssertTrue(app.buttons["Filter: all"].isHittable)
    }
    option("Toggle search placement")
    let integrated = app.searchFields["review-search-field"]
    XCTAssertTrue(integrated.waitForExistence(timeout: 5)); integrated.tap()
    XCTAssertGreaterThanOrEqual(accessory.frame.minY, integrated.frame.maxY)
    app.buttons.matching(NSPredicate(format: "label == 'Close' OR label == 'Cancel'")).firstMatch.tap()
    option("Native title transition")
    app.buttons["review-top"].tap()
    XCTAssertTrue(app.buttons["Filter: all"].isHittable)
    option("Hide pinned filter")
    XCTAssertFalse(accessory.exists)
    app.buttons["review-close"].tap()
  }

  /// Pull past the top, release, then scroll slowly up and back: the native large title must not
  /// flicker under the header's edge effect (owner device report).
  func testLargeTitlePullAndReturn() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openNavigation(app)
    app.buttons["open-scroll-header"].tap()
    XCTAssertTrue(app.buttons["nav-add"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    let list = app.otherElements["navigation-contacts"].exists ? app.otherElements["navigation-contacts"] : app.scrollViews.firstMatch
    let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
    mark("pull"); start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 260)), withVelocity: .slow, thenHoldForDuration: 0.3)
    Thread.sleep(forTimeInterval: 1.0)
    mark("scroll-up"); start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -160)), withVelocity: 120, thenHoldForDuration: 0.3)
    Thread.sleep(forTimeInterval: 0.8)
    let back = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
    mark("scroll-back"); back.press(forDuration: 0.05, thenDragTo: back.withOffset(CGVector(dx: 0, dy: 300)), withVelocity: 120, thenHoldForDuration: 0.3)
    Thread.sleep(forTimeInterval: 1.2)
    XCTAssertTrue(app.buttons["nav-add"].isHittable)
  }

  /// Owner device report (Oct 21): showing the stacked search at the top collapsed the large title
  /// into the bar and re-expanded it (clipped title, two titles at once, compact one drifting).
  /// The large title must stay put while the field slides in and out below it; collapsed, the
  /// compact title must stay. Stillness comes from the recording: `scripts/verify-static-header-video.py`
  /// with `--rect search-large-title --still show-top --still hide-top` and
  /// `--rect search-compact-title --absent show-top --absent hide-top`.
  func testSearchToggleKeepsTitle() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openNavigation(app)
    app.buttons["open-scroll-header"].tap()
    let toggle = app.buttons["nav-search-toggle"], status = app.staticTexts["nav-status"]
    XCTAssertTrue(toggle.waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    let titles = app.navigationBars.firstMatch.staticTexts.matching(identifier: "Contacts").allElementsBoundByIndex
    guard let large = titles.map(\.frame).max(by: { $0.height < $1.height }) else { return XCTFail("No large title") }
    rect("search-large-title", large)
    let width = app.windows.firstMatch.frame.width
    rect("search-compact-title", CGRect(x: width / 2 - 60, y: toggle.frame.minY, width: 120, height: toggle.frame.height))
    let resting = status.frame
    for cycle in 0..<2 {
      mark("show-top\(cycle == 0 ? "" : "-2")"); toggle.tap()
      XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.2)
      XCTAssertGreaterThanOrEqual(status.frame.minY, app.searchFields.firstMatch.frame.maxY - 1, "The field pushes the list down")
      XCTAssertEqual(app.navigationBars.firstMatch.staticTexts.matching(identifier: "Contacts").allElementsBoundByIndex.map(\.frame).max(by: { $0.height < $1.height }) ?? .zero, large, "The large title stays")
      mark("hide-top\(cycle == 0 ? "" : "-2")"); toggle.tap(); Thread.sleep(forTimeInterval: 1.2)
      XCTAssertFalse(app.searchFields.firstMatch.exists)
      XCTAssertEqual(status.frame.minY, resting.minY, accuracy: 1, "The list returns to its resting position")
    }
    // Collapsed: the compact title stays in the bar while the field comes and goes.
    let list = app.otherElements["navigation-contacts"].scrollViews.firstMatch
    list.swipeUp(); Thread.sleep(forTimeInterval: 1.0)
    mark("show-collapsed"); toggle.tap(); XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.2)
    mark("hide-collapsed"); toggle.tap(); Thread.sleep(forTimeInterval: 1.2)
    XCTAssertFalse(app.searchFields.firstMatch.exists)
  }

  /// Owner device report (Oct 21): pulling the review list down shows no refresh spinner, and the
  /// title moves down and clips. Recorded per title transition: a slow pull held past the refresh
  /// threshold (marks `pull-<title>`), then released.
  func testPullToRefreshSpinner() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openNavigation(app)
    app.buttons["nav-review"].tap()
    XCTAssertTrue(app.buttons["review-options"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    let state = app.staticTexts["review-state"], list = app.otherElements["review-list"].scrollViews.firstMatch
    rect("pull-header", CGRect(x: 0, y: 0, width: app.windows.firstMatch.frame.width, height: state.frame.maxY + 40))
    for (index, title) in ["morph", "native"].enumerated() {
      if title == "native" { app.buttons["review-options"].tap(); app.buttons["Native title transition"].tap(); Thread.sleep(forTimeInterval: 0.5) }
      app.buttons["review-top"].tap(); Thread.sleep(forTimeInterval: 1.0)
      let resting = state.frame
      let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
      mark("pull-\(title)")
      start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 420)), withVelocity: .slow, thenHoldForDuration: 0.8)
      let refreshed = NSPredicate(format: "label CONTAINS 'refresh \(index + 1)'")
      expectation(for: refreshed, evaluatedWith: state); waitForExpectations(timeout: 5)
      Thread.sleep(forTimeInterval: 1.5)
      print("ALG-INFO pull-\(title) resting \(resting.minY) after \(state.frame.minY)")
      XCTAssertEqual(state.frame.minY, resting.minY, accuracy: 1, "\(title): after the refresh the list returns to the top")
    }
  }

  /// Owner requirement (Oct 21): the hard band is lighter than UIKit's nearly opaque hard edge
  /// (like Phone's Calls header) and its colour, opacity, blur and separator are adjustable.
  /// Samples an empty band area between the title and the buttons per preset (iOS 26: the
  /// package's band; older iOS: the bar's appearance).
  func testHardEdgeWaitsForTitle() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openNavigation(app); app.buttons["nav-review"].tap()
    XCTAssertTrue(app.buttons["review-options"].waitForExistence(timeout: 5))
    func option(_ label: String) {
      app.buttons["review-options"].tap()
      let item = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
      for _ in 0..<3 where !(item.waitForExistence(timeout: 1) && item.isHittable) { app.collectionViews.firstMatch.swipeUp() }
      item.tap(); Thread.sleep(forTimeInterval: 0.5)
    }
    // A pinned filter gives the boundary an unambiguous public frame in every title mode.
    option("Show pinned filter")
    let accessory = app.otherElements["review-accessory"]
    let list = app.otherElements["review-list"].scrollViews.firstMatch
    func lineBrightness() throws -> Double {
      let shot = app.screenshot(), image = try XCTUnwrap(shot.image.cgImage)
      let scale = CGFloat(image.width) / app.frame.width
      let crop = try XCTUnwrap(image.cropping(to: CGRect(x: 2 * scale, y: (accessory.frame.maxY - 1) * scale, width: 12 * scale, height: scale)))
      var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
      bytes.withUnsafeMutableBytes { buffer in
        CGContext(data: buffer.baseAddress, width: crop.width, height: crop.height, bitsPerComponent: 8,
          bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
      }
      // The hairline is one physical pixel; use the brightest row, not an average over points.
      return (0..<crop.height).map { y in
        (0..<crop.width).reduce(0.0) { $0 + Double(bytes[(y * crop.width + $1) * 4]) } / Double(crop.width)
      }.max() ?? 0
    }
    for native in [false, true] {
      if native { option("Native title transition") }
      for mode in ["Large below bar", "Large in bar", "Compact only"] {
        option(mode); app.buttons["review-top"].tap(); Thread.sleep(forTimeInterval: 0.6)
        mark("hard-top-\(native)-\(mode)")
        let top = try lineBrightness()
        XCTAssertLessThan(top, 5, "No hairline or band at the top: \(native), \(mode)")
        if mode != "Compact only" {
          let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
          mark("hard-small-\(native)-\(mode)")
          start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -16)), withVelocity: .slow, thenHoldForDuration: 0.2)
          // The native/morph snap can return this small drag to the expanded position.
          if app.staticTexts["review-state"].exists && app.staticTexts["review-state"].isHittable {
            XCTAssertLessThan(try lineBrightness(), 5, "A small drag must not reveal the hard boundary")
          }
        }
        mark("hard-collapse-\(native)-\(mode)"); list.swipeUp(); Thread.sleep(forTimeInterval: 0.6)
        let compact = try lineBrightness()
        print("ALG-INFO hard-boundary native=\(native) mode=\(mode) top=\(top) compact=\(compact)")
        XCTAssertGreaterThan(compact, top + 5, "The boundary appears below the filter after collapse")
        app.buttons["review-top"].tap(); Thread.sleep(forTimeInterval: 0.6)
        XCTAssertLessThan(try lineBrightness(), 5, "Returning to the top removes the boundary")
      }
    }
  }

  func testHeaderBandStyles() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openNavigation(app)
    app.buttons["nav-review"].tap()
    XCTAssertTrue(app.buttons["review-options"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    func option(_ label: String) {
      app.buttons["review-options"].tap()
      // The options menu is taller than a smaller iPhone's screen: scroll it to the item.
      let item = app.buttons[label]
      for _ in 0..<3 where !(item.waitForExistence(timeout: 1) && item.isHittable) { app.collectionViews.firstMatch.swipeUp() }
      item.tap(); Thread.sleep(forTimeInterval: 0.8)
    }
    option("Native title transition")
    app.buttons["review-top"].tap(); Thread.sleep(forTimeInterval: 0.8)
    let list = app.otherElements["review-list"].scrollViews.firstMatch
    let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
    start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -300)), withVelocity: .slow, thenHoldForDuration: 0.2)
    Thread.sleep(forTimeInterval: 1.0)
    let search = app.buttons["review-search"].frame
    let area = CGRect(x: search.minX - 34, y: search.minY + 4, width: 20, height: search.height - 8)
    // Rows' avatars pass under the band's top-left corner, where nothing else is drawn: the
    // sharpest vertical step there shows whether the content beneath is blurred.
    let corner = CGRect(x: 8, y: 6, width: 36, height: max(8, search.minY - 14))  // left of the status-bar clock
    var edges: [String: Double] = [:]
    func pixels(_ image: CGImage, _ rect: CGRect, _ scale: CGFloat) throws -> (data: [UInt8], width: Int, height: Int) {
      let cg = try XCTUnwrap(image.cropping(to: CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)))
      var data = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
      data.withUnsafeMutableBytes { buffer in
        CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4,
          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
      }
      return (data, cg.width, cg.height)
    }
    func sample(_ name: String) throws -> [Double] {
      let shot = app.screenshot(); let image = try XCTUnwrap(shot.image.cgImage)
      let attachment = XCTAttachment(screenshot: shot); attachment.name = "band-\(name)"; attachment.lifetime = .keepAlways; add(attachment)
      let scale = CGFloat(image.width) / app.frame.width
      let (data, width, height) = try pixels(image, area, scale)
      let rgb = (0..<3).map { c in stride(from: c, to: data.count, by: 4).reduce(0.0) { $0 + Double(data[$1]) } / Double(width * height) }
      let top = try pixels(image, corner, scale)
      let luma = { (i: Int) in 0.2126 * Double(top.data[i]) + 0.7152 * Double(top.data[i + 1]) + 0.0722 * Double(top.data[i + 2]) }
      var edge = 0.0
      for y in 0..<(top.height - 1) { for x in 0..<top.width { edge = max(edge, abs(luma((y * top.width + x) * 4) - luma(((y + 1) * top.width + x) * 4))) } }
      edges[name] = edge
      print("ALG-INFO band-\(name) \(rgb.map { String(format: "%.1f", $0) }.joined(separator: " ")) edge \(String(format: "%.1f", edge))")
      return rgb
    }
    mark("band-default"); let standard = try sample("default")
    option("Hard band: lighter"); mark("band-lighter"); let lighter = try sample("lighter")
    option("Hard band: tinted"); mark("band-tinted"); let tinted = try sample("tinted")
    option("Hard band: system"); mark("band-system"); let system = try sample("system")
    let luma = { (c: [Double]) in 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2] }
    if #available(iOS 26.0, *) {
      // Owner report (Oct 21): text under the band was sharp — the band dimmed but did not blur.
      for name in ["default", "lighter", "tinted"] { XCTAssertLessThan(edges[name] ?? 99, 6, "\(name): content beneath the band is blurred") }
      XCTAssertLessThan(luma(system), 8, "UIKit's own hard edge is nearly opaque over a black screen")
      XCTAssertGreaterThan(luma(standard), luma(system) + 6, "The default band is lighter than UIKit's hard edge")
    }
    XCTAssertGreaterThan(luma(lighter), luma(standard) + 4, "A lighter colour and lower opacity lighten the band")
    XCTAssertGreaterThan(tinted[2], tinted[0] + 10, "The band takes the app's colour")
  }

  /// Owner reference (Oct 21, Phone's Calls header): a hard top edge still blurs and dims the
  /// content beneath the header progressively, and ends in a hard line. Recorded with the list
  /// scrolled under the header per edge and title transition (marks `edge-<edge>-<title>`).
  func testHeaderEdgeStyles() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openNavigation(app)
    app.buttons["nav-review"].tap()
    XCTAssertTrue(app.buttons["review-options"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    func option(_ label: String) { app.buttons["review-options"].tap(); app.buttons[label].tap(); Thread.sleep(forTimeInterval: 0.5) }
    let list = app.otherElements["review-list"].scrollViews.firstMatch
    rect("edge-header", CGRect(x: 0, y: 0, width: app.windows.firstMatch.frame.width, height: app.buttons["review-search"].frame.maxY + 40))
    for title in ["morph", "native"] {
      if title == "native" { option("Native title transition") }
      for edge in ["soft", "hard"] {
        option(edge == "hard" ? "Hard edge" : "Soft edge")
        app.buttons["review-top"].tap(); Thread.sleep(forTimeInterval: 0.8)
        // A short slow drag leaves rows partly under the header.
        let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -260)), withVelocity: .slow, thenHoldForDuration: 0.2)
        Thread.sleep(forTimeInterval: 1.0); mark("edge-\(edge)-\(title)")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "edge-\(edge)-\(title)"; shot.lifetime = .keepAlways; add(shot)
        Thread.sleep(forTimeInterval: 0.5)
      }
    }
  }

  /// Owner device report (Oct 21, review screen): the search icon adds `search` with `active: true`
  /// and the app removes it after Close. Opening drew the morph title over the field; closing
  /// faded a second title in over the field. Recorded per title transition (marks
  /// `icon-open-<t>` / `icon-close-<t>`); frames are inspected and the layout is asserted.
  func testIconSearchOpenClose() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openNavigation(app)
    app.buttons["nav-review"].tap()
    XCTAssertTrue(app.buttons["review-options"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 1.0)
    let state = app.staticTexts["review-state"], field = app.searchFields["review-search-field"]
    let close = app.buttons.matching(NSPredicate(format: "label == 'Close' OR label == 'Cancel'")).firstMatch
    for transition in ["morph", "native"] {
      if transition == "native" { app.buttons["review-options"].tap(); app.buttons["Native title transition"].tap() }
      app.buttons["review-top"].tap(); Thread.sleep(forTimeInterval: 1.0)
      let top = state.frame
      rect("icon-title-\(transition)", CGRect(x: 0, y: app.buttons["review-search"].frame.maxY, width: app.windows.firstMatch.frame.width, height: top.minY - app.buttons["review-search"].frame.maxY))
      mark("icon-open-\(transition)"); app.buttons["review-search"].tap()
      XCTAssertTrue(field.waitForExistence(timeout: 5)); XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
      Thread.sleep(forTimeInterval: 1.0)
      XCTAssertGreaterThanOrEqual(state.frame.minY, field.frame.maxY - 1, "\(transition): search must not cover the list")
      mark("icon-close-\(transition)"); close.tap(); Thread.sleep(forTimeInterval: 1.5)
      XCTAssertFalse(field.exists, "\(transition): the app removed search after Close")
      XCTAssertEqual(state.frame.minY, top.minY, accuracy: 1, "\(transition): the header returns exactly")
    }
  }

  /// Search shown below the bar, list scrolled up and back, search activated from the field and
  /// closed: the native large title must be back at once (owner device report: 2–3 s late).
  func testSearchCloseRestoresLargeTitle() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    openNavigation(app)
    app.buttons["open-scroll-header"].tap()
    XCTAssertTrue(app.buttons["nav-search-toggle"].waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 0.8)
    app.buttons["nav-search-toggle"].tap()
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5)); Thread.sleep(forTimeInterval: 0.6)
    let list = app.otherElements["navigation-contacts"].scrollViews.firstMatch
    // Collapsed title: the search field stays pinned just below the bar's icons.
    list.swipeUp(); Thread.sleep(forTimeInterval: 0.8)
    let small = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    small.press(forDuration: 0.05, thenDragTo: small.withOffset(CGVector(dx: 0, dy: 120)), withVelocity: .slow, thenHoldForDuration: 0.2)
    Thread.sleep(forTimeInterval: 0.8)
    func visibleTitle() -> XCUIElement {
      app.navigationBars.firstMatch.staticTexts.matching(identifier: "Contacts").allElementsBoundByIndex.first(where: { $0.isHittable })
        ?? app.navigationBars.firstMatch.staticTexts["Contacts"].firstMatch
    }
    for cycle in 0..<3 {
      let suffix = cycle == 0 ? "" : "-\(cycle + 1)"
      rect("search-title" + suffix, visibleTitle().frame)
      mark("activate" + suffix); field.tap()
      let close = app.buttons.matching(NSPredicate(format: "label == 'Close' OR label == 'Cancel'")).firstMatch
      XCTAssertTrue(close.waitForExistence(timeout: 3)); Thread.sleep(forTimeInterval: 0.8)
      mark("close" + suffix); close.tap()
      // tap waits for XCTest idle; verify-search-title-video.py checks the real
      // transition frames, including any disappear/reappear before idle.
      Thread.sleep(forTimeInterval: 3)
      XCTAssertTrue(visibleTitle().isHittable)
      XCTAssertLessThan(visibleTitle().frame.height, 30)
      if cycle == 1 {
        // A new gesture restores ordinary large-title behavior, then Top must
        // also restore it for programmatic scrolling. Re-enter search afterwards.
        list.swipeDown()
        app.buttons["nav-top"].tap()
        XCTAssertGreaterThan(visibleTitle().frame.height, 30)
        list.swipeUp()
      }
    }
    app.buttons["nav-top"].tap()
    XCTAssertGreaterThan(visibleTitle().frame.height, 30)
  }

  func testHeaderReviewFeatures() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launchArguments += ["-ALGAppearance", "dark", "-ALGNavigationAudit"]
    app.launch(); defer { app.terminate() }
    openNavigation(app)
    app.buttons["nav-review"].tap()
    XCTAssertTrue(app.buttons["review-options"].waitForExistence(timeout: 5))
    Thread.sleep(forTimeInterval: 4) // DEBUG-only native 121-state audit writes one small JSON file.
    app.buttons["review-top"].tap()
    XCTAssertTrue(app.buttons["Contact 1"].isHittable)
    app.buttons["review-options"].tap(); app.buttons["Large in bar"].tap()
    app.buttons["review-top"].tap()
    XCTAssertTrue(app.staticTexts["review-state"].label.contains("inlineLarge"))
    app.buttons["review-options"].tap(); app.buttons["Show pinned filter"].tap()
    XCTAssertTrue(app.buttons["Filter: all"].waitForExistence(timeout: 5))
    app.buttons["review-options"].tap(); app.buttons["Custom title and subtitles"].tap()
    XCTAssertTrue(app.staticTexts["◉  Custom contact"].waitForExistence(timeout: 5))
    app.buttons["review-options"].tap(); app.buttons["Update badge in 2 seconds"].tap()
    Thread.sleep(forTimeInterval: 2.3)
    XCTAssertTrue(app.buttons["Large below bar"].exists, "Badge updates must retain the open native menu")
    app.buttons["Large below bar"].tap()
    app.buttons["review-options"].tap(); app.buttons["Text title"].tap()
    app.buttons["review-top"].tap()
    app.buttons["review-search"].tap()
    let field = app.searchFields["review-search-field"]
    XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("Contact 1")
    app.buttons["Contact 1"].tap()
    XCTAssertTrue(app.buttons["review-detail-back"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Newest message"].exists)
    app.buttons["review-detail-back"].tap()
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    XCTAssertEqual(field.value as? String, "Contact 1")
    app.buttons.matching(NSPredicate(format: "label == 'Close' OR label == 'Cancel'")).firstMatch.tap()
    app.buttons["review-top"].tap()
    Thread.sleep(forTimeInterval: 0.6) // Let the animated scroll-to-top settle before pulling.
    // A fast swipe is absorbed by large-title expansion; pull slowly past the refresh threshold like a person does,
    // starting inside the list body rather than on the bar, title row or pinned accessory.
    let pull = app.otherElements["review-list"].scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
    pull.press(forDuration: 0.05, thenDragTo: pull.withOffset(CGVector(dx: 0, dy: 420)), withVelocity: .slow, thenHoldForDuration: 0.4)
    XCTAssertTrue(app.staticTexts["review-state"].waitForExistence(timeout: 3))
    let refreshed = NSPredicate(format: "label CONTAINS 'refresh 1'")
    expectation(for: refreshed, evaluatedWith: app.staticTexts["review-state"])
    waitForExpectations(timeout: 5)
    app.buttons["review-close"].tap()
    XCTAssertTrue(app.buttons["nav-review"].waitForExistence(timeout: 5))
  }

  func testUpgradeMenuBadgeAndDot() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    XCTAssertTrue(app.buttons["open-upgrade-demo"].waitForExistence(timeout: launchTimeout))
    app.buttons["open-upgrade-demo"].tap()
    let share = app.buttons["upgrade-share"], more = app.buttons["upgrade-more"]
    let red: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r > 170 && g < 115 && b < 130 }
    for cycle in 0..<2 {
      more.tap()
      XCTAssertTrue(app.buttons["Pin item"].waitForExistence(timeout: 3))
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.55)).tap()
      XCTAssertTrue(app.buttons["Pin item"].waitForNonExistence(timeout: 3))
      Thread.sleep(forTimeInterval: 0.6)
      let badge = try XCTUnwrap(badgeBox(app, share, name: "group-dismiss-\(cycle)", margin: 5, match: red))
      XCTAssertEqual(badge.height, 18, accuracy: 1, "Dismissal must restore the full badge")
      XCTAssertEqual(badge.midY, share.frame.height * 0.146, accuracy: 1)
    }
    let dot = app.buttons["upgrade-badge-dot"]
    XCTAssertTrue(app.scrollIntoView(dot))
    print("DOT_FRAME \(dot.frame)")
    dot.press(forDuration: 2)
    dot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.3, thenDragTo: dot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: 20)))
    Thread.sleep(forTimeInterval: 1)
    let badge = try XCTUnwrap(badgeBox(app, dot, name: "dot-after-release", match: red))
    XCTAssertEqual(badge.width, 8, accuracy: 1); XCTAssertEqual(badge.height, 8, accuracy: 1)
  }

  func testUpgradeBadgeStyles() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    // Toolbar buttons carry their badge into the spoken value.
    let save = app.buttons["native-toolbar-save"]
    XCTAssertTrue(app.scrollIntoView(save)); XCTAssertEqual(save.value as? String, "4 new")
    app.terminate(); app.launch()
    let open = app.buttons["open-upgrade-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
    let dot = app.buttons["upgrade-badge-dot"], text = app.buttons["upgrade-badge-text"], cap = app.buttons["upgrade-badge-cap"]
    XCTAssertTrue(dot.waitForExistence(timeout: 5)); XCTAssertTrue(app.scrollIntoView(cap))
    Thread.sleep(forTimeInterval: 0.6)
    // Spoken values: a dot is never silent, text reads as itself, an app label wins.
    XCTAssertEqual(dot.value as? String, "New")
    XCTAssertEqual(text.value as? String, "New")
    XCTAssertEqual(cap.value as? String, "120 unread messages")
    XCTAssertEqual(app.buttons["upgrade-pill-saved"].value as? String, "2 of 4, 2 new")
    XCTAssertEqual(app.buttons["upgrade-pill-recent"].value as? String, "3 of 4, New")
    // A dot is an 8 pt circle on the top-right edge.
    let red: (UInt8, UInt8, UInt8) -> Bool = { r, g, b in r > 170 && g < 115 && b < 130 }
    let dotBox = try XCTUnwrap(badgeBox(app, dot, name: "badge-dot", match: red))
    XCTAssertEqual(dotBox.width, 8, accuracy: 2); XCTAssertEqual(dotBox.height, 8, accuracy: 2)
    XCTAssertEqual(dotBox.midX, dot.frame.width * 0.854, accuracy: 2); XCTAssertEqual(dotBox.midY, dot.frame.height * 0.146, accuracy: 2)
    // Custom fill and text colour: a yellow capsule with dark text.
    let yellowBox = try XCTUnwrap(badgeBox(app, text, name: "badge-text") { r, g, b in r > 200 && g > 170 && b < 90 })
    XCTAssertEqual(yellowBox.height, 18, accuracy: 2); XCTAssertGreaterThan(yellowBox.width, 22)
    // The 99+ cap in a custom blue: wider than a single digit.
    let blueBox = try XCTUnwrap(badgeBox(app, cap, name: "badge-cap") { r, g, b in r < 70 && g > 100 && g < 170 && b > 200 })
    XCTAssertEqual(blueBox.height, 18, accuracy: 2); XCTAssertGreaterThan(blueBox.width, 26)
    // A dot on a pill sits on the pill's top-right edge.
    let recent = app.buttons["upgrade-pill-recent"]
    // Narrow margin: the neighbouring Saved pill's red badge is only 10 pt away.
    let pillDot = try XCTUnwrap(badgeBox(app, recent, name: "badge-pill-dot", margin: 5, match: red))
    XCTAssertEqual(pillDot.width, 8, accuracy: 2); XCTAssertEqual(pillDot.height, 8, accuracy: 2)
    XCTAssertGreaterThan(pillDot.midX, recent.frame.width * 0.7)
    let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "badge-styles"; capture.lifetime = .keepAlways; add(capture)
  }

  func testUpgradePillIsolationAndBadge() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    let open = app.buttons["open-upgrade-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
    let saved = app.buttons["upgrade-pill-saved"]
    XCTAssertTrue(saved.waitForExistence(timeout: 5))
    let savedRestingFrame = saved.frame
    for id in ["all", "saved", "recent", "saved", "all"] {
      let pill = app.buttons["upgrade-pill-\(id)"]
      XCTAssertTrue(pill.waitForExistence(timeout: 5))
      pill.press(forDuration: 1.5)
      XCTAssertTrue(pill.isSelected)
      for other in ["all", "saved", "recent"] where other != id {
        XCTAssertFalse(app.buttons["upgrade-pill-\(other)"].isSelected)
      }
      Thread.sleep(forTimeInterval: 0.6)
      let capture = XCTAttachment(screenshot: app.screenshot())
      capture.name = "pill-selected-\(id)"; capture.lifetime = .keepAlways; add(capture)
      XCTAssertEqual(saved.frame.minX, savedRestingFrame.minX, accuracy: 0.3)
      XCTAssertEqual(saved.frame.width, savedRestingFrame.width, accuracy: 0.3)
      XCTAssertEqual(saved.frame.minY, savedRestingFrame.minY, accuracy: 0.3)
    }
    for _ in 0..<3 {
      app.buttons["upgrade-pill-all"].tap()
      app.buttons["upgrade-pill-saved"].tap()
      app.buttons["upgrade-pill-saved"].tap()
      XCTAssertTrue(app.buttons["upgrade-pill-saved"].isSelected)
    }
    app.buttons["upgrade-badge"].press(forDuration: 1.5)
  }

  func testUpgradeBadgeAndHeader() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch(); defer { app.terminate() }
    let open = app.buttons["open-upgrade-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
    let badge = app.buttons["upgrade-badge"]
    XCTAssertTrue(badge.waitForExistence(timeout: 10))
    XCTAssertEqual(badge.value as? String, "77 new")
    badge.press(forDuration: 1)
    let header = app.buttons["upgrade-header-primary"]
    XCTAssertTrue(app.scrollIntoView(header)); header.tap()
    XCTAssertEqual(header.label, "Done")
    let back = app.buttons["upgrade-header-back"]; XCTAssertTrue(back.waitForExistence(timeout: 5)); back.tap()
    XCTAssertEqual(header.label, "More")
    XCTAssertFalse(app.buttons["upgrade-header-back"].exists)
    let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "upgrade-header"; capture.lifetime = .keepAlways; add(capture)
  }

  func testUpgradeHeaderTransitions() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    let open = app.buttons["open-upgrade-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
    let primary = app.buttons["upgrade-header-primary"]
    XCTAssertTrue(app.scrollIntoView(primary, band: 0.2...0.6))
    let resting = primary.frame
    let restingInk = pixels(app.screenshot(), in: resting.insetBy(dx: 5, dy: 5), near: (240, 240, 247))
    for cycle in 0..<3 {
      primary.tap()
      XCTAssertEqual(primary.label, "Done")
      XCTAssertTrue(app.buttons["upgrade-header-back"].exists)
      XCTAssertEqual(primary.frame.midY, resting.midY, accuracy: 0.5)
      XCTAssertEqual(primary.frame.maxX, resting.maxX, accuracy: 0.5)
      Thread.sleep(forTimeInterval: 1)
      // A button may expose "Done" to accessibility while its title is still
      // truncated to three dots. Four rendered letters must cover more ink.
      let titleInk = pixels(app.screenshot(), in: primary.frame.insetBy(dx: 5, dy: 5), near: (240, 240, 247))
      XCTAssertGreaterThan(titleInk, restingInk * 2, "Done must render in full, not as a truncated ellipsis")
      let expanded = XCTAttachment(screenshot: app.screenshot())
      expanded.name = "header-expanded-\(cycle)"; expanded.lifetime = .keepAlways; add(expanded)
      // Exercise Done itself: closing via Back does not press the morphing glass.
      primary.tap()
      XCTAssertEqual(primary.label, "More")
      XCTAssertFalse(app.buttons["upgrade-header-back"].exists)
      XCTAssertEqual(primary.frame.width, resting.width, accuracy: 0.5)
      XCTAssertEqual(primary.frame.midY, resting.midY, accuracy: 0.5)
      XCTAssertEqual(primary.frame.maxX, resting.maxX, accuracy: 0.5)
      Thread.sleep(forTimeInterval: 1.5)
      let collapsed = XCTAttachment(screenshot: app.screenshot())
      collapsed.name = "header-collapsed-\(cycle)"; collapsed.lifetime = .keepAlways; add(collapsed)
    }
  }

  // Companion video checks release luminance; settled screenshots alone cannot
  // detect a transient flash. Exercise both content-changing and static controls.
  func testUpgradeControlReleaseLighting() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    let open = app.buttons["open-upgrade-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
    for id in ["upgrade-badge", "upgrade-clear", "upgrade-share", "upgrade-search", "upgrade-pill-saved", "upgrade-pill-all"] {
      let button = app.buttons[id]
      XCTAssertTrue(app.scrollIntoView(button))
      let resting = button.frame
      print("RELEASE_CONTROL \(id) \(resting)")
      for _ in 0..<2 {
        button.tap()
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertEqual(button.frame, resting, "A fixed-size control must not move on release")
      }
      let capture = XCTAttachment(screenshot: app.screenshot())
      capture.name = "release-\(id)"; capture.lifetime = .keepAlways; add(capture)
    }
  }

  func testUpgradeUnchangedButtonLighting() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-ALGAppearance", "dark"]
    app.launch(); defer { app.terminate() }
    let open = app.buttons["open-upgrade-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
    let search = app.buttons["upgrade-search"]
    XCTAssertTrue(app.scrollIntoView(search))
    let resting = search.frame
    for _ in 0..<3 {
      search.tap()
      XCTAssertTrue(app.staticTexts["upgrade-status"].label.contains("search"))
      XCTAssertEqual(search.frame, resting)
      Thread.sleep(forTimeInterval: 1.5)
    }
    let capture = XCTAttachment(screenshot: app.screenshot())
    capture.name = "unchanged-button-lighting"; capture.lifetime = .keepAlways; add(capture)
  }

  func testUpgradeLargeText() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    app.launch(); defer { app.terminate() }
    let sections = app.buttons["demo-sections"]
    XCTAssertTrue(sections.waitForExistence(timeout: launchTimeout)); sections.tap()
    app.buttons["Controls & badges"].tap()
    let saved = app.buttons["upgrade-pill-saved"]
    XCTAssertTrue(app.scrollIntoView(saved)); XCTAssertGreaterThanOrEqual(saved.frame.height, 44)
    saved.tap(); XCTAssertTrue(app.staticTexts["upgrade-status"].label.contains("saved"))
    let search = app.buttons["upgrade-search"]
    let row = app.otherElements["upgrade-pills"]
    for _ in 0..<3 {
      if search.isHittable { break }
      row.swipeLeft(velocity: .slow)
    }
    XCTAssertTrue(search.isHittable)
    XCTAssertTrue(saved.isSelected, "Scrolling must cancel pill presses")
    search.tap(); XCTAssertTrue(app.staticTexts["upgrade-status"].label.contains("search"))
    let share = app.buttons["upgrade-share"]
    XCTAssertTrue(app.scrollIntoView(share)); share.tap()
    XCTAssertTrue(app.staticTexts["upgrade-status"].label.contains("share"))
    let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "upgrade-large-text"; capture.lifetime = .keepAlways; add(capture)
  }

  func testUpgradeControls() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch(); defer { app.terminate() }
    let open = app.buttons["open-upgrade-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
    let back = app.buttons["upgrade-back-symbol"]
    XCTAssertTrue(back.waitForExistence(timeout: 20))
    XCTAssertEqual(back.frame.width, 44, accuracy: 0.5)
    XCTAssertEqual(back.frame.height, 44, accuracy: 0.5)
    let share = app.buttons["upgrade-share"]; XCTAssertTrue(share.exists); share.tap()
    XCTAssertTrue(app.staticTexts["upgrade-status"].label.contains("share"))
    app.buttons["upgrade-more"].tap()
    let pin = app.buttons["Pin item"]; XCTAssertTrue(pin.waitForExistence(timeout: 5)); pin.tap()
    XCTAssertTrue(app.staticTexts["upgrade-status"].label.contains("pin"))
    app.buttons["upgrade-pill-saved"].tap()
    XCTAssertTrue(app.staticTexts["upgrade-status"].label.contains("saved"))
    let morph = app.buttons["upgrade-morph"]; let before = morph.frame
    morph.tap(); Thread.sleep(forTimeInterval: 0.7)
    XCTAssertEqual(morph.label, "Done")
    XCTAssertGreaterThan(morph.frame.width, before.width + 5)
    XCTAssertEqual(morph.frame.maxX, before.maxX, accuracy: 1)
    let toggle = app.buttons["upgrade-toggle-presence"]; XCTAssertTrue(app.scrollIntoView(toggle)); toggle.tap()
    XCTAssertTrue(app.staticTexts["upgrade-exits"].waitForExistence(timeout: 5))
    let exited = NSPredicate(format: "label == %@", "Exits: 1")
    expectation(for: exited, evaluatedWith: app.staticTexts["upgrade-exits"])
    waitForExpectations(timeout: 5)
    XCTAssertFalse(app.buttons["upgrade-present"].exists)
    toggle.tap(); XCTAssertTrue(app.buttons["upgrade-present"].waitForExistence(timeout: 5))
    let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "upgrade-controls"; capture.lifetime = .keepAlways; add(capture)
  }

  func testConversationMenuAppearance() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    defer { app.terminate() }
    let open = app.buttons["open-context-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
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
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
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
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
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
    openNavigation(app)
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
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
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.55)).tap()
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
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.55)).tap()
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
    openNavigation(app)
    let open = app.buttons["open-search-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
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
      openNavigation(app)
    let open = app.buttons["open-tabs-demo"]
      XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
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
    openNavigation(app)
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
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
    openNavigation(app)
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
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
    openNavigation(app)
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
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
    openNavigation(app)
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
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
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
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
    let sections = app.buttons["demo-sections"]
    XCTAssertTrue(sections.waitForExistence(timeout: launchTimeout)); sections.tap()
    app.buttons["Accessibility"].tap()
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
    openNavigation(app)
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
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
    XCTAssertTrue(open.waitForExistence(timeout: launchTimeout)); if !open.isHittable { XCTAssertTrue(app.scrollIntoView(open)) }; open.tap()
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
      // The component gallery owns the top of the screen; keep the upper placement below it.
      for band in [0.35...0.45, 0.55...0.65, 0.8...0.9] as [ClosedRange<CGFloat>] {
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
