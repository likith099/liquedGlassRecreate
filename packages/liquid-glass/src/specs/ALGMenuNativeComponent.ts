import type * as React from 'react';
import {codegenNativeCommands, codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes,
  type HostComponent} from 'react-native';
export interface NativeProps extends ViewProps {
  title: string;
  itemsJSON: string;
  contextMenu?: CodegenTypes.WithDefault<boolean, false>;
  previewCornerRadius?: CodegenTypes.WithDefault<CodegenTypes.Float, 16>;
  /** Context menu: 'below' keeps the menu below the content (the content moves up if needed). */
  menuPlacement?: CodegenTypes.WithDefault<'system' | 'below', 'system'>;
  /** Per-corner preview radii; -1 uses previewCornerRadius. */
  previewCornerTopLeft?: CodegenTypes.WithDefault<CodegenTypes.Float, -1>;
  previewCornerTopRight?: CodegenTypes.WithDefault<CodegenTypes.Float, -1>;
  previewCornerBottomLeft?: CodegenTypes.WithDefault<CodegenTypes.Float, -1>;
  previewCornerBottomRight?: CodegenTypes.WithDefault<CodegenTypes.Float, -1>;
  toolbar?: CodegenTypes.WithDefault<boolean, false>;
  maxVisibleItems?: CodegenTypes.WithDefault<CodegenTypes.Int32, 3>;
  mergingEnabled?: CodegenTypes.WithDefault<boolean, false>;
  /** An invisible anchor the app positions; open() presents the native menu attached to it. */
  menuAnchor?: CodegenTypes.WithDefault<boolean, false>;
  /** Round icon-only control: SF Symbol alone, square frame, capsule corners. */
  iconMode?: CodegenTypes.WithDefault<boolean, false>;
  /** Icon-mode glyph size in points. */
  symbolPointSize?: CodegenTypes.WithDefault<CodegenTypes.Float, 17>;
  /** Icon-mode material appearance. */
  colorScheme?: CodegenTypes.WithDefault<'system' | 'light' | 'dark', 'system'>;
  /** Icon mode: prominent is filled with the tint colour, for floating action buttons. */
  iconVariant?: CodegenTypes.WithDefault<'regular' | 'prominent', 'regular'>;
  /** Android icon-mode drawable resource name. */
  androidIcon?: string;
  /** Android menu popup style (corner radius, light and dark colours) as JSON; empty for defaults. */
  menuStyleJSON?: string;
  systemImage?: string;
  disabled?: CodegenTypes.WithDefault<boolean, false>;
  forceFallback?: CodegenTypes.WithDefault<boolean, false>;
  glassTint?: ColorValue;
  controlLabel?: string;
  controlHint?: string;
  controlTestID?: string;
  onMenuAction?: CodegenTypes.DirectEventHandler<Readonly<{id: string}>>;
  /** Icon mode without items: the button was activated. */
  onButtonPress?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
  onMenuOpen?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
  onMenuClose?: CodegenTypes.DirectEventHandler<Readonly<{}>>;
}
type NativeMenuComponent = HostComponent<NativeProps>;
interface NativeCommands {
  /** Presents the button's menu. iOS 17.4+ and Android; a no-op on older iOS. */
  open: (viewRef: React.ElementRef<NativeMenuComponent>) => void;
}
export const Commands: NativeCommands = codegenNativeCommands<NativeCommands>({supportedCommands: ['open']});
export default codegenNativeComponent<NativeProps>('ALGMenu') as NativeMenuComponent;
