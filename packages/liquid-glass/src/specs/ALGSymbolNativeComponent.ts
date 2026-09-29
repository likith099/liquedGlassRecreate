import {codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes, type HostComponent} from 'react-native';
/** An SF Symbol drawn by UIKit, for rows React lays out itself (iOS only). */
export interface NativeProps extends ViewProps {
  systemImage: string;
  tint?: ColorValue;
  pointSize?: CodegenTypes.WithDefault<CodegenTypes.Float, 17>;
  weight?: CodegenTypes.WithDefault<'regular' | 'medium' | 'semibold', 'regular'>;
}
export default codegenNativeComponent<NativeProps>('ALGSymbol') as HostComponent<NativeProps>;
