import React from 'react';
import {AccessibilityInfo, Animated, PlatformColor, Text} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import GlassExpandingTabs from '../../packages/liquid-glass/src/GlassExpandingTabs.ios';
import GlassExpandingTabsGeneric from '../../packages/liquid-glass/src/GlassExpandingTabs.tsx';
import NativeExpandingTabs from '../../packages/liquid-glass/src/specs/ALGExpandingTabsNativeComponent';
import {validateExpandingTabs} from '../../packages/liquid-glass/src/validateExpandingTabs';

const options = [
  {value: 'overview', label: 'Overview', systemImage: 'square.grid.2x2', androidIcon: 'ic_overview', tintColor: '#F57C00'},
  {value: 'recent', label: 'Recent', systemImage: 'clock', androidIcon: 'ic_recent'},
  {value: 'archived', label: 'Archived', systemImage: 'archivebox', androidIcon: 'ic_archived', disabled: true},
];
afterEach(() => jest.restoreAllMocks());

test('the native tabs receive serialized options, keep merging off, and split selection from reselection', () => {
  const onValueChange = jest.fn();
  const onReselect = jest.fn();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassExpandingTabs options={options} value="overview" onValueChange={onValueChange}
    onReselect={onReselect} material="tinted" contentInset={20} />);});
  const props = tree.root.findByType(NativeExpandingTabs as never).props;
  const [overview, recent] = JSON.parse(props.optionsJSON);
  expect(overview).toEqual(expect.objectContaining({value: 'overview', label: 'Overview', systemImage: 'square.grid.2x2'}));
  expect(typeof overview.tint).toBe('number');
  expect(recent.tint).toBeUndefined();
  expect(props.material).toBe('tinted');
  expect(props.contentInset).toBe(20);
  expect(props.mergingEnabled).toBe(false);
  act(() => props.onSelectionChange({nativeEvent: {value: 'overview'}}));
  act(() => props.onSelectionChange({nativeEvent: {value: 'archived'}}));
  act(() => props.onSelectionChange({nativeEvent: {value: 'recent'}}));
  expect(onReselect.mock.calls).toEqual([['overview']]);
  expect(onValueChange.mock.calls).toEqual([['recent']]);
  act(() => tree.unmount());
});

test('expanding tab options are validated', () => {
  expect(() => validateExpandingTabs(options, 'overview')).not.toThrow();
  expect(() => validateExpandingTabs([], 'x')).toThrow('at least one');
  expect(() => validateExpandingTabs([options[0], options[0]], 'overview')).toThrow('unique');
  expect(() => validateExpandingTabs([{value: 'a', label: 'A', systemImage: ' '}], 'a')).toThrow('systemImage');
  expect(() => validateExpandingTabs(options, 'missing')).toThrow('match an option');
  expect(() => validateExpandingTabs([{value: 'a', label: 'A', systemImage: 'bell', tintColor: PlatformColor('systemBlue')}], 'a'))
    .toThrow('static colour');
});

test('the Android fallback springs one progress per pill and reports reselection', async () => {
  jest.spyOn(AccessibilityInfo, 'isReduceMotionEnabled').mockResolvedValue(false);
  const spring = jest.spyOn(Animated, 'spring');
  const onValueChange = jest.fn();
  const onReselect = jest.fn();
  let tree!: Renderer.ReactTestRenderer;
  const render = (value: string) => <GlassExpandingTabsGeneric testID="tabs" options={options} value={value}
    onValueChange={onValueChange} onReselect={onReselect} />;
  await act(async () => {tree = Renderer.create(render('overview'));});
  const pill = (value: string) => tree.root.findAll(node => node.props.testID === `tabs-${value}` && node.props.accessibilityRole === 'tab')[0];
  // Every pill announces its label and position, even while collapsed.
  expect(pill('recent').props.accessibilityLabel).toBe('Recent');
  expect(pill('recent').props.accessibilityValue).toEqual({text: '2 of 3'});
  expect(pill('overview').props.accessibilityState).toEqual({selected: true, disabled: false});
  expect(pill('archived').props.disabled).toBe(true);
  // No animation on first mount.
  expect(spring).not.toHaveBeenCalled();
  act(() => pill('recent').props.onPress());
  expect(onValueChange).toHaveBeenCalledWith('recent');
  act(() => pill('overview').props.onPress());
  expect(onReselect).toHaveBeenCalledWith('overview');
  // Only the two pills whose selection changed spring, from their current values.
  await act(async () => tree.update(render('recent')));
  expect(spring).toHaveBeenCalledTimes(2);
  expect(spring.mock.calls.map(call => (call[1] as {toValue: number}).toValue).sort()).toEqual([0, 1]);
  expect(pill('overview').findAllByType(Text).length).toBeGreaterThan(0);
  act(() => tree.unmount());
});

test('the Android pills warn once in development about an option without androidIcon', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  let tree!: Renderer.ReactTestRenderer;
  const bare = [{value: 'plain', label: 'Plain', systemImage: 'circle'}];
  act(() => {tree = Renderer.create(<GlassExpandingTabsGeneric options={bare} value="plain" onValueChange={() => {}} />);});
  act(() => tree.update(<GlassExpandingTabsGeneric options={bare} value="plain" onValueChange={() => {}} />));
  expect(warn.mock.calls.filter(([message]) => String(message).includes('"plain" has no androidIcon'))).toHaveLength(1);
  act(() => tree.unmount());
  warn.mockRestore();
});
