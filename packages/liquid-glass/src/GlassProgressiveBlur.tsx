import React from 'react';
import {useColorScheme} from 'react-native';
import GlassScrollEdge from './GlassScrollEdge';
import type {GlassProgressiveBlurProps} from './types';
/** Size and position the overlay yourself; UIKit supplies the progressive edge treatment. */
export default function GlassProgressiveBlur({edge = 'top', effect = 'soft', fallback = 'solid', fallbackColor,
  pointerEvents = 'box-none', ...props}: GlassProgressiveBlurProps) {
  const dark = useColorScheme() === 'dark';
  return <GlassScrollEdge {...props} edge={edge} effectStyle={effect === 'hard' ? 'progressiveHard' : 'progressive'} pointerEvents={pointerEvents}
    fallbackMode={fallback} fallbackColor={fallbackColor ?? (dark ? '#12141A' : '#F7F8FC')} />;
}
