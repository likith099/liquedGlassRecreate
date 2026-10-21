import {Platform} from 'react-native';
import {isLiquidGlassSupported} from '../../packages/liquid-glass/src/support';

function withVersion(version: string | number, run: () => void) {
  const original = Platform.Version;
  Object.defineProperty(Platform, 'Version', {value: version, configurable: true});
  try { run(); } finally { Object.defineProperty(Platform, 'Version', {value: original, configurable: true}); }
}

// iOS reports dotted versions ("26.7.1"); `Number()` of those is NaN, which once hid the tab accessory.
test.each([['26.7.1', true], ['26.0', true], ['27.0', true], ['18.6', false], ['17.5.1', false]] as const)(
  'iOS %s → Liquid Glass %s', (version, supported) => {
    expect(Platform.OS).toBe('ios');
    withVersion(version, () => expect(isLiquidGlassSupported()).toBe(supported));
  });
