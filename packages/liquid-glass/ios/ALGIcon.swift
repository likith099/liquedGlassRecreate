import UIKit
import Symbols

/// Shared, bounded symbol configuration cache. JSON contains already resolved static colours.
struct ALGSymbol: Decodable, Equatable {
  var name: String = ""
  var pointSize: Double?
  var weight: String?
  var scale: String?
  var rendering: String?
  var paletteColors: [Double]?
  var variableValue: Double?
  static let configurations = NSCache<NSString, UIImage.SymbolConfiguration>()
  func image(defaultSize: CGFloat = 17, tint: UIColor = .label) -> UIImage? {
    let weights: [String: UIImage.SymbolWeight] = ["ultraLight": .ultraLight, "thin": .thin, "light": .light,
      "regular": .regular, "medium": .medium, "semibold": .semibold, "bold": .bold, "heavy": .heavy, "black": .black]
    let key = "\(pointSize ?? Double(defaultSize))/\(weight ?? "medium")/\(scale ?? "medium")" as NSString
    let base: UIImage.SymbolConfiguration
    if let cached = Self.configurations.object(forKey: key) { base = cached }
    else {
      base = UIImage.SymbolConfiguration(pointSize: CGFloat(pointSize ?? Double(defaultSize)),
        weight: weights[weight ?? "medium"] ?? .medium,
        scale: scale == "small" ? .small : scale == "large" ? .large : .medium)
      Self.configurations.countLimit = 128
      Self.configurations.setObject(base, forKey: key)
    }
    var config = base
    switch rendering {
    case "multicolor": config = config.applying(UIImage.SymbolConfiguration.preferringMulticolor())
    case "hierarchical": config = config.applying(UIImage.SymbolConfiguration(hierarchicalColor: tint))
    case "palette": if let colors = paletteColors, !colors.isEmpty {
      config = config.applying(UIImage.SymbolConfiguration(paletteColors: colors.map(ALGIcon.color)))
    }
    case "monochrome": if #available(iOS 16.0, *) { config = config.applying(UIImage.SymbolConfiguration.preferringMonochrome()) }
    default: break
    }
    if #available(iOS 16.0, *), let variableValue {
      return UIImage(systemName: name, variableValue: variableValue, configuration: config)
    }
    return UIImage(systemName: name, withConfiguration: config)
  }
}
struct ALGImageSource: Decodable, Equatable { let uri: String; var scale: Double? }
struct ALGIcon: Decodable, Equatable {
  var symbol: ALGSymbol?
  var imageSource: ALGImageSource?
  var contentTransition: String?
  var pressEffect: String?
  var badge: String?
  var badgeColor: Double?
  var badgeTextColor: Double?
  /// What VoiceOver reads for the badge (JS supplies a default or the app's localized label).
  var badgeAccessibility: String?
  static func decode(_ json: String) -> ALGIcon { (try? JSONDecoder().decode(Self.self, from: Data(json.utf8))) ?? Self() }
  static func color(_ argb: Double) -> UIColor {
    let v = UInt32(truncatingIfNeeded: Int64(argb))
    return UIColor(red: CGFloat((v >> 16) & 255)/255, green: CGFloat((v >> 8) & 255)/255,
      blue: CGFloat(v & 255)/255, alpha: CGFloat((v >> 24) & 255)/255)
  }
  func applyTransition(to config: inout UIButton.Configuration) {
    if #available(iOS 26.0, *), !UIAccessibility.isReduceMotionEnabled, let transition = contentTransition, transition != "none" {
      switch transition {
      case "replaceDownUp": config.symbolContentTransition = UISymbolContentTransition(.replace.downUp)
      case "replaceUpUp": config.symbolContentTransition = UISymbolContentTransition(.replace.upUp)
      default: config.symbolContentTransition = UISymbolContentTransition(.replace)
      }
    }
  }
  func transitionImage(on button: UIButton, image: UIImage?) {
    guard #available(iOS 17.0, *), !UIAccessibility.isReduceMotionEnabled, let image, image.isSymbolImage,
      let contentTransition, contentTransition != "none" else { return }
    if #available(iOS 26.0, *) { return } // The button configuration owns transitions here.
    switch contentTransition {
    case "replaceDownUp": button.imageView?.setSymbolImage(image, contentTransition: .replace.downUp)
    case "replaceUpUp": button.imageView?.setSymbolImage(image, contentTransition: .replace.upUp)
    default: button.imageView?.setSymbolImage(image, contentTransition: .replace)
    }
  }
  func pressed(_ button: UIButton) {
    if #available(iOS 17.0, *), pressEffect == "bounce", !UIAccessibility.isReduceMotionEnabled {
      button.imageView?.addSymbolEffect(.bounce)
    }
  }
}

