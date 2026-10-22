import React from 'react';
import Renderer, {act} from 'react-test-renderer';
import App from '../App';
jest.mock('react-native-safe-area-context', () => require('react-native-safe-area-context/jest/mock').default);
beforeEach(() => { jest.spyOn(require('react-native'), 'useWindowDimensions').mockReturnValue({width: 390, height: 844, scale: 3, fontScale: 1}); });
afterEach(() => { jest.restoreAllMocks(); });

test('the two galleries expose components and direct navigation examples', async () => {
  let tree!: Renderer.ReactTestRenderer;
  await act(async () => { tree = Renderer.create(<App />); });
  const action = (id: string, prop: string) => tree.root.findAll(node => node.props.testID === id && typeof node.props[prop] === 'function')[0].props[prop];
  expect(tree.root.findAllByProps({testID: 'adaptive-surface'}).length).toBeGreaterThan(0);
  await act(async () => { action('open-upgrade-demo', 'onPress')(); });
  expect(tree.root.findAllByProps({testID: 'upgrade-morph'}).length).toBeGreaterThan(0);
  // Category controls remain present while a component section is selected.
  expect(tree.root.findAllByProps({testID: 'demo-categories'}).length).toBeGreaterThan(0);
  await act(async () => { action('demo-categories', 'onValueChange')('navigation'); });
  for (const id of ['nav-review', 'open-scroll-header', 'nav-blur-only', 'acc-open-stack', 'acc-open-tabs', 'open-tabs-demo', 'open-search-demo']) {
    expect(tree.root.findAllByProps({testID: id}).length).toBeGreaterThan(0);
  }
  await act(async () => { action('demo-categories', 'onValueChange')('components'); });
  expect(tree.root.findAllByProps({testID: 'upgrade-morph'}).length).toBeGreaterThan(0);
  await act(async () => { tree.unmount(); });
});

test('accessibility text sizes use a compact native section menu', async () => {
  const dimensions = jest.spyOn(require('react-native'), 'useWindowDimensions').mockReturnValue({width: 390, height: 844, scale: 3, fontScale: 3.1});
  let tree!: Renderer.ReactTestRenderer;
  try {
    await act(async () => { tree = Renderer.create(<App />); });
    expect(tree.root.findAllByProps({testID: 'open-accessibility-demo'})).toHaveLength(0);
    const menu = tree.root.findAll(node => node.props.testID === 'demo-sections' && typeof node.props.onAction === 'function')[0];
    await act(async () => { menu.props.onAction('accessibility'); });
    expect(tree.root.findAllByProps({testID: 'adaptive-segments'}).length).toBeGreaterThan(0);
  } finally {
    await act(async () => { tree?.unmount(); });
    dimensions.mockRestore();
  }
});
