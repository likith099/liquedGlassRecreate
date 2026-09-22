import UIKit
import SwiftUI

private struct SwiftUIClusterAction: Decodable, Equatable, Identifiable {
  let id: String
  let title: String
  let systemImage: String?
  let disabled: Bool?
}

private struct SwiftUIClusterConfiguration: Equatable {
  var actions: [SwiftUIClusterAction] = []
  var expanded = false
  var mergingEnabled = false
  var spacing: CGFloat = 20
  var tint: UIColor?
  var duration = 0.45
  var toggleLabel = "Actions"
}

private final class SwiftUIClusterModel: ObservableObject {
  @Published var configuration = SwiftUIClusterConfiguration()
  @Published var rightToLeft = false
  var activate: (String) -> Void = { _ in }
  var toggle: () -> Void = {}
}

@available(iOS 26.0, *)
private struct SwiftUIClusterContent: View {
  @ObservedObject var model: SwiftUIClusterModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Namespace private var glassNamespace

  private var configuration: SwiftUIClusterConfiguration { model.configuration }

  private func control(id: String, title: String, symbol: String, disabled: Bool,
    action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: UIImage(systemName: symbol) == nil ? "circle" : symbol)
        .font(.system(size: 20, weight: .medium))
    }
    .buttonBorderShape(.circle)
    .controlSize(.large)
    .frame(width: 52, height: 52)
    .disabled(disabled)
    .accessibilityLabel(title)
    .accessibilityIdentifier(id == "__toggle" ? "glass-cluster-toggle" : "glass-action-" + id)
    .glassEffectID(id, in: glassNamespace)
  }

  private var row: some View {
    HStack(spacing: 12) {
      if configuration.expanded {
        ForEach(configuration.actions) { item in
          control(id: item.id, title: item.title, symbol: item.systemImage ?? "circle",
            disabled: item.disabled == true) { model.activate(item.id) }
        }
      }
      control(id: "__toggle", title: configuration.toggleLabel,
        symbol: configuration.expanded ? "xmark" : "plus", disabled: false) { model.toggle() }
        .accessibilityValue(configuration.expanded ? "Expanded" : "Collapsed")
    }
  }

  @ViewBuilder private var styledRow: some View {
    if reduceTransparency { row.buttonStyle(.bordered) }
    else { row.buttonStyle(.glass) }
  }

  var body: some View {
    Group {
      if configuration.mergingEnabled && !reduceTransparency {
        GlassEffectContainer(spacing: configuration.spacing) { styledRow }
      } else { styledRow }
    }
    .tint(configuration.tint.map { Color(uiColor: $0) } ?? .accentColor)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    .padding(.horizontal, 12)
    .animation(reduceMotion || configuration.duration == 0 ? nil : .easeInOut(duration: configuration.duration),
      value: configuration.expanded)
    .environment(\.layoutDirection, model.rightToLeft ? .rightToLeft : .leftToRight)
  }
}

/// Optional stock SwiftUI presentation. The default UIKit cluster is separate so
/// opting into this mode cannot change its accepted tint or native touch behavior.
@objc(ALGSwiftUIActionClusterView)
public final class ALGSwiftUIActionClusterView: UIView {
  private let model = SwiftUIClusterModel()
  private var host: UIViewController?
  private var lastJSON = ""
  private var actions: [SwiftUIClusterAction] = []
  @objc public var onAction: ((String) -> Void)?
  @objc public var onExpandedChange: ((Bool) -> Void)?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    model.activate = { [weak self] id in
      guard let self, self.window != nil, self.model.configuration.expanded,
        let item = self.actions.first(where: { $0.id == id }), item.disabled != true else { return }
      self.onAction?(id)
    }
    model.toggle = { [weak self] in
      guard let self, self.window != nil else { return }
      self.onExpandedChange?(!self.model.configuration.expanded)
    }
    if #available(iOS 26.0, *) {
      let controller = UIHostingController(rootView: SwiftUIClusterContent(model: model))
      controller.view.backgroundColor = .clear
      host = controller
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  @objc public func configure(_ actionsJSON: String, expanded: Bool, mergingEnabled: Bool,
    spacing: CGFloat, tint: UIColor?, duration: Double, toggleLabel: String) {
    if actionsJSON != lastJSON {
      actions = (try? JSONDecoder().decode([SwiftUIClusterAction].self, from: Data(actionsJSON.utf8))) ?? []
      lastJSON = actionsJSON
    }
    let next = SwiftUIClusterConfiguration(actions: actions, expanded: expanded,
      mergingEnabled: mergingEnabled, spacing: spacing.isFinite ? max(0, spacing) : 20,
      tint: tint, duration: duration.isFinite ? max(0, duration) : 0, toggleLabel: toggleLabel)
    // One publication per meaningful prop transaction; state stays React-controlled.
    if model.configuration != next { model.configuration = next }
  }

  private func detachHost() {
    guard let host, host.parent != nil else { return }
    host.willMove(toParent: nil)
    host.view.removeFromSuperview()
    host.removeFromParent()
  }
  private func attachHost() {
    guard window != nil, let host else { return }
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
  public override func layoutSubviews() {
    super.layoutSubviews()
    let rightToLeft = effectiveUserInterfaceLayoutDirection == .rightToLeft
    if model.rightToLeft != rightToLeft { model.rightToLeft = rightToLeft }
    attachHost()
    host?.view.frame = bounds
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
