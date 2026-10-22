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
  var topBand: NavigationBand?
}
/// Hard top band (`edgeEffect.band`): `system` keeps UIKit's hard edge.
private struct NavigationBand: Decodable, Equatable {
  var system: Bool?; var color: Double?; var opacity: Double?; var blur: Double?; var progressive: Bool?
  var separator: Double?; var hideSeparator: Bool?
  /// Any field set by the app (older iOS keeps the system bar background otherwise).
  var customized: Bool { color != nil || opacity != nil || blur != nil || progressive != nil }
  var blurStyle: UIBlurEffect.Style? {
    let amount = blur ?? 0.6
    return amount <= 0 ? nil : amount < 0.34 ? .systemThinMaterial : amount < 0.67 ? .systemMaterial : .systemThickMaterial
  }
  /// Default a step lighter than the screen (like system list headers over a black list).
  var tint: UIColor { (color.map(ALGIcon.color) ?? .secondarySystemBackground).withAlphaComponent(1) }
  var tintOpacity: CGFloat { CGFloat(opacity ?? 0.45) }
}
/// The hard band behind the header on iOS 26: the band colour over the content beneath, ending at
/// the header's bottom line. The progressive blur under it is UIKit's own soft scroll edge (see
/// `updateEdge`): a visual effect view cannot be masked into a gradient (any mask turns its blur
/// off on iOS 26), so `progressive: false` uses an unmasked system material instead. The band
/// appears by animating the material (`effect` to and from nil) and the colour layer's alpha; an
/// alpha below 1 on a visual effect view or its ancestors would disable the blur.
private final class NavigationBandView: UIView {
  private let blur = UIVisualEffectView()
  private let tint = UIView()
  private var material: UIVisualEffect?
  private(set) var shown = false
  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    addSubview(blur); addSubview(tint); tint.alpha = 0
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
  func configure(_ band: NavigationBand) {
    let solid = UIAccessibility.isReduceTransparencyEnabled
    material = solid || band.progressive != false ? nil : band.blurStyle.map { UIBlurEffect(style: $0) }
    if shown { blur.effect = material }
    tint.backgroundColor = band.tint.withAlphaComponent(solid ? max(band.tintOpacity, 0.94) : band.tintOpacity)
  }
  func show(_ visible: Bool, animated: Bool) {
    guard visible != shown else { return }
    shown = visible
    let apply = { self.blur.effect = visible ? self.material : nil; self.tint.alpha = visible ? 1 : 0 }
    if animated { UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: apply) } else { apply() }
  }
  override func layoutSubviews() { super.layoutSubviews(); blur.frame = bounds; tint.frame = bounds }
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
  private var separatorShown = false
  private let band = NavigationBandView()
  private var baseAppearances: (standard: UINavigationBarAppearance, compact: UINavigationBarAppearance?)?
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
  private var compactSearchTitleMode: UINavigationItem.LargeTitleDisplayMode?
  private var compactSearchScrollPosition: CGFloat?
  private var searchDismissing = false
  /// Search the app added already active (a search icon). Apps usually remove it after it closes,
  /// so the morph title waits for that removal before reappearing (see `didDismissSearchController`).
  private var transientSearch = false
  private var titleReveal: DispatchWorkItem?
  /// Search whose field is fading out before removal (`removeSearch`).
  private var fadingSearch: UISearchController?
  private var titleRestoreScheduled = false
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
    separator.isUserInteractionEnabled = false; separator.backgroundColor = .separator; separator.alpha = 0
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
    // The morph title row follows a pull past the top unless a refresh control owns that space (see
    // `ALGNavigationTitle.layout`); an accessory below it follows the same way.
    let scrolledBy = (scroll?.contentOffset.y ?? 0) + (scroll?.adjustedContentInset.top ?? 0)
    let titleRow = morph.enabled && !searching ? max(0, morph.row - (scroll?.refreshControl != nil ? max(0, scrolledBy) : scrolledBy)) : 0
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
    morph.headerBottom = chromeBottom
    morph.layout()
    let largeTitleShowing = !morph.enabled && config.titleDisplayMode != "inline" && searchController?.isActive != true
      && !nativeTitleCollapsed(chromeBottom: chromeBottom, accessory: height)
    let extendsEdge = config.topEdge != "hidden" && !largeTitleShowing
    edgeHost.frame = navigation.view.convert(CGRect(x: 0, y: 0, width: bounds.width, height: max(0, bottom)), to: bar)
    edgeMarker.frame = edgeHost.bounds
    edgeHost.isHidden = !extendsEdge
    let pixel = 1 / max(1, window?.screen.scale ?? traitCollection.displayScale)
    separator.frame = CGRect(x: 0, y: (bottom / pixel).rounded() * pixel - pixel, width: bounds.width, height: pixel)
    // Both decorations use the same settled-title state. A morph can still be
    // travelling after content starts passing beneath the header.
    let settled = morph.enabled ? morph.progress >= 1 : (config.titleDisplayMode == "inline" || config.slots[1].present || titleCollapsed)
    let hardVisible = config.topEdge == "hard" && scrolledBy > 0.5 && settled
      && searchController?.isActive != true && !searching
    let showSeparator = hardVisible && config.topBand?.hideSeparator != true
    if showSeparator != separatorShown {
      separatorShown = showSeparator
      let changes = { self.separator.alpha = showSeparator ? 1 : 0 }
      if window != nil && !UIAccessibility.isReduceMotionEnabled {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: changes)
      } else { separator.layer.removeAllAnimations(); changes() }
    }
    separator.backgroundColor = config.topBand?.separator.map(ALGIcon.color) ?? .separator
    if usesBand {
      if band.superview == nil { navigation.view.insertSubview(band, belowSubview: navigation.navigationBar) }
      let frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, bottom))
      if band.frame != frame { band.frame = frame }
      band.show(hardVisible, animated: window != nil && !UIAccessibility.isReduceMotionEnabled)
    } else if band.superview != nil { band.show(false, animated: false); band.removeFromSuperview() }
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
    scheduleInsets()
    if pendingActivation { activateSearchWhenReady() }
  }
  /// Whether UIKit's native large title has fully collapsed into the bar. Decided as a state
  /// change, not per frame: UIKit updates the bar height and the scroll view's adjusted inset in
  /// different scroll callbacks, so a per-frame comparison flips every frame through the collapse
  /// range (the edge effect then flickers over the title), and a pull past the top stretches the
  /// bar further than the content moves.
  private var titleCollapsed = false
  private var compactBarHeight: CGFloat = 0
  private var lastBarHeight: CGFloat = 0
  private func nativeTitleCollapsed(chromeBottom: CGFloat, accessory: CGFloat) -> Bool {
    guard let scroll else { titleCollapsed = false; return false }
    let barHeight = navigation.navigationBar.bounds.height
    let scrolled = scroll.contentOffset.y + scroll.adjustedContentInset.top
    let barSettled = abs(barHeight - lastBarHeight) < 0.25; lastBarHeight = barHeight
    // Pulled past the top (the inset follows the bar, so a collapsing title keeps this near 0).
    if scrolled < -0.5 { titleCollapsed = false; return false }
    if titleCollapsed {
      // The title starts to expand as soon as the bar grows again.
      if barHeight > compactBarHeight + 1 { titleCollapsed = false }
    } else {
      // Collapsing, the header bottom follows the content 1:1 (within the inset lag); once the bar
      // has stopped shrinking the content runs on beneath it.
      let expandedBottom = scroll.convert(scroll.bounds.origin, to: navigation.view).y
        + scroll.adjustedContentInset.top - scroll.contentInset.top - accessory
      if barSettled, chromeBottom > expandedBottom - scrolled + 4 { titleCollapsed = true; compactBarHeight = barHeight }
    }
    return titleCollapsed
  }
  private func preserveCompactSearchTitle() {
    // iOS 26 also reproduces this with a plain UITableViewController: dismissing
    // search re-hides an already-collapsed large title until a later scroll/layout.
    // Keep UIKit's existing compact title through that transition. Restoring the
    // large mode in didDismiss triggers the same second disappearance.
    guard #available(iOS 26.0, *), !morph.enabled, titleCollapsed,
          screen.navigationItem.largeTitleDisplayMode == .always else { return }
    compactSearchTitleMode = screen.navigationItem.largeTitleDisplayMode
    UIView.performWithoutAnimation { screen.navigationItem.largeTitleDisplayMode = .never }
  }
  private func restoreSearchTitleMode() {
    guard let mode = compactSearchTitleMode else { return }
    compactSearchTitleMode = nil; compactSearchScrollPosition = nil
    UIView.performWithoutAnimation {
      screen.navigationItem.largeTitleDisplayMode = mode
      navigation.navigationBar.setNeedsLayout(); navigation.navigationBar.layoutIfNeeded()
    }
  }
  private func restoreSearchTitleAfterScroll() {
    guard compactSearchTitleMode != nil, compactSearchScrollPosition != nil,
          searchController?.isActive != true, !searchDismissing, !titleRestoreScheduled else { return }
    titleRestoreScheduled = true
    // Insets and offsets can update in separate callbacks. Compare their settled
    // sum so keyboard/search inset compensation isn't mistaken for a new scroll.
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }; self.titleRestoreScheduled = false
      guard self.searchController?.isActive != true, !self.searchDismissing,
            let previous = self.compactSearchScrollPosition, let scroll = self.scroll,
            abs(scroll.contentOffset.y + scroll.adjustedContentInset.top - previous) > 0.5 else { return }
      self.restoreSearchTitleMode()
    }
  }
  private var isAtTop: Bool {
    guard let scroll else { return true }
    return scroll.contentOffset.y <= -scroll.adjustedContentInset.top + 1
  }
  /// Re-lays out the header after UIKit chrome changes outside a transition
  /// (search added or removed), animating the bar and keeping a top-anchored list at the top.
  /// Adds or removes the search bar outside a search transition. UIKit collapses an expanded
  /// native large title into the bar when a stacked search bar is installed on a visible screen
  /// (and re-expands it on a later scroll), which showed as a clipped title, two titles at once and
  /// a late expansion (owner device reports); an animated relayout also grew the field from the
  /// leading edge. The change and, at the top, the return to the expanded top happen in one
  /// run-loop turn without animation, so UIKit's intermediate state is never drawn. The result is
  /// then animated from where things were: the list's content slides (a transform on its content,
  /// so the offset UIKit set stays and nothing reads the motion as scrolling), a morph title
  /// slides with it, and an added field or a returning morph title fades in. A removed field has
  /// already faded out (`removeSearch`), so no two of them are drawn on top of each other. Reduce Motion cross-dissolves instead;
  /// `instant` (search about to activate) does not animate, since activation does.
  private enum SearchBarChange { case instant, animated }
  private func changeSearchBar(keepTop: Bool, _ style: SearchBarChange = .animated, _ change: @escaping () -> Void) {
    let update = { [weak self] in
      guard let self else { return }
      UIView.performWithoutAnimation {
        change()
        self.navigation.navigationBar.setNeedsLayout(); self.navigation.view.setNeedsLayout(); self.navigation.view.layoutIfNeeded()
        if keepTop, let scroll = self.scroll {
          // Crossing the top by a point is what makes UIKit expand its large title (see `scrollToTop`).
          scroll.contentOffset.y = -scroll.adjustedContentInset.top - 1; self.navigation.view.layoutIfNeeded()
          scroll.contentOffset.y = -scroll.adjustedContentInset.top; self.navigation.view.layoutIfNeeded()
          self.titleCollapsed = false
        }
        self.layoutChrome()
      }
    }
    guard window != nil, style == .animated else { update(); return }
    guard !UIAccessibility.isReduceMotionEnabled, let scroll else {
      UIView.transition(with: navigation.view, duration: 0.25, options: [.transitionCrossDissolve, .allowUserInteraction], animations: update)
      return
    }
    let label = morph.label, labelShown = morph.enabled && !label.isHidden && label.alpha > 0
    let oldCenter = label.center, oldTransform = label.transform
    let oldContent = scroll.convert(CGPoint.zero, to: navigation.view).y
    let before = searchController
    update()
    let shift = oldContent - scroll.convert(CGPoint.zero, to: navigation.view).y
    let entering = before == nil ? searchController?.searchBar : nil
    // The app's content views; UIKit's own (large title, edge effects, indicators) stay put.
    let content = scroll.subviews.filter { !String(describing: type(of: $0)).hasPrefix("_") && !($0 is UIRefreshControl) }
    content.forEach { $0.transform = CGAffineTransform(translationX: 0, y: shift) }
    let showsLabel = morph.enabled && !label.isHidden, newCenter = label.center, newTransform = label.transform
    if showsLabel { if labelShown { label.center = oldCenter; label.transform = oldTransform } else { label.alpha = 0 } }
    entering?.alpha = 0
    let fadeIn = labelShown ? nil : (showsLabel ? label : nil)
    // The list clears the field's area early (ease out); what arrives fades in once it has.
    UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut, .allowUserInteraction], animations: {
      content.forEach { $0.transform = .identity }
      if showsLabel { label.center = newCenter; label.transform = newTransform }
    }, completion: { _ in content.forEach { $0.transform = .identity } })
    UIView.animate(withDuration: 0.2, delay: 0.15, options: [.curveEaseOut, .allowUserInteraction], animations: {
      fadeIn?.alpha = 1; entering?.alpha = 1
    }, completion: { _ in fadeIn?.alpha = 1; entering?.alpha = 1 })
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
    restoreSearchTitleMode()
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
    restoreSearchTitleMode()
    pendingTop = true
    scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: -scroll.adjustedContentInset.top - (morph.enabled ? 0 : 1) - collapsedLargeTitleRow), animated: animated && !UIAccessibility.isReduceMotionEnabled)
    if !animated || UIAccessibility.isReduceMotionEnabled { DispatchQueue.main.async { [weak self] in self?.finishTop() } }
  }
  /// Before iOS 26, a scroll to the compact top leaves a collapsed large title collapsed (the
  /// status-bar tap scrolls past it instead). The row to reveal when the native large title is
  /// collapsed; the same row height the morph title reserves to match UIKit's.
  private var collapsedLargeTitleRow: CGFloat {
    guard #unavailable(iOS 26.0), !morph.enabled, screen.navigationItem.largeTitleDisplayMode == .always,
          navigation.traitCollection.verticalSizeClass != .compact else { return 0 }
    let bar = navigation.navigationBar
    var height = bar.bounds.height
    if let search = searchController?.searchBar, search.window != nil, !search.isHidden, search.isDescendant(of: bar) { height -= search.bounds.height }
    let font = bar.standardAppearance.largeTitleTextAttributes[.font] as? UIFont ?? .preferredFont(forTextStyle: .largeTitle)
    let row = ceil(font.lineHeight + 11)
    return height < 44 + row / 2 ? row : 0
  }
  private func finishTop() {
    guard pendingTop, let scroll, !scroll.isDragging else { return }; pendingTop = false
    navigation.view.layoutIfNeeded()
    scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: -scroll.adjustedContentInset.top), animated: false)
    // At the top the title is expanded; UIKit can finish growing the bar after the last scroll callback.
    titleCollapsed = false; layoutChrome()
  }
  public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    pendingTop = false
    if searchController?.isActive != true, !searchDismissing { restoreSearchTitleMode() }
  }
  public func scrollViewDidScroll(_ scrollView: UIScrollView) { layoutChrome(); restoreSearchTitleAfterScroll() }
  public func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) { layoutChrome() }
  public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) { morph.snap(targetContentOffset) }
  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { scheduleInsets() }
  public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { finishTop(); scheduleInsets() }
  public func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool { restoreSearchTitleMode(); return true }
  public func scrollViewDidScrollToTop(_ scrollView: UIScrollView) { pendingTop = true; finishTop() }
  @objc public func focusSearch() {
    guard let controller = searchController else { return }
    if controller.isActive { controller.searchBar.becomeFirstResponder() } else { pendingActivation = true; activateSearchWhenReady() }
  }
  @objc public func dismissSearch() { searchController?.isActive = false; searchController?.searchBar.resignFirstResponder() }
  public override func accessibilityPerformEscape() -> Bool {
    guard config?.hasBack == true else { return false }; onAction?("__navigation_back", ""); return true
  }
  /// iOS 26 hard edge drawn by the package's band (not `band: 'system'`).
  private var usesBand: Bool {
    guard #available(iOS 26.0, *), let config else { return false }
    return config.topEdge == "hard" && config.topBand?.system != true
  }
  private func restoreEdges() {
    if #available(iOS 26.0, *) { for lease in edgeLeases.values { (lease as? NavigationEdgeLease)?.restore() } }
    edgeLeases.removeAll()
  }
  private func updateEdge() {
    band.configure(config?.topBand ?? NavigationBand())
    if #available(iOS 26.0, *), let config, let scroll {
      // A string controls the top. Own the bottom only for an explicit option or our toolbar.
      // The package's band replaces UIKit's hard top edge: beneath it UIKit's soft edge gives the
      // progressive blur (none for `blur: 0`; a uniform material for `progressive: false`).
      let bandEdge = (config.topBand?.blur ?? 0.6) <= 0 || config.topBand?.progressive == false || UIAccessibility.isReduceTransparencyEnabled ? "hidden" : "soft"
      let values: [String: String?] = ["top": usesBand ? bandEdge : config.topEdge, "bottom": config.bottomEdge ?? (config.toolbar.isEmpty ? nil : config.topEdge)]
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
    if previous?.title != next.title || previous?.largeTitle != next.largeTitle || previous?.titleDisplayMode != next.titleDisplayMode || previous?.titlePosition != next.titlePosition || previous?.titleTransition != next.titleTransition || previous?.titleWeight != next.titleWeight || previous?.titleFont != next.titleFont || previous?.slots != next.slots || previous?.subtitle != next.subtitle || previous?.largeSubtitle != next.largeSubtitle || previous?.titleTestID != next.titleTestID || previous?.topBand != next.topBand || previous?.topEdge != next.topEdge { applyTitle() }
    configureSearch(next.search); updateEdge(); layoutChrome()
    // Switching title presentation at the top must show the expanded title, not the
    // compact one UIKit keeps for an unchanged offset.
    if wasAtTop, let previous, previous.titleTransition != next.titleTransition || previous.titleDisplayMode != next.titleDisplayMode {
      DispatchQueue.main.async { [weak self] in self?.scrollToTop(false) }
    }
  }
  private func applyTitle() {
    guard let config else { return }
    // An explicit title/mode/typography change supersedes the saved native mode.
    compactSearchTitleMode = nil; compactSearchScrollPosition = nil
    let item = screen.navigationItem, bar = navigation.navigationBar
    item.title = config.title; bar.accessibilityIdentifier = config.titleTransition == "morph" || config.slots[1].present ? nil : config.titleTestID
    slotHosts[0].accessibilityIdentifier = config.titleTestID
    if #available(iOS 16.0, *) { item.style = config.titlePosition == "leading" ? .browser : .navigator }
    let weights: [String: UIFont.Weight] = ["regular": .regular, "medium": .medium, "semibold": .semibold, "bold": .bold]
    let small = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: config.titleFont.compactSize, weight: weights[config.titleFont.weight ?? "semibold"] ?? .semibold), maximumPointSize: config.titleFont.compactSize * 1.16, compatibleWith: traitCollection)
    let large = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: .systemFont(ofSize: config.titleFont.largeSize, weight: weights[config.titleFont.weight ?? "bold"] ?? .bold), compatibleWith: traitCollection)
    // Derived from the bar's appearances as first seen, so removing a band restores them.
    if baseAppearances == nil { baseAppearances = (bar.standardAppearance.copy(), bar.compactAppearance?.copy()) }
    let base = baseAppearances!
    for compact in [false, true] {
      let appearance = (compact ? base.compact ?? base.standard : base.standard).copy()
      appearance.titleTextAttributes[.font] = small; appearance.largeTitleTextAttributes[.font] = large
      // Before iOS 26 a styled hard band is the bar's own background (iOS 26 draws `band`).
      if #unavailable(iOS 26.0), config.topEdge == "hard", let band = config.topBand, band.system != true, band.customized {
        appearance.backgroundEffect = UIAccessibility.isReduceTransparencyEnabled ? nil : band.blurStyle.map { UIBlurEffect(style: $0) }
        appearance.backgroundColor = band.tint.withAlphaComponent(UIAccessibility.isReduceTransparencyEnabled ? max(band.tintOpacity, 0.94) : band.tintOpacity)
      }
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
  @objc private func accessibilityChanged() { rebuildActions(); morph.layout(); updateEdge(); applyTitle() }
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
    pendingSearchRemoval = false; pendingActivation = false; transientSearch = false
    titleReveal?.cancel(); titleReveal = nil
    // The field fades out before the header closes over it (a snapshot would lose its glass).
    let bar = controller.searchBar
    if window != nil, bar.window != nil, bar.alpha > 0, !UIAccessibility.isReduceMotionEnabled {
      guard fadingSearch !== controller else { return }
      fadingSearch = controller
      UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseIn], animations: { bar.alpha = 0 }) { [weak self] _ in
        guard let self, self.fadingSearch === controller else { return }
        self.fadingSearch = nil; self.removeSearch()
      }
      return
    }
    fadingSearch = nil
    let keepTop = isAtTop
    changeSearchBar(keepTop: keepTop) {
      self.screen.navigationItem.searchController = nil; self.searchController = nil; self.morph.setSearching(false); self.lastSearchText = ""
    }
  }
  private func configureSearch(_ value: NavigationSearch?) {
    guard let value else { removeSearch(); return }
    pendingSearchRemoval = false
    // Search came back while its field was fading out: keep it.
    if let fading = fadingSearch { fadingSearch = nil; fading.searchBar.layer.removeAllAnimations(); fading.searchBar.alpha = 1 }
    var added = false
    if searchController == nil {
      let controller = NavigationSearchController(searchResultsController: nil)
      controller.obscuresBackgroundDuringPresentation = false; controller.searchResultsUpdater = self; controller.searchBar.delegate = self; controller.delegate = self
      controller.onLayout = { [weak self] in self?.layoutChrome() }
      searchController = controller; added = true
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
    // A visible search bar added outside a transition must push the list down, title unchanged.
    // Added already active (a search icon), it is installed and activated in the same run-loop
    // turn: no frame shows the inactive field (or a title over it), and UIKit animates the
    // activation from the expanded header.
    if added, value.active == true {
      transientSearch = true
      changeSearchBar(keepTop: isAtTop, .instant) { self.screen.navigationItem.searchController = controller }
      if controller.searchBar.window != nil { activateSearch(controller) }
    } else if added { changeSearchBar(keepTop: isAtTop) { self.screen.navigationItem.searchController = controller } }
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
      self.activateSearch(controller)
    }
  }
  private func activateSearch(_ controller: UISearchController) {
    pendingActivation = false; activationAttempts = 0
    guard !controller.isActive else { return }
    focusOnPresent = true; controller.isActive = true
    // UIKit accepts first responder once activation has started; didPresent retries if it is still refused.
    DispatchQueue.main.async { [weak self] in
      guard let self, let controller = self.searchController, controller.isActive else { return }
      if controller.searchBar.becomeFirstResponder() { self.focusOnPresent = false }
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
    compactSearchScrollPosition = nil; searchDismissing = false
    preserveCompactSearchTitle()
    onSearch?("focus", searchController.searchBar.text ?? "", searchEventCount)
    layoutSearchTransition(searchController, searching: true)
  }
  public func didPresentSearchController(_ searchController: UISearchController) {
    if focusOnPresent, !searchController.searchBar.searchTextField.isFirstResponder { searchController.searchBar.becomeFirstResponder() }
    focusOnPresent = false
    layoutChrome()
  }
  public func willDismissSearchController(_ searchController: UISearchController) {
    searchDismissing = true
    preserveCompactSearchTitle()
    // A morph title would appear below the returning field and then move when the app removes
    // the search: for a search opened by the app, it stays hidden until then.
    layoutSearchTransition(searchController, searching: morph.enabled && transientSearch)
  }
  public func didDismissSearchController(_ searchController: UISearchController) {
    onSearch?("blur", searchController.searchBar.text ?? "", searchEventCount)
    if morph.enabled, transientSearch, !pendingSearchRemoval {
      // Usually the app removes the search now (`onActiveChange`); `removeSearch` then shows the
      // title in its final place. If the search stays, the title fades in below it.
      let reveal = DispatchWorkItem { [weak self] in
        guard let self, self.searchController?.isActive == false, self.morph.searching else { return }
        self.transientSearch = false; self.titleReveal = nil
        self.changeSearchBar(keepTop: self.isAtTop) { self.morph.setSearching(false) }
      }
      titleReveal?.cancel(); titleReveal = reveal
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: reveal)
    } else { morph.setSearching(false) }
    layoutChrome()
    searchDismissing = false
    if compactSearchTitleMode != nil, let scroll { compactSearchScrollPosition = scroll.contentOffset.y + scroll.adjustedContentInset.top }
    if pendingSearchRemoval { removeSearch() }
  }
}
