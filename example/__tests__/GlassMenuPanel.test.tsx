import React from 'react';
import {Text} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import GlassMenuPanel from '../../packages/liquid-glass/src/GlassMenuPanel';
import type {GlassMenuElement} from '../../packages/liquid-glass/src/types';

const items: GlassMenuElement[] = [
  {id: 'forward', title: 'Forward', systemImage: 'arrowshape.turn.up.right'},
  {id: 'locked', title: 'Locked', disabled: true},
  {kind: 'submenu', id: 'more', title: 'More', items: [{id: 'copy', title: 'Copy'}]},
  {kind: 'section', id: 'manage', title: 'Manage', items: [{id: 'delete', title: 'Delete', destructive: true, checked: false}]},
];
const row = (tree: Renderer.ReactTestRenderer, id: string) =>
  tree.root.findAll(node => node.props.testID === `panel-${id}` && typeof node.props.onPress === 'function')[0];

test('the menu panel reports enabled actions, opens submenus in place and stays where the app puts it', () => {
  const onAction = jest.fn();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassMenuPanel testID="panel" items={items} onAction={onAction} animateIn={false}
    style={{position: 'absolute', bottom: 12, right: 8}} />);});
  const host = tree.root.findAll(node => node.props.accessibilityRole === 'menu')[0];
  expect(host.props.style).toEqual(expect.arrayContaining([{position: 'absolute', bottom: 12, right: 8}]));
  act(() => row(tree, 'forward').props.onPress());
  expect(onAction.mock.calls).toEqual([['forward']]);
  // Disabled items do not act and announce their state.
  expect(row(tree, 'locked').props.accessibilityState).toEqual({disabled: true});
  expect(row(tree, 'delete').props.accessibilityState).toEqual({disabled: false, checked: false});
  expect(tree.root.findAll(node => node.type === Text && node.props.children === 'Manage')).toHaveLength(1);
  // A submenu replaces the rows with a back row and its items.
  act(() => row(tree, 'more').props.onPress());
  expect(onAction).toHaveBeenCalledTimes(1);
  act(() => row(tree, 'copy').props.onPress());
  expect(onAction.mock.calls[1]).toEqual(['copy']);
  const back = tree.root.findAll(node => node.props.accessibilityLabel === 'Back, More' && node.props.onPress)[0];
  act(() => back.props.onPress());
  expect(row(tree, 'forward')).toBeDefined();
  // A disabled panel blocks every item.
  act(() => tree.update(<GlassMenuPanel testID="panel" items={items} onAction={onAction} animateIn={false} disabled />));
  expect(row(tree, 'forward').props.disabled).toBe(true);
  act(() => tree.unmount());
  const error = jest.spyOn(console, 'error').mockImplementation(() => {});
  expect(() => act(() => { Renderer.create(<GlassMenuPanel items={items} onAction={onAction} width={0} />); })).toThrow('width');
  error.mockRestore();
});
