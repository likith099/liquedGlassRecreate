import React from 'react';
import Renderer, {act} from 'react-test-renderer';
import Toolbar from '../../packages/liquid-glass/src/GlassToolbar';
import Menu from '../../packages/liquid-glass/src/GlassMenuButton';
import {validateMenuItems} from '../../packages/liquid-glass/src/menuTree';
import type {GlassMenuElement, GlassToolbarItem} from '../../packages/liquid-glass/src/types';
const items: readonly GlassToolbarItem[] = [
  {id: 'save', title: 'Save'},
  {kind: 'submenu', id: 'sort', title: 'Sort', items: [
    {kind: 'section', id: 'order', title: 'Order', items: [
      {id: 'recent', title: 'Recent', checked: false}, {id: 'blocked', title: 'Blocked', disabled: true},
    ]},
  ]},
  {kind: 'submenu', id: 'disabled', title: 'Disabled', disabled: true, items: [{id: 'child', title: 'Child'}]},
];
function native(tree: Renderer.ReactTestRenderer) { return tree.root.findAll(n => n.props.itemsJSON && n.props.onMenuAction)[0]; }

test('recursive identities, groups and cross-platform nesting are validated', () => {
  expect(() => validateMenuItems(items)).not.toThrow();
  expect(() => validateMenuItems([...items, {id: 'recent', title: 'Duplicate'}])).toThrow('unique');
  expect(() => validateMenuItems([{kind: 'section', id: 'empty', title: '', items: []}])).toThrow('contain');
  expect(() => validateMenuItems([{kind: 'submenu', id: 'outer', title: 'Outer', items}])).toThrow('one submenu');
  let deep: readonly GlassMenuElement[] = [{id: 'leaf', title: 'Leaf'}];
  for (let i = 0; i < 8; i++) deep = [{kind: 'section', id: `group${i}`, title: '', items: deep}];
  expect(() => validateMenuItems(deep)).toThrow('8 levels');
});

test.each([false, true])('leaf events reject disabled ancestors and reconcile replaced items (toolbar=%s)', toolbar => {
  const onAction = jest.fn(); let tree!: Renderer.ReactTestRenderer;
  const render = (nodes: readonly GlassToolbarItem[], disabled = false) => toolbar
    ? <Toolbar items={nodes} disabled={disabled} onAction={onAction} />
    : <Menu title="Menu" items={nodes} disabled={disabled} onAction={onAction} />;
  act(() => {tree = Renderer.create(render(items));});
  const select = (id: string) => act(() => native(tree).props.onMenuAction({nativeEvent: {id}}));
  select('recent'); select('sort'); select('order'); select('child'); select('blocked'); select('missing');
  expect(onAction.mock.calls).toEqual([['recent']]);
  expect(JSON.parse(native(tree).props.itemsJSON)[1].items[0].items[0].checked).toBe(false);
  act(() => tree.update(render([{id: 'archive', title: 'Archive'}])));
  select('recent'); select('save'); select('archive');
  expect(onAction.mock.calls).toEqual([['recent'], ['archive']]);
  act(() => tree.update(render(items, true))); select('recent');
  expect(onAction).toHaveBeenCalledTimes(2);
  act(() => tree.unmount());
});

test('toolbar validates visible limit and keeps empty controls disabled and merging opt-in', () => {
  const onAction = jest.fn(); let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Toolbar items={[]} onAction={onAction} maxVisibleItems={0} />);});
  expect(native(tree).props.disabled).toBe(true);
  expect(native(tree).props.mergingEnabled).toBe(false);
  expect(native(tree).props.maxVisibleItems).toBe(0);
  expect(() => act(() => tree.update(<Toolbar items={items} onAction={onAction} maxVisibleItems={1.5} />))).toThrow('integer');
  act(() => tree.unmount());
});
