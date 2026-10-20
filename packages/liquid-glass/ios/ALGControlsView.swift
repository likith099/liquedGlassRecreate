import UIKit

private struct ControlItem: Decodable, Equatable {
  let id: String
  let label: String
  var side: String?
  var title: String?
  var testID: String?
  var disabled: Bool?
  var tint: Double?
  var symbol: ALGSymbol?
  var imageSource: ALGImageSource?
  var contentTransition: String?
  var pressEffect: String?
  var badge: String?
  var badgeColor: Double?
  var badgeTextColor: Double?
  var badgeAccessibility: String?
  var menu: [ControlMenuItem]?
  /// Header slot identity (`leading:back`). The same slot on two routes is one native
  /// button, so it morphs; `id` stays route-qualified so presses reach the right screen.
  var slot: String?
  var key: String { slot ?? id }
  var icon: ALGIcon { ALGIcon(symbol: symbol, imageSource: imageSource, contentTransition: contentTransition,
    pressEffect: pressEffect, badge: badge, badgeColor: badgeColor, badgeTextColor: badgeTextColor,
    badgeAccessibility: badgeAccessibility) }
}
private struct ControlMenuItem: Decodable, Equatable {
  let id: String; let title: String
  var kind: String?; var systemImage: String?; var symbol: ALGSymbol?
  var disabled: Bool?; var checked: Bool?; var destructive: Bool?; var items: [ControlMenuItem]?
}
private struct ControlsConfig: Decodable, Equatable {
  var mode = "group"
  var items: [ControlItem] = []
  var height: Double?
  var colorScheme: String?
  var disabled: Bool?
  var forceFallback: Bool?
  var value: String?
  var selectedStyle: String?
  var tint: Double?
  var contentInset: Double?
  var horizontalPadding: Double?
  var gap: Double?
  var labelSize: Double?
  var iconCapsuleWidth: Double?
  var scrollSelectedIntoView: Bool?
  /// Header mode: every registered screen's items, keyed by route key (react-native-screens `screenId`).
  var routes: [HeaderRoute]?
  var active: String?
}
private struct HeaderRoute: Decodable, Equatable { let key: String; let items: [ControlItem] }
/// One geometry function shared by `layoutSubviews` and the Fabric measure function,
/// so Yoga sizes the view exactly as the view lays itself out (no JS round trip).
/// Pure UIKit value APIs only: it also runs on React Native's layout thread.
private struct ControlsGeometry {
  var widths: [CGFloat] = []
  var inks: [CGFloat] = []
  var height: CGFloat = 44
  var contentWidth: CGFloat = 1
  static func make(_ config: ControlsConfig, scale: CGFloat, category: UIContentSizeCategory) -> ControlsGeometry {
    let traits = UITraitCollection(preferredContentSizeCategory: category)
    let metrics = UIFontMetrics(forTextStyle: .body)
    let labelSize = CGFloat(config.labelSize ?? 17)
    let base = CGFloat(config.height ?? 44)
    var geometry = ControlsGeometry()
    geometry.height = max(base, min(metrics.scaledValue(for: labelSize, compatibleWith: traits), 34) + 20)
    func font(_ weight: UIFont.Weight) -> UIFont {
      metrics.scaledFont(for: .systemFont(ofSize: labelSize, weight: weight), maximumPointSize: labelSize * 2, compatibleWith: traits)
    }
    func textWidth(_ text: String, _ weights: [UIFont.Weight]) -> CGFloat {
      weights.map { (text as NSString).size(withAttributes: [.font: font($0)]).width }.max() ?? 0
    }
    func pixel(_ value: CGFloat) -> CGFloat { ceil(value * max(1, scale)) / max(1, scale) }
    let padding = CGFloat(config.horizontalPadding ?? 15)
    let pillInset = CGFloat(config.contentInset ?? 20)
    var x: CGFloat = config.mode == "group" ? 14 : config.mode == "pills" ? pillInset : 0
    for (index, item) in config.items.enumerated() {
      let ink = ControlsGeometry.imageWidth(item)
      let width: CGFloat
      if config.mode == "group" {
        // Ink-to-ink spacing is 35pt; split it across neighbouring hit areas.
        width = max(44, (ink ?? 17) + 35)
      } else if let title = item.title {
        // Pills size from the regular label, as Fitness+ does (For You 87 pt); the selected
        // semibold label uses part of its padding, so selection never moves the row or badges.
        let weights: [UIFont.Weight] = config.mode == "pills" ? [.regular] : [config.value == item.id ? .semibold : .regular]
        let image = ink.map { $0 + 6 } ?? 0
        width = max(base, pixel(textWidth(title, weights) + image + padding * 2))
      } else { width = config.mode == "pills" ? CGFloat(config.iconCapsuleWidth ?? 49) : base }
      geometry.widths.append(width); geometry.inks.append(ink ?? 17)
      x += config.mode == "group" ? (ink ?? 17) : width
      if index < config.items.count - 1 { x += config.mode == "group" ? 35 : CGFloat(config.gap ?? 10) }
    }
    x += config.mode == "group" ? 14 : config.mode == "pills" ? pillInset : 0
    geometry.contentWidth = max(1, x)
    return geometry
  }
  /// A loaded image is drawn in its declared point-size box, so layout never depends on the download.
  static func imageWidth(_ item: ControlItem) -> CGFloat? {
    if item.imageSource != nil { return CGFloat(item.symbol?.pointSize ?? 17) }
    return item.symbol?.image()?.size.width
  }
}
/// React Native's font-size multipliers map one-to-one onto content size categories.
private let multiplierCategories: [(Double, UIContentSizeCategory)] = [
  (0.823, .extraSmall), (0.882, .small), (0.941, .medium), (1.0, .large), (1.118, .extraLarge),
  (1.235, .extraExtraLarge), (1.353, .extraExtraExtraLarge), (1.786, .accessibilityMedium),
  (2.143, .accessibilityLarge), (2.643, .accessibilityExtraLarge), (3.143, .accessibilityExtraExtraLarge),
  (3.571, .accessibilityExtraExtraExtraLarge)]

