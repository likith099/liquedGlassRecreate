import React from 'react';
import {AccessibilityInfo, ScrollView, StyleSheet, Text, View} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import {GlassToastProvider, useGlassToast, type GlassToastController} from '../../packages/liquid-glass/src/GlassToast';
import GlassBadge from '../../packages/liquid-glass/src/GlassBadge';
import GlassScrollEdge from '../../packages/liquid-glass/src/GlassScrollEdge.ios';
import GlassScrollEdgeGeneric from '../../packages/liquid-glass/src/GlassScrollEdge.tsx';
import GlassSearchField from '../../packages/liquid-glass/src/GlassSearchField.ios';
import NativeScrollEdge from '../../packages/liquid-glass/src/specs/ALGScrollEdgeNativeComponent';
import * as SearchSpec from '../../packages/liquid-glass/src/specs/ALGSearchFieldNativeComponent';
import type {GlassSearchFieldHandle} from '../../packages/liquid-glass/src/types';

const noop = () => {};
beforeEach(() => {
  jest.spyOn(AccessibilityInfo, 'isReduceMotionEnabled').mockResolvedValue(true);
  jest.spyOn(AccessibilityInfo, 'isReduceTransparencyEnabled').mockResolvedValue(false);
});
afterEach(() => { jest.useRealTimers(); jest.restoreAllMocks(); });

test('toasts announce, replace each other and hide after their duration', async () => {
  jest.useFakeTimers();
  const announce = jest.spyOn(AccessibilityInfo, 'announceForAccessibility').mockImplementation(noop);
  let controller!: GlassToastController;
  function Capture() { controller = useGlassToast(); return null; }
  let tree!: Renderer.ReactTestRenderer;
  await act(async () => {tree = Renderer.create(<GlassToastProvider><Capture /></GlassToastProvider>);});
  act(() => controller.show('Copied', {duration: 1000}));
  expect(announce).toHaveBeenCalledWith('Copied');
  expect(tree.root.findByType(GlassBadge).findByType(Text).props.children).toBe('Copied');
  act(() => controller.show('Saved', {duration: 1000}));
  expect(tree.root.findAllByType(GlassBadge)).toHaveLength(1);
  expect(tree.root.findByType(GlassBadge).findByType(Text).props.children).toBe('Saved');
  act(() => jest.advanceTimersByTime(999));
  expect(tree.root.findAllByType(GlassBadge)).toHaveLength(1);
  act(() => jest.advanceTimersByTime(1));
  expect(tree.root.findAllByType(GlassBadge)).toHaveLength(0);
  act(() => tree.unmount());
});

test('useGlassToast outside a provider explains the missing provider', () => {
  function Orphan() { useGlassToast(); return null; }
  jest.spyOn(console, 'error').mockImplementation(noop);
  expect(() => act(() => { Renderer.create(<Orphan />); })).toThrow('GlassToastProvider');
});

test('the scroll edge passes the mounted ScrollView tag to native code', () => {
  function Screen() {
    const scroll = React.useRef<React.ComponentRef<typeof ScrollView>>(null);
    return <View><ScrollView ref={scroll} /><GlassScrollEdge scrollViewRef={scroll} edge="bottom" effectStyle="soft" /></View>;
  }
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Screen />);});
  const props = tree.root.findByType(NativeScrollEdge as never).props;
  expect(props.edge).toBe('bottom');
  expect(props.effectStyle).toBe('soft');
  expect(typeof props.scrollViewTag).toBe('number');
  act(() => tree.unmount());
});

test('the Android scroll edge draws a gradient scrim toward its edge', () => {
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassScrollEdgeGeneric scrollViewRef={{current: null}} fallbackColor="#101820" />);});
  const scrim = tree.root.findAll(node => node.props.pointerEvents === 'none')[0];
  expect(StyleSheet.flatten(scrim.props.style).experimental_backgroundImage).toBe('linear-gradient(to top, #101820, transparent)');
  act(() => tree.unmount());
});

test('the search field reports text with its event count and ignores edits while disabled', () => {
  const onChangeText = jest.fn();
  const focus = jest.spyOn(SearchSpec.Commands, 'focus').mockImplementation(noop);
  const ref = React.createRef<GlassSearchFieldHandle>();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassSearchField ref={ref} value="" onChangeText={onChangeText} />);});
  const host = () => tree.root.findByType(SearchSpec.default as never);
  expect(host().props.placeholder).toBe('Search');
  expect(host().props.mostRecentEventCount).toBe(0);
  act(() => host().props.onSearchChange({nativeEvent: {text: 'pl', eventCount: 2}}));
  expect(onChangeText).toHaveBeenCalledWith('pl');
  expect(host().props.mostRecentEventCount).toBe(2);
  act(() => ref.current?.focus());
  expect(focus).toHaveBeenCalledTimes(1);
  act(() => tree.update(<GlassSearchField value="pl" disabled onChangeText={onChangeText} />));
  act(() => host().props.onSearchChange({nativeEvent: {text: 'plu', eventCount: 3}}));
  expect(onChangeText).toHaveBeenCalledTimes(1);
  expect(host().props.mostRecentEventCount).toBe(3);
  act(() => tree.unmount());
});
