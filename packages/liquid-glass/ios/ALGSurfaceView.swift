import UIKit

/// Material rendering lives entirely in UIKit. Fabric only supplies props and children.
@objc(ALGSurfaceView)
public final class ALGSurfaceView: UIView {
  private let effectView = UIVisualEffectView()
  private var material = "regular"
  private var interactive = false
  private var glassTint: UIColor?
  private var radius: CGFloat = 24
  private var isContainer = false
  private var mergingEnabled = false
  private var spacing: CGFloat = 20
  private var duration: Double = 0.35
  private var dirty = true
  private var mounted = false
  private var resetInteraction = false

  @objc public var reactContentView: UIView { effectView.contentView }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(effectView)
    NotificationCenter.default.addObserver(self, selector: #selector(accessibilityChanged),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  deinit { NotificationCenter.default.removeObserver(self) }

  @objc public func configure(_ material: String, interactive: Bool, tint: UIColor?,
    radius: CGFloat, container: Bool, mergingEnabled: Bool, spacing: CGFloat, duration: Double, scheme: String) {
    resetInteraction = resetInteraction || self.interactive != interactive || self.isContainer != container || self.mergingEnabled != mergingEnabled
    dirty = dirty || self.material != material || self.interactive != interactive ||
      self.glassTint != tint || self.isContainer != container || self.spacing != spacing || self.mergingEnabled != mergingEnabled
    self.material = material
    self.interactive = interactive
    self.glassTint = tint
    self.radius = max(0, radius)
    self.isContainer = container
    self.mergingEnabled = mergingEnabled
    self.spacing = max(0, spacing)
    self.duration = max(0, duration)
    overrideUserInterfaceStyle = scheme == "dark" ? .dark : scheme == "light" ? .light : .unspecified
    setNeedsLayout()
  }

  @objc private func accessibilityChanged() { dirty = true; setNeedsLayout() }

  public override func didMoveToWindow() {
    super.didMoveToWindow()
    mounted = false
    dirty = true
    setNeedsLayout()
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    effectView.frame = bounds
    if #available(iOS 26.0, *) {
      effectView.cornerConfiguration = .uniformCorners(radius: .fixed(isContainer ? 0 : radius))
    } else {
      effectView.layer.cornerRadius = isContainer ? 0 : radius
      effectView.clipsToBounds = !isContainer
    }
    guard window != nil, bounds.width > 0, bounds.height > 0, dirty else { return }
    dirty = false
    let animate = mounted && !resetInteraction && !UIAccessibility.isReduceMotionEnabled && duration > 0
    if !mounted || resetInteraction { effectView.effect = UIVisualEffect() }
    resetInteraction = false
    mounted = true
    let effect: UIVisualEffect
    if #available(iOS 26.0, *), !UIAccessibility.isReduceTransparencyEnabled {
      if isContainer {
        if mergingEnabled {
          let group = UIGlassContainerEffect()
          group.spacing = spacing
          effect = group
        } else {
          // Keep the children mounted, but remove shared glass compositing.
          effect = UIVisualEffect()
        }
      } else if material != "none" {
        let glass = UIGlassEffect(style: material == "clear" ? .clear : .regular)
        glass.isInteractive = interactive
        glass.tintColor = glassTint
        effect = glass
      } else { effect = UIVisualEffect() }
      effectView.backgroundColor = .clear
    } else if !UIAccessibility.isReduceTransparencyEnabled && !isContainer && material != "none" {
      // Standard system material on pre-glass iOS. Keep the same contentView and
      // dirty-prop gate, so layout/React updates do not allocate another blur.
      effect = UIBlurEffect(style: material == "clear" ? .systemUltraThinMaterial : .systemMaterial)
      effectView.backgroundColor = .clear
      effectView.contentView.backgroundColor = glassTint ?? .clear
    } else {
      effect = UIVisualEffect()
      effectView.backgroundColor = isContainer || material == "none" ? .clear : .secondarySystemBackground
    }
    if #available(iOS 26.0, *) {
      effectView.contentView.backgroundColor = .clear
    } else if UIAccessibility.isReduceTransparencyEnabled || isContainer || material == "none" {
      effectView.contentView.backgroundColor = .clear
    }
    let apply = { self.effectView.effect = effect }
    if animate { UIView.animate(withDuration: duration, animations: apply) } else { apply() }
    effectView.contentView.isUserInteractionEnabled = true
  }
}
