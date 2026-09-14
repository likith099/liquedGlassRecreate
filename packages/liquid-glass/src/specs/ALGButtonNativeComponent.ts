import {codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes} from 'react-native';
export interface NativeProps extends ViewProps {
  title: string;
  systemImage?: string;
  variant?: CodegenTypes.WithDefault<'regular' | 'prominent', 'regular'>;
  disabled?: CodegenTypes.WithDefault<boolean, false>;
  loading?: CodegenTypes.WithDefault<boolean, false>;
  glassTint?: ColorValue;
  colorScheme?: CodegenTypes.WithDefault<'system' | 'light' | 'dark', 'system'>;
  controlLabel?: string;
  controlHint?: string;
  controlTestID?: string;
  onActivate?: CodegenTypes.DirectEventHandler<Readonly<{activated: boolean}>>;
}
export default codegenNativeComponent<NativeProps>('ALGButton', {excludedPlatforms: ['android']});
