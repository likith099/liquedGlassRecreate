import {codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes} from 'react-native';
export interface NativeProps extends ViewProps {
  title: string;
  itemsJSON: string;
  toolbar?: CodegenTypes.WithDefault<boolean, false>;
  maxVisibleItems?: CodegenTypes.WithDefault<CodegenTypes.Int32, 3>;
  mergingEnabled?: CodegenTypes.WithDefault<boolean, false>;
  systemImage?: string;
  disabled?: CodegenTypes.WithDefault<boolean, false>;
  forceFallback?: CodegenTypes.WithDefault<boolean, false>;
  glassTint?: ColorValue;
  controlLabel?: string;
  controlHint?: string;
  controlTestID?: string;
  onMenuAction?: CodegenTypes.DirectEventHandler<Readonly<{id: string}>>;
}
export default codegenNativeComponent<NativeProps>('ALGMenu');
