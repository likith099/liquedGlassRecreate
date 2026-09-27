import {codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes, type HostComponent} from 'react-native';
export interface NativeProps extends ViewProps {
  /** React tag of the ScrollView whose edge effect this container drives; -1 for none. */
  scrollViewTag?: CodegenTypes.WithDefault<CodegenTypes.Int32, -1>;
  edge?: CodegenTypes.WithDefault<'top' | 'bottom', 'bottom'>;
  effectStyle?: CodegenTypes.WithDefault<'automatic' | 'soft' | 'hard', 'automatic'>;
  /** Below iOS 26: a gradient scrim from this colour to clear, under the container. */
  fallbackColor?: ColorValue;
}
export default codegenNativeComponent<NativeProps>('ALGScrollEdge', {excludedPlatforms: ['android']}) as HostComponent<NativeProps>;
