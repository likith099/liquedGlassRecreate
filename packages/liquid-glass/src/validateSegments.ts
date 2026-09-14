import type {GlassSegment} from './types';
export function validateSegments(options: readonly GlassSegment[], value: string | null) {
  if (!options.length) throw new Error('GlassSegmentedControl requires at least one option.');
  const values = new Set<string>();
  for (const option of options) {
    if (!option.value || values.has(option.value)) throw new Error('Segment values must be unique and nonempty.');
    if (!option.label.trim()) throw new Error('Segments require a nonempty label.');
    values.add(option.value);
  }
  if (value !== null && !values.has(value)) throw new Error('Selected value must match an option or be null.');
}
