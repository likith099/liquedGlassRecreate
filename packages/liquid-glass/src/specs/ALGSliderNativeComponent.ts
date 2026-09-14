import {codegenNativeComponent, type ViewProps, type ColorValue, type CodegenTypes} from 'react-native';
type SliderEvent = Readonly<{value: CodegenTypes.Double}>;
export interface NativeProps extends ViewProps {
  value: CodegenTypes.Double;
  minimumValue?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  maximumValue?: CodegenTypes.WithDefault<CodegenTypes.Double, 1>;
  step?: CodegenTypes.WithDefault<CodegenTypes.Double, 0>;
  disabled?: CodegenTypes.WithDefault<boolean, false>;
  glassTint?: ColorValue;
  revision?: CodegenTypes.WithDefault<CodegenTypes.Int32, 0>;
  controlLabel?: string;
  controlHint?: string;
  controlTestID?: string;
  onSliderChange?: CodegenTypes.DirectEventHandler<SliderEvent>;
  onSliderStart?: CodegenTypes.DirectEventHandler<SliderEvent>;
  onSliderComplete?: CodegenTypes.DirectEventHandler<SliderEvent>;
  onSliderCancel?: CodegenTypes.DirectEventHandler<SliderEvent>;
}
export default codegenNativeComponent<NativeProps>('ALGSlider');
