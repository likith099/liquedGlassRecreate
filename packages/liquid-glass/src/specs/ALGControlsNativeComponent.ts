import {codegenNativeComponent, type CodegenTypes, type HostComponent, type ViewProps} from 'react-native';
export interface NativeProps extends ViewProps {
  configJSON: string;
  onControlAction?: CodegenTypes.DirectEventHandler<Readonly<{id: string; action: string}>>;
  onContentSize?: CodegenTypes.DirectEventHandler<Readonly<{width: CodegenTypes.Double; height: CodegenTypes.Double}>>;
}
export default codegenNativeComponent<NativeProps>('ALGControls') as HostComponent<NativeProps>;
