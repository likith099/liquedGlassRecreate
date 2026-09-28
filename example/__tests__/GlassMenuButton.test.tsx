import React from 'react';
import Renderer, {act} from 'react-test-renderer';
import {PlatformColor, processColor} from 'react-native';
import Menu, {validateMenu} from '../../packages/liquid-glass/src/GlassMenuButton';
import {menuStyleJSON} from '../../packages/liquid-glass/src/menuTree';
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

test('the Android menu style is sent as light and dark ARGB colours, and item icons pass through', () => {
  const items = [{id: 'edit', title: 'Edit', androidIcon: 'ic_edit'}, {kind: 'submenu' as const, id: 'more', title: 'More',
    androidIcon: 'ic_more', items: [{id: 'copy', title: 'Copy'}]}];
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Menu title="Actions" items={items} onAction={() => {}}
    androidMenuStyle={{cornerRadius: 24, backgroundColor: {light: '#FFFFFF', dark: '#1A1B20'}, textColor: '#112233'}} />);});
  const host = tree.root.findAll(node => typeof node.props.menuStyleJSON === 'string')[0];
  expect(JSON.parse(host.props.menuStyleJSON)).toEqual({cornerRadius: 24,
    backgroundColor: {light: processColor('#FFFFFF'), dark: processColor('#1A1B20')},
    textColor: {light: processColor('#112233'), dark: processColor('#112233')}});
  expect(JSON.parse(host.props.itemsJSON)[1].androidIcon).toBe('ic_more');
  // Without a style, native code uses its defaults.
  act(() => tree.update(<Menu title="Actions" items={items} onAction={() => {}} />));
  expect(tree.root.findAll(node => typeof node.props.menuStyleJSON === 'string')[0].props.menuStyleJSON).toBe('');
  act(() => tree.unmount());
  expect(() => menuStyleJSON({cornerRadius: -1})).toThrow('cornerRadius');
  expect(() => menuStyleJSON({textColor: PlatformColor('labelColor')})).toThrow('static');
});
