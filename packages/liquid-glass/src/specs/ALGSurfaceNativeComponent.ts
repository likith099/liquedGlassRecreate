import {codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes, type HostComponent} from 'react-native';
export interface NativeProps extends ViewProps {
  backgroundExtension?: CodegenTypes.WithDefault<boolean, false>;
  transition?: CodegenTypes.WithDefault<'none' | 'materialize', 'none'>;
  material?: CodegenTypes.WithDefault<'regular' | 'clear' | 'none', 'regular'>;
  interactive?: CodegenTypes.WithDefault<boolean, false>;
  glassTint?: ColorValue;
  glassRadius?: CodegenTypes.WithDefault<CodegenTypes.Float, 24>;
  container?: CodegenTypes.WithDefault<boolean, false>;
  mergingEnabled?: CodegenTypes.WithDefault<boolean, false>;
  spacing?: CodegenTypes.WithDefault<CodegenTypes.Float, 20>;
  animationDuration?: CodegenTypes.WithDefault<CodegenTypes.Double, 0.35>;
  colorScheme?: CodegenTypes.WithDefault<'system' | 'light' | 'dark', 'system'>;
}
export default codegenNativeComponent<NativeProps>('ALGSurface', {excludedPlatforms: ['android']}) as HostComponent<NativeProps>;
