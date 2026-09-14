import {codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes} from 'react-native';
export interface NativeProps extends ViewProps {
  itemsJSON: string;
  selectedValue: string;
  selectionRevision?: CodegenTypes.WithDefault<CodegenTypes.Int32, 0>;
  disabled?: CodegenTypes.WithDefault<boolean, false>;
  glassTint?: ColorValue;
  controlTestID?: string;
  onSelectionChange?: CodegenTypes.DirectEventHandler<Readonly<{id: string}>>;
}
export default codegenNativeComponent<NativeProps>('ALGTabs');
