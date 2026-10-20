import {codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes, type HostComponent} from 'react-native';
export interface NativeProps extends ViewProps {
  /** React tag of the ScrollView whose edge effect this container drives; -1 for none. */
  scrollViewTag?: CodegenTypes.WithDefault<CodegenTypes.Int32, -1>;
  edge?: CodegenTypes.WithDefault<'top' | 'bottom', 'bottom'>;
  effectStyle?: CodegenTypes.WithDefault<'automatic' | 'soft' | 'hard' | 'progressive' | 'progressiveHard', 'automatic'>;
  fallbackMode?: CodegenTypes.WithDefault<'gradient' | 'blur' | 'solid', 'gradient'>;
  /** Fill for solid/gradient; tint for uniform blur on fallback platforms. */
  fallbackColor?: ColorValue;
}
export default codegenNativeComponent<NativeProps>('ALGScrollEdge') as HostComponent<NativeProps>;
