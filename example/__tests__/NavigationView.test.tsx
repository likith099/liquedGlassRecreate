import React from 'react';
import {Text} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import GlassNavigationView from '../../packages/liquid-glass/src/GlassNavigationView.ios';
import AndroidNavigation from '../../packages/liquid-glass/src/GlassNavigationView.tsx';
import GlassProgressiveBlur from '../../packages/liquid-glass/src/GlassProgressiveBlur';
import NativeNavigation from '../../packages/liquid-glass/src/specs/ALGNavigationNativeComponent';
import NativeEdge from '../../packages/liquid-glass/src/specs/ALGScrollEdgeNativeComponent';
import {navigationAction, navigationItems, navigationTitleOptions, nativeNavigationItems, navigationColor} from '../../packages/liquid-glass/src/navigationConfig';
import {resolveScrollTarget, scrollTargetToTop} from '../../packages/liquid-glass/src/scrollTarget';
import type {GlassNavigationViewProps} from '../../packages/liquid-glass/src/types';
const base: GlassNavigationViewProps = {title: 'Contacts', scrollViewRef: {current: null}};
test('IDs are unique across native placements and disabled or absent menu actions cannot fire', () => {
  const onAction = jest.fn(), onMenu = jest.fn(), onBack = jest.fn();
  const item = {id: 'more', accessibilityLabel: 'More', menu: {items: [{id: 'allowed', title: 'Allowed'}, {id: 'blocked', title: 'Blocked', disabled: true}], onAction: onMenu}};
  const props = {...base, onAction, onBack, leadingItems: [{id: 'disabled', accessibilityLabel: 'Disabled', disabled: true}], trailingItems: [item]};
  expect(() => navigationItems({...props, toolbarItems: [item]})).toThrow('unique');
  navigationAction(props, 'disabled', ''); navigationAction(props, 'missing', '');
  navigationAction(props, 'more', 'blocked'); navigationAction(props, 'more', 'missing');
  expect(onAction).not.toHaveBeenCalled(); expect(onMenu).not.toHaveBeenCalled();
  navigationAction(props, 'more', 'allowed'); expect(onMenu).toHaveBeenCalledWith('allowed');
  navigationAction(props, '__navigation_back', ''); expect(onBack).toHaveBeenCalledTimes(1);
});
test('controlled native search acknowledges edit counts and routes focus, cancel and submission separately', () => {
  const onChangeText = jest.fn(), onSubmit = jest.fn(), onCancel = jest.fn(), onFocusChange = jest.fn();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassNavigationView {...base} search={{value: '', onChangeText, onSubmit, onCancel, onFocusChange}}><Text>List</Text></GlassNavigationView>);});
  const host = () => tree.root.findByType(NativeNavigation as never);
  for (const kind of ['change', 'focus', 'submit', 'cancel', 'blur']) {
    act(() => host().props.onNavigationSearch({nativeEvent: {kind, text: 'Maya', eventCount: 4}}));
  }
  expect(JSON.parse(host().props.configJSON).search.eventCount).toBe(4);
  expect(onChangeText).toHaveBeenCalledTimes(1); expect(onChangeText).toHaveBeenCalledWith('Maya');
  expect(onSubmit).toHaveBeenCalledWith('Maya'); expect(onCancel).toHaveBeenCalledTimes(1);
  expect(onFocusChange.mock.calls).toEqual([[true], [false]]);
  act(() => tree.unmount());
});
test('Android forwards text actions to its Material navigation host', () => {
  let tree!: Renderer.ReactTestRenderer;
  const onAction = jest.fn();
  act(() => {tree = Renderer.create(<AndroidNavigation {...base} onAction={onAction} toolbarItems={[{id: 'done', title: 'Done', accessibilityLabel: 'Done'}]} />);});
  const host = tree.root.findByType(NativeNavigation as never);
  expect(JSON.parse(host.props.configJSON).toolbar[0].title).toBe('Done');
  act(() => host.props.onNavigationAction({nativeEvent: {id: 'done', action: ''}})); expect(onAction).toHaveBeenCalledWith('done');
  act(() => tree.unmount());
});
test('standalone blur accepts either edge without requiring title, actions or header sizing', () => {
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassProgressiveBlur scrollViewRef={{current: null}} edge="bottom" fallback="blur" />);});
  const props = tree.root.findByType(NativeEdge as never).props;
  expect(props.edge).toBe('bottom'); expect(props.effectStyle).toBe('progressive'); expect(props.fallbackMode).toBe('blur');
  expect(props.style).toBeUndefined(); expect(tree.root.findAllByType(Text)).toHaveLength(0);
  act(() => tree.unmount());
});