/// Fabric measure entry point, called by the ALGControls shadow node during layout.
@objc(ALGControlsLayout)
public final class ALGControlsLayout: NSObject {
  @objc public static func measure(_ json: String, scale: Double, fontSizeMultiplier: Double, maxWidth: Double) -> CGSize {
    guard let config = try? JSONDecoder().decode(ControlsConfig.self, from: Data(json.utf8)) else { return CGSize(width: 1, height: 44) }
    let category = multiplierCategories.min { abs($0.0 - fontSizeMultiplier) < abs($1.0 - fontSizeMultiplier) }?.1 ?? .large
    let geometry = ControlsGeometry.make(config, scale: CGFloat(scale), category: category)
    var width = geometry.contentWidth
    if config.mode == "header" || config.mode == "pills" { width = maxWidth.isFinite ? CGFloat(maxWidth) : width }
    else if maxWidth.isFinite { width = min(width, CGFloat(maxWidth)) }
    return CGSize(width: width, height: max(44, geometry.height))
  }
}

private final class ControlButton: ALGDecoratedButton {
  let loader = ALGIconLoader()
  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    bounds.insetBy(dx: -max(0, (44 - bounds.width) / 2), dy: -max(0, (44 - bounds.height) / 2)).contains(point)
  }
}
private final class ControlScrollView: UIScrollView {
  override func touchesShouldCancel(in view: UIView) -> Bool {
    // Immediate button feedback must still yield to a horizontal scroll gesture.
    view is UIControl || super.touchesShouldCancel(in: view)
  }
}

