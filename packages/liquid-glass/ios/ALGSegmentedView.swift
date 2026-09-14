import UIKit

private struct SegmentOption: Decodable {
  let value: String
  let label: String
  let disabled: Bool?
}

/// Native segmented-control interaction and selected-thumb rendering belong to UIKit.
@objc(ALGSegmentedView)
public final class ALGSegmentedView: UIView {
  private let control = UISegmentedControl(items: [])
  private var options: [SegmentOption] = []
  private var lastJSON = ""
  private var selectedValue = ""
  @objc public var onSelectionChange: ((String) -> Void)?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(control)
    control.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  @objc public func configure(_ json: String, selectedValue: String, disabled: Bool,
    tint: UIColor?, scheme: String, label: String, identifier: String) {
    if lastJSON != json {
      options = (try? JSONDecoder().decode([SegmentOption].self, from: Data(json.utf8))) ?? []
      control.removeAllSegments()
      for (index, option) in options.enumerated() {
        control.insertSegment(withTitle: option.label, at: index, animated: false)
        control.setEnabled(!(option.disabled ?? false), forSegmentAt: index)
      }
      lastJSON = json
    }
    self.selectedValue = selectedValue
    control.selectedSegmentIndex = options.firstIndex { $0.value == selectedValue } ?? UISegmentedControl.noSegment
    control.isEnabled = !disabled
    control.selectedSegmentTintColor = tint
    control.accessibilityLabel = label.isEmpty ? nil : label
    control.accessibilityIdentifier = identifier
    overrideUserInterfaceStyle = scheme == "dark" ? .dark : scheme == "light" ? .light : .unspecified
  }

  @objc private func selectionChanged() {
    let index = control.selectedSegmentIndex
    guard control.isEnabled, options.indices.contains(index), !(options[index].disabled ?? false) else { return }
    let next = options[index].value
    // React remains authoritative, including when a callback declines a change.
    control.selectedSegmentIndex = options.firstIndex { $0.value == selectedValue } ?? UISegmentedControl.noSegment
    if next != selectedValue { onSelectionChange?(next) }
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    control.frame = bounds.insetBy(dx: 0, dy: max(0, (bounds.height - 44) / 2))
  }
}
