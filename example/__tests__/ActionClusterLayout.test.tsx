import React from 'react';
import {View} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import Cluster from '../../packages/liquid-glass/src/GlassActionCluster.ios';
import NativeCluster from '../../packages/liquid-glass/src/specs/ALGActionClusterNativeComponent';
import Fallback from '../../packages/liquid-glass/src/fallback/GlassActionCluster';
import {isLiquidGlassSupported} from '../../packages/liquid-glass/src/support';

jest.mock('../../packages/liquid-glass/src/support', () => ({isLiquidGlassSupported: jest.fn(() => true)}));
afterEach(() => jest.mocked(isLiquidGlassSupported).mockReturnValue(true));

// Written for the next verification run; execution is deferred by the owner.
test('narrow host falls back and widening restores native controls without changing controlled state', () => {
  const actions = [{id: 'save', title: 'Save'}, {id: 'share', title: 'Share', disabled: true}];
  const onAction = jest.fn(), onExpandedChange = jest.fn(), onLayout = jest.fn();
  const props = {actions, expanded: true, onAction, onExpandedChange, onLayout};
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Cluster {...props} />);});
  const resize = (width: number) => {
    const root = tree.root.findAllByType(NativeCluster)[0] ?? tree.root.findByType(Fallback);
    act(() => root.props.onLayout({nativeEvent: {layout: {x: 0, y: 0, width, height: 88}}}));
  };
  resize(204); // Exact native width for two actions and the toggle.
  expect(tree.root.findAllByType(NativeCluster)).toHaveLength(1);
  resize(200);
  expect(tree.root.findAllByType(NativeCluster)).toHaveLength(0);
  const fallback = tree.root.findByType(Fallback);
  expect(fallback.props.expanded).toBe(true);
  expect(fallback.props.actions).toBe(actions);
  expect(fallback.props.onAction).toBe(onAction);
  expect(fallback.props.onExpandedChange).toBe(onExpandedChange);
  expect(onAction).not.toHaveBeenCalled();
  expect(onExpandedChange).not.toHaveBeenCalled();
  resize(300);
  expect(tree.root.findAllByType(NativeCluster)).toHaveLength(1);
  expect(onLayout).toHaveBeenCalledTimes(3);
  act(() => tree.update(<Cluster {...props} forceFallback />));
  resize(400);
  expect(tree.root.findAllByType(NativeCluster)).toHaveLength(0);
  act(() => tree.unmount());
});

test('implementation changes preserve controlled props and event routing; fallbacks consume the iOS prop', () => {
  const actions = [{id: 'save', title: 'Save'}, {id: 'share', title: 'Share', disabled: true}];
  const onAction = jest.fn(), onExpandedChange = jest.fn();
  const props = {actions, expanded: true, onAction, onExpandedChange};
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Cluster {...props} />);});
  expect(tree.root.findByType(NativeCluster).props.iosImplementation).toBe('uikit');
  for (const iosImplementation of ['swiftui', 'uikit'] as const) {
    act(() => tree.update(<Cluster {...props} iosImplementation={iosImplementation} />));
    const native = tree.root.findByType(NativeCluster);
    expect(native.props.iosImplementation).toBe(iosImplementation);
    expect(native.props.expanded).toBe(true);
    expect(JSON.parse(native.props.actionsJSON)).toEqual(actions);
    expect(onExpandedChange).not.toHaveBeenCalled();
  }
  act(() => tree.root.findByType(NativeCluster).props.onAction({nativeEvent: {id: 'save'}}));
  expect(onAction).toHaveBeenCalledTimes(1);
  expect(onAction).toHaveBeenCalledWith('save');
  jest.mocked(isLiquidGlassSupported).mockReturnValue(false);
  act(() => tree.update(<Cluster {...props} iosImplementation="swiftui" />));
  expect(tree.root.findAllByType(NativeCluster)).toHaveLength(0);
  expect(tree.root.findByType(Fallback).props.expanded).toBe(true);
  // Android also uses this fallback directly; never send the iOS-only prop to View.
  act(() => tree.update(<Fallback {...props} iosImplementation="swiftui" />));
  expect(tree.root.findAllByType(View)[0].props.iosImplementation).toBeUndefined();
  act(() => tree.unmount());
});
