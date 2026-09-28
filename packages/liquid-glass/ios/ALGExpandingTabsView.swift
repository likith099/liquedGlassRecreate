import UIKit
import SwiftUI

private struct ExpandingTab: Decodable, Equatable, Identifiable {
  let value: String
  let label: String
  let systemImage: String
  /// ARGB from processColor: this tab's accent, used as ink and for the selected wash.
  let tint: Double?
  let disabled: Bool?
  var id: String { value }
}

private struct ExpandingTabsConfiguration: Equatable {
  var tabs: [ExpandingTab] = []
  var selected = ""
  var disabled = false
  var glass = true
  var mergingEnabled = false
  var inset: CGFloat = 16
  var tint: UIColor?
  var identifier = ""
}

private final class ExpandingTabsModel: ObservableObject {
  @Published var configuration = ExpandingTabsConfiguration()
  var select: (String) -> Void = { _ in }
}

/// The geometry of one pill as a function of its progress p (0 idle, 1 selected). It mirrors
/// src/expandingTabsGeometry.ts, whose unit tests pin the formulas and the invariant that the
/// content never outgrows the pill.
private struct PillGeometry {
  let icon: CGFloat
  let gap: CGFloat = 8
  let paddingClosed: CGFloat = 15
  let paddingOpen: CGFloat = 30
  var collapsed: CGFloat { icon + 2 * paddingClosed }
  func expanded(_ label: CGFloat) -> CGFloat { max(collapsed, 2 * paddingOpen + icon + gap + label) }
  func width(_ p: CGFloat, _ label: CGFloat) -> CGFloat { collapsed + (expanded(label) - collapsed) * p }
  func labelOpacity(_ p: CGFloat) -> CGFloat { min(1, max(0, (p - 0.5) / 0.5)) }
}

/// Type sized for the current text size. The pill height grows with the label line, so large
/// accessibility sizes are not clipped.
private struct PillTypography {
  let font: UIFont
  let icon: CGFloat
  let height: CGFloat
  init(category: UIContentSizeCategory) {
    let traits = UITraitCollection(preferredContentSizeCategory: category)
    let metrics = UIFontMetrics(forTextStyle: .subheadline)
    font = metrics.scaledFont(for: .systemFont(ofSize: 15, weight: .bold), compatibleWith: traits)
    icon = ceil(metrics.scaledValue(for: 20, compatibleWith: traits))
    height = max(icon, ceil(font.lineHeight)) + 2 * 8
  }
  /// Measured before the first draw, so a pre-selected pill never pops open.
  func labelWidth(_ label: String) -> CGFloat {
    ceil((label as NSString).size(withAttributes: [.font: font]).width)
  }
}

/// Linear blend of two colours resolved for the current appearance.
private func blend(_ from: UIColor, _ to: UIColor, _ t: CGFloat, _ traits: UITraitCollection) -> Color {
  var a = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0), a: CGFloat(0))
  var b = a
  from.resolvedColor(with: traits).getRed(&a.r, green: &a.g, blue: &a.b, alpha: &a.a)
  to.resolvedColor(with: traits).getRed(&b.r, green: &b.g, blue: &b.b, alpha: &b.a)
  return Color(.sRGB, red: Double(a.r + (b.r - a.r) * t), green: Double(a.g + (b.g - a.g) * t),
    blue: Double(a.b + (b.b - a.b) * t), opacity: Double(a.a + (b.a - a.a) * t))
}

