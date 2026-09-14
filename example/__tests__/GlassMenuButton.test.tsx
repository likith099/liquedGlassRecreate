import React from 'react';
import Renderer, {act} from 'react-test-renderer';
import Menu, {validateMenu} from '../../packages/liquid-glass/src/GlassMenuButton';
const items = [{id: 'save', title: 'Save', checked: false}, {id: 'blocked', title: 'Blocked', disabled: true}];
function native(tree: Renderer.ReactTestRenderer) { return tree.root.findAll(node => node.props.onMenuAction && node.props.itemsJSON)[0]; }
test('validates menu identity without requiring items during loading', () => {
  expect(() => validateMenu('', items)).toThrow('title');
  expect(() => validateMenu('Menu', [...items, items[0]])).toThrow('unique');
  expect(() => validateMenu('Menu', [{id: ' ', title: 'Save'}])).toThrow('nonempty');
  expect(() => validateMenu('Menu', [{id: 'save', title: ' '}])).toThrow('nonempty');
  expect(() => validateMenu('Menu', [])).not.toThrow();
});
test('selection is controlled and disabled, removed, or unknown items cannot activate', () => {
  const onAction = jest.fn(); let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Menu title="Menu" items={items} onAction={onAction} />);});
  const select = (id: string) => act(() => native(tree).props.onMenuAction({nativeEvent: {id}}));
  select('save'); select('blocked'); select('missing');
  expect(onAction.mock.calls).toEqual([['save']]);
  expect(JSON.parse(native(tree).props.itemsJSON)[0].checked).toBe(false);
  act(() => tree.update(<Menu title="Menu" items={[{...items[0], checked: true}]} onAction={onAction} />));
  expect(JSON.parse(native(tree).props.itemsJSON)[0].checked).toBe(true);
  select('blocked');
  act(() => tree.update(<Menu title="Menu" items={items} disabled onAction={onAction} />)); select('save');
  act(() => tree.update(<Menu title="Menu" items={[]} onAction={onAction} />)); select('save');
  expect(native(tree).props.disabled).toBe(true);
  expect(onAction).toHaveBeenCalledTimes(1);
  act(() => tree.unmount());
});
