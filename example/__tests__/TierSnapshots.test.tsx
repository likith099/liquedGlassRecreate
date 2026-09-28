/**
 * Visual-tier snapshots (R18): what each surface renders for the glass (iOS 26), blur (iOS 15–25)
 * and solid (standard fallback, Android) tiers, in light and dark. The native tiers draw their pixels
 * in UIKit, so these pin the props sent to the native views and the fallback styles; the matching
 * screenshots come from the testVisualTiers UI test.
 */
import React from 'react';
import {Text, View} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import GlassView from '../../packages/liquid-glass/src/GlassView.ios';
import GlassButton from '../../packages/liquid-glass/src/GlassButton.ios';
import GlassPressable from '../../packages/liquid-glass/src/GlassPressable';
import GlassBadge from '../../packages/liquid-glass/src/GlassBadge';
import GlassSegmentedControl from '../../packages/liquid-glass/src/GlassSegmentedControl.ios';
import GlassSearchField from '../../packages/liquid-glass/src/GlassSearchField.ios';
import AndroidView from '../../packages/liquid-glass/src/fallback/GlassView';
import AndroidSegmentedControl from '../../packages/liquid-glass/src/fallback/GlassSegmentedControl';
import AndroidSearchField from '../../packages/liquid-glass/src/GlassSearchField.tsx';
import AndroidExpandingTabs from '../../packages/liquid-glass/src/GlassExpandingTabs.tsx';

let mockGlassSupported = false;
jest.mock('../../packages/liquid-glass/src/support', () => ({isLiquidGlassSupported: () => mockGlassSupported}));
afterEach(() => { mockGlassSupported = false; });

const noop = () => {};
const segments = [{value: 'all', label: 'All'}, {value: 'saved', label: 'Saved', count: 3}];
const pills = [{value: 'overview', label: 'Overview', systemImage: 'square.grid.2x2', androidIcon: 'ic_overview'},
  {value: 'recent', label: 'Recent', systemImage: 'clock', androidIcon: 'ic_recent'}];

function Gallery({scheme, solid}: {scheme: 'light' | 'dark'; solid: boolean}) {
  return <View>
    <GlassView colorScheme={scheme} forceFallback={solid} cornerRadius={20}><Text>Surface</Text></GlassView>
    <GlassButton colorScheme={scheme} forceFallback={solid} title="Save" onPress={noop} />
    <GlassPressable colorScheme={scheme} forceFallback={solid} onPress={noop}><Text>Row</Text></GlassPressable>
    <GlassBadge colorScheme={scheme} forceFallback={solid} tintColor="#34C759">New</GlassBadge>
    <GlassSegmentedControl colorScheme={scheme} forceFallback={solid} options={segments} value="all" onValueChange={noop} />
    <GlassSearchField colorScheme={scheme} forceFallback={solid} value="" onChangeText={noop} />
    {solid && <>
      <AndroidView colorScheme={scheme}><Text>Android surface</Text></AndroidView>
      <AndroidSegmentedControl colorScheme={scheme} options={segments} value="all" onValueChange={noop} />
      <AndroidSearchField colorScheme={scheme} value="" onChangeText={noop} />
      <AndroidExpandingTabs options={pills} value="overview" onValueChange={noop} />
    </>}
  </View>;
}

describe.each(['glass', 'blur', 'solid'] as const)('%s tier', tier => {
  test.each(['light', 'dark'] as const)('%s', scheme => {
    mockGlassSupported = tier === 'glass';
    let tree!: Renderer.ReactTestRenderer;
    act(() => {tree = Renderer.create(<Gallery scheme={scheme} solid={tier === 'solid'} />);});
    expect(tree.toJSON()).toMatchSnapshot();
    act(() => tree.unmount());
  });
});
