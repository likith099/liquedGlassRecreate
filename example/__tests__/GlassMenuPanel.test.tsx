import React from 'react';
import {Platform, Text} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import GlassMenuPanel from '../../packages/liquid-glass/src/GlassMenuPanel';
import GlassLongPress from '../../packages/liquid-glass/src/GlassLongPress';
import GlassContextMenu from '../../packages/liquid-glass/src/GlassContextMenu';
import type {GlassMenuElement} from '../../packages/liquid-glass/src/types';

const items: GlassMenuElement[] = [
  {id: 'forward', title: 'Forward', systemImage: 'arrowshape.turn.up.right'},
  {id: 'locked', title: 'Locked', disabled: true},
  {kind: 'section', id: 'manage', title: 'Manage', items: [{id: 'delete', title: 'Delete', destructive: true}]},
  {kind: 'section', id: 'tail', title: '', items: [{id: 'select', title: 'Select'}]},
];
const host = (tree: Renderer.ReactTestRenderer) => tree.root.findAll(node => node.props.itemsJSON && node.props.onMenuAction)[0];

test('measure predicts the native height from rows, section titles and separators', () => {
  // iOS: 9 + 9 padding, three rows of 40 plus one of 40, a 30 title, two 21 separators.
  expect(Platform.OS).toBe('ios');
  expect(GlassMenuPanel.measure(items, {fontScale: 1})).toBe(18 + 4 * 40 + 30 + 2 * 21);
  // Larger text grows rows and titles; smaller text never shrinks below the system size.
  expect(GlassMenuPanel.measure(items, {fontScale: 1.5})).toBe(18 + 4 * 60 + 45 + 2 * 21);
  expect(GlassMenuPanel.measure(items, {fontScale: 0.8})).toBe(GlassMenuPanel.measure(items, {fontScale: 1}));
  expect(GlassMenuPanel.measure(items, {fontScale: 1, maxHeight: 100})).toBe(100);
  // A leading section adds no separator before it, and trailing separators are dropped.
  expect(GlassMenuPanel.measure([{kind: 'section', id: 's', title: '', items: [{id: 'a', title: 'A'}]}], {fontScale: 1})).toBe(58);
});

test('the native panel is sized before it draws, reports enabled actions only and rejects submenus', () => {
  const onAction = jest.fn(); const onCancelTouch = jest.fn();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassMenuPanel testID="panel" items={items} onAction={onAction} onCancelTouch={onCancelTouch}
    appearFrom="top" autoFocus accessibilityModal style={{position: 'absolute', bottom: 12, right: 8}} />);});
  const panel = host(tree);
  expect(panel.props.style).toEqual([{width: 250, height: GlassMenuPanel.measure(items)}, {position: 'absolute', bottom: 12, right: 8}]);
  expect(JSON.parse(panel.props.itemsJSON)).toEqual(items);
  expect(panel.props).toMatchObject({appearFrom: 'top', autoFocus: true, menuModal: true, controlTestID: 'panel', accessibilityRole: 'menu'});
  const select = (id: string) => act(() => host(tree).props.onMenuAction({nativeEvent: {id}}));
  select('forward'); select('locked'); select('manage'); select('unknown'); select('delete');
  expect(onAction.mock.calls).toEqual([['forward'], ['delete']]);
  act(() => host(tree).props.onCancelTouch());
  expect(onCancelTouch).toHaveBeenCalledTimes(1);
  act(() => tree.update(<GlassMenuPanel items={items} onAction={onAction} width={300} maxHeight={120} disabled />));
  expect(host(tree).props.style[0]).toEqual({width: 300, height: 120});
  select('forward');
  expect(onAction).toHaveBeenCalledTimes(2);
  act(() => tree.unmount());
  const error = jest.spyOn(console, 'error').mockImplementation(() => {});
  expect(() => act(() => { Renderer.create(<GlassMenuPanel items={items} onAction={onAction} width={0} />); })).toThrow('width');
  expect(() => act(() => { Renderer.create(<GlassMenuPanel onAction={onAction}
    items={[{kind: 'submenu', id: 'more', title: 'More', items: [{id: 'copy', title: 'Copy'}]}]} />); })).toThrow('submenus');
  error.mockRestore();
});

test('long press passes its options and the native frame, and keeps its children', () => {
  const onLongPress = jest.fn(); let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassLongPress minimumDuration={350.4} haptic="medium" onLongPress={onLongPress}>
    <Text>Message</Text></GlassLongPress>);});
  const native = tree.root.findAll(node => node.props.minimumDuration !== undefined && typeof node.type === 'string')[0];
  expect(native.props).toMatchObject({minimumDuration: 350, allowableMovement: 10, disabled: false, haptic: 'medium'});
  expect(tree.root.findByType(Text).props.children).toBe('Message');
  act(() => native.props.onLongPress({nativeEvent: {x: 1, y: 2, width: 3, height: 4}}));
  expect(onLongPress).toHaveBeenCalledWith({frame: {x: 1, y: 2, width: 3, height: 4}});
  act(() => tree.unmount());
  const error = jest.spyOn(console, 'error').mockImplementation(() => {});
  expect(() => act(() => { Renderer.create(<GlassLongPress minimumDuration={-1} />); })).toThrow('minimumDuration');
  error.mockRestore();
});

test('context menu reports open and close and passes per-corner preview radii', () => {
  const onOpen = jest.fn(); const onClose = jest.fn(); let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassContextMenu items={[{id: 'a', title: 'A'}]} onAction={() => {}} onOpen={onOpen} onClose={onClose}
    previewCornerRadii={{topLeft: 18, bottomRight: 4}}><Text>Bubble</Text></GlassContextMenu>);});
  const native = tree.root.findAll(node => node.props.onMenuAction && node.props.itemsJSON)[0];
  expect(native.props).toMatchObject({previewCornerTopLeft: 18, previewCornerTopRight: -1, previewCornerBottomLeft: -1, previewCornerBottomRight: 4});
  act(() => native.props.onMenuOpen()); act(() => native.props.onMenuClose());
  expect([onOpen.mock.calls.length, onClose.mock.calls.length]).toEqual([1, 1]);
  act(() => tree.unmount());
});
