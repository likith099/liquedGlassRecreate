import UIKit

/// UIKit measures the available title space; the visible raster lives above the bar.
final class ALGNavigationTitleSlot: UIView {
  let placeholder = UILabel()
  var onFrameChange: (() -> Void)?
  private var lastFrame: CGRect?
  override init(frame: CGRect) {
    super.init(frame: frame)
    translatesAutoresizingMaskIntoConstraints = false
    setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    placeholder.textColor = .clear; placeholder.isAccessibilityElement = false
    addSubview(placeholder); isAccessibilityElement = true; accessibilityTraits = .header
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
  override var intrinsicContentSize: CGSize { CGSize(width: UIView.layoutFittingExpandedSize.width, height: 44) }
  override func layoutSubviews() {
    super.layoutSubviews()
    if placeholder.frame != bounds { placeholder.frame = bounds }
    let frame = window.map { convert(bounds, to: $0) }
    if frame != lastFrame { lastFrame = frame; onFrameChange?() }
  }
}

/// Single-raster title morph, adapted from the owner's reviewed UIKit probe.
/// Only transform and fractional center change on the scroll path. No JS events or font animation.
final class ALGNavigationTitle {
  let slot = ALGNavigationTitleSlot()
  let label = UILabel()
  weak var navigation: UINavigationController?
  weak var scroll: UIScrollView?
  var display = "large"
  var enabled = false
  private var largeSize: CGFloat = 34, smallSize: CGFloat = 17
  private var fit = CGSize.zero
  private(set) var row: CGFloat = 0
  private var installedInset: CGFloat = 0
  private var changingInset = false
  private(set) var searching = false
  /// Bottom of the header chrome above the title row (the bar, or a visible stacked search bar).
  var headerBottom: CGFloat = 0
  #if DEBUG
  private var auditStarted = false
  private var auditRows: [[String: Double]] = []
  private var auditTimer: Timer?
  private var auditPasses = 0
  #endif
  private var compactHeight: Bool { navigation?.traitCollection.verticalSizeClass == .compact }
  init() {
    label.numberOfLines = 1; label.lineBreakMode = .byTruncatingTail
    label.isAccessibilityElement = false; label.isUserInteractionEnabled = false; label.textColor = .label
    slot.onFrameChange = { [weak self] in self?.layout() }
  }
  func bind(_ target: UIScrollView?) {
    guard target !== scroll else { return }
    removeInset(); scroll = target; reserveRow()
  }
  func configure(navigation: UINavigationController, enabled: Bool, display: String, text: String,
                 largeFont: UIFont, smallFont: UIFont, weight: UIFont.Weight, identifier: String?) {
    self.navigation = navigation; self.enabled = enabled; self.display = display
    largeSize = largeFont.pointSize; smallSize = min(largeSize, smallFont.pointSize)
    let font = UIFont.systemFont(ofSize: largeSize, weight: weight)
    if label.text != text || label.font != font { label.text = text; label.font = font; fit = text.size(withAttributes: [.font: font]) }
    slot.placeholder.text = text; slot.placeholder.font = smallFont
    slot.accessibilityLabel = text; slot.accessibilityIdentifier = identifier
    row = enabled && display == "large" && !compactHeight ? ceil(largeFont.lineHeight + 11) : 0
    reserveRow()
    if enabled {
      if label.superview !== navigation.view { navigation.view.addSubview(label) }
    } else { label.removeFromSuperview() }
    layout()
  }
  private func reserveRow() {
    let wanted = searching ? 0 : row
    guard let scroll, !changingInset, installedInset != wanted else { return }
    let atTop = scroll.contentOffset.y <= -scroll.adjustedContentInset.top + 0.5
    changingInset = true
    var inset = scroll.contentInset; inset.top += wanted - installedInset; installedInset = wanted
    scroll.contentInset = inset
    if atTop { scroll.contentOffset.y = -scroll.adjustedContentInset.top }
    changingInset = false
  }
  func setSearching(_ value: Bool) {
    searching = value; reserveRow(); layout()
  }
  func removeInset() {
    if let scroll, installedInset != 0 { var inset = scroll.contentInset; inset.top -= installedInset; installedInset = 0; scroll.contentInset = inset }
  }
  private struct Geometry { var dock: CGPoint; var start: CGPoint; var width: CGFloat; var largeWidth: CGFloat; var band: CGFloat; var rtl: Bool }
  private func geometry() -> Geometry? {
    guard enabled, let navigation, slot.window != nil, slot.bounds.width > 0 else { return nil }
    let bar = navigation.navigationBar, view = navigation.view!
    let barFrame = bar.convert(bar.bounds, to: view), space = slot.convert(slot.bounds, to: view)
    let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
    let margin = max(16, bar.directionalLayoutMargins.leading)
    let dock = CGPoint(x: rtl ? space.maxX : space.minX, y: space.midY)
    let below = display == "large" && !compactHeight
    let start = below ? CGPoint(x: rtl ? barFrame.maxX - margin : barFrame.minX + margin, y: max(barFrame.maxY, headerBottom) + row / 2) : dock
    return Geometry(dock: dock, start: start, width: space.width,
      largeWidth: below ? barFrame.width - 2 * margin : space.width,
      band: below ? max(1, start.y - dock.y) : 44, rtl: rtl)
  }
  func layout() {
    guard !searching, let g = geometry(), let navigation, let scroll, navigation.topViewController?.presentedViewController == nil else { label.isHidden = true; return }
    label.isHidden = false
    #if DEBUG
    auditPasses += 1
    if !auditStarted && ProcessInfo.processInfo.arguments.contains("-ALGNavigationAudit") {
      auditStarted = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.startAudit() }
    }
    #endif
    let offset = scroll.contentOffset.y + scroll.adjustedContentInset.top
    var p = compactHeight || display == "inline" ? CGFloat(1) : max(0, min(1, offset / g.band))
    if UIAccessibility.isReduceMotionEnabled { p = p >= 0.5 ? 1 : 0 }
    let end = smallSize / largeSize, width = min(ceil(fit.width), g.width / end)
    let bounds = CGRect(x: 0, y: 0, width: width, height: ceil(fit.height))
    if label.bounds != bounds { label.bounds = bounds }
    let cap = max(0, g.largeWidth + (g.width - g.largeWidth) * p)
    let scale = min(1 + (end - 1) * p, cap / max(1, width))
    let x = g.start.x + (g.dock.x - g.start.x) * p
    // Pulled past the top the title follows the content like UIKit's large title, except with a
    // refresh control: UIKit draws the spinner just above the content, which is this title's row,
    // so the title stays and the spinner appears between it and the list.
    let followsPull = display == "large" && offset < 0 && !compactHeight && !UIAccessibility.isReduceMotionEnabled && scroll.refreshControl == nil
    let y = followsPull ? g.start.y - offset : g.start.y + (g.dock.y - g.start.y) * p
    let center = CGPoint(x: x + (g.rtl ? -1 : 1) * width * scale / 2, y: y)
    if label.center != center { label.center = center }
    let transform = CGAffineTransform(scaleX: scale, y: scale)
    if label.transform != transform { label.transform = transform }
    let resolution = min(12, (label.window?.screen.scale ?? 3) / end)
    if label.contentScaleFactor != resolution { label.contentScaleFactor = resolution }
    if navigation.view.subviews.last !== label { navigation.view.bringSubviewToFront(label) }
  }
  #if DEBUG
  private func startAudit() {
    guard let scroll else { return }
    var step = 0
    let started = CACurrentMediaTime()
    let initialPasses = auditPasses
    let font = label.font
    let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self, weak scroll] timer in
      guard let self, let scroll else { timer.invalidate(); return }
      scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top + CGFloat(step)), animated: false)
      self.layout()
      let frame = self.label.frame
      self.auditRows.append(["step": Double(step), "scale": self.label.transform.a, "x": frame.minX,
        "y": frame.midY, "width": frame.width, "alpha": self.label.alpha,
        "fontSize": self.label.font.pointSize, "sameFont": self.label.font == font ? 1 : 0,
        "boundsWidth": self.label.bounds.width, "rasterScale": self.label.contentScaleFactor])
      step += 1
      if step > 120 {
        timer.invalidate(); self.auditTimer = nil
        let report: [String: Any] = ["rows": self.auditRows, "passes": self.auditPasses - initialPasses,
          "elapsed": CACurrentMediaTime() - started]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]) {
          try? data.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("navigation-morph-audit.json"))
        }
      }
    }
    auditTimer = timer; RunLoop.main.add(timer, forMode: .common)
  }
  #endif
  func snap(_ target: UnsafeMutablePointer<CGPoint>) {
    guard !searching, let g = geometry(), let scroll, !compactHeight, display != "inline", scroll.refreshControl?.isRefreshing != true else { return }
    let top = -scroll.adjustedContentInset.top, proposed = target.pointee.y - top
    if proposed > 0 && proposed < g.band { target.pointee.y = top + (proposed < g.band / 2 ? 0 : g.band) }
  }
}