/// Retains loaded artwork in memory. URI identity gates async completions at the caller.
final class ALGIconLoader {
  private static let cache = NSCache<NSString, UIImage>()
  private var task: URLSessionDataTask?
  private var source: ALGImageSource?
  private(set) var image: UIImage?
  deinit { task?.cancel() }
  func load(_ source: ALGImageSource?, completion: @escaping () -> Void) {
    guard self.source != source else { return }
    task?.cancel(); task = nil; self.source = source; image = nil
    guard let source else { return }
    let key = "\(source.scale ?? 1)@\(source.uri)" as NSString
    if let cached = Self.cache.object(forKey: key) { image = cached; return }
    let finish: (UIImage?) -> Void = { [weak self] image in
      DispatchQueue.main.async {
        guard let self, self.source == source else { return }
        self.image = image
        if let image { Self.cache.countLimit = 128; Self.cache.setObject(image, forKey: key) }
        completion()
      }
    }
    guard let url = URL(string: source.uri), url.scheme != nil else { image = UIImage(named: source.uri); return }
    if url.isFileURL { DispatchQueue.global(qos: .userInitiated).async { finish(UIImage(contentsOfFile: url.path)) }; return }
    task = URLSession.shared.dataTask(with: url) { data, response, _ in
      finish(((response as? HTTPURLResponse)?.statusCode ?? 200) < 400
        ? data.flatMap { UIImage(data: $0, scale: CGFloat(max(1, source.scale ?? 1))) } : nil)
    }
    task?.resume()
  }
  func fitted(_ size: CGFloat) -> UIImage? {
    guard let image, let cg = image.cgImage else { return image }
    let side = max(image.size.width, image.size.height)
    return UIImage(cgImage: cg, scale: image.scale * max(1, side / size), orientation: image.imageOrientation)
      .withRenderingMode(.alwaysOriginal)
  }
}

/// The badge is a public subview of the control. No private UIKit hierarchy is inspected.
final class ALGBadgeLabel: UILabel {
  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false; isAccessibilityElement = false
    textAlignment = .center; font = .systemFont(ofSize: 11, weight: .semibold)
    textColor = .white; clipsToBounds = true
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  func configure(_ text: String?, color: UIColor?, textColor: UIColor? = nil) {
    self.text = text; isHidden = text == nil; backgroundColor = color ?? .systemRed
    self.textColor = textColor ?? .white
  }
  func place(in button: UIButton, host: UIView? = nil) {
    guard !isHidden else { return }
    let h: CGFloat = text?.isEmpty == true ? 8 : 18
    let w = max(h, intrinsicContentSize.width + (h == 8 ? 0 : 8))
    // Keep the badge outside UIKit's masked symbol/content rendering subtree.
    let parent = host ?? button
    if superview !== parent { removeFromSuperview(); parent.addSubview(self) }
    transform = .identity
    bounds = CGRect(x: 0, y: 0, width: w, height: h)
    center = button.convert(CGPoint(x: button.bounds.width * 0.854,
      y: button.bounds.height * 0.146), to: parent)
    layer.cornerRadius = h / 2
  }
}

