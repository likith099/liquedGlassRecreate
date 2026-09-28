import {processColor} from 'react-native';
import type {GlassExpandingTab} from './types';

export function validateExpandingTabs(options: readonly GlassExpandingTab[], value: string) {
  if (!options.length) throw new Error('GlassExpandingTabs requires at least one option.');
  const values = new Set<string>();
  for (const option of options) {
    if (!option.value || values.has(option.value)) throw new Error('Expanding tab values must be unique and nonempty.');
    if (!option.label.trim() || !option.systemImage.trim()) throw new Error('Expanding tabs require a label and a systemImage.');
    if (option.tintColor !== undefined && typeof processColor(option.tintColor) !== 'number') {
      throw new Error('Expanding tab tintColor must be a static colour, not a platform or dynamic colour.');
    }
    values.add(option.value);
  }
  if (!values.has(value)) throw new Error('GlassExpandingTabs value must match an option.');
}
