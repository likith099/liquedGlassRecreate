import {codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes, type HostComponent} from 'react-native';
export interface NativeProps extends ViewProps {
  optionsJSON: string;
  selectedValue: string;
  disabled?: CodegenTypes.WithDefault<boolean, false>;
  material?: CodegenTypes.WithDefault<'glass' | 'tinted', 'glass'>;
  /** Let neighbouring glass pills merge (iOS 26). Off by default. */
  mergingEnabled?: CodegenTypes.WithDefault<boolean, false>;
  contentInset?: CodegenTypes.WithDefault<CodegenTypes.Float, 16>;
  glassTint?: ColorValue;
  controlTestID?: string;
  onSelectionChange?: CodegenTypes.DirectEventHandler<Readonly<{value: string}>>;
}
export default codegenNativeComponent<NativeProps>('ALGExpandingTabs', {excludedPlatforms: ['android']}) as HostComponent<NativeProps>;
