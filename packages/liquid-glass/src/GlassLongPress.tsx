import React from 'react';
import NativeLongPress from './specs/ALGLongPressNativeComponent';
import type {GlassLongPressProps} from './types';

/**
 * A native long press around React children. Before it is recognised it stays out of the way:
 * the children's own taps work and an enclosing list scrolls when the finger moves more than
 * `allowableMovement`. Once recognised it reports the children's frame in window points, cancels
 * their touch (they do not fire onPress on release), and hands the same finger to the most recently
 * mounted GlassMenuPanel: sliding highlights rows, lifting on a row chooses it, and lifting
 * anywhere else leaves the panel open for a tap.
 */
export default function GlassLongPress({children, minimumDuration = 500, allowableMovement = 10, disabled = false,
  haptic = 'none', onLongPress, ...props}: GlassLongPressProps) {
  if (!(Number.isFinite(minimumDuration) && minimumDuration >= 0)) {
    throw new Error('GlassLongPress minimumDuration must be a nonnegative number of milliseconds.');
  }
  if (!(Number.isFinite(allowableMovement) && allowableMovement >= 0)) {
    throw new Error('GlassLongPress allowableMovement must be a nonnegative number.');
  }
  return <NativeLongPress {...props} minimumDuration={Math.round(minimumDuration)} allowableMovement={allowableMovement}
    disabled={disabled} haptic={haptic}
    onLongPress={({nativeEvent: {x, y, width, height}}) => onLongPress?.({frame: {x, y, width, height}})}>
    {children}
  </NativeLongPress>;
}
