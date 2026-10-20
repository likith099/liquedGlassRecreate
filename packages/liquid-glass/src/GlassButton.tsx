import ConfiguredGlassButton from './ConfiguredGlassButton';
import React from 'react';
import GlassPressable from './GlassPressable';
import Fallback from './fallback/NativeGlassButton';
import type {GlassButtonProps} from './types';
export default function GlassButton(props: GlassButtonProps) {
  if (props.title !== undefined && (props.symbol || props.image || props.controlSize || props.badge || props.contentTransition || props.pressEffect)) return <ConfiguredGlassButton {...props} />;
  return props.title === undefined ? <GlassPressable {...props} /> : <Fallback {...props} />;
}