/// Mirrors UIKit's public background-view presentation geometry for the badge only. UIKit
/// owns the press animation; no substitute highlight, spring, or button movement is added.
private final class ALGBadgeDisplayTarget: NSObject {
  weak var button: ALGDecoratedButton?
  @objc func tick(_ link: CADisplayLink) { button?.updateBadgePresentation() }
}
class ALGDecoratedButton: UIButton {
  let badgeLabel = ALGBadgeLabel()
  // Group glass is snapshotted/masked during menu dismissal. Keep its badges in
  // the public host above that material, while tracking the same button geometry.
  weak var badgeHost: UIView?
  private func placeBadge(center: CGPoint, scale: CGFloat) {
    let parent = badgeHost ?? self
    if let source = layer.presentation(), let target = parent.layer.presentation(), parent !== self {
      badgeLabel.center = source.convert(center, to: target)
    } else { badgeLabel.center = convert(center, to: parent) }
    badgeLabel.transform = CGAffineTransform(scaleX: scale, y: scale)
  }
  // Public UIBackgroundConfiguration attachment: no private subview discovery.
  // It draws nothing; UIKit supplies its translation, bounds and deformation.
  private let badgeGeometry = UIView()
  func attachBadgeGeometry(to configuration: inout UIButton.Configuration, enabled: Bool) {
    badgeGeometry.isUserInteractionEnabled = false
    configuration.background.customView = enabled ? badgeGeometry : nil
  }
  private var badgeLink: CADisplayLink?
  private var badgeLayoutGeneration = 0
  private var badgeLayoutTransition: (generation: Int, from: CGRect, to: CGRect, scale: CGFloat)?

