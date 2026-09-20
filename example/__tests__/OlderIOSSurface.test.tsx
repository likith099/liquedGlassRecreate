import React from 'react';
import {StyleSheet, Text} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import GlassView from '../../packages/liquid-glass/src/GlassView.ios';
import NativeSurface from '../../packages/liquid-glass/src/specs/ALGSurfaceNativeComponent';
import Fallback from '../../packages/liquid-glass/src/fallback/GlassView';

jest.mock('../../packages/liquid-glass/src/support', () => ({isLiquidGlassSupported: () => false}));

test('older iOS mounts the native blur host, preserves children/styles, and allows opaque opt-out', () => {
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassView style={{height: 60}} fallbackStyle={{height: 72}}>
    <Text>Preserved content</Text>
  </GlassView>);});
  expect(StyleSheet.flatten(tree.root.findByType(NativeSurface).props.style).height).toBe(72);
  expect(tree.root.findByType(Text).props.children).toBe('Preserved content');
  act(() => tree.update(<GlassView forceFallback><Text>Opaque content</Text></GlassView>));
  expect(tree.root.findAllByType(NativeSurface)).toHaveLength(0);
  expect(tree.root.findAllByType(Fallback)).toHaveLength(1);
  expect(tree.root.findByType(Text).props.children).toBe('Opaque content');
  act(() => tree.unmount());
});
