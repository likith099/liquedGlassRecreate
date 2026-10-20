import UIKit

private struct NavigationMenu: Decodable, Equatable {
  var id: String; var title: String; var kind: String?; var subtitle: String?
  var systemImage: String?; var symbol: ALGSymbol?; var imageSource: ALGImageSource?
  var disabled: Bool?; var destructive: Bool?; var checked: Bool?; var items: [NavigationMenu]?
  var singleSelection: Bool?; var keepsMenuPresented: Bool?
}
private struct NavigationAction: Decodable, Equatable {
  var id: String; var label: String?; var testID: String?; var title: String?
  var spacer: String?; var width: Double?; var systemItem: String?; var imageRendering: String?; var imageShape: String?
  var symbol: ALGSymbol?; var imageSource: ALGImageSource?; var tint: Double?
  var disabled: Bool?; var prominent: Bool?; var selected: Bool?; var hidesSharedBackground: Bool?
  var badge: String?; var badgeColor: Double?; var badgeTextColor: Double?; var badgeAccessibility: String?
  var menu: [NavigationMenu]?
}
private struct NavigationScope: Decodable, Equatable { var id: String; var title: String }
private struct NavigationSearch: Decodable, Equatable {
  var value: String; var placeholder: String?; var hidesWhenScrolling: Bool; var eventCount: Int
  var placement: String; var allowsToolbarIntegration: Bool; var active: Bool?
  var scopes: [NavigationScope]?; var scope: String?; var autoCapitalize: String; var returnKeyType: String; var testID: String
}
private struct NavigationFont: Decodable, Equatable { var compactSize: Double; var largeSize: Double; var weight: String? }
private struct NavigationSlot: Decodable, Equatable { var present: Bool; var height: Double }
private struct NavigationConfig: Decodable, Equatable {
  var title: String; var largeTitle: String?; var titleDisplayMode: String; var titlePosition: String
  var titleTransition: String; var titleWeight: String; var titleFont: NavigationFont; var titleTestID: String?
  var subtitle: String?; var largeSubtitle: String?; var slots: [NavigationSlot]; var hasBack: Bool; var manualInsets: Bool
  var leading: [NavigationAction]; var trailing: [NavigationAction]; var toolbar: [NavigationAction]
  var mergingEnabled: Bool; var tint: Double?; var background: Double?
  var colorScheme: String; var topEdge: String; var bottomEdge: String?; var search: NavigationSearch?
}
private final class NavigationScreen: UIViewController {
  var onLayout: (() -> Void)?
  var scheme = "system"
  override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); onLayout?() }
  override func viewSafeAreaInsetsDidChange() { super.viewSafeAreaInsetsDidChange(); onLayout?() }
  override var preferredStatusBarStyle: UIStatusBarStyle { scheme == "dark" ? .lightContent : scheme == "light" ? .darkContent : .default }
}
private final class NavigationSearchController: UISearchController {
  var onLayout: (() -> Void)?
  override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); onLayout?() }
}
private final class NavigationSlotHost: UIView {
  var preferredHeight: CGFloat = 44 { didSet { if oldValue != preferredHeight { invalidateIntrinsicContentSize() } } }
  override init(frame: CGRect) {
    super.init(frame: frame); translatesAutoresizingMaskIntoConstraints = false
    setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
  override var intrinsicContentSize: CGSize { CGSize(width: UIView.layoutFittingExpandedSize.width, height: preferredHeight) }
  override func layoutSubviews() { super.layoutSubviews(); for child in subviews where child.frame != bounds { child.frame = bounds } }
}
@available(iOS 26.0, *)
private final class NavigationEdgeLease {
  weak var edge: UIScrollEdgeEffect?
  let style: UIScrollEdgeEffect.Style
  let hidden: Bool
  var applied: UIScrollEdgeEffect.Style?
  var appliedHidden = false
  init(_ edge: UIScrollEdgeEffect) { self.edge = edge; style = edge.style; hidden = edge.isHidden }
  func apply(_ value: String) { applied = value == "hard" ? .hard : .soft; appliedHidden = value == "hidden"; edge?.style = applied!; edge?.isHidden = appliedHidden }
  func restore() { if edge?.style == applied { edge?.style = style }; if edge?.isHidden == appliedHidden { edge?.isHidden = hidden } }
}

@objc(ALGNavigationView)
public final class ALGNavigationView: UIView, UISearchResultsUpdating, UISearchBarDelegate, UISearchControllerDelegate, UIScrollViewDelegate {
  @objc public let reactContentView = UIView()
  @objc public var onAction: ((String, String) -> Void)?
  @objc public var onSearch: ((String, String, Int) -> Void)?
  @objc public var onInsets: ((Double, Double, Double) -> Void)?
  private let screen = NavigationScreen()
  private var navigation: UINavigationController!
  private var config: NavigationConfig?
  private weak var scroll: UIScrollView?
  private let morph = ALGNavigationTitle()
  private var children: [Int: UIView] = [:]
  private let slotHosts = [NavigationSlotHost(), NavigationSlotHost(), NavigationSlotHost()]
  private let accessoryHost = UIView()
  private let edgeHost = UIView()
  private let edgeMarker = UIImageView()
  private let separator = UIView()
  private var accessoryInteraction: AnyObject?
  private var edgeLeases: [String: AnyObject] = [:]
  private var insetWork: DispatchWorkItem?
  private var reportedInsets: [Double] = []
  private var updatingLayout = false
  private var pendingTop = false
  private var searchController: UISearchController?
  private var applyingSearch = false
  private var pendingActivation = false
  private var pendingSearchRemoval = false
  private var focusOnPresent = false
  private var searchEventCount = 0
  private var lastSearchText = ""
  private var loaders: [String: ALGIconLoader] = [:]
  private var barItems: [String: UIBarButtonItem] = [:]
  private var itemConfigs: [String: NavigationAction] = [:]

