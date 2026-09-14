import {codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes} from 'react-native';
export interface NativeProps extends ViewProps {
  optionsJSON: string;
  selectedValue: string;
  disabled?: CodegenTypes.WithDefault<boolean, false>;
  glassTint?: ColorValue;
  colorScheme?: CodegenTypes.WithDefault<'system' | 'light' | 'dark', 'system'>;
  controlLabel?: string;
  controlTestID?: string;
  onSelectionChange?: CodegenTypes.DirectEventHandler<Readonly<{value: string}>>;
}
export default codegenNativeComponent<NativeProps>('ALGSegmented', {excludedPlatforms: ['android']});
