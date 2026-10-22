import UIKit
import SwiftUI

/// One slot of a morph button or header row, as SwiftUI renders it.
struct ALGMorphSlot: Equatable, Identifiable {
  let id: String          // glass identity: the slot key, shared across contents and screens
  let itemID: String      // route-qualified id reported on press
  var title: String?
  var symbol: UIImage?
  var symbolKey: String
  let label: String
  let testID: String?
  let width: CGFloat
  let disabled: Bool
  let tint: UIColor?
  let trailing: Bool
  let badge: String?
  let badgeColor: UIColor?
  let badgeTextColor: UIColor?
  let badgeAccessibility: String?
  let menu: UIMenu?
  static func == (a: ALGMorphSlot, b: ALGMorphSlot) -> Bool {
    a.id == b.id && a.itemID == b.itemID && a.title == b.title && a.symbolKey == b.symbolKey && a.label == b.label
      && a.testID == b.testID && a.width == b.width && a.disabled == b.disabled && a.tint == b.tint && a.trailing == b.trailing
      && a.badge == b.badge && a.badgeColor == b.badgeColor && a.badgeTextColor == b.badgeTextColor && a.menu === b.menu
  }
}

/// Content blur for the focus transition (the container draws the glass itself unblurred).
struct ALGFocus: ViewModifier {
  let radius: CGFloat
  func body(content: Content) -> some View { content.blur(radius: radius) }
}

/// Morph timing, matched to Contacts (20 fps): old content out ≈150 ms, glass reshape, new
/// content in over ≈250 ms — ≈0.5 s in all.
enum ALGMorphTiming {
  static let glassResponse: Double = 0.5      // spring response of the glass reshape
  static let glassDamping: Double = 0.82
  static let contentOut: TimeInterval = 0.15  // old content blurs out
  static let contentInDelay: TimeInterval = 0.25
  static let contentIn: TimeInterval = 0.25   // new content focuses in
}

final class ALGMorphModel: ObservableObject {
  @Published var slots: [ALGMorphSlot] = []
  @Published var height: CGFloat = 44
  @Published var inset: CGFloat = 0
  @Published var gap: CGFloat = 10
  @Published var header = false
  @Published var anchor = "trailing"
  @Published var rightToLeft = false
  @Published var reduceMotion = false
  /// How far the host view extends past the control on every side (room for badges).
  let outset: CGFloat = 16
  var activate: (String) -> Void = { _ in }
}

/// SwiftUI's own glass morph: one glass shape per slot (`glassEffectID`) inside a container, so a
/// content change reshapes the glass like liquid while the content blurs out and the new content
/// focuses in (blur replace) — the system-app behaviour.
@available(iOS 26.0, *)
struct ALGMorphRow: View {
  @ObservedObject var model: ALGMorphModel
  @Namespace private var glass

  private func contentKey(_ slot: ALGMorphSlot) -> String {
    slot.title.map { "title:" + $0 } ?? "symbol:" + slot.symbolKey
  }

  private func edge(_ slot: ALGMorphSlot) -> Alignment {
    model.header ? (slot.trailing ? .trailing : .leading) : alignment
  }

  /// The slot owns one persistent glass shape; only its glyph is replaced. Giving each title
  /// a different glass ID makes matchedGeometry remove one shape and insert another, which can
  /// borrow a neighbouring slot's geometry (Edit disappears into Share on the way to Select).
  /// Keeping the material outside the glyph transition also prevents fading/blurring the glass.
  @ViewBuilder private func glyph(_ slot: ALGMorphSlot) -> some View {
    if let title = slot.title {
      Text(title).font(.system(size: 17)).lineLimit(1).fixedSize()
    } else if let symbol = slot.symbol {
      Image(uiImage: symbol.withRenderingMode(.alwaysTemplate))
    }
  }

  @ViewBuilder private func content(_ slot: ALGMorphSlot) -> some View {
    let key = contentKey(slot)
    Group {
      if model.reduceMotion {
        // One glass shape that takes its final size at once; only the content cross-fades.
        ZStack { glyph(slot).transition(.opacity).id(key) }
          .frame(width: slot.width, height: model.height)
          .glassEffect(.regular.interactive(), in: Capsule())
          .glassEffectID(slot.id, in: glass)
      } else {
        ZStack(alignment: edge(slot)) {
          glyph(slot)
            .frame(width: slot.width, height: model.height)
            .transition(contentTransition)
            .id(key)
        }
        .frame(width: slot.width, height: model.height, alignment: edge(slot))
        .glassEffect(.regular.interactive(), in: Capsule())
        .glassEffectID(slot.id, in: glass)
      }
    }
    .contentShape(Capsule())
  }

