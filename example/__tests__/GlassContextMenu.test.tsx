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
test('context menu retains arbitrary content, has no fixed height and rejects invalid or disabled actions', () => {
  const onAction = jest.fn(); let tree!: Renderer.ReactTestRenderer;
  const render = (entries = items, disabled = false) => <GlassContextMenu items={entries} disabled={disabled} onAction={onAction}
    accessibilityLabel="Message" testID="message"><Text>Still visible</Text></GlassContextMenu>;
  act(() => {tree = Renderer.create(render());});
  expect(native(tree).props.contextMenu).toBe(true);
  expect(native(tree).props.style).toBeUndefined();
  expect(native(tree).props.controlLabel).toBe('Message');
  expect(tree.root.findByType(Text).props.children).toBe('Still visible');
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
