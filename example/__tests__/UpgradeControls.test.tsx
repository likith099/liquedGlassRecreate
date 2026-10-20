import React from 'react';
import renderer, {act} from 'react-test-renderer';
import {GlassMetrics, GlassIconButton, GlassIconGroup, GlassPillBar, GlassPresence} from '@likith99/react-native-adaptive-liquid-glass';
import {nativeIcon, badgeText} from '../../packages/liquid-glass/src/iconOptions';
import {controlAction} from '../../packages/liquid-glass/src/controlConfig';
import NativeControls from '../../packages/liquid-glass/src/specs/ALGControlsNativeComponent';
import NativePresence from '../../packages/liquid-glass/src/specs/ALGPresenceNativeComponent';
import NativeMenu from '../../packages/liquid-glass/src/specs/ALGMenuNativeComponent';
it('resolves symbols, rejects invalid numeric configuration and caps badges', () => {
  expect(nativeIcon({symbol: {name: 'heart', weight: 'semibold', variableValue: 0.5}}).symbol.weight).toBe('semibold');
  expect(() => nativeIcon({symbol: {name: 'heart', variableValue: 2}})).toThrow();
  expect(badgeText({count: 100})).toBe('99+');
  expect(() => badgeText({count: -1})).toThrow();
  expect(GlassMetrics.control.regular).toBe(44);
});
it('retains old size precedence and serializes icon options', async () => {
  let tree!: renderer.ReactTestRenderer;
  await act(() => {tree = renderer.create(<GlassIconButton symbol={{name: 'bell', weight: 'bold'}} controlSize="large" size={40} accessibilityLabel="Bell" badge={{count: 4}} onPress={() => {}} />);});
  const host = tree.root.findByType(NativeMenu);
  expect(host.props.style[0]).toEqual({width: 40, height: 40});
  expect(JSON.parse(host.props.iconOptionsJSON).badge).toBe('4');
  await act(() => tree.unmount());
});
it('blocks disabled group actions and disabled nested menu items', () => {
  const press = jest.fn(); const menu = jest.fn();
  const items = [{id: 'disabled', accessibilityLabel: 'Disabled', disabled: true},
    {id: 'menu', accessibilityLabel: 'Menu', menu: {items: [{id: 'delete', title: 'Delete', disabled: true}], onAction: menu}}];
  controlAction(items, 'disabled', '', press); controlAction(items, 'menu', 'delete', press); controlAction(items, 'missing', '', press);
  expect(press).not.toHaveBeenCalled(); expect(menu).not.toHaveBeenCalled();
});
it('keeps pill selection controlled and distinguishes trailing actions', async () => {
  const change = jest.fn(); const action = jest.fn(); let tree!: renderer.ReactTestRenderer;
  await act(() => {tree = renderer.create(<GlassPillBar items={[{id: 'a', label: 'A'}, {id: 'b', label: 'B'}]} value="a" onValueChange={change}
    actions={[{id: 'search', symbol: 'magnifyingglass', accessibilityLabel: 'Search'}]} onAction={action} />);});
  await act(() => tree.root.findByType(NativeControls).props.onControlAction({nativeEvent: {id: 'b', action: ''}}));
  expect(change).toHaveBeenCalledWith('b');
  expect(JSON.parse(tree.root.findByType(NativeControls).props.configJSON).value).toBe('a');
  await act(() => tree.root.findByType(NativeControls).props.onControlAction({nativeEvent: {id: 'search', action: ''}}));
  expect(action).toHaveBeenCalledWith('search'); await act(() => tree.unmount());
});
it('presence retains children, reports once, cancels an interrupted exit and cleans up', async () => {
  const done = jest.fn(); let tree!: renderer.ReactTestRenderer;
  const content = <GlassIconGroup items={[]} />;
  await act(() => {tree = renderer.create(<GlassPresence visible onExited={done}>{content}</GlassPresence>);});
  await act(() => tree.update(<GlassPresence visible={false} onExited={done}>{content}</GlassPresence>));
  const exit = tree.root.findByType(NativePresence).props.onExited;
  await act(() => {exit(); exit();}); expect(done).toHaveBeenCalledTimes(1); expect(tree.toJSON()).toBeNull();
  await act(() => tree.update(<GlassPresence visible onExited={done}>{content}</GlassPresence>));
  await act(() => tree.update(<GlassPresence visible={false} onExited={done}>{content}</GlassPresence>));
  await act(() => tree.update(<GlassPresence visible onExited={done}>{content}</GlassPresence>));
  await act(() => exit()); expect(done).toHaveBeenCalledTimes(1);
  await act(() => tree.update(<GlassPresence visible={false} onExited={done}>{content}</GlassPresence>));
  await act(() => tree.unmount()); expect(done).toHaveBeenCalledTimes(2);
});
