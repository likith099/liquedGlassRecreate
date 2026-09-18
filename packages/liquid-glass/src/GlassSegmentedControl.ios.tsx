import React from 'react';
import {useWindowDimensions} from 'react-native';
import adaptiveHeight from './adaptiveHeight';
import NativeSegmented from './specs/ALGSegmentedNativeComponent';
import Fallback from './fallback/GlassSegmentedControl';
import {isLiquidGlassSupported} from './support';
import {validateSegments} from './validateSegments';
import type {GlassSegmentedControlProps} from './types';
export default function GlassSegmentedControl(props: GlassSegmentedControlProps) {
  const {fontScale} = useWindowDimensions();
  validateSegments(props.options, props.value);
  if (fontScale > 1.3 || props.forceFallback || !isLiquidGlassSupported()) return <Fallback {...props} />;
  const {options, value, onValueChange, tintColor, forceFallback: _fallback, accessibilityLabel,
    accessibilityState: _state, testID, style, ...nativeProps} = props;
  return <NativeSegmented {...nativeProps} style={[{height: adaptiveHeight(52, 18, fontScale)}, style]} accessible={false}
    optionsJSON={JSON.stringify(options)} selectedValue={value ?? ''} glassTint={tintColor}
    controlLabel={accessibilityLabel} controlTestID={testID} onSelectionChange={event => {
      const option = options.find(item => item.value === event.nativeEvent.value);
      if (!props.disabled && option && !option.disabled && option.value !== value) onValueChange(option.value);
    }} />;
}
