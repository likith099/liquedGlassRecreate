import React from 'react';
import {View} from 'react-native';
import {warnSpacingWithoutMerging} from './devWarnings';
import type {GlassContainerProps} from './types';
export default function GlassContainer({spacing, mergingEnabled, forceFallback: _force, ...props}: GlassContainerProps) {
  warnSpacingWithoutMerging(spacing, mergingEnabled);
  return <View {...props} />;
}
