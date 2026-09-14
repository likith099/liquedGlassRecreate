import UIKit

private struct TabItem: Decodable {
  let id: String
  let title: String
  let icon: String?
  let systemImage: String?
  let selectedSystemImage: String?
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
  init(id: String) { tabID = id; super.init(nibName: nil, bundle: nil) }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func loadView() { view = UIView(); view.backgroundColor = .clear }
}

/// The contained controller owns the native tab bar; React owns the screen above it.
@objc(ALGTabsView)
public final class ALGTabsView: UIView, UITabBarControllerDelegate {
  private let controller = UITabBarController()
  private var destinations: [String: TabDestination] = [:]
  private var items: [TabItem] = []
  private var lastJSON = ""
  private var applying = false
  private var disabled = false
  @objc public var onSelectionChange: ((String) -> Void)?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    controller.delegate = self
    controller.view.backgroundColor = .clear
    controller.customizableViewControllers = []
    if #available(iOS 17.0, *) { controller.traitOverrides.horizontalSizeClass = .compact }
    if #available(iOS 18.0, *) { controller.mode = .tabBar }
    if #available(iOS 26.0, *) { controller.tabBarMinimizeBehavior = .never }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  @objc public func configure(_ json: String, selectedValue: String, disabled: Bool,
    tint: UIColor?, identifier: String) {
    applying = true
    defer { applying = false }
    self.disabled = disabled
    let metadataChanged = json != lastJSON
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
      } else {
        let oldIDs = controller.viewControllers?.compactMap { ($0 as? TabDestination)?.tabID } ?? []
        if oldIDs != ordered.map(\.tabID) {
          controller.setViewControllers(ordered, animated: false)
          controller.customizableViewControllers = []
        }
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
        destination.tabBarItem.title = item.title
        destination.tabBarItem.image = UIImage(systemName: symbol) ?? UIImage(systemName: "circle")
        destination.tabBarItem.selectedImage = item.selectedSystemImage.flatMap { UIImage(systemName: $0) }
        destination.tabBarItem.badgeValue = item.badge?.text
      }
      destination.tabBarItem.isEnabled = !disabled && item.disabled != true
      destination.tabBarItem.accessibilityLabel = item.accessibilityLabel ?? item.title
      destination.tabBarItem.accessibilityIdentifier = identifier.isEmpty ? item.id : "\(identifier)-\(item.id)"
      if #available(iOS 18.4, *), let tab = controller.tab(forIdentifier: item.id) {
        tab.title = item.title
        tab.image = item.id == selectedValue
          ? (destination.tabBarItem.selectedImage ?? destination.tabBarItem.image)
          : destination.tabBarItem.image
        tab.badgeValue = item.badge?.text
        tab.isEnabled = !disabled && item.disabled != true
        tab.preferredPlacement = .fixed
        tab.accessibilityLabel = item.accessibilityLabel ?? item.title
        tab.accessibilityIdentifier = destination.tabBarItem.accessibilityIdentifier
      }
    }
    if #available(iOS 18.4, *) {
      if let selected = controller.tab(forIdentifier: selectedValue), controller.selectedTab !== selected {
        controller.selectedTab = selected
      }
    } else if let selected = destinations[selectedValue], controller.selectedViewController !== selected {
      controller.selectedViewController = selected
    }
    controller.tabBar.tintColor = tint
    controller.tabBar.accessibilityIdentifier = identifier
    controller.view.isHidden = items.isEmpty
    setNeedsLayout()
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
    guard !applying, window != nil, !disabled, controller.tab(forIdentifier: tab.identifier) === tab else { return false }
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
