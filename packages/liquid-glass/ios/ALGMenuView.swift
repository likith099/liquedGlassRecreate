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

@objc(ALGMenuView)
public final class ALGMenuView: UIView {
  private let button = UIButton(type: .system)
  private let bar = UIToolbar()
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
  @objc public var onAction: ((String) -> Void)?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(button)
    addSubview(bar)
    bar.isHidden = true
    button.showsMenuAsPrimaryAction = true
    button.changesSelectionAsPrimaryAction = false
    // Keeping the authored order needs iOS 16; below it UIKit picks the order itself.
    if #available(iOS 16.0, *) { button.preferredMenuElementOrder = .fixed }
    button.titleLabel?.adjustsFontForContentSizeCategory = true
    NotificationCenter.default.addObserver(self, selector: #selector(updateAppearance),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(updateAppearance),
      name: UIContentSizeCategory.didChangeNotification, object: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  deinit { NotificationCenter.default.removeObserver(self) }

  @objc public func configure(_ title: String, itemsJSON: String, symbol: String, disabled: Bool,
    tint: UIColor?, forceFallback: Bool, label: String, hint: String, identifier: String,
    toolbar: Bool, maxVisibleItems: Int, mergingEnabled: Bool) {
    let appearanceChanged = !configured || self.title != title || self.symbol != symbol || self.tint != tint || self.forceFallback != forceFallback
    let structureChanged = lastJSON != itemsJSON || self.toolbar != toolbar || self.disabled != disabled ||
      self.maxVisibleItems != maxVisibleItems || self.mergingEnabled != mergingEnabled || self.identifier != identifier
    self.title = title; self.symbol = symbol; self.tint = tint; self.forceFallback = forceFallback
    self.disabled = disabled; self.toolbar = toolbar; self.maxVisibleItems = maxVisibleItems
    self.mergingEnabled = mergingEnabled; self.identifier = identifier
    if lastJSON != itemsJSON {
      lastJSON = itemsJSON
      items = (try? JSONDecoder().decode([MenuItem].self, from: Data(itemsJSON.utf8))) ?? []
    }
    if structureChanged || appearanceChanged {
      revision += 1
      dismissMenus()
      button.menu = UIMenu(children: elements(items, revision: revision))
      needsBarUpdate = true
    }
    button.isHidden = toolbar; bar.isHidden = !toolbar
    button.isEnabled = !disabled && !items.isEmpty
    button.accessibilityLabel = label.isEmpty ? title : label
    button.accessibilityHint = hint
    button.accessibilityIdentifier = identifier
    bar.accessibilityIdentifier = identifier
    // Keep individual native controls exposed to accessibility.
    bar.isAccessibilityElement = false
    if appearanceChanged { updateAppearance() }
    configured = true
    setNeedsLayout()
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
    var controls = visible.map { item -> UIBarButtonItem in
      let control: UIBarButtonItem
      if item.isGroup {
        let menu = UIMenu(children: elements(item.items ?? [], revision: revision))
        if let image = item.systemImage.flatMap({ UIImage(systemName: $0) }) {
          control = UIBarButtonItem(image: image, menu: menu)
        } else { control = UIBarButtonItem(title: item.title, menu: menu) }
      } else {
        control = UIBarButtonItem(primaryAction: action(item, revision: revision))
        if control.image != nil { control.title = nil }
        control.isSelected = item.checked == true
      }
      control.width = width(item)
      control.isEnabled = !disabled && item.disabled != true
      control.accessibilityLabel = item.title
      control.accessibilityIdentifier = identifier.isEmpty ? item.id : "\(identifier)-\(item.id)"
      if item.destructive == true { control.tintColor = .systemRed }
      return control
    }
    if !overflow.isEmpty {
      let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: elements(overflow, revision: revision)))
      more.accessibilityLabel = "More actions"
      more.accessibilityIdentifier = identifier.isEmpty ? "toolbar-overflow" : "\(identifier)-overflow"
      more.isEnabled = !disabled
      more.width = 52
      controls.append(more)
    }
    for control in controls {
      if #available(iOS 16.0, *) { control.preferredMenuElementOrder = .fixed }
      if #available(iOS 26.0, *) {
        control.sharesBackground = mergingEnabled
        control.hidesSharedBackground = forceFallback || UIAccessibility.isReduceTransparencyEnabled
      }
    }
    bar.setItems(controls, animated: false)
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
    button.frame = bounds.insetBy(dx: 4, dy: min(8, bounds.height / 4))
    bar.frame = bounds
    updateBar()
  }
  public override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil { dismissMenus() }
  }
}
