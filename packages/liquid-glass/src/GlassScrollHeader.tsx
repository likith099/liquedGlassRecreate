import React from 'react';
import GlassProgressiveBlur from './GlassProgressiveBlur';
import type {GlassScrollHeaderProps} from './types';
/** @deprecated Use GlassProgressiveBlur with edge="top". This compatible alias remains supported. */
export default function GlassScrollHeader(props: GlassScrollHeaderProps) {
  return <GlassProgressiveBlur {...props} edge="top" />;
}
