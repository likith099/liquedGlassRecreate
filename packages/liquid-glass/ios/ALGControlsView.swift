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
  private var lastSize = CGSize.zero
  private var materialKey = ""
  private var lastAppearance: ControlsConfig?
  private var lastSelection: String?
  @objc public var onAction: ((String, String) -> Void)?
  @objc public var onContentSize: ((Double, Double) -> Void)?
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
    let previous = config
    config = next
    if next.mode == "header", window != nil, let coordinator = transitionCoordinator() {
      coordinator.animate(alongsideTransition: { [weak self] _ in self?.apply(); self?.layoutIfNeeded() }, completion: { [weak self] context in
        if context.isCancelled { self?.config = previous; self?.apply() }
        else if UIAccessibility.isVoiceOverRunning, let self, let first = self.config.items.first, let button = self.buttons[first.id] {
          UIAccessibility.post(notification: .layoutChanged, argument: button)
        }
      })
    }
    overrideUserInterfaceStyle = next.colorScheme == "dark" ? .dark : next.colorScheme == "light" ? .light : .unspecified
    apply()
  }
  private func transitionCoordinator() -> UIViewControllerTransitionCoordinator? {
    var responder: UIResponder? = self
    while let current = responder {
      if let controller = current as? UIViewController, let coordinator = controller.transitionCoordinator { return coordinator }
      responder = current.next
    }
    // A stack wrapped by the host is a descendant, not an ancestor in the responder chain.
    func find(_ controller: UIViewController) -> UIViewControllerTransitionCoordinator? {
      if let transition = controller.transitionCoordinator { return transition }
      for child in controller.children { if let transition = find(child) { return transition } }
      return nil
    }
    return window?.rootViewController.flatMap(find)
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
    let keys = Set(config.items.map(\.id))
    for (id, button) in buttons where !keys.contains(id) { button.badgeHost = nil; button.removeFromSuperview(); button.badgeLabel.removeFromSuperview(); buttons.removeValue(forKey: id); lastItems.removeValue(forKey: id) }
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
      if let existing = buttons[item.id] { button = existing }
      else {
        button = ControlButton(type: .system); buttons[item.id] = button; effect.contentView.addSubview(button)
        button.addAction(UIAction { [weak self, weak button] _ in
          guard let self, let button, self.window != nil, self.config.disabled != true,
            let current = self.config.items.first(where: { $0.id == item.id }), current.disabled != true else { return }
          current.icon.pressed(button)
          if current.menu == nil { self.onAction?(item.id, "") }
        }, for: .primaryActionTriggered)
      }
      button.badgeHost = config.mode == "group" ? self : nil
      let selected = config.value == item.id
      if !appearanceChanged, lastItems[item.id] == item,
        (lastSelection == item.id) == selected { continue }
      button.loader.load(item.imageSource) { [weak self] in
        self?.lastItems.removeValue(forKey: item.id); self?.apply()
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
      UIView.performWithoutAnimation {
        button.configuration = appearance
        if morphsContent {
          // UIKit creates the first title label lazily. Lay it out at the current
          // bounds before the frame spring, so it cannot animate from its zero frame
          // or a wrapped title above the button's vertical center.
          button.titleLabel?.numberOfLines = 1
          button.layoutIfNeeded()
        }
      }
      if lastItems[item.id]?.symbol != item.symbol { item.icon.transitionImage(on: button, image: appearance.image) }
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
      if lastItems[item.id]?.menu != item.menu {
        button.menu = item.menu.map { UIMenu(children: menuElements($0, controlID: item.id)) }
        button.showsMenuAsPrimaryAction = item.menu != nil
        if #available(iOS 16.0, *) { button.preferredMenuElementOrder = .fixed }
      }
      lastItems[item.id] = item
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
    let base = CGFloat(config.height ?? 44)
    let font = UIFontMetrics(forTextStyle: .body).scaledValue(for: CGFloat(config.labelSize ?? 17))
    let height = max(base, min(font, 34) + 20)
    let inset = config.mode == "pills" ? CGFloat(config.contentInset ?? 20) : 0
    var x: CGFloat = config.mode == "group" ? 14 : inset
    var trailing = bounds.width - CGFloat(config.contentInset ?? 20)
    for (index, item) in config.items.enumerated() {
      guard let button = buttons[item.id] else { continue }
      let width: CGFloat
      if config.mode == "group" {
        // Ink-to-ink spacing is 35pt; split it across neighbouring hit areas.
        let ink = button.configuration?.image?.size.width ?? 17
        width = max(44, ink + 35)
      } else if item.title == nil { width = config.mode == "pills" ? CGFloat(config.iconCapsuleWidth ?? 49) : base }
      else if config.mode == "pills", let title = item.title {
        // Selection changes font weight, not row geometry. Reserve both weights
        // so this pill's badge and every following pill keep their resting anchor.
        let size = CGFloat(config.labelSize ?? 17)
        let titleWidth = [UIFont.Weight.regular, .semibold].map { weight in
          let font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: .systemFont(ofSize: size, weight: weight), maximumPointSize: size * 2)
          return (title as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        let imageWidth = button.configuration?.image.map { $0.size.width + 6 } ?? 0
        let scale = traitCollection.displayScale
        width = max(base, ceil((titleWidth + imageWidth + CGFloat(config.horizontalPadding ?? 15) * 2) * scale) / scale)
      }
      else { width = max(base, button.sizeThatFits(CGSize(width: 10000, height: height)).width) }
      let old = button.frame
      if config.mode == "header" {
        if item.side == "trailing" { trailing -= width; x = trailing }
        else if index == 0 { x = CGFloat(config.contentInset ?? 20) }
      }
      let ink = button.configuration?.image?.size.width ?? 17
      let target = CGRect(x: config.mode == "group" ? x + (ink - width) / 2 : x, y: 0, width: width, height: height)
      if morphsContent, window != nil, old.width > 0, old != target, !UIAccessibility.isReduceMotionEnabled {
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
    let size = CGSize(width: max(1, x), height: max(44, height))
    if size != lastSize { lastSize = size; onContentSize?(Double(size.width), Double(size.height)) }
    if config.mode == "pills", config.scrollSelectedIntoView != false, let value = config.value, let selected = buttons[value],
      !scroll.bounds.contains(selected.frame) { scroll.scrollRectToVisible(selected.frame.insetBy(dx: -inset, dy: 0), animated: window != nil && !UIAccessibility.isReduceMotionEnabled) }
  }
}
