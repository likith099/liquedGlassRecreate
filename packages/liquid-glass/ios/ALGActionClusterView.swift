import UIKit

private struct GlassAction: Decodable, Equatable {
  let id: String
  let title: String
  let systemImage: String?
  let disabled: Bool?
}

/// The same plain glass-view hierarchy as GlassView. UIKit owns hit testing,
/// localized lighting, and deformation of both the material and its content.
private final class ClusterItem: UIView {
  // Use the native material tint to restrain dark-mode lightness. This shades
  // the whole material, including its resting appearance; UIKit still owns
  // the highlight and deformation. Explicit caller tints take precedence.
  private static let defaultTint = UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor(white: 0, alpha: 0.65) : .clear
  }
  let surface = ALGSurfaceView()
  let icon = UIImageView()
  var onPress: (() -> Void)?
  private var enabled = true
  private var symbol = ""
  private var appliedMaterial: String?
  private var appliedTint: UIColor?
  private var appliedInteractive: Bool?
  private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(activateTap(_:)))

  override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(surface)
    icon.contentMode = .center
    icon.tintColor = .label
    icon.isUserInteractionEnabled = false
    surface.reactContentView.addSubview(icon)
    isAccessibilityElement = true
    accessibilityTraits = .button
    // Observe activation without cancelling or delaying UIKit's glass touches.
    tap.cancelsTouchesInView = false
    tap.delaysTouchesBegan = false
    tap.delaysTouchesEnded = false
    addGestureRecognizer(tap)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  @objc private func activateTap(_ recognizer: UITapGestureRecognizer) {
    guard recognizer.state == .ended, enabled,
      point(inside: recognizer.location(in: self), with: nil) else { return }
    onPress?()
  }
  override func accessibilityActivate() -> Bool {
    guard enabled, !isHidden, isUserInteractionEnabled else { return false }
    onPress?()
    return true
  }
  func configure(symbol: String, title: String, identifier: String, enabled: Bool,
    material: String, tint: UIColor?, interactive: Bool, toggle: Bool = false) {
    if self.symbol != symbol {
      self.symbol = symbol
      let config = UIImage.SymbolConfiguration(pointSize: toggle ? 22 : 20, weight: .medium)
      icon.image = (UIImage(systemName: symbol, withConfiguration: config)
        ?? UIImage(systemName: "circle", withConfiguration: config))?.withRenderingMode(.alwaysTemplate)
    }
    self.enabled = enabled
    tap.isEnabled = enabled
    icon.alpha = enabled ? 1 : 0.4
    accessibilityLabel = title
    accessibilityIdentifier = identifier
    accessibilityTraits = enabled ? .button : [.button, .notEnabled]
    // Match GlassView's native material, without an independent press treatment.
    let responds = interactive && enabled
    let materialTint = tint ?? Self.defaultTint
    if appliedMaterial != material || appliedTint != materialTint || appliedInteractive != responds {
      appliedMaterial = material; appliedTint = materialTint; appliedInteractive = responds
      surface.configure(material, interactive: responds, tint: materialTint, radius: 26,
        container: false, mergingEnabled: false, spacing: 0, duration: 0, scheme: "system")
    }
  }
  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    let dx = point.x - bounds.midX, dy = point.y - bounds.midY
    return dx * dx + dy * dy <= pow(min(bounds.width, bounds.height) / 2, 2)
  }
  override func layoutSubviews() {
    super.layoutSubviews()
    surface.frame = bounds
    icon.bounds = CGRect(origin: .zero, size: bounds.size)
    icon.center = CGPoint(x: bounds.midX, y: bounds.midY)
  }
}

