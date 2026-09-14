export function validateSlider(value: number, minimum: number, maximum: number, step: number) {
  if (![value, minimum, maximum, step, maximum - minimum].every(Number.isFinite)) {
    throw new Error('GlassSlider values and range must be finite numbers.');
  }
  if (maximum <= minimum) throw new Error('GlassSlider maximumValue must exceed minimumValue.');
  if (step < 0 || step > maximum - minimum) throw new Error('GlassSlider step must be between 0 and the range.');
}
export function normalizeSliderValue(value: number, minimum: number, maximum: number, step: number) {
  const clamped = Math.max(minimum, Math.min(maximum, value));
  if (clamped === maximum || step === 0) return clamped;
  return Math.max(minimum, Math.min(maximum, minimum + Math.round((clamped - minimum) / step) * step));
}
