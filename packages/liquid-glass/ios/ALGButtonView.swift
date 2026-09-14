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
      addSubview(controller.view)
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  @objc public func configure(_ title: String, symbol: String, prominent: Bool, disabled: Bool,
    loading: Bool, tint: UIColor?, scheme: String, label: String, hint: String, identifier: String) {
    model.title = title
    model.symbol = symbol
    model.prominent = prominent
    model.disabled = disabled
    model.loading = loading
    model.tint = tint
    model.label = label
    model.hint = hint
    model.identifier = identifier
    overrideUserInterfaceStyle = scheme == "dark" ? .dark : scheme == "light" ? .light : .unspecified
  }

  public override func layoutSubviews() { super.layoutSubviews(); host?.view.frame = bounds }
  public override func didMoveToWindow() {
    super.didMoveToWindow()
    guard let host else { return }
    if window == nil {
      host.willMove(toParent: nil)
      host.removeFromParent()
      return
    }
    var responder: UIResponder? = superview
    while let current = responder {
      if let parent = current as? UIViewController {
        if host.parent !== parent {
          host.willMove(toParent: nil)
          host.removeFromParent()
          parent.addChild(host)
          host.didMove(toParent: parent)
        }
        break
      }
      responder = current.next
    }
  }
}
