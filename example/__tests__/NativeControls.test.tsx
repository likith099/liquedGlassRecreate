import React from 'react';
import Renderer, {act} from 'react-test-renderer';
import Button from '../../packages/liquid-glass/src/fallback/NativeGlassButton';
import Segmented from '../../packages/liquid-glass/src/fallback/GlassSegmentedControl';
import {validateSegments} from '../../packages/liquid-glass/src/validateSegments';

const options = [{value: 'all', label: 'All'}, {value: 'saved', label: 'Saved'}, {value: 'shared', label: 'Shared', disabled: true}];
function press(tree: Renderer.ReactTestRenderer, id: string) {
  const node = tree.root.findAll(node => node.props.testID === id && node.props.onPress && node.props.accessibilityRole)[0];
  act(() => node.props.onPress());
}

test('button invokes once per press and suppresses activation while loading or disabled', () => {
  const onPress = jest.fn();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Button title="Add" testID="add" onPress={onPress} />);});
  press(tree, 'add');
  expect(onPress).toHaveBeenCalledTimes(1);
  act(() => tree.update(<Button title="Add" testID="add" onPress={onPress} loading />));
  press(tree, 'add');
  expect(onPress).toHaveBeenCalledTimes(1);
  expect(tree.root.findAll(node => node.props.accessibilityState?.busy === true).length).toBeGreaterThan(0);
  act(() => tree.update(<Button title="Add" testID="add" onPress={onPress} disabled />));
  press(tree, 'add');
  expect(onPress).toHaveBeenCalledTimes(1);
  act(() => tree.unmount());
});

test('segments preserve controlled selection and reject disabled and duplicate selections', () => {
  const onValueChange = jest.fn();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Segmented options={options} value="all" testID="filter" onValueChange={onValueChange} />);});
  press(tree, 'filter-saved');
  expect(onValueChange).toHaveBeenLastCalledWith('saved');
  const selected = tree.root.findAll(node => node.props.testID === 'filter-all' && node.props.accessibilityState)[0];
  expect(selected.props.accessibilityState.selected).toBe(true);
  press(tree, 'filter-all');
  press(tree, 'filter-shared');
  expect(onValueChange).toHaveBeenCalledTimes(1);
  act(() => tree.update(<Segmented options={options} value="saved" testID="filter" onValueChange={onValueChange} disabled />));
  press(tree, 'filter-all');
  expect(onValueChange).toHaveBeenCalledTimes(1);
  act(() => tree.update(<Segmented options={options.slice(0, 1)} value={null} testID="filter" onValueChange={onValueChange} />));
  expect(tree.root.findAll(node => node.props.testID === 'filter-saved')).toHaveLength(0);
  act(() => tree.unmount());
});

test('validates stable segment values and the controlled selection', () => {
  expect(() => validateSegments([], null)).toThrow('at least one');
  expect(() => validateSegments([...options, options[0]], null)).toThrow('unique');
  expect(() => validateSegments([{value: '', label: 'A'}], null)).toThrow('nonempty');
  expect(() => validateSegments(options, 'missing')).toThrow('match');
  expect(() => validateSegments(options, null)).not.toThrow();
});