  @ViewBuilder private func slot(_ slot: ALGMorphSlot) -> some View {
    let control = Group {
      if let menu = slot.menu {
        Menu { ALGMenuContent(menu: menu) } label: { content(slot) }
      } else {
        Button { model.activate(slot.itemID) } label: { content(slot) }
      }
    }
    control
      // Glass on the measured frame itself (the glass button style would add its own padding; see `content`).
      .buttonStyle(.plain)
      .foregroundStyle(slot.tint.map { Color(uiColor: $0) } ?? Color.primary)
      .disabled(slot.disabled)
      // Badges draw above the glass container (see `body`), so the glass neither blends nor clips them.
      .anchorPreference(key: ALGSlotBounds.self, value: .bounds) { slot.badge == nil ? [:] : [slot.id: $0] }
      .accessibilityLabel(slot.label)
      .accessibilityValue(slot.badge == nil ? "" : slot.badgeAccessibility ?? slot.badge ?? "")
      .accessibilityIdentifier(slot.testID ?? slot.id)
  }

  private func badge(_ slot: ALGMorphSlot, _ text: String) -> some View {
    Text(text.isEmpty ? " " : text).font(.system(size: 11, weight: .semibold))
      .foregroundStyle(Color(uiColor: slot.badgeTextColor ?? .white))
      .padding(.horizontal, text.isEmpty ? 0 : 4)
      .frame(minWidth: text.isEmpty ? 8 : 18, minHeight: text.isEmpty ? 8 : 18)
      .background(Capsule().fill(Color(uiColor: slot.badgeColor ?? .systemRed)))
      .fixedSize()
  }

  /// The system-app sequence: the old content blurs out, the glass flows into its new shape, and
  /// the new content focuses in once the glass is nearly there.
  private var contentTransition: AnyTransition {
    // Blur and fade only: `.blurReplace` also scales, which would shrink the glass shape with it.
    let focus = AnyTransition.opacity.combined(with: .modifier(active: ALGFocus(radius: 10), identity: ALGFocus(radius: 0)))
    return .asymmetric(
      insertion: focus.animation(.easeOut(duration: ALGMorphTiming.contentIn).delay(ALGMorphTiming.contentInDelay)),
      removal: focus.animation(.easeIn(duration: ALGMorphTiming.contentOut)))
  }

  private var alignment: Alignment {
    model.anchor == "leading" ? .leading : model.anchor == "trailing" ? .trailing : .center
  }

  var body: some View {
    // Blend distance below the slot gaps: separate controls keep separate glass at rest (as the
    // UIKit path draws them); each slot still reshapes in place through its glass ID.
    GlassEffectContainer(spacing: min(model.gap, 12) - 2) {
      if model.header {
        // Same placement as the UIKit path: leading from the leading edge `gap` apart, trailing
        // from the trailing edge 12 apart, the first trailing item outermost.
        HStack(spacing: 0) {
          HStack(spacing: model.gap) { ForEach(model.slots.filter { !$0.trailing }) { self.slot($0) } }
          Spacer(minLength: 0)
          HStack(spacing: 12) { ForEach(model.slots.filter { $0.trailing }.reversed()) { self.slot($0) } }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
      } else {
        // The container sizes to its content, so the row fills it explicitly: a trailing-anchored
        // morph keeps its trailing edge while the glass widens.
        HStack(spacing: model.gap) { ForEach(model.slots) { self.slot($0) } }
          .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: alignment)
      }
    }
    .padding(.horizontal, model.inset)
    // While the control shrinks, the glass is briefly wider than the host: keep it anchored.
    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: model.header ? .center : alignment)
    .environment(\.layoutDirection, model.rightToLeft ? .rightToLeft : .leftToRight)
    // Centred where the UIKit path anchors it, the capsule's 45° top-trailing point; it rides the
    // glass through the reshape.
    .overlayPreferenceValue(ALGSlotBounds.self) { anchors in
      GeometryReader { proxy in
        ForEach(model.slots) { slot in
          if let text = slot.badge, let anchor = anchors[slot.id] {
            let frame = proxy[anchor]
            badge(slot, text).position(x: frame.minX + frame.width * 0.854, y: frame.minY + frame.height * 0.146)
          }
        }
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
    // The host view is outset so badges can overhang the controls.
    .padding(model.outset)
  }
}

struct ALGSlotBounds: PreferenceKey {
  static var defaultValue: [String: Anchor<CGRect>] = [:]
  static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
    value.merge(nextValue()) { $1 }
  }
}

