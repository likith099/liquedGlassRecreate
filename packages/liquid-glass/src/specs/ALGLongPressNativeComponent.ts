import {codegenNativeComponent, type ViewProps, type CodegenTypes, type HostComponent} from 'react-native';
/** A native long press around React children that hands its finger to the latest menu panel. */
export interface NativeProps extends ViewProps {
  minimumDuration?: CodegenTypes.WithDefault<CodegenTypes.Int32, 500>;
  allowableMovement?: CodegenTypes.WithDefault<CodegenTypes.Float, 10>;
  disabled?: CodegenTypes.WithDefault<boolean, false>;
  haptic?: CodegenTypes.WithDefault<'none' | 'light' | 'medium' | 'heavy' | 'soft' | 'rigid', 'none'>;
  onLongPress?: CodegenTypes.DirectEventHandler<Readonly<{x: CodegenTypes.Double; y: CodegenTypes.Double; width: CodegenTypes.Double; height: CodegenTypes.Double}>>;
}
export default codegenNativeComponent<NativeProps>('ALGLongPress') as HostComponent<NativeProps>;
