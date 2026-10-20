import React from 'react';
import {processColor} from 'react-native';
import renderer, {act} from 'react-test-renderer';
import {GlassIconButton, GlassMenuButton, GlassPillBar, GlassTabBar, GlassToolbar} from '@likith99/react-native-adaptive-liquid-glass';
import {badgeSpoken, badgeText, nativeIcon, nativeMenuItems, normalizeBadge} from '../../packages/liquid-glass/src/iconOptions';
import NativeControls from '../../packages/liquid-glass/src/specs/ALGControlsNativeComponent';
import NativeMenu from '../../packages/liquid-glass/src/specs/ALGMenuNativeComponent';
import NativeTabs from '../../packages/liquid-glass/src/specs/ALGTabsNativeComponent';

async function render(element: React.ReactElement) {
  let tree!: renderer.ReactTestRenderer;
  await act(() => {tree = renderer.create(element);});
  return tree;
}

it('draws counts, text and dots with one 99+ cap', () => {
  expect(badgeText({count: 7})).toBe('7');
  expect(badgeText({count: 99})).toBe('99');
  expect(badgeText({count: 100})).toBe('99+');
  expect(badgeText({text: 'New'})).toBe('New');
  expect(badgeText({indicator: true})).toBe('');
  expect(badgeText(null)).toBeUndefined();
  expect(() => badgeText({count: 1.5})).toThrow();
  expect(() => badgeText({text: '  '})).toThrow(/indicator/);
});

it('normalizes the shorthand badge forms', () => {
  expect(normalizeBadge(3)).toEqual({count: 3});
  expect(normalizeBadge('dot')).toEqual({indicator: true});
  expect(normalizeBadge({text: 'New'})).toEqual({text: 'New'});
  expect(normalizeBadge(undefined)).toBeUndefined();
  expect(normalizeBadge(null)).toBeNull();
});

it('speaks a default or the app label, never silence for a dot', () => {
  expect(badgeSpoken({count: 3})).toBe('3 new');
  expect(badgeSpoken({count: 250})).toBe('99+ new');
  expect(badgeSpoken({text: 'Updated'})).toBe('Updated');
  expect(badgeSpoken({indicator: true})).toBe('New');
  expect(badgeSpoken({count: 3}, '3 unread messages')).toBe('3 unread messages');
  expect(badgeSpoken({count: 3}, ' ')).toBe('3 new');
  expect(badgeSpoken(undefined, 'ignored')).toBeUndefined();
});

it('serializes badge colours and the spoken label for native code', () => {
  const icon = nativeIcon({symbol: 'bell', badge: {indicator: true}, badgeColor: '#0A84FF', badgeTextColor: '#000000',
    badgeAccessibilityLabel: 'Unread'});
  expect(icon.badge).toBe('');
  expect(icon.badgeColor).toBe(processColor('#0A84FF'));
  expect(icon.badgeTextColor).toBe(processColor('#000000'));
  expect(icon.badgeAccessibility).toBe('Unread');
  expect(() => nativeIcon({badge: {count: 1}, badgeTextColor: {} as never})).toThrow(/static/);
});

it('passes every badge option from an icon button', async () => {
  const tree = await render(<GlassIconButton symbol="bell" accessibilityLabel="Bell" badge={{text: 'New'}} badgeColor="yellow"
    badgeTextColor="black" onPress={() => {}} />);
  const options = JSON.parse(tree.root.findByType(NativeMenu).props.iconOptionsJSON);
  expect(options).toMatchObject({badge: 'New', badgeColor: processColor('yellow'), badgeTextColor: processColor('black'),
    badgeAccessibility: 'New'});
  // The new props are consumed, not forwarded to the native view as unknown props.
  expect(tree.root.findByType(NativeMenu).props.badgeTextColor).toBeUndefined();
  await act(() => tree.unmount());
});

