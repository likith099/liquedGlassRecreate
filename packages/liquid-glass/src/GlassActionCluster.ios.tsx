import React from 'react';
import NativeCluster from './specs/ALGActionClusterNativeComponent';
import Fallback from './fallback/GlassActionCluster';
import {isLiquidGlassSupported} from './support';
import {validateActions} from './validateActions';
import type {GlassActionClusterProps} from './types';
export default function GlassActionCluster({actions, onAction, onExpandedChange, tintColor,
  animationDuration = 0.45, pressFeedback: _pressFeedback, forceFallback, toggleLabel = 'Actions', style, ...props}: GlassActionClusterProps) {
  validateActions(actions);
  if (forceFallback || !isLiquidGlassSupported()) {
    return <Fallback {...props} actions={actions} onAction={onAction} onExpandedChange={onExpandedChange}
      style={style} toggleLabel={toggleLabel} />;
  }
  return <NativeCluster {...props} style={[{height: 88, minWidth: 80}, style]}
    actionsJSON={JSON.stringify(actions)} glassTint={tintColor} duration={animationDuration} toggleLabel={toggleLabel}
    onAction={event => onAction(event.nativeEvent.id)}
    onExpandedChange={event => onExpandedChange(event.nativeEvent.expanded)} />;
}