/// Everything a pill draws, derived from one animatable progress (and the label width, so a
/// label or text-size change animates instead of snapping).
private struct PillFace: View, Animatable {
  var progress: CGFloat
  var labelWidth: CGFloat
  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(progress, labelWidth) }
    set { progress = newValue.first; labelWidth = newValue.second }
  }
  let label: String
  let symbol: String
  let accent: UIColor
  let typography: PillTypography
  let glass: Bool
  let traits: UITraitCollection

  var body: some View {
    let p = min(1, max(0, progress))
    let geometry = PillGeometry(icon: typography.icon)
    // Icon and label share one colour, blended from secondary ink to the accent. They are drawn
    // above the material, never inside it, so no vibrancy changes their colour mid-transition.
    let ink = blend(.secondaryLabel, accent, p, traits)
    HStack(spacing: 0) {
      Image(systemName: UIImage(systemName: symbol) == nil ? "circle" : symbol)
        .font(.system(size: typography.icon * 0.85, weight: .semibold))
        .frame(width: typography.icon, height: typography.icon)
      Color.clear.frame(width: geometry.gap * p, height: 1)
      // Laid out at its natural width and revealed from the icon outwards by a growing clip box.
      Text(label).font(Font(typography.font)).lineLimit(1).fixedSize()
        .opacity(geometry.labelOpacity(p))
        .frame(width: labelWidth * p, alignment: .leading)
        .clipped()
    }
    .foregroundStyle(ink)
    .frame(width: geometry.width(p, labelWidth), height: typography.height)
    .background { plate(p) }
  }

  @ViewBuilder private func plate(_ p: CGFloat) -> some View {
    let wash = Color(uiColor: accent).opacity((traits.userInterfaceStyle == .dark ? 0.26 : 0.16) * p)
    ZStack {
      if #available(iOS 26.0, *), glass {
        Color.clear.glassEffect(.regular, in: Capsule())
      } else {
        Capsule().fill(Color(uiColor: .tertiarySystemFill))
      }
      Capsule().fill(wash)
    }
  }
}

private struct PillPressStyle: ButtonStyle {
  let reduceMotion: Bool
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
  }
}

/// One pill with its own progress. It starts at its target, so the first frame draws the
/// selected pill open without animating, and only later changes spring from the current value.
private struct PillButton: View {
  let tab: ExpandingTab
  let selected: Bool
  let position: (index: Int, count: Int)
  let accent: UIColor
  let typography: PillTypography
  let glass: Bool
  let disabled: Bool
  let identifier: String
  let reduceMotion: Bool
  let traits: UITraitCollection
  let select: () -> Void
  @State private var progress: CGFloat

  init(tab: ExpandingTab, selected: Bool, position: (index: Int, count: Int), accent: UIColor,
    typography: PillTypography, glass: Bool, disabled: Bool, identifier: String, reduceMotion: Bool,
    traits: UITraitCollection, select: @escaping () -> Void) {
    self.tab = tab; self.selected = selected; self.position = position; self.accent = accent
    self.typography = typography; self.glass = glass; self.disabled = disabled; self.identifier = identifier
    self.reduceMotion = reduceMotion; self.traits = traits; self.select = select
    _progress = State(initialValue: selected ? 1 : 0)
  }

  private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 1) }

  var body: some View {
    let labelWidth = typography.labelWidth(tab.label)
    Button(action: select) {
      PillFace(progress: progress, labelWidth: labelWidth, label: tab.label, symbol: tab.systemImage,
        accent: accent, typography: typography, glass: glass, traits: traits)
    }
    .buttonStyle(PillPressStyle(reduceMotion: reduceMotion))
    // Restore a 44 pt target around the shorter pill.
    .padding(.vertical, max(0, (44 - typography.height) / 2))
    .contentShape(Rectangle())
    .disabled(disabled)
    .opacity(disabled ? 0.45 : 1)
    .accessibilityLabel(tab.label)
    .accessibilityValue("\(position.index + 1) of \(position.count)")
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    .accessibilityIdentifier(identifier.isEmpty ? tab.value : "\(identifier)-\(tab.value)")
    .onChange(of: selected) { isSelected in
      withAnimation(spring) { progress = isSelected ? 1 : 0 }
    }
    .animation(spring, value: labelWidth)
  }
}

