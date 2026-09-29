import UIKit
import UIKit.UIGestureRecognizerSubclass

private struct PanelItem: Decodable {
  let id: String
  let title: String
  let kind: String?
  let systemImage: String?
  let disabled: Bool?
  let destructive: Bool?
  let checked: Bool?
  let items: [PanelItem]?
}

/// Layout metrics, measured from UIKit's own iOS 26 menu (iPhone 17 Pro Max, default text size).
/// `GlassMenuPanel.measure` in JavaScript computes the same height from the same numbers: change
/// them together.
enum PanelMetrics {
  static let width: CGFloat = 250
  static let paddingVertical: CGFloat = 9
  static let row: CGFloat = 40
  static let separator: CGFloat = 21
  static let title: CGFloat = 30
  static let cornerRadius: CGFloat = 30
  static let legacyCornerRadius: CGFloat = 13
  /// Space between a highlighted row and the platter's sides: the same as above the first row.
  static let highlightGap: CGFloat = paddingVertical
  static func scale(_ fontScale: CGFloat) -> CGFloat { max(1, fontScale) }
}

private enum Line {
  case item(PanelItem)
  case title(String)
  case separator
}

/// Sections become an optional title between separators. Mirrors `rowsOf` in GlassMenuPanel.tsx.
private func lines(_ items: [PanelItem]) -> [Line] {
  var out: [Line] = []
  for item in items {
    if item.kind == "section" {
      if let last = out.last, case .separator = last {} else if !out.isEmpty { out.append(.separator) }
      if !item.title.isEmpty { out.append(.title(item.title)) }
      out.append(contentsOf: lines(item.items ?? []))
      out.append(.separator)
    } else {
      out.append(.item(item))
    }
  }
  while let last = out.last, case .separator = last { out.removeLast() }
  return out
}

/// Hands a long press's finger to the most recently mounted menu panel. The press may be
/// recognised before the panel mounts, so the latest point waits here until one does.
@objc(ALGMenuPanelTracker)
public final class ALGMenuPanelTracker: NSObject {
  @objc public static let shared = ALGMenuPanelTracker()
  private var panels: [WeakPanel] = []
  private var active = false
  private var pending: CGPoint?
  private struct WeakPanel { weak var view: ALGMenuPanelView? }
  fileprivate var current: ALGMenuPanelView? {
    panels.removeAll { $0.view == nil }
    return panels.last?.view
  }
  fileprivate func register(_ panel: ALGMenuPanelView) {
    panels.removeAll { $0.view == nil || $0.view === panel }
    panels.append(WeakPanel(view: panel))
    if active, let point = pending { panel.trackExternal(at: point) }
  }
  fileprivate func unregister(_ panel: ALGMenuPanelView) { panels.removeAll { $0.view == nil || $0.view === panel } }
  /// The long press was recognised; the finger is still down.
  @objc public func begin() { active = true; pending = nil }
  /// The finger moved, in window coordinates.
  @objc public func move(to point: CGPoint) {
    guard active else { return }
    pending = point
    current?.trackExternal(at: point)
  }
  /// The finger lifted, in window coordinates: select the row under it, if any.
  @objc public func end(at point: CGPoint) {
    guard active else { return }
    active = false; pending = nil
    current?.endExternal(at: point)
  }
  @objc public func cancel() {
    guard active else { return }
    active = false; pending = nil
    current?.cancelExternal()
  }
}

/// Reports a single finger from touch down to lift, without delaying or cancelling anyone's touches.
final class PanelTouchRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
  override init(target: Any?, action: Selector?) {
    super.init(target: target, action: action)
    cancelsTouchesInView = false
    delaysTouchesBegan = false
    delaysTouchesEnded = false
  }
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    if state == .possible { state = .began } else { touches.forEach { ignore($0, for: event) } }
  }
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) { state = .changed }
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { state = .ended }
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .cancelled }
  override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
  override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

