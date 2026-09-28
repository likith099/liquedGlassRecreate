import UIKit

/// A system search field on material: glass on iOS 26, system blur on 15–25, and an opaque
/// fill under Reduce Transparency or forceFallback. UIKit owns editing, the clear button and
/// the keyboard; React owns the text through `value`.
@objc(ALGSearchFieldView)
public final class ALGSearchFieldView: UIView, UITextFieldDelegate {
  private let surface = UIVisualEffectView()
  private let field = UISearchTextField()
  private var eventCount = 0
  private var forceFallback = false
  @objc public var onChangeText: ((String, Int) -> Void)?
  @objc public var onSubmit: ((String) -> Void)?
  @objc public var onFocus: (() -> Void)?
  @objc public var onBlur: (() -> Void)?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(surface)
    surface.clipsToBounds = true
    surface.contentView.addSubview(field)
    // The surface draws the capsule; remove the field's own rounded background.
    field.borderStyle = .none
    field.backgroundColor = .clear
    field.returnKeyType = .search
    field.adjustsFontForContentSizeCategory = true
    field.delegate = self
    field.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
    // VoiceOver announces a search field, not a plain text field.
    field.accessibilityTraits.insert(.searchField)
    NotificationCenter.default.addObserver(self, selector: #selector(updateMaterial),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  deinit { NotificationCenter.default.removeObserver(self) }

  @objc public func configure(_ value: String, mostRecentEventCount: Int, placeholder: String, disabled: Bool,
    tint: UIColor?, scheme: String, forceFallback: Bool, label: String, identifier: String) {
    // Apply React's value unless newer native edits are still on their way to React.
    if mostRecentEventCount >= eventCount, field.text != value, field.markedTextRange == nil {
      field.text = value
    }
    field.placeholder = placeholder
    field.isEnabled = !disabled
    field.tintColor = tint
    field.accessibilityLabel = label.isEmpty ? placeholder : label
    field.accessibilityIdentifier = identifier
    overrideUserInterfaceStyle = scheme == "dark" ? .dark : scheme == "light" ? .light : .unspecified
    if self.forceFallback != forceFallback || surface.effect == nil && surface.backgroundColor == nil {
      self.forceFallback = forceFallback
      updateMaterial()
    }
  }

  @objc private func updateMaterial() {
    surface.backgroundColor = nil
    if UIAccessibility.isReduceTransparencyEnabled || forceFallback {
      surface.effect = nil
      surface.backgroundColor = .tertiarySystemFill
    } else if #available(iOS 26.0, *) {
      surface.effect = UIGlassEffect(style: .regular)
    } else {
      surface.effect = UIBlurEffect(style: .systemMaterial)
    }
    setNeedsLayout()
  }

  @objc public func focusField() { field.becomeFirstResponder() }
  @objc public func blurField() { field.resignFirstResponder() }

  @objc private func editingChanged() {
    eventCount += 1
    onChangeText?(field.text ?? "", eventCount)
  }
  public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    onSubmit?(textField.text ?? "")
    textField.resignFirstResponder()
    return false
  }
  public func textFieldDidBeginEditing(_ textField: UITextField) { onFocus?() }
  public func textFieldDidEndEditing(_ textField: UITextField) { onBlur?() }

  public override func layoutSubviews() {
    super.layoutSubviews()
    surface.frame = bounds
    if #available(iOS 26.0, *) { surface.cornerConfiguration = .capsule() }
    surface.layer.cornerRadius = bounds.height / 2
    field.frame = bounds.insetBy(dx: 10, dy: 0)
  }
}
