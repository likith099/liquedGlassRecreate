import UIKit
/// Shared public menu semantics for standalone menus and navigation bar menus.
enum ALGNativeMenu {
  static func options(inline: Bool, singleSelection: Bool) -> UIMenu.Options {
    var result: UIMenu.Options = inline ? .displayInline : []
    if singleSelection { result.insert(.singleSelection) }; return result
  }
  static func action(id: String, title: String, subtitle: String?, image: UIImage?, disabled: Bool,
                     destructive: Bool, checked: Bool, keepsPresented: Bool, handler: @escaping () -> Void) -> UIAction {
    var attributes: UIMenuElement.Attributes = []
    if disabled { attributes.insert(.disabled) }; if destructive { attributes.insert(.destructive) }
    if #available(iOS 16.0, *), keepsPresented { attributes.insert(.keepsMenuPresented) }
    let action = UIAction(title: title, image: image, identifier: UIAction.Identifier(id), attributes: attributes, state: checked ? .on : .off) { _ in handler() }
    if #available(iOS 16.0, *) { action.subtitle = subtitle }; return action
  }
}
