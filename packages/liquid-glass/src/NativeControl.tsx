import React from 'react';
import NativeControls, {type NativeProps} from './specs/ALGControlsNativeComponent';
/**
 * The native shadow node measures the control during layout (no JS round trip), so
 * the first frame has its final size and a content change resizes even while JS is
 * busy. Explicit layout in `style` still wins; `stretch` fills the cross axis.
 * `minimumHeight` is part of the native configuration and kept for call-site clarity.
 */
export default function NativeControl({style, stretch, minimumHeight: _minimumHeight, ...props}: NativeProps & {stretch?: boolean; minimumHeight: number}) {
  return <NativeControls {...props} accessible={false} style={[stretch ? {alignSelf: 'stretch' as const} : null, style]} />;
}