it('gives pills a count, text or dot badge with colours', async () => {
  const tree = await render(<GlassPillBar value="all" onValueChange={() => {}} items={[
    {id: 'all', label: 'All', badge: 2},
    {id: 'recent', label: 'Recent', badge: {indicator: true}, badgeColor: 'blue'},
    {id: 'new', label: 'New', badge: {text: 'Beta'}, badgeTextColor: 'black', badgeAccessibilityLabel: 'In beta'},
  ]} />);
  const items = JSON.parse(tree.root.findByType(NativeControls).props.configJSON).items;
  expect(items.map((item: {badge?: string}) => item.badge)).toEqual(['2', '', 'Beta']);
  expect(items[1].badgeColor).toBe(processColor('blue'));
  expect(items[2]).toMatchObject({badgeTextColor: processColor('black'), badgeAccessibility: 'In beta'});
  expect(items[0].badgeAccessibility).toBe('2 new');
  await act(() => tree.unmount());
});

it('sends tab badges as a count, dot or text, with colours', async () => {
  const tree = await render(<GlassTabBar value="a" onValueChange={() => {}} items={[
    {id: 'a', title: 'A', badge: 3, badgeColor: '#FF3B30', badgeTextColor: 'white'},
    {id: 'b', title: 'B', badge: 'dot'},
    {id: 'c', title: 'C', badge: {text: 'New'}},
    {id: 'd', title: 'D', badge: {count: 5}},
    {id: 'e', title: 'E', badge: {indicator: true}},
  ]} />);
  const items = JSON.parse(tree.root.findByType(NativeTabs).props.itemsJSON);
  expect(items.map((item: {badge?: unknown}) => item.badge)).toEqual([3, 'dot', {text: 'New'}, 5, 'dot']);
  expect(items[0]).toMatchObject({badgeColor: processColor('#FF3B30'), badgeTextColor: processColor('white')});
  expect(items[1].badgeColor).toBeUndefined();
  await act(() => tree.unmount());
});

it('rejects invalid tab badges', async () => {
  const error = jest.spyOn(console, 'error').mockImplementation(() => {});
  for (const badge of [-1, {text: ''}, 'star' as never]) {
    await expect(render(<GlassTabBar value="a" onValueChange={() => {}} items={[{id: 'a', title: 'A', badge}]} />)).rejects.toThrow();
  }
  error.mockRestore();
});

it('warns once that menu rows cannot show badges, but not for toolbar buttons', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  nativeMenuItems([{id: 'row-badge', title: 'Row', badge: {count: 1}}]);
  nativeMenuItems([{id: 'row-badge', title: 'Row', badge: {count: 1}}]);
  expect(warn).toHaveBeenCalledTimes(1);
  expect(warn.mock.calls[0][0]).toMatch(/row-badge/);
  warn.mockClear();
  const toolbar = nativeMenuItems([{id: 'button-badge', title: 'Save', badge: {count: 4}}], false) as {badge?: string}[];
  expect(warn).not.toHaveBeenCalled();
  expect(toolbar[0].badge).toBe('4');
  warn.mockRestore();
});

it('keeps toolbar button badges and flags badged menu rows', async () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  const tree = await render(<GlassToolbar onAction={() => {}} items={[{id: 'save', title: 'Save', badge: {count: 4}, badgeColor: 'green'}]} />);
  const items = JSON.parse(tree.root.findByType(NativeMenu).props.itemsJSON);
  expect(items[0]).toMatchObject({badge: '4', badgeColor: processColor('green'), badgeAccessibility: '4 new'});
  expect(warn).not.toHaveBeenCalled();
  await act(() => tree.unmount());
  const menu = await render(<GlassMenuButton title="More" onAction={() => {}} items={[{id: 'menu-row-badge', title: 'Row', badge: {indicator: true}}]} />);
  expect(warn).toHaveBeenCalledWith(expect.stringMatching(/menu-row-badge/));
  await act(() => menu.unmount());
  warn.mockRestore();
});
