import XCTest
import UIKit

final class GlassInteractionTests: XCTestCase {
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
    XCTAssertTrue(button.waitForExistence(timeout: 45))
    for _ in 0..<7 { if button.isHittable { break }; app.swipeUp() }
    XCTAssertTrue(button.isHittable)
    for standard in [false, true] {
      if standard {
        let setting = app.switches["menu-fallback-toggle"]
        for _ in 0..<5 { if setting.isHittable { break }; app.swipeUp() }
        setting.tap()
        for _ in 0..<5 { if button.isHittable { break }; app.swipeDown() }
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
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.12)).tap()
    XCTAssertTrue(app.buttons["Share item"].waitForNonExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Menu selected: remove"].exists, "Dismissal must not emit an action")
    let disable = app.switches["menu-disabled-toggle"]
    for _ in 0..<5 { if disable.isHittable { break }; app.swipeUp() }
    disable.tap()
    XCTAssertFalse(button.isEnabled)
    disable.tap()
    XCTAssertTrue(button.isEnabled)
  }

  func testToolbarAndMenuBatch() throws {
    // The shared menu host changed; include its existing flat-menu regression.
    try testNativeMenuActionsAndFallback()
    let app = XCUIApplication(); app.launch()
    func reveal(_ element: XCUIElement) {
      for _ in 0..<14 {
        if element.exists && element.isHittable { return }
        if element.exists && element.frame.midY < app.frame.midY { app.swipeDown() }
        else { app.swipeUp() }
      }
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
    XCTAssertTrue(save.waitForExistence(timeout: 45)); reveal(save); save.tap(); expectStatus("save")
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

  func testNativeTabNavigationBatch() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: 45)); open.tap()
    func tab(_ name: String) -> XCUIElement { app.buttons["\(name) tab"] }
    func screen(_ name: String) { XCTAssertTrue(app.staticTexts["\(name) screen"].waitForExistence(timeout: 8)) }
    func toggle(_ id: String) {
      let control = app.switches[id]
      for _ in 0..<5 { if control.isHittable { break }; app.swipeUp() }
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
    for _ in 0..<5 { if jump.isHittable { break }; app.swipeDown() }
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

  func testNativeTabsBadgeRemovalSnapshot() throws {
    continueAfterFailure = false
    let app = XCUIApplication(); app.launch()
    let open = app.buttons["open-tabs-demo"]
    XCTAssertTrue(open.waitForExistence(timeout: 45)); open.tap()
    let badges = app.switches["tabs-badges-toggle"]
    XCTAssertTrue(badges.waitForExistence(timeout: 8)); badges.tap()
    XCTAssertEqual(badges.value as? String, "0")
    XCTAssertTrue(app.staticTexts["Home screen"].exists)
    let capture = XCTAttachment(screenshot: app.screenshot())
    capture.name = "Native tabs cleared badges fresh capture"; capture.lifetime = .keepAlways; add(capture)
  }

  func testGlassHighlightComparison() throws {
    let app = XCUIApplication()
    app.launch()
    let toggle = app.buttons["glass-cluster-toggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: 45))
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
    XCTAssertTrue(toggle.waitForExistence(timeout: 45))
    let setting = app.switches["interactive-toggle"]
    for expected in ["1", "0"] {
      for _ in 0..<5 {
        if setting.isHittable { break }
        app.swipeUp()
      }
      XCTAssertEqual(setting.value as? String, expected)
      setting.tap()
      XCTAssertEqual(setting.value as? String, expected == "0" ? "1" : "0")
      for _ in 0..<5 {
        if toggle.isHittable { break }
        app.swipeDown()
      }
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
    XCTAssertTrue(toggle.waitForExistence(timeout: 45))
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
    XCTAssertTrue(toggle.waitForExistence(timeout: 45))
    // Exercise native press/release and React callback updates in both rendering modes.
    // These assertions verify behavior, not frame rate or optical smoothness.
    for merging in [false, true] {
      if merging {
        let setting = app.switches["merging-enabled-toggle"]
        for _ in 0..<5 {
          if setting.isHittable { break }
          app.swipeUp()
        }
        XCTAssertTrue(setting.isHittable)
        XCTAssertEqual(setting.value as? String, "0")
        setting.tap()
        for _ in 0..<5 {
          if toggle.isHittable { break }
          app.swipeDown()
        }
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
    XCTAssertTrue(app.buttons["glass-counter"].waitForExistence(timeout: 45))
    let slider = app.sliders["native-slider"]
    for _ in 0..<8 {
      if slider.isHittable { break }
      app.swipeUp()
    }
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
    XCTAssertTrue(app.buttons["glass-counter"].waitForExistence(timeout: 45))
    let segments = app.segmentedControls["native-segments"]
    for _ in 0..<5 {
      if segments.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(segments.isHittable, app.debugDescription)
    XCTAssertFalse(segments.buttons["Shared"].isEnabled)
    segments.buttons["Saved"].tap()
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
    XCTAssertFalse(segments.buttons["Saved"].isEnabled)
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
    XCTAssertTrue(app.buttons["glass-counter"].waitForExistence(timeout: 45), app.debugDescription)
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
}
