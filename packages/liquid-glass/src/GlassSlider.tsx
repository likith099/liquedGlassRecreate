import React, {useState} from 'react';
import NativeSlider from './specs/ALGSliderNativeComponent';
import {normalizeSliderValue, validateSlider} from './sliderMath';
import type {GlassSliderProps} from './types';
export default function GlassSlider({value, minimumValue = 0, maximumValue = 1, step = 0,
  disabled, tintColor, onValueChange, onSlidingStart, onSlidingComplete, onSlidingCancel,
  accessibilityLabel, accessibilityHint, accessibilityState: _state, testID, style, ...props}: GlassSliderProps) {
  validateSlider(value, minimumValue, maximumValue, step);
  const [revision, setRevision] = useState(0);
  const normalize = (next: number) => normalizeSliderValue(next, minimumValue, maximumValue, step);
  const reconcile = () => setRevision(previous => (previous + 1) % 2147483647);
  return <NativeSlider {...props} style={[{height: 52}, style]} accessible={false}
    value={normalize(value)} minimumValue={minimumValue} maximumValue={maximumValue} step={step}
    disabled={disabled} glassTint={tintColor} revision={revision} controlLabel={accessibilityLabel}
    controlHint={accessibilityHint} controlTestID={testID}
    onSliderChange={event => {if (!disabled) onValueChange(normalize(event.nativeEvent.value));}}
    onSliderStart={event => {if (!disabled) onSlidingStart?.(normalize(event.nativeEvent.value));}}
    onSliderComplete={event => {
      // Also force native reconciliation if the parent deliberately keeps the same value.
      reconcile();
      if (!disabled) onSlidingComplete?.(normalize(event.nativeEvent.value));
    }}
    onSliderCancel={event => {reconcile(); onSlidingCancel?.(normalize(event.nativeEvent.value));}} />;
}