test('inlineLarge protects leading actions, morph implies leading, and a custom title wins', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  expect(navigationTitleOptions({...base, onBack: () => {}, titleDisplayMode: 'inlineLarge'}).titleDisplayMode).toBe('large');
  expect(navigationTitleOptions({...base, onBack: () => {}, titleDisplayMode: 'inlineLarge', titleTransition: 'morph'})).toMatchObject({titleDisplayMode: 'inlineLarge', titlePosition: 'leading'});
  expect(navigationTitleOptions({...base, titleTransition: 'morph', titleView: <Text>Avatar</Text>}).titleTransition).toBe('native');
  warn.mockRestore();
});
test('SectionList responder, FlashList offset and direct ScrollView use public ref methods', () => {
  const scrollTo = jest.fn(), scrollToOffset = jest.fn();
  const scroll = {scrollTo};
  const section = {getScrollResponder: () => scroll};
  expect(resolveScrollTarget({getNativeScrollRef: () => section})).toBe(scroll);
  scrollTargetToTop(section, false); expect(scrollTo).toHaveBeenCalledWith({y: 0, animated: false});
  scrollTargetToTop({scrollToOffset}, true); expect(scrollToOffset).toHaveBeenCalledWith({offset: 0, animated: true});
});
test('edge ownership, search localization, slots and settled insets serialize independently', () => {
  let tree!: Renderer.ReactTestRenderer;
  const onInsets = jest.fn(), onScope = jest.fn();
  act(() => { tree = Renderer.create(<GlassNavigationView {...base} edgeEffect={{top: 'hard'}} onBarInsetsChange={onInsets}
    titleView={<Text>Custom</Text>} accessory={<Text>Filter</Text>}
    search={{value: '', onChangeText: () => {}, placement: 'integratedButton', scopes: {items: [{id: 'a', title: 'A'}], value: 'a', onChange: onScope}}} />); });
  const host = tree.root.findByType(NativeNavigation as never), config = JSON.parse(host.props.configJSON);
  expect(config.topEdge).toBe('hard'); expect(config.bottomEdge).toBeUndefined();
  expect(config.search.placeholder).toBeUndefined(); expect(config.search.placement).toBe('integratedButton');
  expect(config.slots[1].present).toBe(true); expect(config.slots[4].present).toBe(true);
  act(() => host.props.onNavigationInsets({nativeEvent: {top: 100, bottom: 34, titleWidth: 180}}));
  expect(onInsets).toHaveBeenCalledWith({top: 100, bottom: 34});
  act(() => host.props.onNavigationSearch({nativeEvent: {kind: 'scope', text: 'a', eventCount: 0}}));
  expect(onScope).toHaveBeenCalledWith('a'); act(() => tree.unmount());
});
test('badge-only updates retain other item config and explicit spacers', () => {
  const a = {id: 'a', accessibilityLabel: 'A', systemItem: 'done' as const};
  const before = nativeNavigationItems([a, {id: 'space', spacer: 'flexible'}, {id: 'b', accessibilityLabel: 'B', badge: {count: 1}}]);
  const after = nativeNavigationItems([a, {id: 'space', spacer: 'flexible'}, {id: 'b', accessibilityLabel: 'B', badge: {count: 2}}]);
  expect(before[0]).toEqual(after[0]); expect(before[1]).toEqual(after[1]); expect(before[2]).not.toEqual(after[2]);
  expect(navigationColor({light: '#FFFFFF', dark: '#000000'}, true)).toBeDefined();
});
test('production drops invalid IDs across placements without throwing', () => {
  const runtime = globalThis as typeof globalThis & {__DEV__: boolean};
  const original = runtime.__DEV__, warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  try {
    runtime.__DEV__ = false;
    const entry = {id: 'same', accessibilityLabel: 'Same'};
    expect(navigationItems({...base, leadingItems: [entry], trailingItems: [entry]}).trailing).toEqual([]);
  } finally { runtime.__DEV__ = original; warn.mockRestore(); }
});
test('independent hard blur retains the full native edge marker', () => {
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassProgressiveBlur scrollViewRef={{current: null}} effect="hard" />);});
  expect(tree.root.findByType(NativeEdge as never).props.effectStyle).toBe('progressiveHard');
  act(() => tree.unmount());
});
