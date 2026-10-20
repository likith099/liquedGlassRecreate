import {codegenNativeComponent, type CodegenTypes, type HostComponent, type ViewProps} from 'react-native';
export interface NativeProps extends ViewProps {
  visible?: CodegenTypes.WithDefault<boolean, true>;
  transition?: CodegenTypes.WithDefault<'none' | 'materialize', 'materialize'>;
  onExited?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}
export default codegenNativeComponent<NativeProps>('ALGPresence') as HostComponent<NativeProps>;
