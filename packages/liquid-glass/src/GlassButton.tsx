import React from 'react';
import GlassPressable from './GlassPressable';
import Fallback from './fallback/NativeGlassButton';
import type {GlassButtonProps} from './types';
export default function GlassButton(props: GlassButtonProps) {
  return props.title === undefined ? <GlassPressable {...props} /> : <Fallback {...props} />;
}