  public override init(frame: CGRect) {
    super.init(frame: frame)
    screen.view = reactContentView; screen.definesPresentationContext = true; screen.edgesForExtendedLayout = .all
    navigation = UINavigationController(rootViewController: screen)
    navigation.navigationBar.prefersLargeTitles = true
    // This controller owns one screen. The outer navigator owns back gestures.
    navigation.interactivePopGestureRecognizer?.isEnabled = false
    addSubview(navigation.view)
    let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
    edgeMarker.image = image; edgeMarker.isAccessibilityElement = false
    edgeHost.isUserInteractionEnabled = false; edgeHost.addSubview(edgeMarker)
    separator.isUserInteractionEnabled = false; separator.backgroundColor = .separator
    navigation.navigationBar.insertSubview(edgeHost, at: 0); navigation.view.addSubview(separator)
    screen.onLayout = { [weak self] in self?.layoutChrome() }
    NotificationCenter.default.addObserver(self, selector: #selector(accessibilityChanged), name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(accessibilityChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
  deinit { NotificationCenter.default.removeObserver(self); insetWork?.cancel() }
  @objc public func attach(to parent: UIViewController?) {
    guard let parent, parent !== navigation, navigation.parent !== parent else { return }
    detach(); parent.addChild(navigation)
    if navigation.view.superview !== self { addSubview(navigation.view) }
    navigation.view.frame = bounds; navigation.didMove(toParent: parent)
  }
  @objc public func detach() {
    guard navigation.parent != nil else { return }
    // A navigator can temporarily remove a screen from the window. Preserve its search session.
    navigation.willMove(toParent: nil); navigation.removeFromParent()
  }
  @objc public func setReactChild(_ child: UIView, at index: Int) {
    children[index] = child
    if index == 0 { reactContentView.addSubview(child) }
    else if index < 4 { slotHosts[index - 1].addSubview(child) }
    else { accessoryHost.addSubview(child) }
    applyTitle(); setNeedsLayout()
  }
  @objc public func removeReactChild(_ child: UIView) {
    children = children.filter { $0.value !== child }; child.removeFromSuperview()
  }
  public override func layoutSubviews() { super.layoutSubviews(); if navigation.view.frame != bounds { navigation.view.frame = bounds }; layoutChrome() }
  public override func traitCollectionDidChange(_ previous: UITraitCollection?) {
    super.traitCollectionDidChange(previous)
    if previous?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory || previous?.verticalSizeClass != traitCollection.verticalSizeClass { applyTitle() }
  }
  private func layoutChrome() {
    guard !updatingLayout, let config else { return }
    updatingLayout = true; defer { updatingLayout = false }
    let bar = navigation.navigationBar
    let barFrame = bar.convert(bar.bounds, to: navigation.view)
    let height = config.slots[4].present ? CGFloat(config.slots[4].height) : 0
    let searching = morph.searching
    let titleRow = morph.enabled && !searching ? max(0, morph.row - ((scroll?.contentOffset.y ?? 0) + (scroll?.adjustedContentInset.top ?? 0))) : 0
    // The public search bar includes its scope row. During presentation it can
    // extend below (or replace) the navigation bar, including stacked placement.
    var chromeBottom = navigation.isNavigationBarHidden ? navigation.view.safeAreaInsets.top : barFrame.maxY
    if let searchBar = searchController?.searchBar, searchBar.window != nil, !searchBar.isHidden {
      let searchFrame = searchBar.convert(searchBar.bounds, to: navigation.view)
      // Toolbar-integrated search belongs to the bottom edge, not this header.
      if searchFrame.minY < max(barFrame.maxY, navigation.view.safeAreaInsets.top) + 1 {
        chromeBottom = max(chromeBottom, searchFrame.maxY)
      }
    }
    let accessoryFrame = CGRect(x: screen.view.safeAreaInsets.left, y: chromeBottom + titleRow,
      width: max(0, bounds.width - screen.view.safeAreaInsets.left - screen.view.safeAreaInsets.right), height: height)
    if accessoryHost.superview == nil { navigation.view.addSubview(accessoryHost) }
    accessoryHost.isHidden = height == 0
    if accessoryHost.frame != accessoryFrame { accessoryHost.frame = accessoryFrame }
    for child in accessoryHost.subviews where child.frame != accessoryHost.bounds { child.frame = accessoryHost.bounds }
    if screen.additionalSafeAreaInsets.top != height { screen.additionalSafeAreaInsets.top = height }
    // One continuous edge element spans the whole header (bar, search, title row,
    // accessory). Without it UIKit's band ends at the bar items, above the header's
    // bottom, and content shows between that band and the separator.
    // iOS 26 hosts an expanded native large title inside the scroll view, beneath the
    // edge effect, so a region reaching below it blurs the title (hard style fills a
    // band to the lowest element). While that title shows, content stays below the
    // header, so no extension is needed until the title has collapsed. The morph
    // label is drawn above everything and is unaffected.
    let bottom = accessoryFrame.maxY
    let largeTitleShowing = !morph.enabled && config.titleDisplayMode != "inline" && searchController?.isActive != true
      && !nativeTitleCollapsed(chromeBottom: chromeBottom, accessory: height)
    let extendsEdge = config.topEdge != "hidden" && !largeTitleShowing
    edgeHost.frame = navigation.view.convert(CGRect(x: 0, y: 0, width: bounds.width, height: max(0, bottom)), to: bar)
    edgeMarker.frame = edgeHost.bounds
    edgeHost.isHidden = !extendsEdge
    let pixel = 1 / max(1, window?.screen.scale ?? traitCollection.displayScale)
    separator.frame = CGRect(x: 0, y: (bottom / pixel).rounded() * pixel - pixel, width: bounds.width, height: pixel)
    separator.isHidden = config.topEdge != "hard"
    // Extend the native bar's own edge region. A separate edge interaction can
    // sample UIKit's large title even when its marker is a sibling below the bar.
    navigation.view.bringSubviewToFront(separator)
    navigation.view.bringSubviewToFront(accessoryHost)
    if #available(iOS 26.0, *) {
      // Without an extension UIKit's own bar edge is already correct.
      if extendsEdge, let scroll {
        let interaction = (accessoryInteraction as? UIScrollEdgeElementContainerInteraction) ?? UIScrollEdgeElementContainerInteraction()
        interaction.scrollView = scroll; interaction.edge = .top
        if accessoryInteraction == nil { bar.addInteraction(interaction); accessoryInteraction = interaction }
      } else if let interaction = accessoryInteraction as? UIScrollEdgeElementContainerInteraction {
        bar.removeInteraction(interaction); accessoryInteraction = nil
      }
    }
    morph.headerBottom = chromeBottom
    morph.layout(); scheduleInsets()
    if pendingActivation { activateSearchWhenReady() }
  }
  /// UIKit keeps the scroll view's safe area at the fully expanded header, and a
  /// collapsing native large title raises the header bottom 1:1 with the scroll.
  /// Once the header sits below that line the title has fully collapsed.
  private func nativeTitleCollapsed(chromeBottom: CGFloat, accessory: CGFloat) -> Bool {
    guard let scroll else { return false }
    let expandedBottom = scroll.convert(scroll.bounds.origin, to: navigation.view).y
      + scroll.adjustedContentInset.top - scroll.contentInset.top - accessory
    let scrolled = scroll.contentOffset.y + scroll.adjustedContentInset.top
    return chromeBottom > expandedBottom - scrolled + 0.5
  }
  private var isAtTop: Bool {
    guard let scroll else { return true }
    return scroll.contentOffset.y <= -scroll.adjustedContentInset.top + 1
  }
  /// Re-lays out the header after UIKit chrome changes outside a transition
  /// (search added or removed), animating the bar and keeping a top-anchored list at the top.
  private func relayoutHeader(keepTop: Bool) {
    navigation.navigationBar.setNeedsLayout(); navigation.view.setNeedsLayout()
    let apply = { [weak self] in
      guard let self else { return }
      self.navigation.view.layoutIfNeeded()
      if keepTop, let scroll = self.scroll { scroll.contentOffset.y = -scroll.adjustedContentInset.top }
      self.layoutChrome()
    }
    guard window != nil, !UIAccessibility.isReduceMotionEnabled else { apply(); if keepTop { scrollToTop(false) }; return }
    UIView.animate(withDuration: 0.3, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: apply) { [weak self] _ in
      if keepTop { self?.scrollToTop(false) }
    }
  }
  public override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil, pendingActivation { activateSearchWhenReady() }
  }
  private func scheduleInsets() {
    // Emit settled geometry, never a JS scroll animation stream.
    insetWork?.cancel()
    let work = DispatchWorkItem { [weak self] in
      guard let self, self.window != nil, self.scroll?.isDragging != true, self.scroll?.isDecelerating != true else { return }
      let width = self.config?.slots[1].present == true ? self.slotHosts[0].bounds.width : self.morph.slot.bounds.width
      let next = [Double(self.screen.view.safeAreaInsets.top), Double(self.screen.view.safeAreaInsets.bottom), Double(max(1, width))]
      if next != self.reportedInsets { self.reportedInsets = next; self.onInsets?(next[0], next[1], next[2]) }
    }
    insetWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
  }
  @objc public func bindScrollView(_ view: UIScrollView?) {
    guard scroll !== view else { updateEdge(); return }
    restoreEdges(); morph.bind(nil); scroll = view; screen.setContentScrollView(view, for: .all); morph.bind(view)
    applyTitle(); updateEdge(); layoutChrome()
    #if DEBUG
    if let view, view.contentInsetAdjustmentBehavior != .automatic, config?.manualInsets != true {
      NSLog("[GlassNavigationView] Set contentInsetAdjustmentBehavior=automatic, or use onBarInsetsChange to manage content insets.")
    }
    #endif
  }
  @objc public func scrollToTop(_ animated: Bool) {
    guard let scroll else { return }
    pendingTop = true
    scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: -scroll.adjustedContentInset.top - (morph.enabled ? 0 : 1)), animated: animated && !UIAccessibility.isReduceMotionEnabled)
    if !animated || UIAccessibility.isReduceMotionEnabled { DispatchQueue.main.async { [weak self] in self?.finishTop() } }
  }
  private func finishTop() {
    guard pendingTop, let scroll, !scroll.isDragging else { return }; pendingTop = false
    navigation.view.layoutIfNeeded()
    scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: -scroll.adjustedContentInset.top), animated: false)
  }
  public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { pendingTop = false }
  public func scrollViewDidScroll(_ scrollView: UIScrollView) { layoutChrome() }
  public func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) { layoutChrome() }
  public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) { morph.snap(targetContentOffset) }
  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { scheduleInsets() }
  public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { finishTop(); scheduleInsets() }
  public func scrollViewDidScrollToTop(_ scrollView: UIScrollView) { pendingTop = true; finishTop() }
  @objc public func focusSearch() {
    guard let controller = searchController else { return }
    if controller.isActive { controller.searchBar.becomeFirstResponder() } else { pendingActivation = true; activateSearchWhenReady() }
  }
  @objc public func dismissSearch() { searchController?.isActive = false; searchController?.searchBar.resignFirstResponder() }
  public override func accessibilityPerformEscape() -> Bool {
    guard config?.hasBack == true else { return false }; onAction?("__navigation_back", ""); return true
  }
  private func restoreEdges() {
    if #available(iOS 26.0, *) { for lease in edgeLeases.values { (lease as? NavigationEdgeLease)?.restore() } }
    edgeLeases.removeAll()
  }
  private func updateEdge() {
    if #available(iOS 26.0, *), let config, let scroll {
      // A string controls the top. Own the bottom only for an explicit option or our toolbar.
      let values: [String: String?] = ["top": config.topEdge, "bottom": config.bottomEdge ?? (config.toolbar.isEmpty ? nil : config.topEdge)]
      for (key, value) in values {
        if let value {
          let lease = (edgeLeases[key] as? NavigationEdgeLease) ?? NavigationEdgeLease(key == "top" ? scroll.topEdgeEffect : scroll.bottomEdgeEffect)
          edgeLeases[key] = lease; lease.apply(value)
        } else { (edgeLeases.removeValue(forKey: key) as? NavigationEdgeLease)?.restore() }
      }
    }
  }
  @objc public func configure(_ json: String) {
    guard let next = try? JSONDecoder().decode(NavigationConfig.self, from: Data(json.utf8)), next != config, next.slots.count == 5 else { return }
    let previous = config; config = next
    let wasAtTop = isAtTop
    #if DEBUG
    if previous == nil {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
        if let self, self.window != nil, self.scroll == nil, self.config?.manualInsets != true {
          NSLog("[GlassNavigationView] No scroll view resolved. Supply the mounted list ref; use onBarInsetsChange for a manually inset screen.")
        }
      }
    }
    #endif
    overrideUserInterfaceStyle = next.colorScheme == "dark" ? .dark : next.colorScheme == "light" ? .light : .unspecified
    navigation.overrideUserInterfaceStyle = overrideUserInterfaceStyle; screen.scheme = next.colorScheme; screen.setNeedsStatusBarAppearanceUpdate()
    reactContentView.backgroundColor = next.background.map(ALGIcon.color) ?? .systemBackground
    navigation.view.backgroundColor = reactContentView.backgroundColor
    navigation.navigationBar.tintColor = next.tint.map(ALGIcon.color) ?? .label; navigation.toolbar.tintColor = navigation.navigationBar.tintColor
    if previous?.leading != next.leading || previous?.trailing != next.trailing || previous?.toolbar != next.toolbar || previous?.mergingEnabled != next.mergingEnabled || previous?.tint != next.tint { rebuildActions() }
    if previous?.title != next.title || previous?.largeTitle != next.largeTitle || previous?.titleDisplayMode != next.titleDisplayMode || previous?.titlePosition != next.titlePosition || previous?.titleTransition != next.titleTransition || previous?.titleWeight != next.titleWeight || previous?.titleFont != next.titleFont || previous?.slots != next.slots || previous?.subtitle != next.subtitle || previous?.largeSubtitle != next.largeSubtitle || previous?.titleTestID != next.titleTestID { applyTitle() }
    configureSearch(next.search); updateEdge(); layoutChrome()
    // Switching title presentation at the top must show the expanded title, not the
    // compact one UIKit keeps for an unchanged offset.
    if wasAtTop, let previous, previous.titleTransition != next.titleTransition || previous.titleDisplayMode != next.titleDisplayMode {
      DispatchQueue.main.async { [weak self] in self?.scrollToTop(false) }
    }
  }
  private func applyTitle() {
    guard let config else { return }
    let item = screen.navigationItem, bar = navigation.navigationBar
    item.title = config.title; bar.accessibilityIdentifier = config.titleTransition == "morph" || config.slots[1].present ? nil : config.titleTestID
    slotHosts[0].accessibilityIdentifier = config.titleTestID
    if #available(iOS 16.0, *) { item.style = config.titlePosition == "leading" ? .browser : .navigator }
    let weights: [String: UIFont.Weight] = ["regular": .regular, "medium": .medium, "semibold": .semibold, "bold": .bold]
    let small = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: config.titleFont.compactSize, weight: weights[config.titleFont.weight ?? "semibold"] ?? .semibold), maximumPointSize: config.titleFont.compactSize * 1.16, compatibleWith: traitCollection)
    let large = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: .systemFont(ofSize: config.titleFont.largeSize, weight: weights[config.titleFont.weight ?? "bold"] ?? .bold), compatibleWith: traitCollection)
    for compact in [false, true] {
      let appearance = (compact ? bar.compactAppearance ?? bar.standardAppearance : bar.standardAppearance).copy()
      appearance.titleTextAttributes[.font] = small; appearance.largeTitleTextAttributes[.font] = large
      // The component's boundary follows the whole header, including accessories.
      // Suppress the bar's own shadow so it cannot bisect that region.
      appearance.shadowColor = .clear; appearance.shadowImage = UIImage()
      if compact { bar.compactAppearance = appearance } else { bar.standardAppearance = appearance }
    }
    for appearance in [bar.scrollEdgeAppearance, bar.compactScrollEdgeAppearance].compactMap({ $0 }) {
      appearance.shadowColor = .clear; appearance.shadowImage = UIImage()
    }
    let custom = config.slots[1].present
    let morphing = config.titleTransition == "morph" && !custom
    morph.configure(navigation: navigation, enabled: morphing, display: config.titleDisplayMode,
      text: config.largeTitle ?? config.title, largeFont: large, smallFont: small,
      weight: config.titleWeight == "semibold" ? .semibold : .bold, identifier: config.titleTestID)
    for i in 0..<3 { slotHosts[i].preferredHeight = CGFloat(config.slots[i + 1].height) }
    item.titleView = custom ? slotHosts[0] : morphing ? morph.slot : nil
    if morphing || config.titleDisplayMode == "inline" { item.largeTitleDisplayMode = .never }
    else if #available(iOS 17.0, *), config.titleDisplayMode == "inlineLarge" { item.largeTitleDisplayMode = .inline }
    else { item.largeTitleDisplayMode = .always }
    if #available(iOS 26.0, *) {
      item.largeTitle = config.largeTitle; item.subtitle = config.subtitle; item.largeSubtitle = config.largeSubtitle
      item.subtitleView = config.slots[2].present ? slotHosts[1] : nil
      item.largeSubtitleView = config.slots[3].present ? slotHosts[2] : nil
    }
    setNeedsLayout()
  }
  @objc private func accessibilityChanged() { rebuildActions(); morph.layout(); updateEdge() }
  private func icon(_ symbol: ALGSymbol?, _ source: ALGImageSource?, key: String, original: Bool = false, circle: Bool = false) -> UIImage? {
    let loader = loaders[key] ?? ALGIconLoader(); loaders[key] = loader
    loader.load(source) { [weak self] in self?.rebuildActions(forceImages: true) }
    guard var image = loader.fitted(CGFloat(symbol?.pointSize ?? 24)) else { return symbol?.image(tint: navigation.navigationBar.tintColor) }
    if circle {
      let side = min(image.size.width, image.size.height)
      image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
        UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: side, height: side)).addClip()
        image.draw(at: CGPoint(x: (side - image.size.width) / 2, y: (side - image.size.height) / 2))
      }
    }
    return image.withRenderingMode(original ? .alwaysOriginal : .alwaysTemplate)
  }
  private func menu(_ entries: [NavigationMenu], owner: String, disabled: Bool = false) -> UIMenu {
    UIMenu(children: entries.map { entry -> UIMenuElement in
      let image = icon(entry.symbol ?? entry.systemImage.map { ALGSymbol(name: $0) }, entry.imageSource, key: owner + "/" + entry.id)
      let unavailable = disabled || entry.disabled == true
      if let children = entry.items {
        var options: UIMenu.Options = entry.kind == "section" ? .displayInline : []
        if entry.singleSelection == true { options.insert(.singleSelection) }
        return UIMenu(title: entry.title, image: image, identifier: UIMenu.Identifier(entry.id), options: options, children: menu(children, owner: owner, disabled: unavailable).children)
      }
      return ALGNativeMenu.action(id: entry.id, title: entry.title, subtitle: entry.subtitle, image: image,
        disabled: unavailable, destructive: entry.destructive == true, checked: entry.checked == true, keepsPresented: entry.keepsMenuPresented == true) { [weak self] in self?.onAction?(owner, entry.id) }
    })
  }
  @objc private func activate(_ item: UIBarButtonItem) { if let id = barItems.first(where: { $0.value === item })?.key { onAction?(id, "") } }
  private func barItem(_ entry: NavigationAction, forceImages: Bool) -> UIBarButtonItem {
    let old = itemConfigs[entry.id]
    let item: UIBarButtonItem
    if let existing = barItems[entry.id], old?.systemItem == entry.systemItem, old?.spacer == entry.spacer { item = existing }
    else {
      let systems: [String: UIBarButtonItem.SystemItem] = ["close": .close, "done": .done, "cancel": .cancel, "edit": .edit, "add": .add, "save": .save, "search": .search]
      if entry.spacer != nil { item = UIBarButtonItem(systemItem: entry.spacer == "flexible" ? .flexibleSpace : .fixedSpace) }
      else if let key = entry.systemItem, let system = systems[key] { item = UIBarButtonItem(barButtonSystemItem: system, target: self, action: #selector(activate(_:))) }
      else { item = UIBarButtonItem(title: entry.title, style: .plain, target: self, action: #selector(activate(_:))) }
      barItems[entry.id] = item
    }
    if entry.spacer != nil { item.width = CGFloat(max(0, entry.width ?? 12)); itemConfigs[entry.id] = entry; return item }
    if old?.symbol != entry.symbol || old?.imageSource != entry.imageSource || old?.imageRendering != entry.imageRendering || old?.imageShape != entry.imageShape || old == nil || forceImages {
      let image = icon(entry.symbol, entry.imageSource, key: entry.id, original: entry.imageRendering == "original", circle: entry.imageShape == "circle")
      if entry.systemItem == nil || image != nil { item.image = image }
    }
    if entry.systemItem == nil { item.title = entry.title ?? (item.image == nil ? entry.label : nil) }
    if old?.menu != entry.menu { item.menu = entry.menu.map { menu($0, owner: entry.id) } }
    // UIKit presents a bar item's menu on tap only when it has no target/action; otherwise it requires a long press.
    item.target = item.menu == nil ? self : nil; item.action = item.menu == nil ? #selector(activate(_:)) : nil
    if #available(iOS 26.0, *) { item.style = entry.prominent == true ? .prominent : .plain; item.identifier = entry.id }
    else { item.style = entry.prominent == true ? .done : .plain }
    item.isSelected = entry.selected == true; item.isEnabled = entry.disabled != true; item.tintColor = entry.tint.map(ALGIcon.color)
    item.accessibilityLabel = entry.label; item.accessibilityIdentifier = entry.testID ?? entry.id; item.accessibilityValue = entry.badgeAccessibility ?? entry.badge
    if #available(iOS 16.0, *) { item.preferredMenuElementOrder = .fixed }
    if #available(iOS 26.0, *) {
      item.sharesBackground = config?.mergingEnabled == true; item.hidesSharedBackground = entry.hidesSharedBackground == true
      if old?.badge != entry.badge || old?.badgeColor != entry.badgeColor || old?.badgeTextColor != entry.badgeTextColor {
        if let text = entry.badge { var badge: UIBarButtonItem.Badge = text.isEmpty ? .indicator() : .string(text); badge.backgroundColor = entry.badgeColor.map(ALGIcon.color); badge.foregroundColor = entry.badgeTextColor.map(ALGIcon.color); item.badge = badge }
        else { item.badge = nil }
      }
    }
    itemConfigs[entry.id] = entry; return item
  }
  private func rebuildActions(forceImages: Bool = false) {
    guard let config else { return }
    let left = config.leading.map { barItem($0, forceImages: forceImages) }, right = config.trailing.reversed().map { barItem($0, forceImages: forceImages) }
    if screen.navigationItem.leftBarButtonItems != left { screen.navigationItem.leftBarButtonItems = left }
    if screen.navigationItem.rightBarButtonItems != right { screen.navigationItem.rightBarButtonItems = right }
    var toolbar: [UIBarButtonItem] = []
    let explicitSpacing = config.toolbar.contains { $0.spacer != nil }
    for entry in config.toolbar {
      if !explicitSpacing && !toolbar.isEmpty { let key = "__space_" + entry.id; let spacer = barItems[key] ?? UIBarButtonItem(systemItem: .flexibleSpace); barItems[key] = spacer; toolbar.append(spacer) }
      toolbar.append(barItem(entry, forceImages: forceImages))
    }
    if screen.toolbarItems != toolbar { screen.toolbarItems = toolbar }
    navigation.setToolbarHidden(toolbar.isEmpty, animated: false)
    let used = Set((config.leading + config.trailing + config.toolbar).map(\.id))
    itemConfigs = itemConfigs.filter { used.contains($0.key) }
    barItems = barItems.filter { used.contains($0.key) || $0.key.hasPrefix("__space_") }
  }
  private func removeSearch() {
    guard let controller = searchController else { return }
    // Let UIKit finish the dismissal animation first; removal completes in didDismissSearchController.
    if controller.isActive { pendingSearchRemoval = true; controller.isActive = false; return }
    let keepTop = isAtTop
    pendingSearchRemoval = false; pendingActivation = false
    screen.navigationItem.searchController = nil; searchController = nil; morph.setSearching(false); lastSearchText = ""
    relayoutHeader(keepTop: keepTop)
  }
  private func configureSearch(_ value: NavigationSearch?) {
    guard let value else { removeSearch(); return }
    pendingSearchRemoval = false
    var added = false
    if searchController == nil {
      let controller = NavigationSearchController(searchResultsController: nil)
      controller.obscuresBackgroundDuringPresentation = false; controller.searchResultsUpdater = self; controller.searchBar.delegate = self; controller.delegate = self
      controller.onLayout = { [weak self] in self?.layoutChrome() }
      searchController = controller; screen.navigationItem.searchController = controller; added = true
    }
    guard let controller = searchController else { return }
    if #available(iOS 16.0, *) {
      var placement: UINavigationItem.SearchBarPlacement = .stacked
      if #available(iOS 26.0, *) {
        if value.placement == "integrated" { placement = .integrated }
        if value.placement == "integratedButton" { placement = .integratedButton }
        if value.placement == "integratedCentered" { placement = .integratedCentered }
        screen.navigationItem.searchBarPlacementAllowsToolbarIntegration = value.allowsToolbarIntegration
      }
      screen.navigationItem.preferredSearchBarPlacement = placement
    }
    controller.searchBar.placeholder = value.placeholder
    controller.searchBar.searchTextField.accessibilityIdentifier = value.testID
    controller.searchBar.autocapitalizationType = ["sentences": UITextAutocapitalizationType.sentences, "words": .words, "characters": .allCharacters][value.autoCapitalize] ?? .none
    controller.searchBar.returnKeyType = ["done": UIReturnKeyType.done, "go": .go][value.returnKeyType] ?? .search
    controller.searchBar.scopeButtonTitles = value.scopes?.map(\.title)
    controller.searchBar.selectedScopeButtonIndex = value.scopes?.firstIndex(where: { $0.id == value.scope }) ?? 0
    screen.navigationItem.hidesSearchBarWhenScrolling = value.hidesWhenScrolling
    if value.eventCount >= searchEventCount && controller.searchBar.text != value.value { applyingSearch = true; controller.searchBar.text = value.value; lastSearchText = value.value; applyingSearch = false }
    if value.active == true, !controller.isActive { pendingActivation = true; activateSearchWhenReady() }
    else if value.active == false, controller.isActive { pendingActivation = false; controller.isActive = false }
    // A visible search bar added outside a transition must push the title and list down smoothly.
    if added && value.active != true { relayoutHeader(keepTop: isAtTop) }
  }
  /// UIKit ignores activation before a stacked search bar is in a window, so the
  /// request retries briefly; integrated placements may keep the bar out of the
  /// window until expanded, so the last attempt activates regardless. Requested
  /// activation also focuses the field, matching Android's SearchView.show().
  private var activationScheduled = false
  private var activationAttempts = 0
  private func activateSearchWhenReady() {
    guard window != nil, !activationScheduled else { return }
    activationScheduled = true
    DispatchQueue.main.asyncAfter(deadline: .now() + (activationAttempts == 0 ? 0 : 0.05)) { [weak self] in
      guard let self else { return }
      self.activationScheduled = false
      guard self.pendingActivation, let controller = self.searchController, self.window != nil else { self.activationAttempts = 0; return }
      if controller.searchBar.window == nil && self.activationAttempts < 8 { self.activationAttempts += 1; self.activateSearchWhenReady(); return }
      self.pendingActivation = false; self.activationAttempts = 0
      guard !controller.isActive else { return }
      self.focusOnPresent = true; controller.isActive = true
      // UIKit accepts first responder once activation has started; didPresent retries if it is still refused.
      DispatchQueue.main.async { [weak self] in
        guard let self, let controller = self.searchController, controller.isActive else { return }
        if controller.searchBar.becomeFirstResponder() { self.focusOnPresent = false }
      }
    }
  }
  public func updateSearchResults(for searchController: UISearchController) {
    let text = searchController.searchBar.text ?? ""
    guard !applyingSearch, text != lastSearchText else { return }; lastSearchText = text; searchEventCount += 1; onSearch?("change", text, searchEventCount)
  }
  public func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
    if let scopes = config?.search?.scopes, scopes.indices.contains(selectedScope) { onSearch?("scope", scopes[selectedScope].id, searchEventCount) }
  }
  public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { onSearch?("submit", searchBar.text ?? "", searchEventCount) }
  public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) { searchBar.text = ""; if let searchController { updateSearchResults(for: searchController) }; onSearch?("cancel", "", searchEventCount) }
  private func layoutSearchTransition(_ controller: UISearchController, searching: Bool) {
    let layout = { [weak self] in
      guard let self else { return }
      self.morph.setSearching(searching)
      self.navigation.view.layoutIfNeeded(); self.layoutChrome()
    }
    if let coordinator = controller.transitionCoordinator ?? navigation.transitionCoordinator,
       coordinator.animate(alongsideTransition: { _ in layout() }, completion: { [weak self] _ in self?.layoutChrome() }) { return }
    layout()
  }
  public func willPresentSearchController(_ searchController: UISearchController) {
    onSearch?("focus", searchController.searchBar.text ?? "", searchEventCount)
    layoutSearchTransition(searchController, searching: true)
  }
  public func didPresentSearchController(_ searchController: UISearchController) {
    if focusOnPresent, !searchController.searchBar.searchTextField.isFirstResponder { searchController.searchBar.becomeFirstResponder() }
    focusOnPresent = false
    layoutChrome()
  }
  public func willDismissSearchController(_ searchController: UISearchController) { layoutSearchTransition(searchController, searching: false) }
  public func didDismissSearchController(_ searchController: UISearchController) {
    onSearch?("blur", searchController.searchBar.text ?? "", searchEventCount)
    morph.setSearching(false); layoutChrome()
    if pendingSearchRemoval { removeSearch() }
  }
}
