import UIKit
import SwiftUI

private final class ButtonModel: ObservableObject {
  @Published var title = ""
  @Published var symbol = ""
  @Published var prominent = false
  @Published var disabled = false
  @Published var loading = false
  @Published var tint: UIColor?
  @Published var label = ""
  @Published var hint = ""
  @Published var identifier = ""
  var activate: () -> Void = {}
}

@available(iOS 26.0, *)
private struct NativeButtonContent: View {
  @ObservedObject var model: ButtonModel
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  private var button: some View {
    Button {
      if !model.disabled && !model.loading { model.activate() }
    } label: {
      HStack(spacing: 8) {
        if model.loading { ProgressView().accessibilityHidden(true) }
        else if !model.symbol.isEmpty { Image(systemName: model.symbol).accessibilityHidden(true) }
        Text(model.title)
      }
      .frame(maxWidth: .infinity)
    }
    .disabled(model.disabled || model.loading)
    .accessibilityLabel(model.label.isEmpty ? model.title : model.label)
    .accessibilityHint(model.hint)
    .accessibilityValue(model.loading ? "Loading" : "")
    .accessibilityIdentifier(model.identifier)
  }

  var body: some View {
    Group {
      if reduceTransparency {
        if model.prominent { button.buttonStyle(.borderedProminent) }
        else { button.buttonStyle(.bordered) }
      } else if model.prominent {
        button.buttonStyle(.glassProminent)
      } else {
        button.buttonStyle(.glass)
      }
    }
    .controlSize(.large)
    .tint(model.tint.map { Color(uiColor: $0) } ?? .accentColor)
    .padding(.horizontal, 4)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

@objc(ALGButtonView)
public final class ALGButtonView: UIView {
  private let model = ButtonModel()
  private var host: UIViewController?
  @objc public var onActivate: (() -> Void)?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    model.activate = { [weak self] in self?.onActivate?() }
    if #available(iOS 26.0, *) {
      let controller = UIHostingController(rootView: NativeButtonContent(model: model))
      controller.view.backgroundColor = .clear
      host = controller
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  @objc public func configure(_ title: String, symbol: String, prominent: Bool, disabled: Bool,
    loading: Bool, tint: UIColor?, scheme: String, label: String, hint: String, identifier: String) {
    // @Published emits even for equal assignments. React commits frequently
    // carry unchanged fields; keep those from invalidating SwiftUI content.
    if model.title != title { model.title = title }
    if model.symbol != symbol { model.symbol = symbol }
    if model.prominent != prominent { model.prominent = prominent }
    if model.disabled != disabled { model.disabled = disabled }
    if model.loading != loading { model.loading = loading }
    if model.tint != tint { model.tint = tint }
    if model.label != label { model.label = label }
    if model.hint != hint { model.hint = hint }
    if model.identifier != identifier { model.identifier = identifier }
    overrideUserInterfaceStyle = scheme == "dark" ? .dark : scheme == "light" ? .light : .unspecified
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
    attachHost()
    host?.view.frame = bounds
  }
  public override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      detachHost()
    } else {
      attachHost()
      // Fabric may finish connecting the responder chain after window insertion.
      DispatchQueue.main.async { [weak self] in self?.attachHost() }
    }
  }
}
