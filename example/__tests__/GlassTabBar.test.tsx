import React from 'react';
import Renderer, {act} from 'react-test-renderer';
import Tabs from '../../packages/liquid-glass/src/GlassTabBar';
import {validateTabs} from '../../packages/liquid-glass/src/validateTabs';
const items = [{id: 'home', title: 'Home'}, {id: 'inbox', title: 'Inbox', badge: 3}, {id: 'disabled', title: 'Disabled', disabled: true}];
function native(tree: Renderer.ReactTestRenderer) {return tree.root.findAll(n => n.props.onSelectionChange && n.props.itemsJSON)[0];}

test('tab identity, selected value, counts and badge inputs have an explicit contract', () => {
  expect(() => validateTabs(items, 'home')).not.toThrow();
  expect(() => validateTabs([], null)).not.toThrow();
  expect(() => validateTabs(items, null)).toThrow('value');
  expect(() => validateTabs([], 'home')).toThrow('value');
  expect(() => validateTabs(items, 'missing')).toThrow('value');
  expect(() => validateTabs([...items, items[0]], 'home')).toThrow('unique');
  expect(() => validateTabs([{id: ' ', title: 'Home'}], ' ')).toThrow('nonempty');
  expect(() => validateTabs(Array.from({length: 6}, (_, n) => ({id: String(n), title: String(n)})), '0')).toThrow('5');
  for (const badge of [-1, .5, NaN, Infinity, 2147483648]) {
    expect(() => validateTabs([{id: 'home', title: 'Home', badge}], 'home')).toThrow('badge');
  }
});

test('rejected and invalid native selections force reconciliation without mutating the controlled value', () => {
  const onValueChange = jest.fn(), onTabReselect = jest.fn(); let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Tabs items={items} value="home" onValueChange={onValueChange} onTabReselect={onTabReselect} />);});
  const select = (id: string) => act(() => native(tree).props.onSelectionChange({nativeEvent: {id}}));
  const before = native(tree).props.selectionRevision;
  select('inbox');
  expect(onValueChange.mock.calls).toEqual([['inbox']]);
  expect(native(tree).props.selectedValue).toBe('home');
  expect(native(tree).props.selectionRevision).toBeGreaterThan(before);
  select('home'); select('disabled'); select('removed');
  expect(onValueChange).toHaveBeenCalledTimes(1);
  expect(onTabReselect.mock.calls).toEqual([['home']]);
  act(() => tree.update(<Tabs items={[...items].reverse()} value="inbox" onValueChange={onValueChange} />));
  expect(native(tree).props.selectedValue).toBe('inbox');
  expect(JSON.parse(native(tree).props.itemsJSON)[1].badge).toBe(3);
  act(() => tree.unmount());
});

test('programmatic changes emit nothing and disabled, replaced and empty tabs cannot select', () => {
  const onValueChange = jest.fn(); let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Tabs items={items} value="home" onValueChange={onValueChange} />);});
  act(() => tree.update(<Tabs items={items} value="inbox" onValueChange={onValueChange} />));
  expect(onValueChange).not.toHaveBeenCalled();
  act(() => tree.update(<Tabs items={[{id: 'new', title: 'New', badge: 'dot'}]} value="new" disabled onValueChange={onValueChange} />));
  act(() => native(tree).props.onSelectionChange({nativeEvent: {id: 'home'}}));
  act(() => native(tree).props.onSelectionChange({nativeEvent: {id: 'new'}}));
  act(() => tree.update(<Tabs items={[]} value={null} onValueChange={onValueChange} />));
  expect(native(tree).props.disabled).toBe(true);
  expect(onValueChange).not.toHaveBeenCalled();
  act(() => tree.unmount());
});
