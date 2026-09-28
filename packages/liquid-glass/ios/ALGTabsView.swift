import UIKit

/// A React Native image source resolved in JavaScript: a Metro URL in development, a file in the
/// app bundle in release, or any URI the app passes.
private struct TabImageSource: Decodable {
  let uri: String
  let scale: Double
}
private struct TabItem: Decodable {
  let id: String
  let title: String
  let icon: String?
  let systemImage: String?
  let selectedSystemImage: String?
  /// Asset-catalog image names, tried before the SF Symbols.
  let image: String?
  let selectedImage: String?
  let imageSource: TabImageSource?
  let selectedImageSource: TabImageSource?
  /// "template" or "original"; sources default to template, asset names to their catalog setting.
  let imageRenderingMode: String?
  /// ARGB colours from processColor; icons are baked with them and labels use per-item appearance.
  let selectedTint: Double?
  let inactiveTint: Double?
  let badge: Badge?
  let disabled: Bool?
  let accessibilityLabel: String?
  enum Badge: Decodable {
    case number(Int), dot
    init(from decoder: Decoder) throws {
      let value = try decoder.singleValueContainer()
      if let number = try? value.decode(Int.self) { self = .number(number) }
      else if try value.decode(String.self) == "dot" { self = .dot }
      else { throw DecodingError.dataCorruptedError(in: value, debugDescription: "Invalid badge") }
    }
    var text: String {
      switch self { case .dot: return ""; case .number(let number): return number > 999 ? "999+" : String(number) }
    }
  }
}
private final class TabDestination: UIViewController {
  let tabID: String
  // The configured artwork. On the UITab path UIKit writes each tab's image into
  // tabBarItem, so tabBarItem cannot be read back as the source of truth.
  var image: UIImage?
  var selectedImage: UIImage?
  /// Empty when the title is drawn into the images (iOS 26 per-tab colours).
  var displayTitle = ""
  init(id: String) { tabID = id; super.init(nibName: nil, bundle: nil) }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func loadView() { view = UIView(); view.backgroundColor = .clear }
}

/// Artwork from image sources, decoded once per URI and scale and held in memory only; nothing is
/// written to disk. All state is used on the main thread.
private enum TabImageLoader {
  /// Tab artwork larger than this is scaled down to fit, as UIKit does not size tab images.
  static let maximumSide: CGFloat = 30
  private static let cache = NSCache<NSString, UIImage>()
  private static var waiting: [String: [() -> Void]] = [:]
  private static var failed = Set<String>()
  private static func key(_ source: TabImageSource) -> String { "\(source.scale)@\(source.uri)" }
  static func cached(_ source: TabImageSource) -> UIImage? { cache.object(forKey: key(source) as NSString) }
  static func hasFailed(_ source: TabImageSource) -> Bool { failed.contains(key(source)) }
  /// Loads the source once; every caller waiting on it is called back on the main thread.
  static func load(_ source: TabImageSource, completion: @escaping () -> Void) {
    let key = key(source)
    if waiting[key] != nil { waiting[key]?.append(completion); return }
    waiting[key] = [completion]
    let finish: (UIImage?) -> Void = { image in
      DispatchQueue.main.async {
        if let image { cache.setObject(fitted(image), forKey: key as NSString) } else { failed.insert(key) }
        waiting.removeValue(forKey: key)?.forEach { $0() }
      }
    }
    guard let url = URL(string: source.uri), url.scheme != nil else {
      // A bare name, as some release asset setups resolve require() to.
      finish(UIImage(named: source.uri))
      return
    }
    URLSession.shared.dataTask(with: url) { data, response, _ in
      let status = (response as? HTTPURLResponse)?.statusCode ?? 200
      finish(status < 400 ? data.flatMap { UIImage(data: $0, scale: CGFloat(max(source.scale, 1))) } : nil)
    }.resume()
  }
  /// Scales oversized artwork down by raising its scale factor, keeping every pixel.
  private static func fitted(_ image: UIImage) -> UIImage {
    let side = max(image.size.width, image.size.height)
    guard side > maximumSide, let cgImage = image.cgImage else { return image }
    return UIImage(cgImage: cgImage, scale: image.scale * side / maximumSide, orientation: image.imageOrientation)
  }
}

