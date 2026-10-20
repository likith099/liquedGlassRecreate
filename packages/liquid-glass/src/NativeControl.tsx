import React, {useState} from 'react';
import NativeControls, {type NativeProps} from './specs/ALGControlsNativeComponent';
/** One size event per content/font change, never per animation frame. Explicit layout wins. */
export default function NativeControl({style, stretch, minimumHeight, ...props}: NativeProps & {stretch?: boolean; minimumHeight: number}) {
  const [size, setSize] = useState({width: minimumHeight, height: minimumHeight});
  return <NativeControls {...props} accessible={false}
    style={[{height: size.height, ...(stretch ? {alignSelf: 'stretch' as const} : {width: size.width})}, style]}
    onContentSize={({nativeEvent: next}) => setSize(previous => previous.width === next.width && previous.height === next.height ? previous : next)} />;
}
