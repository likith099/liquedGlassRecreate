import React, {useReducer} from 'react';
import {useWindowDimensions} from 'react-native';
import adaptiveHeight from './adaptiveHeight';
import NativeTabs from './specs/ALGTabsNativeComponent';
import {validateTabs} from './validateTabs';
import type {GlassTabBarProps} from './types';

export default function GlassTabBar({items, value, onValueChange, onTabReselect, disabled = false,
  tintColor, testID, style, accessibilityState: _state, ...props}: GlassTabBarProps) {
  const {fontScale} = useWindowDimensions();
  validateTabs(items, value);
  const [selectionRevision, reconcile] = useReducer((revision: number) => (revision + 1) & 0x7fffffff, 0);
  return <NativeTabs {...props} accessible={false} style={[{height: adaptiveHeight(80, 24, fontScale), minWidth: 180}, style]}
    itemsJSON={JSON.stringify(items)} selectedValue={value ?? ''} selectionRevision={selectionRevision}
    disabled={disabled || items.length === 0} glassTint={tintColor} controlTestID={testID}
    onSelectionChange={event => {
      // A native tap may select provisionally. Always send a prop transaction,
      // even if React rejects the request and the controlled value is unchanged.
      reconcile();
      const item = items.find(candidate => candidate.id === event.nativeEvent.id);
      if (disabled || !item || item.disabled) return;
      if (item.id === value) onTabReselect?.(item.id);
      else onValueChange(item.id);
    }} />;
}
