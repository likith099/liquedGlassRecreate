import {processColor} from 'react-native';
import type {GlassSegment} from './types';

/** The label a segment displays, including its count. */
export function segmentLabel(option: GlassSegment): string {
  return option.count === undefined ? option.label : `${option.label} ${option.count > 99 ? '99+' : option.count}`;
}
export function validateSegments(options: readonly GlassSegment[], value: string | null) {
  if (!options.length) throw new Error('GlassSegmentedControl requires at least one option.');
  const values = new Set<string>();
  for (const option of options) {
    if (!option.value || values.has(option.value)) throw new Error('Segment values must be unique and nonempty.');
    if (!option.label.trim()) throw new Error('Segments require a nonempty label.');
    if (option.count !== undefined && (!Number.isInteger(option.count) || option.count < 0)) {
      throw new Error('Segment count must be a nonnegative integer.');
    }
    if (option.tintColor !== undefined && typeof processColor(option.tintColor) !== 'number') {
      throw new Error('Segment tintColor must be a static colour, not a platform or dynamic colour.');
    }
    values.add(option.value);
  }
  if (value !== null && !values.has(value)) throw new Error('Selected value must match an option or be null.');
}
