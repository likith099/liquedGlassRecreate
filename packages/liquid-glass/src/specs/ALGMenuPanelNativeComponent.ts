import type * as React from 'react';
import {codegenNativeCommands, codegenNativeComponent, type ViewProps, type CodegenTypes,
  type HostComponent} from 'react-native';
/** A menu drawn in place by UIKit or Android views, laid out by React Native. */
export interface NativeProps extends ViewProps {
  itemsJSON: string;
  /** The text size multiplier, so native rows match GlassMenuPanel.measure(). */
  fontScale?: CodegenTypes.WithDefault<CodegenTypes.Float, 1>;
  colorScheme?: CodegenTypes.WithDefault<'system' | 'light' | 'dark', 'system'>;
  disabled?: CodegenTypes.WithDefault<boolean, false>;
  appearFrom?: CodegenTypes.WithDefault<'none' | 'top' | 'bottom', 'none'>;
  autoFocus?: CodegenTypes.WithDefault<boolean, false>;
  menuModal?: CodegenTypes.WithDefault<boolean, false>;
  /** Android popup style (corner radius, light and dark colours) as JSON. */
  menuStyleJSON?: string;
  controlTestID?: string;
  onMenuAction?: CodegenTypes.DirectEventHandler<Readonly<{id: string}>>;
  onCancelTouch?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
  onDismissed?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
  onRequestClose?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}
type NativeMenuPanelComponent = HostComponent<NativeProps>;
interface NativeCommands {
  /** Animates the panel out, then fires onDismissed. */
  dismiss: (viewRef: React.ElementRef<NativeMenuPanelComponent>) => void;
}
export const Commands: NativeCommands = codegenNativeCommands<NativeCommands>({supportedCommands: ['dismiss']});
export default codegenNativeComponent<NativeProps>('ALGMenuPanel') as NativeMenuPanelComponent;
