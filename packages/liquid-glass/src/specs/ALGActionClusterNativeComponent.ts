import {codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes} from 'react-native';
export interface NativeProps extends ViewProps {
  actionsJSON?: string;
  expanded?: CodegenTypes.WithDefault<boolean, false>;
  mergingEnabled?: CodegenTypes.WithDefault<boolean, false>;
  spacing?: CodegenTypes.WithDefault<CodegenTypes.Float, 20>;
  glassTint?: ColorValue;
  material?: CodegenTypes.WithDefault<'regular' | 'clear', 'regular'>;
  interactive?: CodegenTypes.WithDefault<boolean, true>;
  duration?: CodegenTypes.WithDefault<CodegenTypes.Double, 0.45>;
  toggleLabel?: string;
  onAction?: CodegenTypes.DirectEventHandler<Readonly<{id: string}>>;
  onExpandedChange?: CodegenTypes.DirectEventHandler<Readonly<{expanded: boolean}>>;
}
export default codegenNativeComponent<NativeProps>('ALGActionCluster', {excludedPlatforms: ['android']});
