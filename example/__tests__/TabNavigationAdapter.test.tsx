import React from 'react';
import Renderer, {act} from 'react-test-renderer';
import type {BottomTabBarProps} from '@react-navigation/bottom-tabs';
import Adapter from '../navigation/NativeNavigationTabBar';
function fixture(prevented = false) {
  const emit = jest.fn(() => ({defaultPrevented: prevented})), navigate = jest.fn();
  const props = {
    state: {index: 0, routes: [{key: 'home-key', name: 'Home'}, {key: 'inbox-key', name: 'Inbox', params: {filter: 'new'}}]},
    descriptors: {'home-key': {options: {}}, 'inbox-key': {options: {tabBarBadge: 3}}},
    navigation: {emit, navigate}, insets: {top: 0, bottom: 20, left: 0, right: 0},
  } as unknown as BottomTabBarProps;
  return {props, emit, navigate};
}
function select(tree: Renderer.ReactTestRenderer, id: string) {
  act(() => tree.root.findAll(n => n.props.onSelectionChange && n.props.itemsJSON)[0].props.onSelectionChange({nativeEvent: {id}}));
}
test('adapter navigates by stable route key, preserves params, and emits reselection without another navigation', () => {
  const {props,emit,navigate} = fixture(); let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Adapter {...props} reversed />);});
  select(tree, 'inbox-key');
  expect(emit).toHaveBeenCalledWith({type: 'tabPress', target: 'inbox-key', canPreventDefault: true});
  expect(navigate).toHaveBeenCalledWith('Inbox', {filter: 'new'});
  select(tree, 'home-key');
  expect(emit).toHaveBeenCalledTimes(2); expect(navigate).toHaveBeenCalledTimes(1);
  act(() => tree.unmount());
});
test('preventDefault and disabled routes block navigation while retaining router selection', () => {
  const {props,navigate} = fixture(true); let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Adapter {...props} />);});
  select(tree, 'inbox-key'); expect(navigate).not.toHaveBeenCalled();
  const disabledFixture = fixture();
  act(() => tree.update(<Adapter {...disabledFixture.props} disabledRoutes={['Inbox']} />));
  select(tree, 'inbox-key');
  expect(disabledFixture.navigate).not.toHaveBeenCalled();
  expect(disabledFixture.emit).not.toHaveBeenCalled();
  const native = tree.root.findAll(n => n.props.onSelectionChange && n.props.itemsJSON)[0];
  expect(native.props.selectedValue).toBe('home-key');
  act(() => tree.unmount());
});
