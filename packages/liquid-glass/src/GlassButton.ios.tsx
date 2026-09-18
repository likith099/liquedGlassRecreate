import React from 'react';
import {useWindowDimensions} from 'react-native';
import adaptiveHeight from './adaptiveHeight';
import NativeButton from './specs/ALGButtonNativeComponent';
import GlassPressable from './GlassPressable';
import Fallback from './fallback/NativeGlassButton';
import {isLiquidGlassSupported} from './support';
import type {GlassButtonProps} from './types';
export default function GlassButton(props: GlassButtonProps) {
  const {fontScale} = useWindowDimensions();
  if (props.title === undefined) return <GlassPressable {...props} />;
  if (props.forceFallback || !isLiquidGlassSupported()) return <Fallback {...props} />;
  const {onPress, tintColor, forceFallback: _fallback, accessibilityLabel, accessibilityHint,
    accessibilityState: _state, testID, style, ...nativeProps} = props;
  return <NativeButton {...nativeProps} style={[{height: adaptiveHeight(64, 20, fontScale)}, style]} glassTint={tintColor}
    accessible={false} controlLabel={accessibilityLabel ?? props.title} controlHint={accessibilityHint}
    controlTestID={testID} onActivate={() => {if (!props.disabled && !props.loading) onPress();}} />;
}
