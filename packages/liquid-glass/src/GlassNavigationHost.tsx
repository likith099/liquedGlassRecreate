import React, {useImperativeHandle, useRef, useLayoutEffect, useState, useEffect} from 'react';
import {BackHandler, findNodeHandle, Platform, View, useColorScheme} from 'react-native';
import NativeNavigation, {Commands} from './specs/ALGNavigationNativeComponent';
import {navigationAction, navigationItems, nativeNavigationItems, navigationTitleOptions, navigationColor, navigationBand} from './navigationConfig';
import {resolveScrollTarget, scrollTargetToTop} from './scrollTarget';
import type {GlassNavigationViewProps} from './types';
export default function GlassNavigationHost(props: GlassNavigationViewProps) {
  const {ref, title, largeTitle, titleDisplayMode: _display, titlePosition: _position, titleFont: _font,
    titleTransition: _transition, titleWeight = 'bold', titleView, subtitleView, largeSubtitleView, accessory,
    titleTestID, backTestID: _backID, handlesSystemBack = false, androidCollapsing = false, onBarInsetsChange,
    subtitle, largeSubtitle, scrollViewRef, children, leadingItems: _leading, trailingItems: _trailing, toolbarItems: _toolbar,
    onAction: _action, onBack, backAccessibilityLabel: _backLabel, search, mergingEnabled = false,
    tintColor, contentBackgroundColor, colorScheme = 'system', edgeEffect = 'soft',
    topInset = 'auto', bottomInset = 'auto', style, ...viewProps} = props;
  const systemDark = useColorScheme() === 'dark';
  const dark = colorScheme === 'dark' || (colorScheme === 'system' && systemDark);
  const [tag, setTag] = useState(-1), [eventCount, setEventCount] = useState(0);
  const [metrics, setMetrics] = useState({top: 0, bottom: 0, titleWidth: 160});
  const [heights, setHeights] = useState([0, 44, 24, 24, 0]);
  const host = useRef<React.ElementRef<typeof NativeNavigation>>(null);
  const bound = useRef<unknown>(null);
  const activeSearch = useRef(false);
  const bind = () => {
    const target = resolveScrollTarget(scrollViewRef.current);
    if (target && target !== bound.current) {
      const next = findNodeHandle(target as never) ?? -1;
      if (next > 0) { bound.current = target; setTag(next); }
    }
  };
  useLayoutEffect(() => {
    bind();
    if (bound.current) return;
    // A list's native ref can attach a few frames after this view. Retry briefly
    // instead of waiting for an unrelated re-render to bind the title row and edge.
    let frame = 0, attempts = 0;
    const retry = () => { bind(); if (!bound.current && ++attempts < 30) frame = requestAnimationFrame(retry); };
    frame = requestAnimationFrame(retry);
    return () => cancelAnimationFrame(frame);
  }); // Inspect identity only; don't resolve a native tag or schedule a frame for each keystroke.
  useEffect(() => {
    if (Platform.OS !== 'android' || !handlesSystemBack || !onBack) return;
    const subscription = BackHandler.addEventListener('hardwareBackPress', () => { if (activeSearch.current && host.current) Commands.dismissSearch(host.current); else onBack(); return true; });
    return () => subscription.remove();
  }, [handlesSystemBack, onBack]);
  useImperativeHandle(ref, () => ({
    scrollToTop: (animated = true) => {
      if (Platform.OS === 'android') scrollTargetToTop(scrollViewRef.current, animated);
      if (host.current) Commands.scrollToTop(host.current, animated);
    },
    focusSearch: () => { if (host.current) Commands.focusSearch(host.current); },
    dismissSearch: () => { if (host.current) Commands.dismissSearch(host.current); },
  }), [scrollViewRef]);
  const items = navigationItems(props);
  const edges = typeof edgeEffect === 'string' ? {top: edgeEffect} : edgeEffect;
  const band = typeof edgeEffect === 'object' ? edgeEffect.band : undefined;
  const slots = [children, titleView, subtitleView, largeSubtitleView, accessory];
  return <NativeNavigation {...viewProps} ref={host} style={[{flex: 1}, style]} scrollViewTag={tag}
    configJSON={JSON.stringify({title, largeTitle, ...navigationTitleOptions(props), titleWeight, subtitle, largeSubtitle,
      mergingEnabled, tint: navigationColor(tintColor, dark), background: navigationColor(contentBackgroundColor, dark),
      colorScheme, topEdge: edges.top ?? 'soft', bottomEdge: edges.bottom, topBand: navigationBand(band, dark), hasBack: !!onBack, titleTestID,
      androidCollapsing, topInset, bottomInset, manualInsets: !!onBarInsetsChange,
      slots: slots.map((content, i) => ({present: i === 0 || content != null, height: heights[i]})),
      leading: nativeNavigationItems(items.leading), trailing: nativeNavigationItems(items.trailing), toolbar: nativeNavigationItems(items.toolbar),
      search: search ? {value: search.value, placeholder: search.placeholder, hidesWhenScrolling: search.hidesWhenScrolling ?? true, eventCount,
        placement: search.placement ?? 'stacked', allowsToolbarIntegration: search.allowsToolbarIntegration ?? false,
        active: search.active, scopes: search.scopes?.items, scope: search.scopes?.value,
        autoCapitalize: search.autoCapitalize ?? 'none', returnKeyType: search.returnKeyType ?? 'search', cancelLabel: search.cancelLabel,
        testID: search.testID ?? 'navigation-search'} : undefined})}
    onNavigationInsets={({nativeEvent: next}) => {
      setMetrics(old => old.top === next.top && old.bottom === next.bottom && old.titleWidth === next.titleWidth ? old : next);
      onBarInsetsChange?.({top: next.top, bottom: next.bottom});
    }}
    onNavigationAction={({nativeEvent: {id, action}}) => navigationAction(props, id, action)}
    onNavigationSearch={({nativeEvent: event}) => {
      if (event.kind === 'change') { setEventCount(event.eventCount); search?.onChangeText(event.text); }
      else if (event.kind === 'submit') search?.onSubmit?.(event.text);
      else if (event.kind === 'cancel') search?.onCancel?.();
      else if (event.kind === 'scope') search?.scopes?.onChange(event.text);
      else { const active = event.kind === 'focus'; activeSearch.current = active; search?.onFocusChange?.(active); search?.onActiveChange?.(active); }
    }}>
    {slots.map((content, index) => <View key={index} collapsable={false} pointerEvents="box-none"
      onLayout={index === 0 ? bind : event => {
        const height = event.nativeEvent.layout.height;
        setHeights(old => old[index] === height ? old : old.map((v, i) => i === index ? height : v));
      }}
      style={index === 0 ? {position: 'absolute', left: 0, right: 0,
        top: Platform.OS === 'android' ? metrics.top : 0, bottom: Platform.OS === 'android' ? metrics.bottom : 0}
        : {position: 'absolute', left: 0, ...(index === 1 || index === 2 ? {width: metrics.titleWidth} : {right: 0})}}>
      {content}
    </View>)}
  </NativeNavigation>;
}
