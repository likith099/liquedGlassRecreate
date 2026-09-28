import React from 'react';
import Renderer, {act} from 'react-test-renderer';
import GlassIconButton, {validateIconButton} from '../../packages/liquid-glass/src/GlassIconButton';
import GlassMenuButton from '../../packages/liquid-glass/src/GlassMenuButton';
import * as NativeMenuSpec from '../../packages/liquid-glass/src/specs/ALGMenuNativeComponent';

const noop = () => {};
const items = [{id: 'share', title: 'Share'}, {id: 'locked', title: 'Locked', disabled: true}];
const host = (tree: Renderer.ReactTestRenderer) => tree.root.findByType(NativeMenuSpec.default as never);

test('a plain icon button is a square native icon host that reports presses', () => {
  const onPress = jest.fn();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassIconButton systemImage="xmark" accessibilityLabel="Close"
    size={40} colorScheme="dark" onPress={onPress} />);});
  const props = host(tree).props;
  expect(props.iconMode).toBe(true);
  expect(props.title).toBe('');
  expect(props.symbolPointSize).toBe(16);
  expect(props.colorScheme).toBe('dark');
  expect(props.controlLabel).toBe('Close');
  expect(JSON.parse(props.itemsJSON)).toEqual([]);
  expect(props.style).toEqual(expect.arrayContaining([{width: 40, height: 40}]));
  act(() => props.onButtonPress({nativeEvent: {}}));
  expect(onPress).toHaveBeenCalledTimes(1);
  act(() => tree.update(<GlassIconButton systemImage="xmark" accessibilityLabel="Close" disabled onPress={onPress} />));
  act(() => host(tree).props.onButtonPress({nativeEvent: {}}));
  expect(onPress).toHaveBeenCalledTimes(1);
  act(() => tree.unmount());
});

test('a menu icon button delivers enabled actions and typed open/close events', () => {
  const onAction = jest.fn();
  const onOpen = jest.fn();
  const onClose = jest.fn();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassIconButton systemImage="ellipsis" accessibilityLabel="More"
    symbolPointSize={17} menu={{items, onAction}} onOpen={onOpen} onClose={onClose} />);});
  const props = host(tree).props;
  expect(props.symbolPointSize).toBe(17);
  act(() => props.onMenuOpen({nativeEvent: {}}));
  act(() => props.onMenuAction({nativeEvent: {id: 'locked'}}));
  act(() => props.onMenuAction({nativeEvent: {id: 'share'}}));
  act(() => props.onMenuClose({nativeEvent: {}}));
  expect(onAction.mock.calls).toEqual([['share']]);
  expect(onOpen).toHaveBeenCalledTimes(1);
  expect(onClose).toHaveBeenCalledTimes(1);
  act(() => tree.unmount());
});

test('ref.open() dispatches the native open command to the host', () => {
  const open = jest.spyOn(NativeMenuSpec.Commands, 'open').mockImplementation(noop);
  const ref = React.createRef<import('../../packages/liquid-glass/src/types').GlassMenuHandle>();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassMenuButton ref={ref} title="Sort" items={items} onAction={noop} />);});
  act(() => ref.current?.open());
  expect(open).toHaveBeenCalledTimes(1);
  expect(open.mock.calls[0][0]).toBe(host(tree).instance);
  act(() => tree.unmount());
  open.mockRestore();
});

test('icon button props are validated', () => {
  const base = {systemImage: 'xmark', accessibilityLabel: 'Close', onPress: noop};
  expect(() => validateIconButton(base)).not.toThrow();
  expect(() => validateIconButton({...base, systemImage: ' '})).toThrow('systemImage');
  expect(() => validateIconButton({...base, accessibilityLabel: ''})).toThrow('accessibilityLabel');
  expect(() => validateIconButton({...base, size: 0})).toThrow('size');
  expect(() => validateIconButton({...base, symbolPointSize: Number.NaN})).toThrow('symbolPointSize');
  expect(() => validateIconButton({...base, menu: {items, onAction: noop}})).toThrow('not both');
  expect(() => validateIconButton({systemImage: 'xmark', accessibilityLabel: 'Close'})).toThrow('onPress or menu');
});
