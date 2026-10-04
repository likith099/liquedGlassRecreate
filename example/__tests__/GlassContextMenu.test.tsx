import React from 'react';
import {Modal, Text} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import GlassContextMenu from '../../packages/liquid-glass/src/GlassContextMenu';
import type {GlassMenuElement} from '../../packages/liquid-glass/src/types';

const items: GlassMenuElement[] = [
  {id: 'edit', title: 'Edit'},
  {id: 'blocked', title: 'Blocked', disabled: true},
  {kind: 'submenu', id: 'group', title: 'Group', disabled: true, items: [{id: 'hidden', title: 'Hidden'}]},
];
function native(tree: Renderer.ReactTestRenderer) { return tree.root.findAll(node => node.props.onMenuAction && node.props.itemsJSON)[0]; }
test('context menu forwards live appearance and fallback resolves explicit theme', () => {
  let tree!: Renderer.ReactTestRenderer;
  const render = (colorScheme?: 'system' | 'light' | 'dark', forceFallback = false) =>
    <GlassContextMenu testID="theme" items={items} onAction={() => {}} colorScheme={colorScheme} forceFallback={forceFallback}>
      <Text>Message</Text>
    </GlassContextMenu>;
  act(() => {tree = Renderer.create(render(), {createNodeMock: () => ({
    measureInWindow: (callback: (...frame: number[]) => void) => callback(20, 100, 280, 90),
  })});});
  expect(native(tree).props.colorScheme).toBe('system');
  for (const scheme of ['dark', 'light', 'system'] as const) {
    act(() => tree.update(render(scheme)));
    expect(native(tree).props.colorScheme).toBe(scheme);
  }
  for (const scheme of ['dark', 'light'] as const) {
    act(() => tree.update(render(scheme, true)));
    const host = tree.root.findAll(node => node.props.testID === 'theme' && node.instance?.measureInWindow)[0];
    host.instance.measureInWindow = (callback: (...frame: number[]) => void) => callback(20, 100, 280, 90);
    const trigger = tree.root.findAll(node => node.props.testID === 'theme' && !!node.props.onLongPress)[0];
    act(() => trigger.props.onLongPress());
    const edit = tree.root.findAllByType(Text).find(node => node.props.children === 'Edit');
    expect(edit?.props.style).toEqual(expect.arrayContaining([{color: scheme === 'dark' ? '#F5F5F9' : '#222737'}]));
  }
  act(() => tree.unmount());
});
test('context menu retains arbitrary content, has no fixed height and rejects invalid or disabled actions', () => {
  const onAction = jest.fn(); let tree!: Renderer.ReactTestRenderer;
  const render = (entries = items, disabled = false) => <GlassContextMenu items={entries} disabled={disabled} onAction={onAction}
    accessibilityLabel="Message" testID="message"><Text>Still visible</Text></GlassContextMenu>;
  act(() => {tree = Renderer.create(render());});
  expect(native(tree).props.contextMenu).toBe(true);
  expect(native(tree).props.style).toBeUndefined();
  expect(native(tree).props.controlLabel).toBe('Message');
  expect(tree.root.findByType(Text).props.children).toBe('Still visible');
  act(() => native(tree).props.onMenuOpen());
  const select = (id: string) => act(() => native(tree).props.onMenuAction({nativeEvent: {id}}));
  select('edit'); select('blocked'); select('hidden'); select('group'); select('unknown');
  expect(onAction.mock.calls).toEqual([['edit']]);
  act(() => tree.update(render([{id: 'new', title: 'New'}]))); select('edit'); select('new');
  act(() => tree.update(render(items, true))); select('edit');
  act(() => tree.update(render([]))); select('edit');
  expect(native(tree).props.disabled).toBe(true);
  expect(onAction.mock.calls).toEqual([['edit'], ['new']]);
  expect(tree.root.findByType(Text).props.children).toBe('Still visible');
  act(() => tree.unmount());
});

