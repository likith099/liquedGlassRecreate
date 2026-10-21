import React, {useMemo, useReducer, useLayoutEffect, useState} from 'react';
import {View, Platform, findNodeHandle, useWindowDimensions, type ColorValue} from 'react-native';
import adaptiveHeight from './adaptiveHeight';
import {isLiquidGlassSupported} from './support';
import NativeTabs from './specs/ALGTabsNativeComponent';
import {resolveTabImage, staticColor, validateTabs} from './validateTabs';
import type {GlassTabBarProps, GlassTabItem} from './types';

/** The items as native code reads them: resolved images and ARGB colours. */
function nativeItems(items: readonly GlassTabItem[], inactiveTintColor: ColorValue | undefined) {
  const barInactive = staticColor(inactiveTintColor, 'inactiveTintColor');
  return JSON.stringify(items.map(({image, selectedImage, selectedTintColor, inactiveTintColor: inactive, scrollViewRef: _scrollViewRef,
    badge, badgeColor, badgeTextColor, ...item}) => {
    const normal = resolveTabImage(image, 'image');
    const selected = resolveTabImage(selectedImage, 'selectedImage');
    // Native reads a count, 'dot', or {text}; the count/text forms share the controls' shape.
    const nativeBadge = typeof badge === 'object' && badge !== null
      ? 'count' in badge ? badge.count : 'text' in badge ? {text: badge.text} : 'dot'
      : badge;
    return {...item, badge: nativeBadge, badgeColor: staticColor(badgeColor, 'badgeColor'),
      badgeTextColor: staticColor(badgeTextColor, 'badgeTextColor'),
      image: normal.name, imageSource: normal.source, selectedImage: selected.name,
      selectedImageSource: selected.source, selectedTint: staticColor(selectedTintColor, 'selectedTintColor'),
      inactiveTint: staticColor(inactive, 'inactiveTintColor') ?? barInactive};
  }));
}

export default function GlassTabBar({items, value, onValueChange, onTabReselect, disabled = false,
  minimizeBehavior = 'never', bottomAccessory, bottomAccessoryHeight = 44, tintColor, inactiveTintColor, androidBackgroundColor, androidIndicatorColor, testID, style,
  accessibilityState: _state, ...props}: GlassTabBarProps) {
  const [scrollViewTagsJSON, setTags] = useState('{}');
  useLayoutEffect(() => {
    const tags = JSON.stringify(Object.fromEntries(items.map(item => [item.id, item.scrollViewRef?.current ? findNodeHandle(item.scrollViewRef.current as never) ?? -1 : -1])));
    setTags(current => current === tags ? current : tags);
  });
  const nativeAccessory = isLiquidGlassSupported();
  const {fontScale} = useWindowDimensions();
  validateTabs(items, value);
  const itemsJSON = useMemo(() => nativeItems(items, inactiveTintColor), [items, inactiveTintColor]);
  const [selectionRevision, reconcile] = useReducer((revision: number) => (revision + 1) & 0x7fffffff, 0);
  const tabs = <NativeTabs {...props} accessible={false} style={[{height: adaptiveHeight(80, 24, fontScale), minWidth: 180}, style]}
    minimizeBehavior={minimizeBehavior} scrollViewTagsJSON={scrollViewTagsJSON} hasAccessory={nativeAccessory && !!bottomAccessory}
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
    }}>{nativeAccessory && bottomAccessory ? <View style={{height: bottomAccessoryHeight, width: '100%'}}>{bottomAccessory}</View> : null}</NativeTabs>;
  return !nativeAccessory && bottomAccessory ? <View><View style={{height: bottomAccessoryHeight}}>{bottomAccessory}</View>{tabs}</View> : tabs;
}
