import {codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes, type HostComponent} from 'react-native';
export interface NativeProps extends ViewProps {
  itemsJSON: string;
  selectedValue: string;
  selectionRevision?: CodegenTypes.WithDefault<CodegenTypes.Int32, 0>;
  disabled?: CodegenTypes.WithDefault<boolean, false>;
  glassTint?: ColorValue;
  androidBackgroundColor?: ColorValue;
  androidIndicatorColor?: ColorValue;
  controlTestID?: string;
  onSelectionChange?: CodegenTypes.DirectEventHandler<Readonly<{id: string}>>;
}
export default codegenNativeComponent<NativeProps>('ALGTabs') as HostComponent<NativeProps>;