/// One row: the SF Symbol leading, then the title, then a checkmark when checked, as UIKit's menu.
private final class PanelRow: UIView {
  let item: PanelItem
  let enabled: Bool
  private let highlight = UIView()
  init(item: PanelItem, enabled: Bool, reserveIcon: Bool, scale: CGFloat, font: UIFont, legacy: Bool) {
    self.item = item
    self.enabled = enabled
    super.init(frame: .zero)
    let destructive = item.destructive == true
    let ink: UIColor = !enabled ? .tertiaryLabel : destructive ? .systemRed : .label
    highlight.backgroundColor = legacy ? .tertiarySystemFill : UIColor.label.withAlphaComponent(0.1)
    highlight.layer.cornerCurve = .continuous
    highlight.isHidden = true
    addSubview(highlight)
    let title = UILabel()
    title.text = item.title
    title.font = font
    title.textColor = ink
    title.lineBreakMode = .byTruncatingTail
    title.tag = 1
    addSubview(title)
    let symbol = UIImage.SymbolConfiguration(pointSize: 17 * scale, weight: .regular)
    if reserveIcon, let name = item.systemImage, let image = UIImage(systemName: name, withConfiguration: symbol) {
      let icon = UIImageView(image: image)
      icon.tintColor = ink
      icon.contentMode = .center
      icon.tag = 2
      addSubview(icon)
    }
    if item.checked == true {
      let check = UIImageView(image: UIImage(systemName: "checkmark",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 15 * scale, weight: .semibold)))
      check.tintColor = ink
      check.contentMode = .center
      check.tag = 3
      addSubview(check)
    }
    isAccessibilityElement = true
    accessibilityLabel = item.title
    accessibilityTraits = enabled ? .button : [.button, .notEnabled]
    if item.checked == true { accessibilityTraits.insert(.selected) }
    if destructive { accessibilityHint = "Destructive" }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  var reserveIcon = false
  func layout(scale: CGFloat, reserveIcon: Bool, legacy: Bool) {
    if legacy {
      // Pre-26 menus highlight edge to edge; the platter's rounded clip shapes the first and last rows.
      highlight.frame = bounds
      highlight.layer.cornerRadius = 0
    } else {
      // Concentric with the platter: the same gap on the sides as above the first row, and the
      // platter's radius less that gap, so the highlight's ends follow the platter's corners.
      let gap = PanelMetrics.highlightGap
      highlight.frame = bounds.insetBy(dx: gap, dy: 0)
      highlight.layer.cornerRadius = min(PanelMetrics.cornerRadius - gap, highlight.frame.height / 2)
    }
    let titleX: CGFloat = reserveIcon ? 62 * scale : 20 * scale
    let trailing: CGFloat = viewWithTag(3) == nil ? 20 * scale : 46 * scale
    viewWithTag(1)?.frame = CGRect(x: titleX, y: 0, width: max(0, bounds.width - titleX - trailing), height: bounds.height)
    viewWithTag(2)?.frame = CGRect(x: 38 * scale - 12 * scale, y: (bounds.height - 24 * scale) / 2, width: 24 * scale, height: 24 * scale)
    viewWithTag(3)?.frame = CGRect(x: bounds.width - 31 * scale - 10 * scale, y: (bounds.height - 20 * scale) / 2,
      width: 20 * scale, height: 20 * scale)
  }
  func setHighlighted(_ on: Bool) { highlight.isHidden = !on }
  /// VoiceOver's double tap chooses the row, as lifting a finger on it does.
  var onActivate: (() -> Void)?
  override func accessibilityActivate() -> Bool {
    guard enabled, let onActivate else { return false }
    onActivate()
    return true
  }
}

/// A menu drawn in place, laid out by React Native, never presented by UIKit: the iOS 26 glass
/// platter (system material below 26) with UIKit menu rows. Touch down highlights a row, sliding
/// moves the highlight with a selection tick per row, and lifting on an enabled row chooses it.
/// A long press elsewhere can hand its finger over through ALGMenuPanelTracker.
@objc(ALGMenuPanelView)
public final class ALGMenuPanelView: UIView {
  @objc public var onAction: ((String) -> Void)?
  @objc public var onCancelTouch: (() -> Void)?
  @objc public var onDismissed: (() -> Void)?
  /// VoiceOver's escape gesture: the app should close the menu.
  @objc public var onRequestClose: (() -> Void)?

  private let platter = UIVisualEffectView(effect: nil)
  private let shadow = UIView()
  private let scroll = UIScrollView()
  private var rows: [PanelRow] = []
  private var separators: [UIView] = []
  private var titles: [UILabel] = []
  private var entries: [Line] = []
  private var lastJSON = ""
  private var fontScale: CGFloat = 1
  private var disabled = false
  private var appearFrom = "none"
  private var autoFocus = false
  private var highlighted: PanelRow?
  private let feedback = UISelectionFeedbackGenerator()
  private var appeared = false
  private var tracking = false
  private var builtDisabled = false
  private var builtIdentifier = ""