/// The contained controller owns the native tab bar; React owns the screen above it.
@objc(ALGTabsView)
public final class ALGTabsView: UIView, UITabBarControllerDelegate {
  private let controller = UITabBarController()
  private var destinations: [String: TabDestination] = [:]
  private var items: [TabItem] = []
  private var lastJSON = ""
  private var lastTint: UIColor?
  private var lastIdentifier = ""
  private var bakedStyle: UIUserInterfaceStyle?
  private var applying = false
  private var disabled = false
  private var selectedValue = ""
  /// True once UIKit holds exactly the configured UITab list. The legacy
  /// viewControllers array is then never installed over it: one tab model per controller.
  private var usesTabs = false
  @objc public var onSelectionChange: ((String) -> Void)?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    controller.delegate = self
    controller.view.backgroundColor = .clear
    controller.customizableViewControllers = []
    if #available(iOS 17.0, *) { controller.traitOverrides.horizontalSizeClass = .compact }
    if #available(iOS 18.0, *) { controller.mode = .tabBar }
    if #available(iOS 26.0, *) { controller.tabBarMinimizeBehavior = .never }
    else {
      // Without a scroll view UIKit uses the transparent scroll-edge appearance, so the
      // bar would have no background below iOS 26. Use the standard material bar.
      let appearance = UITabBarAppearance()
      appearance.configureWithDefaultBackground()
      controller.tabBar.standardAppearance = appearance
      controller.tabBar.scrollEdgeAppearance = appearance
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  public override func traitCollectionDidChange(_ previous: UITraitCollection?) {
    super.traitCollectionDidChange(previous)
    // Label images are drawn for one appearance; redraw them for the new one.
    guard previous?.userInterfaceStyle != traitCollection.userInterfaceStyle, bakedStyle != nil,
      bakedStyle != traitCollection.userInterfaceStyle else { return }
    reapplyArtwork()
  }
  /// Rebuilds every item's artwork from the last configuration.
  private func reapplyArtwork() {
    guard !lastJSON.isEmpty else { return }
    let json = lastJSON
    lastJSON = ""
    configure(json, selectedValue: selectedValue, disabled: disabled, tint: lastTint, identifier: lastIdentifier)
  }
  /// Tab artwork from an asset name or an image source. A source that is still loading gives a clear
  /// placeholder of the standard size, and the item is rebuilt when it arrives; one that failed gives
  /// nil, so the item falls back to its symbol.
  private func artwork(_ name: String?, _ source: TabImageSource?, rendering: String?) -> UIImage? {
    var image: UIImage?
    if let name {
      image = UIImage(named: name)
    } else if let source {
      if let loaded = TabImageLoader.cached(source) {
        image = loaded
      } else if TabImageLoader.hasFailed(source) {
        return nil
      } else {
        TabImageLoader.load(source) { [weak self] in self?.reapplyArtwork() }
        return Self.placeholder
      }
    }
    switch rendering ?? (source != nil ? "template" : nil) {
    case "template": return image?.withRenderingMode(.alwaysTemplate)
    case "original": return image?.withRenderingMode(.alwaysOriginal)
    default: return image
    }
  }
  private static let placeholder = UIGraphicsImageRenderer(size: CGSize(width: 25, height: 25)).image { _ in }

  @objc public func configure(_ json: String, selectedValue: String, disabled: Bool,
    tint: UIColor?, identifier: String) {
    lastIdentifier = identifier
    applying = true
    defer { applying = false }
    self.disabled = disabled
    self.selectedValue = selectedValue
    // Artwork depends on the bar tint too: selected label images default to it.
    let metadataChanged = json != lastJSON || tint != lastTint
    lastTint = tint
    if metadataChanged {
      lastJSON = json
      items = (try? JSONDecoder().decode([TabItem].self, from: Data(json.utf8))) ?? []
      var next: [String: TabDestination] = [:]
      let ordered = items.map { item -> TabDestination in
        let destination = destinations[item.id] ?? TabDestination(id: item.id)
        next[item.id] = destination
        return destination
      }
      destinations = next
      if #available(iOS 18.4, *) {
        // Modern UIKit owns enabled state on UITab, not the legacy tabBarItem.
        let tabs = ordered.map { destination in
          controller.tabs.first { $0.identifier == destination.tabID } ??
            UITab(title: "", image: nil, identifier: destination.tabID) { _ in destination }
        }
        if controller.tabs.map(\.identifier) != tabs.map(\.identifier) {
          controller.setTabs(tabs, animated: false)
        }
        usesTabs = controller.tabs.map(\.identifier) == ordered.map(\.tabID)
      }
      // UIKit adopts the UITab API from the app's deployment target, not just the running
      // OS, so #available alone can leave an app built for an older target with tabs that
      // UIKit ignores and no view controllers at all. Drive the legacy array only then.
      let currentIDs = controller.viewControllers?.compactMap { ($0 as? TabDestination)?.tabID } ?? []
      if !usesTabs, currentIDs != ordered.map(\.tabID) {
        controller.setViewControllers(ordered, animated: false)
        controller.customizableViewControllers = []
      }
    }
    for item in items {
      guard let destination = destinations[item.id] else { continue }
      if metadataChanged {
        let preset: String
        switch item.icon {
        case "home": preset = "house"
        case "search": preset = "magnifyingglass"
        case "library": preset = "books.vertical"
        case "favorites": preset = "heart"
        case "inbox": preset = "tray"
        case "settings": preset = "gearshape"
        default: preset = "circle"
        }
        let symbol = item.systemImage ?? preset
        let rendering = item.imageRenderingMode
        let image = artwork(item.image, item.imageSource, rendering: rendering) ?? UIImage(systemName: symbol) ??
          UIImage(systemName: "circle")
        let selectedImage = artwork(item.selectedImage, item.selectedImageSource, rendering: rendering) ??
          item.selectedSystemImage.flatMap { UIImage(systemName: $0) }
        let inactiveTint = item.inactiveTint.map(Self.color)
        let selectedTint = item.selectedTint.map(Self.color)
        // Baked colours survive UIKit's selection tint and the iOS 26 drag lens.
        destination.image = Self.baked(image, inactiveTint) ?? image
        destination.selectedImage = Self.baked(selectedImage ?? image, selectedTint) ?? selectedImage
        destination.displayTitle = item.title
        var badgeOffset = UIOffset.zero
        if #available(iOS 26.0, *), selectedTint != nil || inactiveTint != nil, let image {
          // The iOS 26 drag lens paints every text label in the selected tab's colour. The title
          // is drawn in code, at runtime and in memory, into each state's image so the lens shows
          // this tab's own colour; the system title is left empty.
          let normal = Self.labelImage(image, title: item.title, color: inactiveTint ?? .label, traits: traitCollection)
          let selected = Self.labelImage(selectedImage ?? image, title: item.title,
            color: selectedTint ?? tint ?? .tintColor, traits: traitCollection)
          destination.image = normal.image
          destination.selectedImage = selected.image
          destination.displayTitle = ""
          badgeOffset = normal.badgeOffset
          bakedStyle = traitCollection.userInterfaceStyle
        }
        applyItemAppearance(destination.tabBarItem, selected: selectedTint, inactive: inactiveTint, badgeOffset: badgeOffset)
        destination.tabBarItem.title = destination.displayTitle
        destination.tabBarItem.image = destination.image
        destination.tabBarItem.selectedImage = destination.selectedImage
        destination.tabBarItem.badgeValue = item.badge?.text
      }
      // UIKit derives the tab button, its label and its selected trait from the tab itself.
      // Neither UITab nor UITabBarItem declares a public accessibilityTraits property, so
      // isEnabled is the only public control over the disabled state; see docs/accessibility.md.
      let enabled = !disabled && item.disabled != true
      destination.tabBarItem.isEnabled = enabled
      destination.tabBarItem.accessibilityLabel = item.accessibilityLabel ?? item.title
      destination.tabBarItem.accessibilityIdentifier = identifier.isEmpty ? item.id : "\(identifier)-\(item.id)"
      if #available(iOS 18.4, *), usesTabs, let tab = controller.tabs.first(where: { $0.identifier == item.id }) {
        tab.title = destination.displayTitle
        // Always the unselected artwork: UIKit swaps in tabBarItem.selectedImage itself, including
        // under the iOS 26 drag lens. Swapping tab.image here left the selected image showing on
        // a tab the lens had moved away from.
        tab.image = destination.image
        destination.tabBarItem.selectedImage = destination.selectedImage
        tab.badgeValue = item.badge?.text
        tab.isEnabled = enabled
        tab.preferredPlacement = .fixed
        tab.accessibilityLabel = item.accessibilityLabel ?? item.title
        tab.accessibilityIdentifier = destination.tabBarItem.accessibilityIdentifier
      }
    }
    applySelection()
    controller.tabBar.tintColor = tint
    controller.tabBar.accessibilityIdentifier = identifier
    controller.view.isHidden = items.isEmpty
    setNeedsLayout()
  }
  /// Tab bar symbol size, matching UIKit's own rendering of unconfigured symbols in the bar.
  private static let bakedSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular, scale: .large)
  /// An image drawn in `color`. iOS 26 re-tints unselected symbol images even when they are
  /// .alwaysOriginal, so there symbols are rasterized; a bitmap keeps its colour.
  private static func baked(_ image: UIImage?, _ color: UIColor?) -> UIImage? {
    guard let image, let color else { return nil }
    // Original-colour artwork keeps its own colours.
    if !image.isSymbolImage, image.renderingMode == .alwaysOriginal { return image }
    guard #available(iOS 26.0, *), image.isSymbolImage else {
      return image.withTintColor(color, renderingMode: .alwaysOriginal)
    }
    let symbol = image.applyingSymbolConfiguration(bakedSymbolConfiguration) ?? image
    let tinted = symbol.withTintColor(color, renderingMode: .alwaysOriginal)
    let bitmap = UIGraphicsImageRenderer(size: tinted.size).image { _ in tinted.draw(at: .zero) }
    return bitmap.withRenderingMode(.alwaysOriginal)
  }
  /// Icon and title drawn together in one colour for `traits` (appearance and display scale),
  /// entirely in memory; nothing is read from or written to assets. Metrics follow the system
  /// tab item: a 26 pt icon band, a 3 pt gap and the 10 pt medium system label font. The badge
  /// offset moves UIKit's badge from the image's corner back to the icon's corner.
  @available(iOS 26.0, *)
  private static func labelImage(_ icon: UIImage, title: String, color: UIColor,
    traits: UITraitCollection) -> (image: UIImage, badgeOffset: UIOffset) {
    let band: CGFloat = 26, gap: CGFloat = 3
    let font = UIFont.systemFont(ofSize: 10, weight: .medium)
    let glyphSource = icon.isSymbolImage ? (icon.applyingSymbolConfiguration(bakedSymbolConfiguration) ?? icon) : icon
    let textSize = (title as NSString).size(withAttributes: [.font: font])
    let size = CGSize(width: ceil(max(glyphSource.size.width, textSize.width)), height: ceil(band + gap + textSize.height))
    let glyphOrigin = CGPoint(x: (size.width - glyphSource.size.width) / 2, y: (band - glyphSource.size.height) / 2)
    let resolved = color.resolvedColor(with: traits)
    // Original-colour artwork keeps its colours; symbols and template images take the tab colour.
    let glyph = !icon.isSymbolImage && icon.renderingMode == .alwaysOriginal
      ? glyphSource : glyphSource.withTintColor(resolved, renderingMode: .alwaysOriginal)
    let format = UIGraphicsImageRendererFormat(for: traits)
    format.scale = traits.displayScale > 0 ? traits.displayScale : UITraitCollection.current.displayScale
    let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
      glyph.draw(at: glyphOrigin)
      (title as NSString).draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: band + gap),
        withAttributes: [.font: font, .foregroundColor: resolved])
    }.withRenderingMode(.alwaysOriginal)
    return (image, UIOffset(horizontal: -glyphOrigin.x, vertical: glyphOrigin.y))
  }
  private static func color(_ argb: Double) -> UIColor {
    let value = UInt32(truncatingIfNeeded: Int64(argb))
    return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255, alpha: CGFloat((value >> 24) & 0xFF) / 255)
  }
  /// Per-item label and icon colours. The bar's own appearance is copied so the item keeps the
  /// bar's background and glass configuration; only this item's colours change.
  private func applyItemAppearance(_ item: UITabBarItem, selected: UIColor?, inactive: UIColor?, badgeOffset: UIOffset) {
    // Title attributes on the item itself, alongside the per-item appearance below.
    item.setTitleTextAttributes(inactive.map { [.foregroundColor: $0] }, for: .normal)
    item.setTitleTextAttributes(selected.map { [.foregroundColor: $0] }, for: .selected)
    guard selected != nil || inactive != nil else {
      item.standardAppearance = nil
      item.scrollEdgeAppearance = nil
      return
    }
    let appearance = controller.tabBar.standardAppearance.copy()
    for layout in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
      if let selected {
        layout.selected.iconColor = selected
        layout.selected.titleTextAttributes[.foregroundColor] = selected
      }
      if let inactive {
        layout.normal.iconColor = inactive
        layout.normal.titleTextAttributes[.foregroundColor] = inactive
      }
      layout.normal.badgePositionAdjustment = badgeOffset
      layout.selected.badgePositionAdjustment = badgeOffset
    }
    item.standardAppearance = appearance
    item.scrollEdgeAppearance = appearance
  }
  /// Selecting on a controller that is not yet in a parent, or with a tab UIKit does not
  /// hold, asserts inside UIKit's tab model. Selection waits for attachment instead.
  private func applySelection() {
    guard window != nil, controller.parent != nil, !selectedValue.isEmpty else { return }
    let wasApplying = applying
    applying = true
    defer { applying = wasApplying }
    if #available(iOS 18.4, *), usesTabs {
      guard let selected = controller.tabs.first(where: { $0.identifier == selectedValue }) else { return }
      if controller.selectedTab !== selected { controller.selectedTab = selected }
    } else if let selected = destinations[selectedValue],
      controller.viewControllers?.contains(where: { $0 === selected }) == true,
      controller.selectedViewController !== selected {
      controller.selectedViewController = selected
    }
  }
  private func currentItem(_ destination: UIViewController) -> TabItem? {
    guard let tab = destination as? TabDestination, destinations[tab.tabID] === tab else { return nil }
    return items.first { $0.id == tab.tabID }
  }
  public func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
    guard !applying, window != nil, !disabled, let item = currentItem(viewController) else { return false }
    return item.disabled != true
  }
  public func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
    guard !applying, window != nil, !disabled, let item = currentItem(viewController), item.disabled != true else { return }
    onSelectionChange?(item.id)
  }
  @available(iOS 18.0, *)
  public func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
    guard !applying, window != nil, !disabled else { return false }
    return items.contains { $0.id == tab.identifier && $0.disabled != true }
  }
  @available(iOS 18.0, *)
  public func tabBarController(_ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?) {
    guard self.tabBarController(tabBarController, shouldSelectTab: selectedTab) else { return }
    onSelectionChange?(selectedTab.identifier)
  }
  private func attachController() {
    guard window != nil else { return }
    var responder: UIResponder? = superview
    while let current = responder, !(current is UIViewController) { responder = current.next }
    guard let parent = responder as? UIViewController, parent !== controller else { return }
    if controller.parent !== parent {
      detachController()
      parent.addChild(controller)
      addSubview(controller.view)
      controller.didMove(toParent: parent)
      applySelection()
    }
    controller.view.frame = bounds
  }
  private func detachController() {
    guard controller.parent != nil else { return }
    controller.willMove(toParent: nil)
    controller.view.removeFromSuperview()
    controller.removeFromParent()
  }
  public override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil { detachController() }
    else {
      attachController()
      DispatchQueue.main.async { [weak self] in self?.attachController() }
    }
  }
  public override func layoutSubviews() {
    super.layoutSubviews()
    attachController()
    controller.view.frame = bounds
  }
}
