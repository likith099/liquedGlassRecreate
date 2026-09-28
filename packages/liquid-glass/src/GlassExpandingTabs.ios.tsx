import React from 'react';
import {processColor, useWindowDimensions} from 'react-native';
import adaptiveHeight from './adaptiveHeight';
import NativeExpandingTabs from './specs/ALGExpandingTabsNativeComponent';
import {validateExpandingTabs} from './validateExpandingTabs';
import type {GlassExpandingTabsProps} from './types';

/**
 * SwiftUI icon pills. Each pill animates one progress value: its width, the label revealed from
 * the icon, and the icon and label colour all follow it, with no overshoot. Glass on iOS 26.
 * Reduce Motion changes selection instantly. The row scrolls when it overflows.
 */
export default function GlassExpandingTabs({options, value, onValueChange, onReselect, material = 'glass',
  mergingEnabled = false, contentInset = 16, tintColor, disabled = false, accessibilityState: _state, testID,
  style, ...props}: GlassExpandingTabsProps) {
  const {fontScale} = useWindowDimensions();
  validateExpandingTabs(options, value);
  // The pill height grows with the label line; keep a 44 pt minimum touch target.
  return <NativeExpandingTabs {...props} accessible={false} style={[{height: adaptiveHeight(44, 20, fontScale)}, style]}
    optionsJSON={JSON.stringify(options.map(option => ({value: option.value, label: option.label,
      systemImage: option.systemImage, disabled: option.disabled,
      tint: option.tintColor === undefined ? undefined : processColor(option.tintColor)})))}
    selectedValue={value} disabled={disabled} material={material} mergingEnabled={mergingEnabled}
    contentInset={contentInset}
    glassTint={tintColor} controlTestID={testID}
    onSelectionChange={event => {
      const option = options.find(item => item.value === event.nativeEvent.value);
      if (disabled || !option || option.disabled) return;
      if (option.value === value) onReselect?.(option.value);
      else onValueChange(option.value);
    }} />;
}