@objc(ALGControlsView)
public final class ALGControlsView: UIView {
  private let scroll = ControlScrollView()
  private let effect = UIVisualEffectView()
  private var config = ControlsConfig()
  private var buttons: [String: ControlButton] = [:]
  private var lastItems: [String: ControlItem] = [:]
  private var lastJSON = ""
  private var materialKey = ""
  private var lastAppearance: ControlsConfig?
  private var lastSelection: String?
  // Header transitions (G7): driven by the stack's own transition coordinator.
  private weak var navigation: UINavigationController?
  private var observedGestures: [ObjectIdentifier] = []
  private var displayedRoute: String?
  private var trackedTransition: ObjectIdentifier?
  private var inTransition = false
  private var exiting: [(key: String, button: ControlButton)] = []
  private var watch: CADisplayLink?
  private var watchDeadline: CFTimeInterval = 0
  @objc public var onAction: ((String, String) -> Void)?
  // Both the Fabric wrapper and its native controls must settle before UIKit's
  // release lighting tail. A second, longer spring can readapt the lens again.
  @objc public var layoutAnimationDuration: TimeInterval { 0.25 }
  @objc public var layoutAnimationDamping: CGFloat { 1 }
  private var morphsContent: Bool { config.mode == "morph" || config.mode == "header" }
  @objc public var animatesLayout: Bool { config.mode != "pills" && window != nil && !UIAccessibility.isReduceMotionEnabled }
  public override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(scroll); scroll.addSubview(effect)
    scroll.showsHorizontalScrollIndicator = false; scroll.clipsToBounds = false
    // Forward touch-down immediately so badge tracking starts with UIKit's glass
    // highlight, rather than after UIScrollView's default 150 ms touch delay.
    scroll.delaysContentTouches = false
    NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: UIContentSizeCategory.didChangeNotification, object: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  deinit { NotificationCenter.default.removeObserver(self) }
  @objc public func configure(_ json: String) {
    guard json != lastJSON, let next = try? JSONDecoder().decode(ControlsConfig.self, from: Data(json.utf8)) else { return }
    lastJSON = json
    config = next
    if next.mode == "header" {
      // The displayed route follows the stack's top screen; a transition retargets it natively.
      if !inTransition {
        let key = Self.screenKey(attachNavigation()?.topViewController) ?? next.active
        if let items = Self.items(next, key) { displayedRoute = key; config.items = items }
      } else if let items = Self.items(next, displayedRoute) { config.items = items }
      // react-native-screens starts the push/pop after this commit (sometimes frames later):
      // watch briefly for its transition instead of switching early.
      if !inTransition, let active = next.active, active != displayedRoute { watchForTransition() }
    }
    overrideUserInterfaceStyle = next.colorScheme == "dark" ? .dark : next.colorScheme == "light" ? .light : .unspecified
    apply()
  }
  private static func items(_ config: ControlsConfig, _ key: String?) -> [ControlItem]? {
    guard let key, let routes = config.routes else { return nil }
    return routes.first { $0.key == key }?.items
  }
  /// react-native-screens' screen view publishes the navigator route key as `screenId`.
  private static func screenKey(_ controller: UIViewController?) -> String? {
    guard let view = controller?.view, view.responds(to: NSSelectorFromString("screenId")) else { return nil }
    return view.value(forKey: "screenId") as? String
  }
  /// The stack this header sits above: a sibling subtree of the host, found once and observed.
  @discardableResult private func attachNavigation() -> UINavigationController? {
    if let navigation, navigation.view.window != nil { return navigation }
    var queue: [UIView] = superview?.superview?.subviews ?? [], depth = 0
    while !queue.isEmpty, depth < 14, navigation == nil {
      var next: [UIView] = []
      for view in queue where view !== superview {
        if let controller = view.next as? UINavigationController { navigation = controller; break }
        next.append(contentsOf: view.subviews)
      }
      queue = next; depth += 1
    }
    guard let navigation else { return nil }
    // Interactive back starts natively; JS learns of it only when it finishes.
    var gestures = navigation.view.gestureRecognizers ?? []
    gestures += navigation.view.superview?.gestureRecognizers ?? []
    if let pop = navigation.interactivePopGestureRecognizer { gestures.append(pop) }
    for gesture in gestures where gesture is UIPanGestureRecognizer && !observedGestures.contains(ObjectIdentifier(gesture)) {
      observedGestures.append(ObjectIdentifier(gesture)); gesture.addTarget(self, action: #selector(stackGesture(_:)))
    }
    return navigation
  }
  /// Bounded native watch (≤ 1.5 s) for the stack transition that follows a focus change.
  private func watchForTransition() {
    watchDeadline = CACurrentMediaTime() + 1.5
    guard watch == nil else { return }
    let link = CADisplayLink(target: self, selector: #selector(watchTick)); link.add(to: .main, forMode: .common); watch = link
  }
  @objc private func watchTick() {
    followTransition()
    let top = Self.screenKey(navigation?.topViewController)
    if inTransition || window == nil { stopWatching(); return }
    if let top, top != displayedRoute, let items = Self.items(config, top) {
      // The stack changed without an animated transition.
      displayedRoute = top; config.items = items; apply(); stopWatching(); return
    }
    if CACurrentMediaTime() > watchDeadline {
      // No navigation transition: the focus change is the whole update.
      if let active = config.active, active != displayedRoute, let items = Self.items(config, active) { displayedRoute = active; config.items = items; apply() }
      stopWatching()
    }
  }
  private func stopWatching() { watch?.invalidate(); watch = nil }
  public override func willMove(toWindow newWindow: UIWindow?) { super.willMove(toWindow: newWindow); if newWindow == nil { stopWatching() } }
  @objc private func stackGesture(_ gesture: UIGestureRecognizer) {
    guard gesture.state == .began || gesture.state == .changed else { return }
    DispatchQueue.main.async { [weak self] in self?.followTransition() }
  }
  /// Runs the slot diff inside the stack's transition, so UIKit times it, scrubs it with an
  /// interactive swipe and reverses it on cancel. JavaScript does nothing per frame.
  private func followTransition() {
    guard config.mode == "header", !inTransition, let coordinator = attachNavigation()?.transitionCoordinator else { return }
    let identity = ObjectIdentifier(coordinator as AnyObject)
    guard trackedTransition != identity, let toKey = Self.screenKey(coordinator.viewController(forKey: .to)),
      toKey != displayedRoute, let toItems = Self.items(config, toKey) else { return }
    trackedTransition = identity
    let fromKey = displayedRoute, fromItems = config.items
    inTransition = true
    let queued = coordinator.animate(alongsideTransition: { [weak self] _ in
      guard let self else { return }
      self.displayedRoute = toKey; self.config.items = toItems; self.apply()
      self.setNeedsLayout(); self.layoutIfNeeded()
    }, completion: { [weak self] context in
      guard let self else { return }
      self.inTransition = false; self.trackedTransition = nil
      let leaving = self.exiting; self.exiting = []
      if context.isCancelled {
        // UIKit has reversed the animated geometry; restore the outgoing screen's controls.
        for entry in leaving where self.buttons[entry.key] == nil { entry.button.transform = .identity; entry.button.isUserInteractionEnabled = true; entry.button.accessibilityElementsHidden = false; entry.button.badgeLabel.alpha = 1; self.buttons[entry.key] = entry.button }
        self.displayedRoute = fromKey; self.config.items = fromItems; self.lastItems = [:]; self.apply()
      } else {
        for entry in leaving { entry.button.removeFromSuperview(); entry.button.badgeLabel.removeFromSuperview() }
        if UIAccessibility.isVoiceOverRunning, let first = self.config.items.first, let button = self.buttons[first.key] {
          UIAccessibility.post(notification: .layoutChanged, argument: button)
        }
      }
    })
    if !queued { inTransition = false; trackedTransition = nil; displayedRoute = toKey; config.items = toItems; apply() }
  }
  public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    if bounds.contains(point) {
      for button in buttons.values { let local = button.convert(point, from: self); if let hit = button.hitTest(local, with: event) { return hit } }
      if config.mode == "header" { return nil }
    }
    return super.hitTest(point, with: event)
  }
  public override func traitCollectionDidChange(_ previous: UITraitCollection?) {
    super.traitCollectionDidChange(previous)
    if previous?.userInterfaceStyle != traitCollection.userInterfaceStyle { appearanceChanged() }
  }
  @objc private func appearanceChanged() { materialKey = ""; lastAppearance = nil; apply() }
  private var glass: Bool {
    if #available(iOS 26.0, *) { return config.forceFallback != true && !UIAccessibility.isReduceTransparencyEnabled }
    return false
  }
  private func apply() {
    let keys = Set(config.items.map(\.key))
    for (key, button) in buttons where !keys.contains(key) {
      buttons.removeValue(forKey: key); lastItems.removeValue(forKey: key); button.badgeHost = nil
      guard config.mode == "header", window != nil else {
        button.removeFromSuperview(); button.badgeLabel.removeFromSuperview(); continue
      }
      if UIAccessibility.isReduceMotionEnabled {
        // Reduce Motion: fade instead of shrinking.
        UIView.transition(with: button, duration: 0.2, options: .transitionCrossDissolve, animations: { button.isHidden = true; button.badgeLabel.isHidden = true }) { _ in
          button.removeFromSuperview(); button.badgeLabel.removeFromSuperview()
        }
        continue
      }
      // Dematerialize as UIKit's bar items do: shrink to the centre and vanish (~80 ms on pop).
      button.isUserInteractionEnabled = false; button.accessibilityElementsHidden = true
      let shrink = { button.transform = CGAffineTransform(scaleX: 0.01, y: 0.01); button.badgeLabel.alpha = 0 }
      if inTransition { exiting.append((key, button)); shrink() }
      else {
        UIView.animate(withDuration: 0.08, delay: 0, options: [.curveEaseIn, .beginFromCurrentState], animations: shrink) { _ in
          button.removeFromSuperview(); button.badgeLabel.removeFromSuperview()
        }
      }
    }
    let key = "\(glass)/\(config.mode)/\(UIAccessibility.isReduceTransparencyEnabled)"
    if materialKey != key {
      materialKey = key
      if #available(iOS 26.0, *), glass {
        if config.mode == "group" {
          let material = UIGlassEffect(style: .regular); material.isInteractive = true; effect.effect = material
          effect.cornerConfiguration = .capsule()
        } else if config.mode == "pills" || morphsContent {
          // Independent controls must not share highlight compositing. Adding or
          // removing a slot must not readapt another button's material. A single
          // morphing button also needs no shared glass container.
          effect.effect = nil
        } else {
          let container = UIGlassContainerEffect(); container.spacing = 0; effect.effect = container
        }
        effect.backgroundColor = .clear
      } else {
        effect.effect = nil
        effect.backgroundColor = config.mode == "group" ? .secondarySystemBackground : .clear
        effect.layer.cornerRadius = CGFloat(config.height ?? 44) / 2
      }
    }
    var appearanceKey = config
    appearanceKey.items = []; appearanceKey.value = nil
    let appearanceChanged = lastAppearance != appearanceKey
    for (index, item) in config.items.enumerated() {
      let button: ControlButton
      if let existing = buttons[item.key] { button = existing }
      else {
        button = ControlButton(type: .system); buttons[item.key] = button; effect.contentView.addSubview(button)
        let key = item.key
        button.addAction(UIAction { [weak self, weak button] _ in
          guard let self, let button, self.window != nil, self.config.disabled != true,
            let current = self.config.items.first(where: { $0.key == key }), current.disabled != true else { return }
          current.icon.pressed(button)
          if current.menu == nil { self.onAction?(current.id, "") }
        }, for: .primaryActionTriggered)
      }
      button.badgeHost = config.mode == "group" ? self : nil
      let selected = config.value == item.id
      if !appearanceChanged, lastItems[item.key] == item,
        (lastSelection == item.id) == selected { continue }
      button.loader.load(item.imageSource) { [weak self] in
        self?.lastItems.removeValue(forKey: item.key); self?.apply()
      }
      var appearance: UIButton.Configuration
      if morphsContent, !appearanceChanged,
        (lastSelection == item.id) == selected, let current = button.configuration {
        // A content change keeps the existing glass configuration and its native
        // press/release state, rather than constructing a fresh material mid-release.
        appearance = current
      } else if config.mode == "group" { appearance = .plain() }
      else if #available(iOS 26.0, *), glass { appearance = selected ? .prominentGlass() : .glass() }
      else { appearance = selected ? .filled() : .gray() }
      let tint = item.tint.map(ALGIcon.color) ?? config.tint.map(ALGIcon.color) ?? .label
      appearance.cornerStyle = .capsule
      appearance.title = item.title
      appearance.image = button.loader.fitted(CGFloat(item.symbol?.pointSize ?? 17)) ?? item.symbol?.image(tint: tint)
      appearance.imagePadding = 6
      let size = CGFloat(config.labelSize ?? 17)
      let font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: size, weight: selected ? .semibold : .regular), maximumPointSize: size * 2)
      let selectedForeground: UIColor = traitCollection.userInterfaceStyle == .dark ? .black : .white
      appearance.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
        var out = incoming; out.font = font
        out.foregroundColor = selected ? selectedForeground : tint
        return out
      }
      appearance.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: item.title == nil ? 0 : CGFloat(config.horizontalPadding ?? 15), bottom: 0, trailing: item.title == nil ? 0 : CGFloat(config.horizontalPadding ?? 15))
      appearance.baseForegroundColor = selected && config.selectedStyle != "tinted" ? .systemBackground : tint
      if selected { appearance.baseBackgroundColor = config.selectedStyle == "tinted" ? tint : .label; button.tintColor = appearance.baseBackgroundColor }
      else { button.tintColor = tint }
      if morphsContent {
        appearance.titleLineBreakMode = .byTruncatingTail
        if #available(iOS 26.0, *) { appearance.symbolContentTransition = nil }
      }
      item.icon.applyTransition(to: &appearance)
      button.attachBadgeGeometry(to: &appearance, enabled: item.badge != nil)
      let previousItem = lastItems[item.key]
      let contentChanged = previousItem != nil && (previousItem?.title != item.title || previousItem?.symbol != item.symbol || previousItem?.imageSource != item.imageSource)
      if morphsContent, contentChanged, window != nil, UIAccessibility.isReduceMotionEnabled {
        // Reduce Motion: the morph becomes a 0.2 s cross-fade at the final size.
        UIView.transition(with: button, duration: 0.2, options: [.transitionCrossDissolve, .allowUserInteraction]) {
          button.configuration = appearance; button.titleLabel?.numberOfLines = 1; button.layoutIfNeeded()
        }
      } else { UIView.performWithoutAnimation {
        button.configuration = appearance
        if morphsContent {
          // UIKit creates the first title label lazily. Lay it out at the current
          // bounds before the frame spring, so it cannot animate from its zero frame
          // or a wrapped title above the button's vertical center.
          button.titleLabel?.numberOfLines = 1
          button.layoutIfNeeded()
        }
      } }
      if lastItems[item.key]?.symbol != item.symbol { item.icon.transitionImage(on: button, image: appearance.image) }
      button.isEnabled = config.disabled != true && item.disabled != true
      button.accessibilityLabel = item.label; button.accessibilityIdentifier = item.testID
      button.accessibilityTraits = selected ? [.button, .selected] : .button
      // A pill reads its position, then its badge ("2 of 4, 2 new"); other controls read the badge.
      let spokenBadge = item.badge == nil ? nil : item.badgeAccessibility ?? item.badge
      let position = item.title != nil && config.mode == "pills"
        ? "\(index + 1) of \(config.items.filter { $0.title != nil }.count)" : nil
      button.accessibilityValue = [position, spokenBadge].compactMap { $0 }.joined(separator: ", ")
      button.badgeLabel.configure(item.badge, color: item.badgeColor.map(ALGIcon.color),
        textColor: item.badgeTextColor.map(ALGIcon.color))
      if lastItems[item.key]?.menu != item.menu || lastItems[item.key]?.id != item.id {
        button.menu = item.menu.map { UIMenu(children: menuElements($0, controlID: item.id)) }
        button.showsMenuAsPrimaryAction = item.menu != nil
        if #available(iOS 16.0, *) { button.preferredMenuElementOrder = .fixed }
      }
      lastItems[item.key] = item
    }
    lastAppearance = appearanceKey; lastSelection = config.value
    setNeedsLayout()
  }
  private func menuElements(_ items: [ControlMenuItem], controlID: String, parentEnabled: Bool = true) -> [UIMenuElement] {
    items.map { item in
      let image = item.symbol?.image() ?? item.systemImage.flatMap { UIImage(systemName: $0) }
      if let children = item.items {
        return UIMenu(title: item.title, image: image, options: item.kind == "section" ? .displayInline : [], children: menuElements(children, controlID: controlID, parentEnabled: parentEnabled && item.disabled != true))
      }
      var attributes: UIMenuElement.Attributes = []
      if !parentEnabled || item.disabled == true || config.items.first(where: { $0.id == controlID })?.disabled == true { attributes.insert(.disabled) }
      if item.destructive == true { attributes.insert(.destructive) }
      return UIAction(title: item.title, image: image, attributes: attributes, state: item.checked == true ? .on : .off) { [weak self] _ in
        guard let self, self.window != nil, self.config.disabled != true else { return }
        self.onAction?(controlID, item.id)
      }
    }
  }
  public override func layoutSubviews() {
    super.layoutSubviews()
    scroll.frame = bounds; scroll.isScrollEnabled = config.mode == "pills"
    let geometry = ControlsGeometry.make(config, scale: traitCollection.displayScale, category: traitCollection.preferredContentSizeCategory)
    let height = geometry.height
    let inset = config.mode == "pills" ? CGFloat(config.contentInset ?? 20) : 0
    var x: CGFloat = config.mode == "group" ? 14 : inset
    var trailing = bounds.width - CGFloat(config.contentInset ?? 20)
    for (index, item) in config.items.enumerated() {
      guard let button = buttons[item.key] else { continue }
      let width = geometry.widths[index]
      #if DEBUG
      if morphsContent, item.title != nil, button.sizeThatFits(CGSize(width: 10000, height: height)).width > width + 0.5 {
        NSLog("[ALGControls] UIKit wants %.1f pt for '%@'; shared geometry gave %.1f pt.", button.sizeThatFits(CGSize(width: 10000, height: height)).width, item.title ?? "", width)
      }
      #endif
      let old = button.frame
      if config.mode == "header" {
        if item.side == "trailing" { trailing -= width; x = trailing }
        else if index == 0 { x = CGFloat(config.contentInset ?? 20) }
      }
      let ink = geometry.inks[index]
      let target = CGRect(x: config.mode == "group" ? x + (ink - width) / 2 : x, y: 0, width: width, height: height)
      if old == .zero, config.mode == "header" {
        // A control that only the incoming screen has appears at full size within one frame,
        // as UIKit's bar items do, rather than growing from a zero frame inside the transition.
        UIView.performWithoutAnimation { button.frame = target; button.layoutIfNeeded() }
      }
      // Inside a navigation transition the frame inherits UIKit's (scrubbable) timing.
      if morphsContent, window != nil, old.width > 0, old != target, !UIAccessibility.isReduceMotionEnabled, !inTransition {
        let badgeTransition = button.beginBadgeLayoutTransition(to: target)
        // Share the wrapper's timing; neither layer should keep resizing the
        // lens after UIKit has begun fading its native press illumination.
        UIView.animate(withDuration: layoutAnimationDuration, delay: 0, usingSpringWithDamping: layoutAnimationDamping, initialSpringVelocity: 0,
          options: [.beginFromCurrentState, .allowUserInteraction], animations: {
            button.frame = target
            button.setNeedsLayout(); button.layoutIfNeeded()
          },
          completion: { [weak button] _ in button?.endBadgeLayoutTransition(badgeTransition) })
      } else {
        button.frame = target
        if morphsContent, old != target {
          // Initial layout and Reduce Motion need the same final content geometry.
          button.setNeedsLayout(); button.layoutIfNeeded()
        }
      }
      if config.mode == "header", item.side == "trailing" { trailing -= 12 }
      x += config.mode == "group" ? ink : width
      if index < config.items.count - 1 { x += config.mode == "group" ? 35 : CGFloat(config.gap ?? 10) }
    }
    x += config.mode == "group" ? 14 : inset
    if config.mode == "header" { x = bounds.width }
    effect.frame = CGRect(x: 0, y: 0, width: x, height: height)
    scroll.contentSize = CGSize(width: x, height: max(height, 44))
    scroll.alwaysBounceHorizontal = x > bounds.width
    if config.mode == "pills", config.scrollSelectedIntoView != false, let value = config.value, let selected = buttons[value],
      !scroll.bounds.contains(selected.frame) { scroll.scrollRectToVisible(selected.frame.insetBy(dx: -inset, dy: 0), animated: window != nil && !UIAccessibility.isReduceMotionEnabled) }
  }
}
