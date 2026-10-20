import type * as React from 'react';
import {codegenNativeComponent, codegenNativeCommands, type ViewProps, type CodegenTypes, type HostComponent} from 'react-native';
export interface NativeProps extends ViewProps {
  configJSON: string;
  scrollViewTag?: CodegenTypes.WithDefault<CodegenTypes.Int32, -1>;
  onNavigationInsets?: CodegenTypes.DirectEventHandler<Readonly<{top: CodegenTypes.Double; bottom: CodegenTypes.Double; titleWidth: CodegenTypes.Double}>>;
  onNavigationAction?: CodegenTypes.DirectEventHandler<Readonly<{id: string; action: string}>>;
  onNavigationSearch?: CodegenTypes.DirectEventHandler<Readonly<{kind: string; text: string; eventCount: CodegenTypes.Int32}>>;
}
type NativeNavigation = HostComponent<NativeProps>;
interface NativeCommands {
  scrollToTop: (viewRef: React.ElementRef<NativeNavigation>, animated: boolean) => void;
  focusSearch: (viewRef: React.ElementRef<NativeNavigation>) => void;
  dismissSearch: (viewRef: React.ElementRef<NativeNavigation>) => void;
}
export const Commands: NativeCommands = codegenNativeCommands<NativeCommands>({supportedCommands: ['scrollToTop', 'focusSearch', 'dismissSearch']});
export default codegenNativeComponent<NativeProps>('ALGNavigation') as NativeNavigation;