/// UIKit menu tree rendered as SwiftUI menu content (actions keep their handlers).
@available(iOS 26.0, *)
struct ALGMenuContent: View {
  let menu: UIMenu
  var body: some View {
    ForEach(Array(menu.children.enumerated()), id: \.offset) { _, element in
      if let action = element as? UIAction {
        Button(role: action.attributes.contains(.destructive) ? .destructive : nil) {
          action.performWithSender(nil, target: nil)
        } label: {
          if let image = action.image { Label { Text(action.title) } icon: { Image(uiImage: image) } } else { Text(action.title) }
        }
        .disabled(action.attributes.contains(.disabled))
      } else if let submenu = element as? UIMenu {
        if submenu.options.contains(.displayInline) { Section(submenu.title) { ALGMenuContent(menu: submenu) } }
        else { Menu(submenu.title) { ALGMenuContent(menu: submenu) } }
      }
    }
  }
}

/// Hosts `ALGMorphRow` in a UIKit view, attached to the nearest view controller.
@available(iOS 26.0, *)
final class ALGMorphHost {
  let model = ALGMorphModel()
  let controller: UIViewController
  init() {
    let hosting = UIHostingController(rootView: ALGMorphRow(model: model))
    hosting.view.backgroundColor = .clear
    hosting.sizingOptions = []
    // The row lays out in the control's own bounds; a header near the status bar must not inset it.
    hosting.safeAreaRegions = []
    controller = hosting
  }
  var view: UIView { controller.view }
  func attach(to owner: UIView) {
    guard owner.window != nil else { return }
    var responder: UIResponder? = owner.superview
    while let current = responder, !(current is UIViewController) { responder = current.next }
    guard let parent = responder as? UIViewController, parent !== controller else { return }
    if controller.parent !== parent {
      detach()
      parent.addChild(controller); owner.addSubview(controller.view); controller.didMove(toParent: parent)
    }
  }
  func detach() {
    guard controller.parent != nil else { return }
    controller.willMove(toParent: nil); controller.view.removeFromSuperview(); controller.removeFromParent()
  }
  /// Publishes new slots inside one animation, so SwiftUI morphs glass and blur-replaces content.
  func update(_ slots: [ALGMorphSlot], height: CGFloat, inset: CGFloat, gap: CGFloat, header: Bool, anchor: String, animated: Bool) {
    let apply = {
      if self.model.height != height { self.model.height = height }
      if self.model.inset != inset { self.model.inset = inset }
      if self.model.gap != gap { self.model.gap = gap }
      if self.model.header != header { self.model.header = header }
      if self.model.anchor != anchor { self.model.anchor = anchor }
      if self.model.slots != slots { self.model.slots = slots }
    }
    guard animated, model.slots != slots, !model.slots.isEmpty else { apply(); return }
    let reduceMotion = UIAccessibility.isReduceMotionEnabled
    if model.reduceMotion != reduceMotion { model.reduceMotion = reduceMotion }
    guard reduceMotion else { withAnimation(.spring(response: ALGMorphTiming.glassResponse, dampingFraction: ALGMorphTiming.glassDamping), apply); return }
    // Reduce Motion: the glass takes its final size at once (old content, new widths), then the
    // content cross-fades in the next frame.
    let resized = slots.map { slot -> ALGMorphSlot in
      guard let old = model.slots.first(where: { $0.id == slot.id }) else { return slot }
      var next = slot; next.title = old.title; next.symbol = old.symbol; next.symbolKey = old.symbolKey; return next
    }
    var instant = Transaction(); instant.disablesAnimations = true
    withTransaction(instant) {
      if self.model.height != height { self.model.height = height }
      if self.model.inset != inset { self.model.inset = inset }
      if self.model.gap != gap { self.model.gap = gap }
      if self.model.header != header { self.model.header = header }
      if self.model.anchor != anchor { self.model.anchor = anchor }
      self.model.slots = resized
    }
    DispatchQueue.main.async { [model] in
      guard model.slots == resized else { return }  // a newer update already replaced them
      withAnimation(.easeInOut(duration: 0.2)) { model.slots = slots }
    }
  }
}
