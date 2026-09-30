import UIKit

private struct MenuItem: Decodable, Equatable {
  let id: String
  let title: String
  let kind: String?
  let systemImage: String?
  let disabled: Bool?
  let destructive: Bool?
  let checked: Bool?
  let items: [MenuItem]?
  let placement: String?
  var isGroup: Bool { kind == "section" || kind == "submenu" }
}

/// Reports UIKit's own menu presentation and dismissal for the button's menu.
private final class MenuButton: UIButton {
  var onMenuDisplay: (() -> Void)?
  var onMenuEnd: (() -> Void)?
  override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
    willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
    super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
    onMenuDisplay?()
  }
  override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
    willEndFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
    super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
    // Close after UIKit's dismissal completes, so the event follows the morph back.
    if let animator { animator.addCompletion { [weak self] in self?.onMenuEnd?() } } else { onMenuEnd?() }
  }
}

@objc(ALGMenuView)
public final class ALGMenuView: UIView, UIContextMenuInteractionDelegate {
  @objc public let reactContentView = UIView()
  /// With the menu below: an invisible stand-in exactly over the content. UIKit's press-in plays on it
  /// (UIKit enlarges its highlight preview while the finger is down), so the content keeps its size.
  private let pressStandIn = UIView()
  private lazy var contextInteraction = UIContextMenuInteraction(delegate: self)
  private var contextMenu = false
  private var previewCornerRadius: CGFloat = 16
  /// Per-corner preview radii (top left, top right, bottom left, bottom right); a negative value
  /// uses previewCornerRadius.
  @objc public var previewCornerRadii: [NSNumber] = []
  /// "below": the context menu opens below the content, which glides up only as far as the menu
  /// needs (Messages-style); "system": UIKit's default placement around the content in place.
  @objc public var menuPlacement = "system"
  private let button = MenuButton(type: .system)
  private let bar = UIToolbar()
  // iOS 26 glass controls. Kept out of the UIToolbar, which restyles hosted
  // glass buttons; see glassViews(_:).
  private let glassRow = UIStackView()
  private var glassToolbar = false
  private var items: [MenuItem] = []
  private var lastJSON = ""
  private var revision = 0
  private var title = ""
  private var symbol = ""
  private var tint: UIColor?
  private var forceFallback = false
  private var disabled = false
  private var toolbar = false
  private var maxVisibleItems = 3
  private var mergingEnabled = false
  private var identifier = ""
  private var configured = false
  private var needsBarUpdate = true
  private var lastWidth: CGFloat = -1
  private var iconMode = false
  private var symbolPointSize: CGFloat = 17
  private var colorScheme = "system"
  private var iconProminent = false
  private var iconChanged = false
  /// An invisible anchor for GlassMenuPanel: the app positions this view, and UIKit presents the
  /// button's native menu attached to it when the app calls open().
  private var menuAnchor = false
  /// Icon mode without items is a plain button.
  private var isPlainButton: Bool { iconMode && items.isEmpty }
  @objc public var onAction: ((String) -> Void)?
  @objc public var onPress: (() -> Void)?
  @objc public var onMenuOpen: (() -> Void)?
  @objc public var onMenuClose: (() -> Void)?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(button)
    addSubview(bar)
    addSubview(glassRow)
    addSubview(reactContentView)
    pressStandIn.isUserInteractionEnabled = false
    pressStandIn.backgroundColor = .clear
    addSubview(pressStandIn)
    reactContentView.isHidden = true
    reactContentView.addInteraction(contextInteraction)
    bar.isHidden = true
    glassRow.isHidden = true
    glassRow.alignment = .center
    glassRow.translatesAutoresizingMaskIntoConstraints = false
    let inset = glassRow.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor)
    inset.priority = .defaultHigh
    NSLayoutConstraint.activate([
      glassRow.centerXAnchor.constraint(equalTo: centerXAnchor),
      glassRow.centerYAnchor.constraint(equalTo: centerYAnchor), inset])
    button.showsMenuAsPrimaryAction = true
    button.changesSelectionAsPrimaryAction = false
    // Keeping the authored order needs iOS 16; below it UIKit picks the order itself.
    if #available(iOS 16.0, *) { button.preferredMenuElementOrder = .fixed }
    button.titleLabel?.adjustsFontForContentSizeCategory = true
    button.addAction(UIAction { [weak self] _ in
      guard let self, self.isPlainButton, !self.disabled, self.window != nil else { return }
      self.onPress?()
    }, for: .primaryActionTriggered)
    button.onMenuDisplay = { [weak self] in self?.onMenuOpen?() }
    button.onMenuEnd = { [weak self] in self?.onMenuClose?() }
    NotificationCenter.default.addObserver(self, selector: #selector(updateAppearance),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(updateAppearance),
      name: UIContentSizeCategory.didChangeNotification, object: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  deinit { NotificationCenter.default.removeObserver(self) }

  /// Anchor mode; call before configure(...), which applies it.
  @objc public func setMenuAnchor(_ enabled: Bool) {
    iconChanged = iconChanged || menuAnchor != enabled
    menuAnchor = enabled
  }

  /// Icon-mode settings; call before configure(...), which applies them.
  @objc public func setIcon(_ enabled: Bool, pointSize: CGFloat, colorScheme: String, prominent: Bool) {
    let size = pointSize > 0 ? pointSize : 17
    iconChanged = iconChanged || iconMode != enabled || symbolPointSize != size || self.colorScheme != colorScheme ||
      iconProminent != prominent
    iconMode = enabled; symbolPointSize = size; self.colorScheme = colorScheme; iconProminent = prominent
  }

  /// Presents the button's menu as if tapped. UIKit exposes this from iOS 17.4.
  @objc public func openMenu() {
    guard !toolbar, !contextMenu, !isPlainButton, !disabled, !items.isEmpty, window != nil,
      button.isEnabled, button.menu != nil else { return }
    if #available(iOS 17.4, *) { button.performPrimaryAction() }
  }

  @objc public func configure(_ title: String, itemsJSON: String, symbol: String, disabled: Bool,
    tint: UIColor?, forceFallback: Bool, label: String, hint: String, identifier: String,
    toolbar: Bool, maxVisibleItems: Int, mergingEnabled: Bool,
    contextMenu: Bool, previewCornerRadius: CGFloat) {
    let appearanceChanged = !configured || iconChanged || self.title != title || self.symbol != symbol || self.tint != tint || self.forceFallback != forceFallback
    let structureChanged = lastJSON != itemsJSON || self.toolbar != toolbar || self.disabled != disabled ||
      self.maxVisibleItems != maxVisibleItems || self.mergingEnabled != mergingEnabled || self.identifier != identifier ||
      self.contextMenu != contextMenu || self.previewCornerRadius != previewCornerRadius
    self.title = title; self.symbol = symbol; self.tint = tint; self.forceFallback = forceFallback
    self.disabled = disabled; self.toolbar = toolbar; self.maxVisibleItems = maxVisibleItems
    self.mergingEnabled = mergingEnabled; self.identifier = identifier
    self.contextMenu = contextMenu; self.previewCornerRadius = previewCornerRadius
    if lastJSON != itemsJSON {
      lastJSON = itemsJSON
      items = (try? JSONDecoder().decode([MenuItem].self, from: Data(itemsJSON.utf8))) ?? []
    }
    iconChanged = false
    if structureChanged || appearanceChanged {
      revision += 1
      dismissMenus()
      button.menu = isPlainButton ? nil : UIMenu(children: elements(items, revision: revision))
      button.showsMenuAsPrimaryAction = !isPlainButton
      needsBarUpdate = true
    }
    updateVisibility()
    reactContentView.accessibilityIdentifier = contextMenu ? identifier : nil
    reactContentView.isAccessibilityElement = contextMenu && !label.isEmpty
    reactContentView.accessibilityLabel = label
    reactContentView.accessibilityHint = hint.isEmpty ? "Touch and hold for actions" : hint
    reactContentView.accessibilityCustomActions = contextMenu && !disabled ? accessibilityActions(items) : nil
    button.isEnabled = !disabled && (isPlainButton || !items.isEmpty)
    // An anchor is not a control of its own: the app opens its menu, whose items VoiceOver reads.
    button.isAccessibilityElement = !menuAnchor
    button.accessibilityLabel = label.isEmpty ? title : label
    button.accessibilityHint = hint
    button.accessibilityIdentifier = identifier
    bar.accessibilityIdentifier = identifier
    glassRow.accessibilityIdentifier = identifier
    // Keep individual native controls exposed to accessibility.
    bar.isAccessibilityElement = false
    if appearanceChanged { updateAppearance() }
    configured = true
    setNeedsLayout()
  }

  private func accessibilityActions(_ nodes: [MenuItem]) -> [UIAccessibilityCustomAction] {
    nodes.filter { $0.disabled != true }.flatMap { item -> [UIAccessibilityCustomAction] in
      if item.isGroup { return accessibilityActions(item.items ?? []) }
      let version = revision
      return [UIAccessibilityCustomAction(name: item.title) { [weak self] _ in
        guard let self, self.window != nil, !self.disabled, self.revision == version,
          self.enabledAction(item.id, in: self.items) != nil else { return false }
        self.onAction?(item.id)
        return true
      }]
    }
  }

  public func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
    configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
    guard contextMenu, !disabled, !items.isEmpty else { return nil }
    let version = revision
    // "below": UIKit gets a separate preview (a snapshot of the content) and lays it out with the menu
    // itself, the way Messages does: the menu opens below the preview, and the preview glides up only
    // as far as the menu needs (measured on iOS 26.5). The press-in stays on the content, in place.
    // (Moving the targeted preview instead makes it jump at touch-down: UIKit asks for it then.)
    let provider: UIContextMenuContentPreviewProvider? = menuPlacement == "below" ? { [weak self] in
      guard let self, let snapshot = self.reactContentView.snapshotView(afterScreenUpdates: false) else { return nil }
      // UIKit clips the lifted preview to its own continuous corner (about 32 pt, measured on iOS
      // 26.5), which would round a small bubble into a circle. A clear margin sized from the content's
      // own corner radius keeps that clip outside the content, so it keeps its shape.
      let size = self.reactContentView.bounds.size
      let margin = self.previewMargin()
      let host = UIView(frame: CGRect(x: 0, y: 0, width: size.width + 2 * margin, height: size.height + 2 * margin))
      host.backgroundColor = .clear
      snapshot.frame.origin = CGPoint(x: margin, y: margin)
      host.addSubview(snapshot)
      let controller = UIViewController()
      controller.view = host
      controller.preferredContentSize = host.bounds.size
      return controller
    } : nil
    return UIContextMenuConfiguration(identifier: nil, previewProvider: provider) { [weak self] _ in
      guard let self, self.revision == version, !self.disabled else { return nil }
      return UIMenu(children: self.elements(self.items, revision: version))
    }
  }
  /// Clear space around the lifted preview so UIKit's corner clip misses the content's corners:
  /// 10 pt for square content, less as the content's own (smallest) corner radius grows.
  private func previewMargin() -> CGFloat {
    // Only iOS 26 clips the lifted preview this far; earlier versions show their container's
    // background in any margin, so they get none.
    guard #available(iOS 26.0, *) else { return 0 }
    let corners = (0..<4).map { index -> CGFloat in
      let value = index < previewCornerRadii.count ? CGFloat(truncating: previewCornerRadii[index]) : -1
      return value >= 0 ? value : previewCornerRadius
    }
    return max(4, ceil(10 - (corners.min() ?? 0) / 4))
  }

  /// The content as the context menu's preview, in place: the press-in and the return on dismissal.
  /// With the menu below, the return morphs from the lifted preview's padded container; its outline
  /// keeps the same clear margin, so the shrinking clip never cuts into the content.
  private func contentPreview(dismissing: Bool = false) -> UITargetedPreview? {
    guard reactContentView.window != nil else { return nil }
    let parameters = UIPreviewParameters()
    parameters.backgroundColor = .clear
    if dismissing, menuPlacement == "below" {
      let margin = previewMargin()
      parameters.visiblePath = UIBezierPath(roundedRect: reactContentView.bounds.insetBy(dx: -margin, dy: -margin),
        cornerRadius: previewCornerRadius + margin)
    } else {
      parameters.visiblePath = previewPath(in: reactContentView.bounds)
    }
    return UITargetedPreview(view: reactContentView, parameters: parameters)
  }
  /// A rounded rectangle with its own radius per corner, so a grouped bubble keeps its tight
  /// corner while lifted.
  private func previewPath(in rect: CGRect) -> UIBezierPath {
    func radius(_ index: Int) -> CGFloat {
      let value = index < previewCornerRadii.count ? CGFloat(truncating: previewCornerRadii[index]) : -1
      return min(value >= 0 ? value : previewCornerRadius, rect.width / 2, rect.height / 2)
    }
    let (topLeft, topRight, bottomLeft, bottomRight) = (radius(0), radius(1), radius(2), radius(3))
    if topLeft == topRight, topRight == bottomLeft, bottomLeft == bottomRight {
      return UIBezierPath(roundedRect: rect, cornerRadius: topLeft)
    }
    let path = UIBezierPath()
    path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
    path.addArc(withCenter: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight), radius: topRight,
      startAngle: -.pi / 2, endAngle: 0, clockwise: true)
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
    path.addArc(withCenter: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight), radius: bottomRight,
      startAngle: 0, endAngle: .pi / 2, clockwise: true)
    path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
    path.addArc(withCenter: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft), radius: bottomLeft,
      startAngle: .pi / 2, endAngle: .pi, clockwise: true)
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
    path.addArc(withCenter: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft), radius: topLeft,
      startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
    path.close()
    return path
  }
  // The long-press menu's own open and close, like the menu button's.
  public func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
    willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
    // The lifted copy now stands for the content, which is hidden until the copy returns. UIKit fades
    // the copy in over the first frames, so the content fades out over the same time: no gap.
    if menuPlacement == "below" {
      UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
        self.reactContentView.alpha = 0
      }
    }
    onMenuOpen?()
  }
  public func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
    willEndFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
    let finish = { [weak self] in
      guard let self else { return }
      self.reactContentView.alpha = 1
      self.onMenuClose?()
    }
    if let animator { animator.addCompletion(finish) } else { finish() }
  }
  public func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
    previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
    guard menuPlacement == "below" else { return contentPreview() }
    // No press-in scaling: UIKit's press-in plays on the invisible stand-in, without a shadow.
    guard pressStandIn.window != nil else { return nil }
    let parameters = UIPreviewParameters()
    parameters.backgroundColor = .clear
    parameters.visiblePath = UIBezierPath(roundedRect: pressStandIn.bounds, cornerRadius: previewCornerRadius + previewMargin())
    parameters.shadowPath = UIBezierPath()
    return UITargetedPreview(view: pressStandIn, parameters: parameters)
  }
  public func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
    previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
    // The copy returns onto the content, which UIKit shows again when the return finishes.
    if menuPlacement == "below" { reactContentView.alpha = 1 }
    return contentPreview(dismissing: true)
  }

  private func enabledAction(_ id: String, in nodes: [MenuItem]) -> MenuItem? {
    for item in nodes where item.disabled != true {
      if item.isGroup {
        if let found = enabledAction(id, in: item.items ?? []) { return found }
      } else if item.id == id { return item }
    }
    return nil
  }
  private func action(_ item: MenuItem, revision: Int) -> UIAction {
    var attributes: UIMenuElement.Attributes = []
    if item.disabled == true || item.isGroup { attributes.insert(.disabled) }
    if item.destructive == true { attributes.insert(.destructive) }
    return UIAction(title: item.title, image: item.systemImage.flatMap { UIImage(systemName: $0) },
      identifier: UIAction.Identifier(item.id), attributes: attributes, state: item.checked == true ? .on : .off) { [weak self] _ in
      guard let self, self.window != nil, !self.disabled, self.revision == revision,
        self.enabledAction(item.id, in: self.items) != nil else { return }
      self.onAction?(item.id)
    }
  }
  private func elements(_ nodes: [MenuItem], revision: Int) -> [UIMenuElement] {
    nodes.map { item in
      if item.isGroup && item.disabled != true {
        return UIMenu(title: item.title, image: item.systemImage.flatMap { UIImage(systemName: $0) },
          identifier: UIMenu.Identifier(item.id), options: item.kind == "section" ? [.displayInline] : [],
          children: elements(item.items ?? [], revision: revision))
      }
      return action(item, revision: revision)
    }
  }
  @objc private func updateAppearance() {
    if menuAnchor {
      // No title, image or background: only the native menu this button owns is ever seen.
      button.overrideUserInterfaceStyle = .unspecified
      button.configuration = .plain()
      setNeedsLayout()
      return
    }
    if iconMode { applyIconAppearance(); return }
    button.overrideUserInterfaceStyle = .unspecified
    var configuration: UIButton.Configuration
    let appearance = UIToolbarAppearance()
    if #available(iOS 26.0, *), !forceFallback, !UIAccessibility.isReduceTransparencyEnabled {
      configuration = .glass()
      appearance.configureWithDefaultBackground()
      bar.isTranslucent = true
    } else {
      configuration = .tinted()
      appearance.configureWithOpaqueBackground()
      bar.isTranslucent = false
    }
    configuration.title = title
    configuration.image = symbol.isEmpty ? nil : UIImage(systemName: symbol)
    configuration.imagePadding = 8
    configuration.cornerStyle = .capsule
    configuration.buttonSize = .large
    configuration.baseForegroundColor = tint
    button.configuration = configuration
    bar.tintColor = tint
    bar.standardAppearance = appearance
    bar.scrollEdgeAppearance = appearance
    bar.compactAppearance = appearance
    needsBarUpdate = true
    setNeedsLayout()
  }

  /// A round, symbol-only button: glass on iOS 26, gray below it and under Reduce Transparency.
  private func applyIconAppearance() {
    var configuration: UIButton.Configuration
    if #available(iOS 26.0, *), !forceFallback, !UIAccessibility.isReduceTransparencyEnabled {
      configuration = iconProminent ? .prominentGlass() : .glass()
    } else {
      configuration = iconProminent ? .filled() : .gray()
    }
    configuration.image = UIImage(systemName: symbol,
      withConfiguration: UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .medium))
    configuration.title = nil
    configuration.cornerStyle = .capsule
    configuration.contentInsets = .zero
    if iconProminent {
      // Prominent glass takes its colour from the view tint; filled uses the base background.
      configuration.baseForegroundColor = .white
      configuration.baseBackgroundColor = tint
      button.tintColor = tint
    } else {
      configuration.baseForegroundColor = tint ?? .label
      button.tintColor = nil
    }
    button.configuration = configuration
    switch colorScheme {
    case "light": button.overrideUserInterfaceStyle = .light
    case "dark": button.overrideUserInterfaceStyle = .dark
    default: button.overrideUserInterfaceStyle = .unspecified
    }
    setNeedsLayout()
  }

  private func updateBar() {
    guard toolbar, bounds.width > 0, needsBarUpdate || lastWidth != bounds.width else { return }
    dismissMenus()
    needsBarUpdate = false; lastWidth = bounds.width
    let font = UIFont.preferredFont(forTextStyle: .body)
    func width(_ item: MenuItem) -> CGFloat {
      let hasSymbol = item.systemImage.flatMap { UIImage(systemName: $0) } != nil
      return hasSymbol ? 52 : max(52, ceil((item.title as NSString).size(withAttributes: [.font: font]).width) + 40)
    }
    // Reserve overflow space whenever there are hidden items. On narrow layouts,
    // move actions to a native menu instead of clipping or shrinking their labels.
    var visible: [MenuItem] = []
    var used: CGFloat = 0
    let available = max(0, bounds.width - 32)
    for item in items where item.placement != "overflow" {
      let candidate = width(item)
      let needsOverflow = visible.count + 1 < items.count
      if visible.count < maxVisibleItems && used + candidate + (needsOverflow ? 60 : 0) <= available {
        visible.append(item); used += candidate
      }
    }
    let visibleIDs = Set(visible.map(\.id))
    let overflow = items.filter { !visibleIDs.contains($0.id) }
    var controls = visible.map { item in
      BarControl(label: item.title, id: identifier.isEmpty ? item.id : "\(identifier)-\(item.id)",
        image: item.systemImage.flatMap { UIImage(systemName: $0) }, title: item.title,
        menu: item.isGroup ? UIMenu(children: elements(item.items ?? [], revision: revision)) : nil,
        action: item.isGroup ? nil : action(item, revision: revision),
        enabled: !disabled && item.disabled != true, selected: !item.isGroup && item.checked == true,
        destructive: item.destructive == true, width: width(item))
    }
    if !overflow.isEmpty {
      controls.append(BarControl(label: "More actions",
        id: identifier.isEmpty ? "toolbar-overflow" : "\(identifier)-overflow",
        image: UIImage(systemName: "ellipsis"), title: nil,
        menu: UIMenu(children: elements(overflow, revision: revision)), action: nil,
        enabled: !disabled, selected: false, destructive: false, width: 52))
    }
    glassRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
    if #available(iOS 26.0, *), !forceFallback, !UIAccessibility.isReduceTransparencyEnabled {
      glassToolbar = true
      bar.setItems([], animated: false)
      glassRow.spacing = mergingEnabled ? 0 : 12
      glassViews(controls).forEach(glassRow.addArrangedSubview)
    } else {
      glassToolbar = false
      bar.setItems(controls.map(standardBarItem), animated: false)
    }
    updateVisibility()
  }

  private func updateVisibility() {
    let showsToolbar = toolbar && !contextMenu
    button.isHidden = toolbar || contextMenu
    bar.isHidden = !showsToolbar || glassToolbar
    glassRow.isHidden = !showsToolbar || !glassToolbar
    reactContentView.isHidden = !contextMenu
  }

  private struct BarControl {
    let label: String
    let id: String
    let image: UIImage?
    let title: String?
    let menu: UIMenu?
    let action: UIAction?
    let enabled: Bool
    let selected: Bool
    let destructive: Bool
    let width: CGFloat
  }

  private func standardBarItem(_ control: BarControl) -> UIBarButtonItem {
    let item: UIBarButtonItem
    if let menu = control.menu {
      if let image = control.image { item = UIBarButtonItem(image: image, menu: menu) }
      else { item = UIBarButtonItem(title: control.title, menu: menu) }
    } else {
      item = UIBarButtonItem(primaryAction: control.action)
      if item.image != nil { item.title = nil }
      item.isSelected = control.selected
    }
    item.width = control.width
    item.isEnabled = control.enabled
    item.accessibilityLabel = control.label
    item.accessibilityIdentifier = control.id
    if control.destructive { item.tintColor = .systemRed }
    if #available(iOS 16.0, *) { item.preferredMenuElementOrder = .fixed }
    if #available(iOS 26.0, *) {
      item.sharesBackground = mergingEnabled
      item.hidesSharedBackground = forceFallback || UIAccessibility.isReduceTransparencyEnabled
    }
    return item
  }

  // A standalone UIToolbar shows the menu-dismissal morph through a portal
  // inside its hosted item glass. That glass renders opaque until UIKit
  // finishes the morph about a second later. Buttons that own their glass and
  // menu use the direct morph, as GlassMenuButton does. They sit outside the
  // toolbar because it restyles hosted glass (lighter fill, no rim, wider
  // spacing). Visibility and overflow are still decided by updateBar().
  @available(iOS 26.0, *)
  private func glassViews(_ controls: [BarControl]) -> [UIView] {
    guard mergingEnabled, !controls.isEmpty else {
      return controls.map { barButton($0, configuration: .glass()) }
    }
    // Shared glass: one interactive capsule behind plain buttons.
    let effect = UIGlassEffect(style: .regular)
    effect.isInteractive = true
    let capsule = UIVisualEffectView(effect: effect)
    capsule.cornerConfiguration = .capsule()
    let stack = UIStackView(arrangedSubviews: controls.map { barButton($0, configuration: .plain()) })
    stack.spacing = 4
    stack.translatesAutoresizingMaskIntoConstraints = false
    capsule.contentView.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: capsule.contentView.topAnchor),
      stack.bottomAnchor.constraint(equalTo: capsule.contentView.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: capsule.contentView.leadingAnchor, constant: 4),
      stack.trailingAnchor.constraint(equalTo: capsule.contentView.trailingAnchor, constant: -4)])
    return [capsule]
  }

  private func barButton(_ control: BarControl, configuration base: UIButton.Configuration) -> UIButton {
    var configuration = base
    configuration.image = control.image
    configuration.title = control.image == nil ? control.title : nil
    configuration.cornerStyle = .capsule
    configuration.baseForegroundColor = control.destructive ? .systemRed : (tint ?? .label)
    let button = UIButton(configuration: configuration)
    if let menu = control.menu {
      button.menu = menu
      button.showsMenuAsPrimaryAction = true
      if #available(iOS 16.0, *) { button.preferredMenuElementOrder = .fixed }
    } else if let action = control.action {
      // Added rather than passed as primaryAction so the action's title does
      // not replace the symbol-only configuration.
      button.addAction(action, for: .primaryActionTriggered)
    }
    button.isEnabled = control.enabled
    button.isSelected = control.selected
    button.accessibilityLabel = control.label
    button.accessibilityIdentifier = control.id
    button.titleLabel?.adjustsFontForContentSizeCategory = true
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      button.widthAnchor.constraint(equalToConstant: control.image == nil ? control.width : 48),
      button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)])
    return button
  }
  private func dismissMenus() {
    func dismiss(in view: UIView) {
      for interaction in view.interactions {
        (interaction as? UIContextMenuInteraction)?.dismissMenu()
      }
      for child in view.subviews { dismiss(in: child) }
    }
    dismiss(in: self)
  }
  public override func layoutSubviews() {
    super.layoutSubviews()
    // Icon mode fills its square host so capsule corners form a circle.
    // Icon mode and anchors fill their host; the menu attaches to an anchor's exact frame.
    button.frame = iconMode || menuAnchor ? bounds : bounds.insetBy(dx: 4, dy: min(8, bounds.height / 4))
    bar.frame = bounds
    reactContentView.frame = bounds
    // Same frame as the lifted copy's container (content plus its clear margin), so UIKit's hand-over
    // from the stand-in to the copy starts exactly over the content.
    pressStandIn.frame = menuPlacement == "below" ? bounds.insetBy(dx: -previewMargin(), dy: -previewMargin()) : bounds
    updateBar()
  }
  public override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil { dismissMenus() }
  }
}