private struct ExpandingTabsContent: View {
  @ObservedObject var model: ExpandingTabsModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.sizeCategory) private var sizeCategory
  @Environment(\.colorScheme) private var colorScheme

  private var configuration: ExpandingTabsConfiguration { model.configuration }

  private func accent(for tab: ExpandingTab) -> UIColor {
    guard let argb = tab.tint else { return configuration.tint ?? .tintColor }
    let value = UInt32(truncatingIfNeeded: Int64(argb))
    return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255, alpha: CGFloat((value >> 24) & 0xFF) / 255)
  }

  @ViewBuilder private func row(_ typography: PillTypography, glass: Bool, traits: UITraitCollection) -> some View {
    let pills = HStack(spacing: 8) {
      ForEach(Array(configuration.tabs.enumerated()), id: \.element.id) { index, tab in
        PillButton(tab: tab, selected: tab.value == configuration.selected,
          position: (index, configuration.tabs.count), accent: accent(for: tab), typography: typography,
          glass: glass, disabled: configuration.disabled || tab.disabled == true,
          identifier: configuration.identifier, reduceMotion: reduceMotion, traits: traits) {
          model.select(tab.value)
        }
        .id(tab.value)
      }
    }
    // Glass pills merge only when the caller opts in.
    if #available(iOS 26.0, *), glass, configuration.mergingEnabled {
      GlassEffectContainer(spacing: 8) { pills }
    } else {
      pills
    }
  }

  var body: some View {
    let typography = PillTypography(category: UIContentSizeCategory(sizeCategory))
    let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
    let glass = configuration.glass && !reduceTransparency
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        row(typography, glass: glass, traits: traits)
          .padding(.horizontal, configuration.inset)
          .frame(maxHeight: .infinity)
      }
      .modifier(NoHorizontalBounce())
      // Keep the selected pill visible when the row overflows.
      .onChange(of: configuration.selected) { selected in
        if reduceMotion { proxy.scrollTo(selected) }
        else { withAnimation(.spring(response: 0.32, dampingFraction: 1)) { proxy.scrollTo(selected) } }
      }
    }
  }
}

private struct NoHorizontalBounce: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 16.4, *) { content.scrollBounceBehavior(.basedOnSize, axes: .horizontal) } else { content }
  }
}

@objc(ALGExpandingTabsView)
public final class ALGExpandingTabsView: UIView {
  private let model: ExpandingTabsModel
  private let host: UIHostingController<ExpandingTabsContent>
  private let haptics = UISelectionFeedbackGenerator()
  private var lastJSON = ""
  private var tabs: [ExpandingTab] = []
  /// Emits the tapped value, including the current one; React turns a repeat into onReselect.
  @objc public var onSelectionChange: ((String) -> Void)?

  public override init(frame: CGRect) {
    let model = ExpandingTabsModel()
    self.model = model
    host = UIHostingController(rootView: ExpandingTabsContent(model: model))
    super.init(frame: frame)
    host.view.backgroundColor = .clear
    model.select = { [weak self] value in
      guard let self, self.window != nil, !self.model.configuration.disabled,
        let tab = self.tabs.first(where: { $0.value == value }), tab.disabled != true else { return }
      if value != self.model.configuration.selected { self.haptics.selectionChanged() }
      self.onSelectionChange?(value)
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  @objc public func configure(_ json: String, selectedValue: String, disabled: Bool, glass: Bool,
    mergingEnabled: Bool, inset: CGFloat, tint: UIColor?, identifier: String) {
    if json != lastJSON {
      tabs = (try? JSONDecoder().decode([ExpandingTab].self, from: Data(json.utf8))) ?? []
      lastJSON = json
    }
    let next = ExpandingTabsConfiguration(tabs: tabs, selected: selectedValue, disabled: disabled, glass: glass,
      mergingEnabled: mergingEnabled, inset: inset, tint: tint, identifier: identifier)
    // React stays authoritative: selection changes only when the value prop changes.
    if model.configuration != next { model.configuration = next }
  }

  private func attachHost() {
    guard window != nil else { return }
    var responder: UIResponder? = superview
    while let current = responder, !(current is UIViewController) { responder = current.next }
    guard let parent = responder as? UIViewController, parent !== host else { return }
    if host.parent !== parent {
      detachHost()
      parent.addChild(host)
      host.view.frame = bounds
      addSubview(host.view)
      host.didMove(toParent: parent)
    }
  }
  private func detachHost() {
    guard host.parent != nil else { return }
    host.willMove(toParent: nil)
    host.view.removeFromSuperview()
    host.removeFromParent()
  }
  public override func layoutSubviews() {
    super.layoutSubviews()
    attachHost()
    host.view.frame = bounds
  }
  public override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil { detachHost() }
    else {
      attachHost()
      DispatchQueue.main.async { [weak self] in self?.attachHost() }
    }
  }
}