  private var legacy: Bool {
    if #available(iOS 26.0, *) { return UIAccessibility.isReduceTransparencyEnabled } else { return true }
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    shadow.layer.shadowColor = UIColor.black.cgColor
    shadow.layer.shadowOpacity = 0.18
    shadow.layer.shadowRadius = 24
    shadow.layer.shadowOffset = CGSize(width: 0, height: 8)
    addSubview(shadow)
    addSubview(platter)
    scroll.showsVerticalScrollIndicator = true
    scroll.delaysContentTouches = false
    scroll.alwaysBounceVertical = false
    platter.contentView.addSubview(scroll)
    accessibilityContainerType = .semanticGroup
    let touches = PanelTouchRecognizer(target: self, action: #selector(follow(_:)))
    touches.delegate = touches
    addGestureRecognizer(touches)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  @objc public func configure(_ json: String, fontScale: CGFloat, colorScheme: String, disabled: Bool,
    appearFrom: String, autoFocus: Bool, modal: Bool, identifier: String) {
    self.disabled = disabled
    self.appearFrom = appearFrom
    self.autoFocus = autoFocus
    accessibilityViewIsModal = modal
    accessibilityIdentifier = identifier.isEmpty ? nil : identifier
    overrideUserInterfaceStyle = colorScheme == "dark" ? .dark : colorScheme == "light" ? .light : .unspecified
    if json != lastJSON || fontScale != self.fontScale || disabled != builtDisabled || identifier != builtIdentifier {
      lastJSON = json
      self.fontScale = fontScale
      builtDisabled = disabled
      builtIdentifier = identifier
      let items = (try? JSONDecoder().decode([PanelItem].self, from: Data(json.utf8))) ?? []
      rebuild(items, identifier: identifier)
    }
    applyMaterial()
    setNeedsLayout()
  }

  private func applyMaterial() {
    let radius = legacy ? PanelMetrics.legacyCornerRadius : PanelMetrics.cornerRadius
    if #available(iOS 26.0, *), !legacy {
      // Glass at its final material from the first frame: set without animation, never faded in.
      let glass = UIGlassEffect(style: .regular)
      glass.isInteractive = true
      platter.effect = glass
      platter.cornerConfiguration = .uniformCorners(radius: .fixed(radius))
      shadow.isHidden = true
    } else {
      platter.effect = UIAccessibility.isReduceTransparencyEnabled ? nil : UIBlurEffect(style: .systemMaterial)
      platter.backgroundColor = UIAccessibility.isReduceTransparencyEnabled ? .secondarySystemBackground : nil
      platter.layer.cornerRadius = radius
      platter.layer.cornerCurve = .continuous
      platter.clipsToBounds = true
      shadow.layer.cornerRadius = radius
      shadow.isHidden = false
    }
  }

  private func rebuild(_ items: [PanelItem], identifier: String) {
    cancelHighlight()
    rows.forEach { $0.removeFromSuperview() }
    separators.forEach { $0.removeFromSuperview() }
    titles.forEach { $0.removeFromSuperview() }
    rows = []; separators = []; titles = []
    entries = lines(items)
    let scale = PanelMetrics.scale(fontScale)
    let font = UIFont.systemFont(ofSize: 17 * fontScale)
    let reserveIcon = entries.contains { if case .item(let item) = $0 { return item.systemImage != nil } else { return false } }
    for entry in entries {
      switch entry {
      case .item(let item):
        let row = PanelRow(item: item, enabled: !disabled && item.disabled != true, reserveIcon: reserveIcon,
          scale: scale, font: font, legacy: legacy)
        row.reserveIcon = reserveIcon
        row.accessibilityIdentifier = identifier.isEmpty ? nil : "\(identifier)-\(item.id)"
        row.onActivate = { [weak self] in
          guard let self, !self.disabled else { return }
          self.onAction?(item.id)
        }
        rows.append(row)
        scroll.addSubview(row)
      case .title(let text):
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 13 * fontScale, weight: .semibold)
        label.textColor = .secondaryLabel
        label.accessibilityTraits = .header
        titles.append(label)
        scroll.addSubview(label)
      case .separator:
        let line = UIView()
        line.backgroundColor = .separator
        line.isAccessibilityElement = false
        separators.append(line)
        scroll.addSubview(line)
      }
    }
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    shadow.frame = bounds
    shadow.layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: shadow.layer.cornerRadius).cgPath
    platter.frame = bounds
    scroll.frame = platter.contentView.bounds
    let scale = PanelMetrics.scale(fontScale)
    var y = PanelMetrics.paddingVertical
    var rowIndex = 0, titleIndex = 0, separatorIndex = 0
    for entry in entries {
      switch entry {
      case .item:
        let row = rows[rowIndex]; rowIndex += 1
        row.frame = CGRect(x: 0, y: y, width: bounds.width, height: (PanelMetrics.row * scale).rounded())
        row.layout(scale: scale, reserveIcon: row.reserveIcon, legacy: legacy)
        y += row.frame.height
      case .title:
        let label = titles[titleIndex]; titleIndex += 1
        let height = (PanelMetrics.title * scale).rounded()
        label.frame = CGRect(x: 20 * scale, y: y, width: bounds.width - 40 * scale, height: height)
        y += height
      case .separator:
        let line = separators[separatorIndex]; separatorIndex += 1
        let hairline = 1 / max(1, window?.screen.scale ?? UIScreen.main.scale)
        line.frame = CGRect(x: 16 * scale, y: y + (PanelMetrics.separator - hairline) / 2,
          width: bounds.width - 32 * scale, height: hairline)
        y += PanelMetrics.separator
      }
    }
    y += PanelMetrics.paddingVertical
    scroll.contentSize = CGSize(width: bounds.width, height: y)
    scroll.isScrollEnabled = y > bounds.height + 0.5
  }

  public override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      ALGMenuPanelTracker.shared.register(self)
      if !appeared { appeared = true; appear() }
    } else {
      ALGMenuPanelTracker.shared.unregister(self)
    }
  }

  /// A spring from the edge it opens from, like the system menu. Transform only: glass does not
  /// render inside a fading view.
  private func appear() {
    if autoFocus, let first = rows.first(where: { $0.enabled }) ?? rows.first {
      DispatchQueue.main.async { UIAccessibility.post(notification: .screenChanged, argument: first) }
    }
    guard appearFrom == "top" || appearFrom == "bottom", !UIAccessibility.isReduceMotionEnabled else { return }
    layoutIfNeeded()
    let shift = (appearFrom == "top" ? -1 : 1) * bounds.height * 0.08
    transform = CGAffineTransform(translationX: 0, y: shift).scaledBy(x: 0.9, y: 0.9)
    UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0,
      options: [.allowUserInteraction, .beginFromCurrentState]) { self.transform = .identity }
  }

  /// Shrinks back toward the edge it opened from, then reports the end.
  @objc public func dismiss() {
    cancelHighlight()
    guard !UIAccessibility.isReduceMotionEnabled else { onDismissed?(); return }
    let shift = (appearFrom == "bottom" ? 1 : -1) * bounds.height * 0.06
    UIView.animate(withDuration: 0.22, delay: 0, options: [.beginFromCurrentState, .curveEaseIn]) {
      self.transform = CGAffineTransform(translationX: 0, y: shift).scaledBy(x: 0.92, y: 0.92)
      self.alpha = 0
    } completion: { _ in self.onDismissed?() }
  }

  // MARK: Tracking

  private func row(at point: CGPoint) -> PanelRow? {
    let inScroll = convert(point, to: scroll)
    guard bounds.contains(point) else { return nil }
    return rows.first { $0.frame.contains(inScroll) }
  }
  private func move(to point: CGPoint) {
    let target = row(at: point).flatMap { $0.enabled ? $0 : nil }
    guard target !== highlighted else { return }
    highlighted?.setHighlighted(false)
    highlighted = target
    if let target {
      target.setHighlighted(true)
      feedback.selectionChanged()
      feedback.prepare()
    }
  }
  private func finish(at point: CGPoint) {
    let target = row(at: point)
    cancelHighlight()
    if let target, target.enabled, !disabled { onAction?(target.item.id) } else { onCancelTouch?() }
  }
  private func cancelHighlight() {
    highlighted?.setHighlighted(false)
    highlighted = nil
  }

  /// Rows sit in a scroll view, which does not pass touches up the responder chain, so the panel
  /// follows the finger with a recognizer that sees every touch inside it. It never cancels touches
  /// and recognises alongside everything else, React Native's touch handler included.
  @objc private func follow(_ recognizer: PanelTouchRecognizer) {
    let point = recognizer.location(in: self)
    switch recognizer.state {
    case .began:
      tracking = true
      feedback.prepare()
      // The first row needs no tick: the finger landed on it.
      let target = row(at: point).flatMap { $0.enabled ? $0 : nil }
      highlighted = target
      target?.setHighlighted(true)
    case .changed:
      guard tracking else { return }
      // Once the rows scroll, the touch is a scroll, not a selection.
      if scroll.isDragging { tracking = false; cancelHighlight(); return }
      move(to: point)
    case .ended:
      guard tracking else { return }
      tracking = false
      finish(at: point)
    default:
      tracking = false
      cancelHighlight()
    }
  }

  fileprivate func trackExternal(at windowPoint: CGPoint) {
    guard window != nil else { return }
    move(to: convert(windowPoint, from: nil))
  }
  fileprivate func endExternal(at windowPoint: CGPoint) {
    guard window != nil else { return }
    let point = convert(windowPoint, from: nil)
    // Lifting off the panel after a long press leaves it open for a normal tap.
    if row(at: point) == nil { cancelHighlight(); return }
    finish(at: point)
  }
  fileprivate func cancelExternal() { cancelHighlight() }

  public override func accessibilityPerformEscape() -> Bool {
    guard let onRequestClose else { return false }
    onRequestClose()
    return true
  }
}
