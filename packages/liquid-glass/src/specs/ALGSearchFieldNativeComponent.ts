import type * as React from 'react';
import {codegenNativeCommands, codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes,
  type HostComponent} from 'react-native';
export interface NativeProps extends ViewProps {
  value: string;
  /** The last native change event React has seen; stale values are not applied over newer typing. */
  mostRecentEventCount: CodegenTypes.Int32;
  placeholder?: string;
  disabled?: CodegenTypes.WithDefault<boolean, false>;
  glassTint?: ColorValue;
  colorScheme?: CodegenTypes.WithDefault<'system' | 'light' | 'dark', 'system'>;
  forceFallback?: CodegenTypes.WithDefault<boolean, false>;
  controlLabel?: string;
  controlTestID?: string;
  onSearchChange?: CodegenTypes.DirectEventHandler<Readonly<{text: string; eventCount: CodegenTypes.Int32}>>;
  onSearchSubmit?: CodegenTypes.DirectEventHandler<Readonly<{text: string}>>;
  onSearchFocus?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
  onSearchBlur?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}
type NativeSearchField = HostComponent<NativeProps>;
interface NativeCommands {
  focus: (viewRef: React.ElementRef<NativeSearchField>) => void;
  blur: (viewRef: React.ElementRef<NativeSearchField>) => void;
}
export const Commands: NativeCommands = codegenNativeCommands<NativeCommands>({supportedCommands: ['focus', 'blur']});
export default codegenNativeComponent<NativeProps>('ALGSearchField', {excludedPlatforms: ['android']}) as NativeSearchField;
