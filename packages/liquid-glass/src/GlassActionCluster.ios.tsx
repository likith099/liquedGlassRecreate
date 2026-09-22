import React, {useState} from 'react';
import type {LayoutChangeEvent} from 'react-native';
import NativeCluster from './specs/ALGActionClusterNativeComponent';
import Fallback from './fallback/GlassActionCluster';
import {isLiquidGlassSupported} from './support';
import {validateActions} from './validateActions';
import type {GlassActionClusterProps} from './types';
export default function GlassActionCluster({actions, onAction, onExpandedChange, tintColor,
  iosImplementation = 'uikit',
  animationDuration = 0.45, pressFeedback: _pressFeedback, forceFallback, toggleLabel = 'Actions', style, onLayout, ...props}: GlassActionClusterProps) {
  const [width, setWidth] = useState<number | null>(null);
  validateActions(actions);
  // Match UIKit's 52-point controls, 12-point gaps and 12-point edge insets.
  // Measure this component, not the screen: a split window or nested panel can
  // be narrower. Keep the controlled expanded state across renderer changes.
  const tooNarrow = width !== null && width < 76 + actions.length * 64;
  const handleLayout = (event: LayoutChangeEvent) => {
    const nextWidth = event.nativeEvent.layout.width;
    if (Number.isFinite(nextWidth) && nextWidth > 0) setWidth(nextWidth);
    onLayout?.(event);
  };
  if (forceFallback || !isLiquidGlassSupported() || tooNarrow) {
    return <Fallback {...props} actions={actions} onAction={onAction} onExpandedChange={onExpandedChange}
      style={style} toggleLabel={toggleLabel} onLayout={handleLayout} />;
  }
  return <NativeCluster {...props} style={[{height: 88, minWidth: 80}, style]}
    iosImplementation={iosImplementation}
    onLayout={handleLayout}
    actionsJSON={JSON.stringify(actions)} glassTint={tintColor} duration={animationDuration} toggleLabel={toggleLabel}
    onAction={event => onAction(event.nativeEvent.id)}
    onExpandedChange={event => onExpandedChange(event.nativeEvent.expanded)} />;
}
