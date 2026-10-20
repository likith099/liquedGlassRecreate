import React, {useLayoutEffect, useRef, useState} from 'react';
import type {ViewProps} from 'react-native';
import NativePresence from './specs/ALGPresenceNativeComponent';
export interface GlassPresenceProps extends ViewProps {
  visible: boolean;
  transition?: 'none' | 'materialize';
  onExited?: () => void;
}
/** Retains the last children until native exit completion. Interrupted exits do not report completion. */
export default function GlassPresence({visible, children, transition = 'materialize', onExited, ...props}: GlassPresenceProps) {
  const [mounted, setMounted] = useState(visible);
  const retained = useRef(children);
  const state = useRef({visible, exiting: false, onExited});
  useLayoutEffect(() => {
    state.current.visible = visible; state.current.onExited = onExited;
    if (visible) { retained.current = children; state.current.exiting = false; setMounted(true); }
    else if (mounted) state.current.exiting = true;
  }, [visible, children, mounted, onExited]);
  useLayoutEffect(() => () => {
    if (state.current.exiting) { state.current.exiting = false; state.current.onExited?.(); }
  }, []);
  if (!mounted && !visible) return null;
  return <NativePresence {...props} visible={visible} transition={transition}
    pointerEvents={visible ? props.pointerEvents : 'none'} accessibilityElementsHidden={!visible}
    importantForAccessibility={visible ? props.importantForAccessibility : 'no-hide-descendants'}
    onExited={() => {
      if (state.current.visible || !state.current.exiting) return;
      state.current.exiting = false; setMounted(false); state.current.onExited?.();
    }}>{visible ? children : retained.current}</NativePresence>;
}