  // Frame morphs change the proxy's bounds independently of a press. Never feed that
  // ratio into the press peak: a shrinking capsule can otherwise latch an enormous scale.
  // The generation protects a new transition from an interrupted animation's completion.
  func beginBadgeLayoutTransition(to frame: CGRect) -> Int {
    badgeLayoutGeneration += 1
    let current = layer.presentation()?.frame ?? self.frame
    badgeLayoutTransition = (badgeLayoutGeneration, current, frame, badgeScale)
    badgePeak = 1; badgeScaleVelocity = 0
    trackBadge()
    return badgeLayoutGeneration
  }
  func endBadgeLayoutTransition(_ generation: Int) {
    guard badgeLayoutTransition?.generation == generation else { return }
    badgeLayoutTransition = nil
    stopBadgeTracking()
  }
  private var badgeTouchActive = false
  // The glass button leans toward the finger during a press-drag. UIKit renders that lean on a
  // private glass layer that no public content/background view exposes, so the badge mirrors it
  // from the live touch location instead: an eased translation toward the finger, capped so the
  // badge rides the glass rather than chasing the finger. Zero when no finger is tracking.
  private var badgeTouchPoint: CGPoint?
  private var badgeLean: CGPoint = .zero
  private let badgeLeanFactor: CGFloat = 0.09
  private let badgeLeanCapRatio: CGFloat = 0.11
  // UIKit's background-view proxy captures the press swell-up but relaxes after a couple of seconds
  // even while the glass stays enlarged. While the glass is enlarged the badge follows it directly;
  // once the finger lifts the badge springs back to rest with the glass's own bounce, so it reads
  // as part of the glass rather than a sticker easing on its own.
  private var badgeScale: CGFloat = 1
  private var badgePeak: CGFloat = 1
  private var badgeScaleVelocity: CGFloat = 0
  private let badgeSpringResponse: CGFloat = 0.32
  private let badgeSpringDamping: CGFloat = 0.6
  override init(frame: CGRect) {
    super.init(frame: frame); addSubview(badgeLabel)
    addTarget(self, action: #selector(beginBadgeTouch), for: [.touchDown, .touchDragEnter, .touchDragInside, .touchDragOutside])
    addTarget(self, action: #selector(endBadgeTouch), for: [.touchUpInside, .touchUpOutside, .touchCancel])
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  deinit { badgeLink?.invalidate() }
  override var isHighlighted: Bool {
    didSet { if isHighlighted { trackBadge() } }
  }
  // Record the live finger position so the badge can lean with the glass during the drag.
  override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    badgeTouchPoint = touch.location(in: self); return super.beginTracking(touch, with: event)
  }
  override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    badgeTouchPoint = touch.location(in: self); return super.continueTracking(touch, with: event)
  }
  override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
    badgeTouchPoint = nil; super.endTracking(touch, with: event)
  }
  override func cancelTracking(with event: UIEvent?) {
    badgeTouchPoint = nil; super.cancelTracking(with: event)
  }
  @objc private func beginBadgeTouch() { badgeTouchActive = true; trackBadge() }
  @objc private func endBadgeTouch() { badgeTouchActive = false }
  @objc private func trackBadge() {
    guard !badgeLabel.isHidden, window != nil, badgeLink == nil else { return }
    let target = ALGBadgeDisplayTarget(); target.button = self
    let link = CADisplayLink(target: target, selector: #selector(ALGBadgeDisplayTarget.tick(_:)))
    badgeLink = link; link.add(to: .main, forMode: .common)
  }
  private func stopBadgeTracking() {
    badgeLink?.invalidate(); badgeLink = nil; badgeLean = .zero; badgeTouchPoint = nil
    badgeScale = 1; badgePeak = 1; badgeScaleVelocity = 0
    UIView.performWithoutAnimation { badgeLabel.place(in: self, host: badgeHost) }
  }
  fileprivate func updateBadgePresentation() {
    guard window != nil, !badgeLabel.isHidden else { stopBadgeTracking(); return }
    if let transition = badgeLayoutTransition {
      let presented = layer.presentation() ?? layer
      let rect = presented.bounds
      // Retire any existing press swell along with the frame animation, without a
      // one-frame size jump. Position uses the *presented* bounds throughout.
      let total = abs(transition.from.width - transition.to.width) + abs(transition.from.height - transition.to.height)
      let remaining = abs(rect.width - transition.to.width) + abs(rect.height - transition.to.height)
      let fraction = total > 0.01 ? min(1, remaining / total) : 0
      let scale = 1 + (transition.scale - 1) * fraction
      badgeScale = scale
      UIView.performWithoutAnimation {
        placeBadge(center: CGPoint(x: rect.midX + rect.width * 0.354 * scale,
          y: rect.midY - rect.height * 0.354 * scale), scale: scale)
      }
      return
    }
    // Ease the badge's lean toward the finger (zero target once the finger lifts), mirroring the
    // glass's own drag lean. Capped to a fraction of the control so the badge stays on the glass.
    var leanTarget = CGPoint.zero
    if let point = badgeTouchPoint {
      let cap = min(bounds.width, bounds.height) * badgeLeanCapRatio
      var lx = (point.x - bounds.midX) * badgeLeanFactor, ly = (point.y - bounds.midY) * badgeLeanFactor
      let magnitude = hypot(lx, ly)
      if magnitude > cap, magnitude > 0 { lx *= cap / magnitude; ly *= cap / magnitude }
      leanTarget = CGPoint(x: lx, y: ly)
    }
    badgeLean.x += (leanTarget.x - badgeLean.x) * 0.3
    badgeLean.y += (leanTarget.y - badgeLean.y) * 0.3
    let content: UIView? = badgeGeometry.superview != nil ? badgeGeometry : (configuration?.image != nil ? imageView : titleLabel)
    // Track the background, not the relatively rigid glyph. Include animated
    // bounds as well as transforms, since drag stretch can change either.
    // Legacy plain controls without an attachment retain content tracking.
    guard let source = content?.layer.presentation(), let destination = layer.presentation() else { return }
    let middle = CGPoint(x: source.bounds.midX, y: source.bounds.midY)
    let center = source.convert(middle, to: destination)
    // UIKit briefly reparents the background attachment at highlight onset. Its
    // presentation conversion can then return a window-relative point hundreds of
    // points outside this button. Keep the previous badge pose until it is local
    // again; that transient sample is not glass deformation.
    guard center.x.isFinite, center.y.isFinite,
      bounds.insetBy(dx: -bounds.width, dy: -bounds.height).contains(center),
      source.bounds.width > 0, source.bounds.height > 0 else { return }
    let x = source.convert(CGPoint(x: middle.x + 1, y: middle.y), to: destination)
    let y = source.convert(CGPoint(x: middle.x, y: middle.y + 1), to: destination)
    let sx = content === badgeGeometry ? source.bounds.width / max(1, bounds.width) : 1
    let sy = content === badgeGeometry ? source.bounds.height / max(1, bounds.height) : 1
    let a = (x.x - center.x) * sx, b = (x.y - center.y) * sx
    let c = (y.x - center.x) * sy, d = (y.y - center.y) * sy
    let dx = bounds.width * 0.354, dy = -bounds.height * 0.354
    // The glass's own drag gesture cancels the button's UIControl tracking the moment a drag
    // starts, yet the glass stays enlarged — so the press flags are unreliable. Follow the live
    // proxy scale (which stays enlarged through the drag) and separately hold the peak while the
    // button still reports a press, which covers the in-place hold where the proxy relaxes early.
    let proxyScale = max((a + d) / 2, hypot(a, b))
    guard proxyScale.isFinite, proxyScale > 0 else { return }
    let pressed = badgeTouchActive || isHighlighted
    let dt = CGFloat(min(1.0 / 30, max(1.0 / 120, badgeLink?.duration ?? 1.0 / 60)))
    if pressed {
      // Finger down: ride the glass directly and remember the peak (the proxy relaxes early on an
      // in-place hold, so the peak keeps the badge enlarged while the glass stays enlarged).
      badgePeak = max(badgePeak, proxyScale); badgeScale = max(proxyScale, badgePeak); badgeScaleVelocity = 0
    } else if proxyScale > 1.05 {
      // Finger lifted off the button but the glass is still enlarged (its own drag gesture took the
      // touch): keep following the live glass scale.
      badgePeak = proxyScale; badgeScale = proxyScale; badgeScaleVelocity = 0
    } else {
      // Released: spring back to rest with the glass's bounce instead of a flat ease.
      badgePeak = 1
      let omega = 2 * CGFloat.pi / badgeSpringResponse
      let accel = omega * omega * (1 - badgeScale) - 2 * badgeSpringDamping * omega * badgeScaleVelocity
      badgeScaleVelocity += accel * dt; badgeScale += badgeScaleVelocity * dt
    }
    let s = badgeScale
    // Stop once the finger is gone and both the glass and the badge (and its spring) are at rest.
    if !pressed, badgeTouchPoint == nil, proxyScale < 1.05,
      abs(badgeScale - 1) < 0.004, abs(badgeScaleVelocity) < 0.03 { stopBadgeTracking(); return }
    // Legacy title tracking (no owned attachment) keeps the button centre as its anchor to ignore
    // transient text relayout; the badge attachment is centred on the control.
    let anchor = content !== badgeGeometry && configuration?.image == nil
      ? CGPoint(x: bounds.midX, y: bounds.midY) : center
    CATransaction.begin(); CATransaction.setDisableActions(true)
    placeBadge(center: CGPoint(x: anchor.x + s * dx + badgeLean.x,
      y: anchor.y + s * dy + badgeLean.y), scale: s)
    CATransaction.commit()
  }
  override func layoutSubviews() {
    super.layoutSubviews()
    UIView.performWithoutAnimation { badgeLabel.place(in: self, host: badgeHost) }
    // Replacing glass/plain/prominent configurations can insert content above an
    // existing badge. Keep it visible through the whole native press transition.
    (badgeHost ?? self).bringSubviewToFront(badgeLabel)
    if badgeLink != nil { updateBadgePresentation() }
  }
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      badgeLayoutTransition = nil; badgeTouchActive = false
      stopBadgeTracking()
    }
  }
}
