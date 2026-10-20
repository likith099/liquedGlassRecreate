import React from 'react';
import {type ViewProps} from 'react-native';
import NativeSurface from './specs/ALGSurfaceNativeComponent';
/** iOS 26 extends the content behind adjacent chrome using UIBackgroundExtensionView. */
export default function GlassBackgroundExtension(props: ViewProps) { return <NativeSurface {...props} backgroundExtension material="none" />; }
