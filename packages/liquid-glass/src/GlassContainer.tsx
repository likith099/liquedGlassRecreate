import React from 'react';
import {View} from 'react-native';
import type {GlassContainerProps} from './types';
export default function GlassContainer({spacing: _spacing, mergingEnabled: _merging, forceFallback: _force, ...props}: GlassContainerProps) {
  return <View {...props} />;
}