/// Stable UIKit controls and material hosts. Both surfaces and action icons now
/// use ALGSurfaceView; expansion never changes the toggle's material or opacity.
@objc(ALGActionClusterView)
public final class ALGActionClusterView: UIView {
  private let container = ALGSurfaceView()
  private let toggle = ClusterItem()
  private var items: [String: ClusterItem] = [:]
  private var actions: [GlassAction] = []
  private var lastJSON = ""
  private var expanded = false
  private var mergingEnabled = false
  private var spacing: CGFloat = 20
  private var material = "regular"
  private var glassTint: UIColor?
  private var interactive = true
  private var toggleLabel = "Actions"
  private var duration = 0.45
  private var lastSize = CGSize.zero
  private var animationGeneration = 0
  private var configured = false
  @objc public var onAction: ((String) -> Void)?
  @objc public var onExpandedChange: ((Bool) -> Void)?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(container)
    container.reactContentView.addSubview(toggle)
    toggle.onPress = { [weak self] in
      guard let self else { return }
      self.onExpandedChange?(!self.expanded)
    }
    NotificationCenter.default.addObserver(self, selector: #selector(accessibilityChanged),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(accessibilityChanged),
      name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  deinit { NotificationCenter.default.removeObserver(self) }

  @objc public func configure(_ actionsJSON: String, expanded: Bool, mergingEnabled: Bool, spacing: CGFloat,
    tint: UIColor?, material: String, interactive: Bool, duration: Double, toggleLabel: String) {
    var nextActions = actions
    if lastJSON != actionsJSON {
      nextActions = (try? JSONDecoder().decode([GlassAction].self, from: Data(actionsJSON.utf8))) ?? []
      lastJSON = actionsJSON
    }
    let actionsChanged = nextActions != actions
    let groupChanged = !configured || self.mergingEnabled != mergingEnabled || self.spacing != max(0, spacing)
    let appearanceChanged = !configured || self.glassTint != tint || self.material != material || self.interactive != interactive
    let labelChanged = self.toggleLabel != toggleLabel
    let expansionChanged = self.expanded != expanded
    let wasConfigured = configured
    self.expanded = expanded
    self.mergingEnabled = mergingEnabled
    self.spacing = max(0, spacing)
    self.material = material
    self.glassTint = tint
    self.interactive = interactive
    self.duration = duration.isFinite ? max(0, duration) : 0
    self.toggleLabel = toggleLabel
    configured = true

    if actionsChanged {
      let nextIDs = Set(nextActions.map(\.id))
      for id in Array(items.keys) where !nextIDs.contains(id) { items.removeValue(forKey: id)?.removeFromSuperview() }
      for action in nextActions where items[action.id] == nil {
        let item = ClusterItem()
        item.isHidden = true
        item.frame = toggleFrame
        item.onPress = { [weak self] in
          guard let self, self.expanded,
            let current = self.actions.first(where: { $0.id == action.id }), !(current.disabled ?? false) else { return }
          self.onAction?(action.id)
        }
        items[action.id] = item
      }
      actions = nextActions
      container.reactContentView.bringSubviewToFront(toggle)
    }
    if groupChanged {
      container.configure("regular", interactive: false, tint: nil, radius: 0, container: true,
        mergingEnabled: mergingEnabled, spacing: self.spacing, duration: 0, scheme: "system")
    }
    if appearanceChanged || actionsChanged || labelChanged { updateAppearance() }
    toggle.accessibilityValue = expanded ? "Expanded" : "Collapsed"
    if expansionChanged || actionsChanged || groupChanged || !wasConfigured {
      updatePositions(animated: expansionChanged && wasConfigured && !groupChanged && !actionsChanged)
    }
  }

  private func updateAppearance() {
    toggle.configure(symbol: "plus", title: toggleLabel, identifier: "glass-cluster-toggle", enabled: true,
      material: material, tint: glassTint, interactive: interactive, toggle: true)
    for action in actions {
      items[action.id]?.configure(symbol: action.systemImage ?? "circle", title: action.title,
        identifier: "glass-action-" + action.id, enabled: !(action.disabled ?? false),
        material: material, tint: glassTint, interactive: interactive)
    }
  }
  private var toggleFrame: CGRect {
    CGRect(x: bounds.width - 12 - 52, y: (bounds.height - 52) / 2, width: 52, height: 52)
  }
  private func actionFrame(at index: Int) -> CGRect {
    toggleFrame.offsetBy(dx: -CGFloat(actions.count - index) * 64, dy: 0)
  }
  private func updatePositions(animated: Bool) {
    guard bounds.width > 0, bounds.height > 0 else { setNeedsLayout(); return }
    animationGeneration += 1
    let generation = animationGeneration
    let animate = animated && window != nil && duration > 0 && !UIAccessibility.isReduceMotionEnabled
    toggle.frame = toggleFrame
    for (index, action) in actions.enumerated() {
      guard let item = items[action.id] else { continue }
      // Hidden controls cannot receive taps or accessibility focus during collapse.
      item.isUserInteractionEnabled = expanded
      item.accessibilityElementsHidden = !expanded
      if expanded && item.isHidden {
        item.frame = mergingEnabled && animate ? toggleFrame : actionFrame(at: index)
        item.alpha = mergingEnabled || !animate ? 1 : 0
        if item.superview == nil { container.reactContentView.addSubview(item) }
        item.isHidden = false
      }
    }
    container.reactContentView.bringSubviewToFront(toggle)
    let changes = {
      for (index, action) in self.actions.enumerated() {
        guard let item = self.items[action.id] else { continue }
        item.frame = self.mergingEnabled && !self.expanded ? self.toggleFrame : self.actionFrame(at: index)
        item.alpha = self.mergingEnabled || self.expanded ? 1 : 0
      }
      // Rotate only the glyph. The toggle's glass stays at the same bounds/opacity.
      self.toggle.icon.transform = CGAffineTransform(rotationAngle: self.expanded ? .pi / 4 : 0)
    }
    let finish: (Bool) -> Void = { [weak self] _ in
      guard let self, generation == self.animationGeneration else { return }
      for item in self.items.values {
        item.isHidden = !self.expanded
        // Retain identity in the dictionary, but remove collapsed controls from
        // UIKit's hierarchy so accessibility cannot discover hidden actions.
        if !self.expanded { item.removeFromSuperview() }
      }
    }
    if animate {
      UIView.animate(withDuration: duration, delay: 0,
        options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut], animations: changes, completion: finish)
    } else {
      for item in items.values { item.layer.removeAllAnimations() }
      toggle.icon.layer.removeAllAnimations()
      UIView.performWithoutAnimation(changes)
      finish(true)
    }
  }
  @objc private func accessibilityChanged() { updateAppearance(); updatePositions(animated: false) }
  public override func layoutSubviews() {
    super.layoutSubviews()
    container.frame = bounds
    if lastSize != bounds.size { lastSize = bounds.size; updatePositions(animated: false) }
  }
  public override func didMoveToWindow() {
    super.didMoveToWindow()
    updatePositions(animated: false)
  }
}
