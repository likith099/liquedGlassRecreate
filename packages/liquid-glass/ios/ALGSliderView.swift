import UIKit

private final class AccessibleGlassSlider: UISlider {
  var adjust: ((Double) -> Void)?
  override func accessibilityIncrement() { adjust?(1) }
  override func accessibilityDecrement() { adjust?(-1) }
}

@objc(ALGSliderView)
public final class ALGSliderView: UIView {
  private let slider = AccessibleGlassSlider()
  private var minimum = 0.0
  private var maximum = 1.0
  private var step = 0.0
  private var controlledValue = 0.0
  private var dragging = false
  private var lastEmitted: Double?
  @objc public var onChange: ((Double) -> Void)?
  @objc public var onStart: ((Double) -> Void)?
  @objc public var onComplete: ((Double) -> Void)?
  @objc public var onCancel: ((Double) -> Void)?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(slider)
    slider.addTarget(self, action: #selector(start), for: .touchDown)
    slider.addTarget(self, action: #selector(change), for: .valueChanged)
    slider.addTarget(self, action: #selector(finish), for: [.touchUpInside, .touchUpOutside])
    slider.addTarget(self, action: #selector(cancel), for: .touchCancel)
    slider.adjust = { [weak self] direction in
      guard let self, self.slider.isEnabled else { return }
      self.onStart?(self.controlledValue)
      let increment = self.step > 0 ? self.step : (self.maximum - self.minimum) / 20
      let value = self.normalized(self.controlledValue + direction * increment)
      self.position(value)
      if value != self.controlledValue { self.onChange?(value) }
      self.onComplete?(value)
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  @objc public func configure(_ value: Double, minimum: Double, maximum: Double, step: Double,
    disabled: Bool, tint: UIColor?, label: String, hint: String, identifier: String) {
    guard minimum.isFinite, maximum.isFinite, value.isFinite, step.isFinite,
      (maximum - minimum).isFinite, maximum > minimum, step >= 0, step <= maximum - minimum else { return }
    if dragging && (disabled || self.minimum != minimum || self.maximum != maximum || self.step != step) { cancel() }
    self.minimum = minimum
    self.maximum = maximum
    self.step = step
    controlledValue = normalized(value)
    slider.isEnabled = !disabled
    slider.minimumTrackTintColor = tint
    slider.accessibilityLabel = label.isEmpty ? nil : label
    slider.accessibilityHint = hint.isEmpty ? nil : hint
    slider.accessibilityIdentifier = identifier
    // UIKit keeps ownership of the thumb during tracking, avoiding JS echo jitter.
    if !dragging { position(controlledValue) }
  }
  private func normalized(_ value: Double) -> Double {
    let clamped = min(maximum, max(minimum, value))
    if clamped == maximum || step == 0 { return clamped }
    return min(maximum, max(minimum, minimum + ((clamped - minimum) / step).rounded() * step))
  }
  private var current: Double { normalized(minimum + Double(slider.value) * (maximum - minimum)) }
  private func position(_ value: Double) {
    slider.value = Float((value - minimum) / (maximum - minimum))
    slider.accessibilityValue = String(format: "%.6g", value)
  }
  @objc private func start() {
    guard slider.isEnabled, !dragging else { return }
    dragging = true
    lastEmitted = current
    onStart?(current)
  }
  @objc private func change() {
    guard slider.isEnabled else { return }
    let value = current
    // Snap only for stepped sliders; preserve UIKit momentum for continuous tracking.
    if step > 0 { position(value) }
    else { slider.accessibilityValue = String(format: "%.6g", value) }
    if value != lastEmitted { lastEmitted = value; onChange?(value) }
    if !dragging { onComplete?(value) }
  }
  @objc private func finish() {
    guard dragging else { return }
    change()
    let value = current
    dragging = false
    onComplete?(value)
  }
  @objc private func cancel() {
    guard dragging else { return }
    dragging = false
    position(controlledValue)
    onCancel?(controlledValue)
  }
  public override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil { cancel() }
  }
  public override func layoutSubviews() { super.layoutSubviews(); slider.frame = bounds }
}
