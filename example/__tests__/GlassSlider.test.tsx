import React from 'react';
import Renderer, {act} from 'react-test-renderer';
import GlassSlider from '../../packages/liquid-glass/src/GlassSlider';
import {normalizeSliderValue, validateSlider} from '../../packages/liquid-glass/src/sliderMath';

function native(tree: Renderer.ReactTestRenderer) {
  return tree.root.findAll(node => node.props.onSliderComplete && node.props.revision !== undefined)[0];
}
const event = (value: number) => ({nativeEvent: {value}});

test.each([
  [-20, 0, 100, 10, 0], [120, 0, 100, 10, 100], [44, 0, 100, 10, 40],
  [45, 0, 100, 10, 50], [-4, -10, 10, 4, -2], [1, 0, 1, 0.3, 1],
  [0.26, 0, 1, 0.1, 0.3], [0.26, 0, 1, 0, 0.26],
])('normalizes %s within [%s, %s] at step %s', (value, min, max, step, expected) => {
  expect(normalizeSliderValue(value, min, max, step)).toBeCloseTo(expected, 10);
});

test('rejects invalid numeric ranges and steps', () => {
  for (const args of [[NaN, 0, 1, 0], [0, 1, 1, 0], [0, 1, 0, 0], [0, 0, 1, -1], [0, 0, 1, 2], [0, -Number.MAX_VALUE, Number.MAX_VALUE, 0]]) {
    expect(() => validateSlider(...args as [number, number, number, number])).toThrow();
  }
});

test('continuous changes are snapped and a declined completion forces controlled reconciliation', () => {
  const change = jest.fn(), start = jest.fn(), complete = jest.fn(), cancel = jest.fn();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassSlider value={40} maximumValue={100} step={10}
    onValueChange={change} onSlidingStart={start} onSlidingComplete={complete} onSlidingCancel={cancel} />);});
  act(() => native(tree).props.onSliderStart(event(40)));
  act(() => native(tree).props.onSliderChange(event(76)));
  expect(start).toHaveBeenCalledWith(40);
  expect(change).toHaveBeenCalledWith(80);
  act(() => native(tree).props.onSliderComplete(event(80)));
  expect(complete).toHaveBeenCalledWith(80);
  expect(native(tree).props.value).toBe(40);
  expect(native(tree).props.revision).toBe(1);
  act(() => native(tree).props.onSliderCancel(event(40)));
  expect(cancel).toHaveBeenCalledWith(40);
  expect(complete).toHaveBeenCalledTimes(1);
  expect(native(tree).props.revision).toBe(2);
  act(() => tree.update(<GlassSlider value={90} maximumValue={100} disabled onValueChange={change} onSlidingComplete={complete} />));
  act(() => native(tree).props.onSliderChange(event(70)));
  act(() => native(tree).props.onSliderComplete(event(70)));
  expect(change).toHaveBeenCalledTimes(1);
  expect(complete).toHaveBeenCalledTimes(1);
  expect(native(tree).props.value).toBe(90);
  act(() => tree.unmount());
});
