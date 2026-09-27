import React from 'react';
import {AccessibilityInfo, Dimensions, PlatformColor, StyleSheet, Text, View} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import GlassBadge from '../../packages/liquid-glass/src/GlassBadge';
import GlassIconButton from '../../packages/liquid-glass/src/GlassIconButton';
import GlassView from '../../packages/liquid-glass/src/GlassView';
import GlassSegmentedControl from '../../packages/liquid-glass/src/GlassSegmentedControl.ios';
import SegmentedFallback from '../../packages/liquid-glass/src/fallback/GlassSegmentedControl';
import NativeSegmented from '../../packages/liquid-glass/src/specs/ALGSegmentedNativeComponent';
import NativeMenu from '../../packages/liquid-glass/src/specs/ALGMenuNativeComponent';
import {segmentLabel, validateSegments} from '../../packages/liquid-glass/src/validateSegments';

let mockGlassSupported = false;
jest.mock('../../packages/liquid-glass/src/support', () => ({isLiquidGlassSupported: () => mockGlassSupported}));
let mockReduceTransparency = false;
beforeEach(() => {
  jest.spyOn(AccessibilityInfo, 'isReduceTransparencyEnabled').mockImplementation(() => Promise.resolve(mockReduceTransparency));
});
afterEach(() => { mockGlassSupported = false; mockReduceTransparency = false; jest.restoreAllMocks(); });

const noop = () => {};

test('GlassBadge tints blur below iOS 26, leaves glass clear unless tintGlass, and uses solidColor when solid', async () => {
  let tree!: Renderer.ReactTestRenderer;
  await act(async () => {tree = Renderer.create(<GlassBadge tintColor="#F57C00" solidColor="#333333">New</GlassBadge>);});
  expect(tree.root.findByType(GlassView).props.tintColor).toBe('#F57C00');
  expect(tree.root.findByType(Text).props.children).toBe('New');
  expect(tree.root.findByType(GlassView).props.accessibilityLabel).toBe('New');
  mockGlassSupported = true;
  await act(async () => tree.update(<GlassBadge tintColor="#F57C00">New</GlassBadge>));
  expect(tree.root.findByType(GlassView).props.tintColor).toBeUndefined();
  await act(async () => tree.update(<GlassBadge tintColor="#F57C00" tintGlass>New</GlassBadge>));
  expect(tree.root.findByType(GlassView).props.tintColor).toBe('#F57C00');
  await act(async () => tree.update(<GlassBadge solidColor="#333333" forceFallback>New</GlassBadge>));
  expect(tree.root.findAllByType(GlassView)).toHaveLength(0);
  expect(StyleSheet.flatten(tree.root.findAllByType(View)[0].props.style).backgroundColor).toBe('#333333');
  act(() => tree.unmount());
});

test('GlassBadge uses the solid fill under Reduce Transparency', async () => {
  mockGlassSupported = true;
  mockReduceTransparency = true;
  let tree!: Renderer.ReactTestRenderer;
  await act(async () => {tree = Renderer.create(<GlassBadge solidColor="#101820">Updating</GlassBadge>);});
  expect(tree.root.findAllByType(GlassView)).toHaveLength(0);
  act(() => tree.unmount());
});

test('segments show counts and send each option tint to native code', () => {
  mockGlassSupported = true;
  // Standard text size: above 1.3 the control intentionally uses the React fallback.
  const initial = Dimensions.get('window');
  const standard = {width: 390, height: 844, scale: 3, fontScale: 1};
  act(() => Dimensions.set({window: standard, screen: standard}));
  const options = [{value: 'all', label: 'All', count: 4, tintColor: '#F57C00'},
    {value: 'saved', label: 'Saved', count: 120}];
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassSegmentedControl options={options} value="all" onValueChange={noop} />);});
  const [first, second] = JSON.parse(tree.root.findByType(NativeSegmented as never).props.optionsJSON);
  expect(first.label).toBe('All 4');
  expect(typeof first.tint).toBe('number');
  expect(second.label).toBe('Saved 99+');
  expect(second.tint).toBeUndefined();
  act(() => tree.unmount());
  act(() => Dimensions.set({window: initial, screen: initial}));
});

test('the segmented fallback uses the selected option tint and counted labels', () => {
  const options = [{value: 'a', label: 'Saved', count: 2, tintColor: '#2E7D32'}, {value: 'b', label: 'Shared'}];
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<SegmentedFallback options={options} value="a" onValueChange={noop} tintColor="#000000" />);});
  const segment = tree.root.findAll(node => node.props.accessibilityLabel === 'Saved 2')[0];
  expect(StyleSheet.flatten(segment.props.style).backgroundColor).toBe('#2E7D32');
  act(() => tree.unmount());
  expect(segmentLabel({value: 'x', label: 'Inbox'})).toBe('Inbox');
  expect(() => validateSegments([{value: 'a', label: 'A', count: -1}], 'a')).toThrow('count');
  expect(() => validateSegments([{value: 'a', label: 'A', tintColor: PlatformColor('systemBlue')}], 'a')).toThrow('static colour');
});

test('a prominent icon button sends its variant to the native host', () => {
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassIconButton systemImage="plus" accessibilityLabel="Add item"
    size={56} variant="prominent" tintColor="#6159B7" onPress={noop} />);});
  const props = tree.root.findByType(NativeMenu as never).props;
  expect(props.iconVariant).toBe('prominent');
  expect(props.symbolPointSize).toBe(22);
  act(() => tree.update(<GlassIconButton systemImage="plus" accessibilityLabel="New" onPress={noop} />));
  expect(tree.root.findByType(NativeMenu as never).props.iconVariant).toBe('regular');
  act(() => tree.unmount());
});
