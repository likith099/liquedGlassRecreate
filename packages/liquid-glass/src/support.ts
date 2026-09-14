import {Platform} from 'react-native';
/** The package requires a native build with Xcode 26+. This is an OS capability check. */
export function isLiquidGlassSupported(): boolean {
  return Platform.OS === 'ios' && Number.parseInt(String(Platform.Version), 10) >= 26;
}