test('afterClose delays once, preserves accessibility actions and cancels stale pending actions', () => {
  const events: string[] = [];
  let tree!: Renderer.ReactTestRenderer;
  const render = (entries = items, disabled = false) => <GlassContextMenu items={entries} disabled={disabled}
    actionTiming="afterClose" onAction={id => events.push(id)} onClose={() => events.push('close')}><Text>Message</Text></GlassContextMenu>;
  act(() => {tree = Renderer.create(render());});
  const open = () => act(() => native(tree).props.onMenuOpen());
  const choose = (id: string) => act(() => native(tree).props.onMenuAction({nativeEvent: {id}}));
  const close = () => act(() => native(tree).props.onMenuClose());
  open(); choose('edit'); choose('blocked');
  expect(events).toEqual([]);
  close(); expect(events).toEqual(['close', 'edit']);
  close(); expect(events).toEqual(['close', 'edit', 'close']);
  choose('edit'); // A VoiceOver custom action has no menu lifecycle.
  expect(events.at(-1)).toBe('edit');
  open(); close(); expect(events.at(-1)).toBe('close'); // Outside dismissal has no action.
  open(); choose('edit'); act(() => tree.update(render([{id: 'new', title: 'New'}]))); close();
  expect(events.filter(value => value === 'edit')).toHaveLength(2);
  act(() => tree.update(render())); open(); choose('edit');
  act(() => tree.update(render(items, true))); close();
  expect(events.filter(value => value === 'edit')).toHaveLength(2);
  act(() => tree.update(render())); open(); choose('edit');
  const lateClose = native(tree).props.onMenuClose;
  act(() => tree.unmount()); act(() => lateClose());
  expect(events.filter(value => value === 'edit')).toHaveLength(2);
});

test('plain fallback honors afterClose action ordering', () => {
  const events: string[] = [];
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassContextMenu forceFallback actionTiming="afterClose" items={items}
    testID="deferred" onAction={id => events.push(id)} onClose={() => events.push('close')}><Text>Message</Text></GlassContextMenu>,
  {createNodeMock: () => ({measureInWindow: (callback: (...frame: number[]) => void) => callback(20, 100, 280, 90)})});});
  const host = tree.root.findAll(node => node.props.testID === 'deferred' && node.instance?.measureInWindow)[0];
  host.instance.measureInWindow = (callback: (...frame: number[]) => void) => callback(20, 100, 280, 90);
  const trigger = tree.root.findAll(node => node.props.testID === 'deferred' && !!node.props.onLongPress)[0];
  act(() => trigger.props.onLongPress());
  const edit = tree.root.findAll(node => node.props.accessibilityLabel === 'Edit' && !!node.props.onPress)[0];
  act(() => edit.props.onPress());
  expect(events).toEqual(['close', 'edit']);
  act(() => tree.unmount());
});

test('plain fallback preserves content, navigates submenus and dismisses on selection or replacement', () => {
  const onAction = jest.fn(); let tree!: Renderer.ReactTestRenderer;
  const entries: GlassMenuElement[] = [{id: 'edit', title: 'Edit'},
    {kind: 'submenu', id: 'more', title: 'More', items: [{id: 'copy', title: 'Copy'}]}];
  const render = (list = entries, disabled = false) => <GlassContextMenu forceFallback items={list}
    disabled={disabled} onAction={onAction} testID="message"><Text>Still visible</Text></GlassContextMenu>;
  act(() => {tree = Renderer.create(render(), {createNodeMock: () => ({
    measureInWindow: (callback: (x: number, y: number, width: number, height: number) => void) => callback(20, 100, 280, 90),
  })});});
  const trigger = () => tree.root.findAll(node => node.props.testID === 'message' && !!node.props.onLongPress)[0];
  const host = tree.root.findAll(node => node.props.testID === 'message' && node.instance?.measureInWindow)[0];
  host.instance.measureInWindow = (callback: (x: number, y: number, width: number, height: number) => void) => callback(20, 100, 280, 90);
  const row = (label: string) => tree.root.findAll(node => node.props.accessibilityLabel === label && !!node.props.onPress)[0];
  expect(trigger().props.onPress).toBeUndefined();
  act(() => trigger().props.onLongPress());
  expect(tree.root.findByType(Modal).props.visible).toBe(true);
  expect(tree.root.findAllByType(Text).some(node => node.props.children === 'Still visible')).toBe(true);
  act(() => row('More').props.onPress());
  act(() => row('Copy').props.onPress());
  expect(onAction.mock.calls).toEqual([['copy']]);
  expect(tree.root.findByType(Modal).props.visible).toBe(false);
  act(() => trigger().props.onLongPress());
  act(() => tree.update(render([{id: 'new', title: 'New'}])));
  expect(tree.root.findByType(Modal).props.visible).toBe(false);
  act(() => trigger().props.onLongPress());
  act(() => row('Dismiss menu').props.onPress());
  expect(onAction).toHaveBeenCalledTimes(1);
  act(() => tree.update(render(entries, true)));
  act(() => trigger().props.onLongPress());
  expect(tree.root.findByType(Modal).props.visible).toBe(false);
  act(() => tree.unmount());
});
