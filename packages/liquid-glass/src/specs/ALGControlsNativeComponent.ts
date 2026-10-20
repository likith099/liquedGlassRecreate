import {codegenNativeComponent, type CodegenTypes, type HostComponent, type ViewProps} from 'react-native';
export interface NativeProps extends ViewProps {
  configJSON: string;
  onControlAction?: CodegenTypes.DirectEventHandler<Readonly<{id: string; action: string}>>;
}
// interfaceOnly: the shadow node is hand-written (common/cpp) so Yoga measures the control natively.
export default codegenNativeComponent<NativeProps>('ALGControls', {interfaceOnly: true}) as HostComponent<NativeProps>;
