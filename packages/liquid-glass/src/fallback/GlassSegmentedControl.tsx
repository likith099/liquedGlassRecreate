import React from 'react';
import {Pressable, Text, View, useColorScheme} from 'react-native';
import type {GlassSegmentedControlProps} from '../types';
import {validateSegments} from '../validateSegments';
export default function GlassSegmentedControl({options, value, onValueChange, disabled, tintColor,
  colorScheme = 'system', forceFallback: _fallback, style, testID, ...props}: GlassSegmentedControlProps) {
  validateSegments(options, value);
  const system = useColorScheme();
  const dark = (colorScheme === 'system' ? system : colorScheme) === 'dark';
  return <View {...props} testID={testID} accessible={false}
    style={[{flexDirection: 'row', alignItems: 'stretch', backgroundColor: dark ? '#242630' : '#E7E7EE', borderRadius: 16, padding: 4}, style]}>
    {options.map(option => {
      const inactive = !!(disabled || option.disabled);
      const selected = option.value === value;
      return <Pressable key={option.value} testID={testID ? `${testID}-${option.value}` : undefined}
        accessibilityRole="radio" accessibilityLabel={option.label}
        accessibilityState={{selected, checked: selected, disabled: inactive}} disabled={inactive}
        android_ripple={{color: '#80808040', foreground: true}}
        onPress={() => {if (!inactive && !selected) onValueChange(option.value);}}
        style={{flex: 1, minHeight: 48, padding: 8, alignItems: 'center', justifyContent: 'center', borderRadius: 12,
          overflow: 'hidden', opacity: inactive ? 0.4 : 1, backgroundColor: selected ? tintColor ?? (dark ? '#4B4D5A' : '#FFFFFF') : 'transparent'}}>
        <Text style={{fontSize: 14, fontWeight: selected ? '700' : '500', textAlign: 'center', color: dark ? '#F4F4FA' : '#242630'}}>{option.label}</Text>
      </Pressable>;
    })}
  </View>;
}
