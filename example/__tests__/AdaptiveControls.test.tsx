import React from 'react';
import * as RN from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import Segmented from '../../packages/liquid-glass/src/GlassSegmentedControl.ios';
import Tabs from '../../packages/liquid-glass/src/GlassTabBar';
import Button from '../../packages/liquid-glass/src/GlassButton.ios';
import Menu from '../../packages/liquid-glass/src/GlassMenuButton';
import Toolbar from '../../packages/liquid-glass/src/GlassToolbar';
import Cluster from '../../packages/liquid-glass/src/fallback/GlassActionCluster';

jest.mock('../../packages/liquid-glass/src/support', () => ({isLiquidGlassSupported: () => true}));
const initialWindow = RN.Dimensions.get('window');
afterEach(() => {act(() => RN.Dimensions.set({window: initialWindow, screen: initialWindow})); jest.restoreAllMocks();});
function scale(fontScale: number) {
  const dimensions = {width: 320, height: 800, scale: 3, fontScale};
  act(() => RN.Dimensions.set({window: dimensions, screen: dimensions}));
}
test('large text keeps selector options side by side and individually accessible without losing controlled state', () => {
  scale(1); const change = jest.fn(); let tree!: Renderer.ReactTestRenderer;
  const props = {testID: 'filter', options: [{value: 'all', label: 'All'}, {value: 'saved', label: 'Saved'}, {value: 'locked', label: 'Locked', disabled: true}], value: 'all', onValueChange: change};
  act(() => {tree = Renderer.create(<Segmented {...props} />);});
  expect(tree.root.findAll(n => n.props.optionsJSON).length).toBeGreaterThan(0);
  scale(2);
  act(() => tree.update(<Segmented {...props} />));
  const host = tree.root.findAll(n => n.props.testID === 'filter' && n.props.accessible === false)[0];
  // Options stay side by side at every text size; their labels wrap instead of truncating.
  expect(RN.StyleSheet.flatten(host.props.style).flexDirection).toBe('row');
  expect(RN.StyleSheet.flatten(tree.root.findAll(n => n.props.testID === 'filter-all' && n.props.accessibilityRole === 'radio')[0].props.style).flex).toBe(1);
  const option = (id: string) => tree.root.findAll(n => n.props.testID === `filter-${id}` && n.props.accessibilityRole === 'radio')[0];
  expect(option('all').props.accessibilityState.checked).toBe(true);
  expect(option('locked').props.accessibilityState.disabled).toBe(true);
  act(() => option('saved').props.onPress());
  expect(change.mock.calls).toEqual([['saved']]);
  expect(option('all').props.accessibilityState.checked).toBe(true);
  scale(1);
  act(() => tree.update(<Segmented {...props} />));
  expect(tree.root.findAll(n => n.props.optionsJSON)[0].props.selectedValue).toBe('all');
  act(() => tree.unmount());
});

test('default native hosts grow with font scale and explicit caller heights remain authoritative', () => {
  scale(2); let tree!: Renderer.ReactTestRenderer;
  const items = [{id: 'home', title: 'Home'}];
  for (const height of [undefined, 100]) {
    act(() => {tree = Renderer.create(<>
      <Button title="Add" style={height ? {height} : undefined} onPress={() => {}} />
      <Menu title="Menu" items={items} style={height ? {height} : undefined} onAction={() => {}} />
      <Toolbar items={items} style={height ? {height} : undefined} onAction={() => {}} />
      <Tabs items={items} value="home" style={height ? {height} : undefined} onValueChange={() => {}} />
    </>);});
    const nodes = tree.root.findAll(n => typeof n.type === 'string' && (n.props.controlLabel === 'Add' || n.props.itemsJSON));
    expect(nodes.length).toBe(4);
    for (const node of nodes) {
      // Only the text share of the default height grows, so a doubled font scale adds one
      // line height rather than doubling the whole control.
      expect(RN.StyleSheet.flatten(node.props.style).height).toBe(height ?? (node.props.selectedValue ? 104 : 84));
    }
    act(() => tree.unmount());
  }
});

test('fallback cluster keeps child actions exposed and reports expansion and disabled state', () => {
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Cluster accessible expanded actions={[{id: 'locked', title: 'Locked', systemImage: 'lock', disabled: true}]}
    onExpandedChange={() => {}} onAction={() => {}} />);});
  expect(tree.root.findByType(RN.View).props.accessible).toBe(false);
  expect(tree.root.findAll(n => n.props.testID === 'glass-cluster-toggle' && n.props.accessibilityState)[0].props.accessibilityState.expanded).toBe(true);
  expect(tree.root.findAll(n => n.props.testID === 'glass-action-locked' && n.props.accessibilityState)[0].props.accessibilityState.disabled).toBe(true);
  act(() => tree.unmount());
});
