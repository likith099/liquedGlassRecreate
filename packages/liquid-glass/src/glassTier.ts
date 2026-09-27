import {useEffect, useState} from 'react';
import {AccessibilityInfo, Platform} from 'react-native';
import {isLiquidGlassSupported} from './support';

/** The material a native surface renders: iOS 26 glass, older-iOS system blur, or an opaque surface. */
export type GlassTier = 'glass' | 'blur' | 'solid';

function tierFor(reduceTransparency: boolean): GlassTier {
  if (Platform.OS !== 'ios' || reduceTransparency) return 'solid';
  return isLiquidGlassSupported() ? 'glass' : 'blur';
}

/**
 * The live material tier, following the Reduce Transparency setting. The setting is read
 * asynchronously, so the first render assumes it is off. `forceFallback` and `fallbackMaterial`
 * are per-component choices and are not reflected here.
 */
export function useGlassTier(): GlassTier {
  const [reduceTransparency, setReduceTransparency] = useState(false);
  useEffect(() => {
    if (Platform.OS !== 'ios') return;
    let active = true;
    AccessibilityInfo.isReduceTransparencyEnabled().then(enabled => { if (active) setReduceTransparency(enabled); });
    const subscription = AccessibilityInfo.addEventListener('reduceTransparencyChanged', setReduceTransparency);
    return () => { active = false; subscription.remove(); };
  }, []);
  return tierFor(reduceTransparency);
}
