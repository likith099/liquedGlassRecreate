import React, {useMemo, useReducer} from 'react';
import {useWindowDimensions, type ColorValue} from 'react-native';
import adaptiveHeight from './adaptiveHeight';
import NativeTabs from './specs/ALGTabsNativeComponent';
import {resolveTabImage, staticColor, validateTabs} from './validateTabs';
import type {GlassTabBarProps, GlassTabItem} from './types';

/** The items as native code reads them: resolved images and ARGB colours. */
function nativeItems(items: readonly GlassTabItem[], inactiveTintColor: ColorValue | undefined) {
  const barInactive = staticColor(inactiveTintColor, 'inactiveTintColor');
  return JSON.stringify(items.map(({image, selectedImage, selectedTintColor, inactiveTintColor: inactive, ...item}) => {
    const normal = resolveTabImage(image, 'image');
    const selected = resolveTabImage(selectedImage, 'selectedImage');
    return {...item, image: normal.name, imageSource: normal.source, selectedImage: selected.name,
      selectedImageSource: selected.source, selectedTint: staticColor(selectedTintColor, 'selectedTintColor'),
      inactiveTint: staticColor(inactive, 'inactiveTintColor') ?? barInactive};
  }));
}

export default function GlassTabBar({items, value, onValueChange, onTabReselect, disabled = false,
  tintColor, inactiveTintColor, androidBackgroundColor, androidIndicatorColor, testID, style,
  accessibilityState: _state, ...props}: GlassTabBarProps) {
  const {fontScale} = useWindowDimensions();
  validateTabs(items, value);
  const itemsJSON = useMemo(() => nativeItems(items, inactiveTintColor), [items, inactiveTintColor]);
  const [selectionRevision, reconcile] = useReducer((revision: number) => (revision + 1) & 0x7fffffff, 0);
  return <NativeTabs {...props} accessible={false} style={[{height: adaptiveHeight(80, 24, fontScale), minWidth: 180}, style]}
    itemsJSON={itemsJSON} selectedValue={value ?? ''} selectionRevision={selectionRevision}
    disabled={disabled || items.length === 0} glassTint={tintColor} androidBackgroundColor={androidBackgroundColor}
    androidIndicatorColor={androidIndicatorColor} controlTestID={testID}
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
