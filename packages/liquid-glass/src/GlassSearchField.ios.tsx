import React, {useImperativeHandle, useRef, useState} from 'react';
import {useWindowDimensions} from 'react-native';
import adaptiveHeight from './adaptiveHeight';
import NativeSearchField, {Commands} from './specs/ALGSearchFieldNativeComponent';
import type {GlassHostRef, GlassSearchFieldProps} from './types';

/**
 * A UIKit UISearchTextField on glass (iOS 26), system blur (15–25) or an opaque fill. Controlled:
 * pass `value` and update it in `onChangeText`.
 */
export default function GlassSearchField({ref, value, onChangeText, onSubmitEditing, onFocus, onBlur,
  placeholder = 'Search', disabled = false, tintColor, colorScheme = 'system', forceFallback = false,
  accessibilityLabel, accessibilityState: _state, testID, style, ...props}: GlassSearchFieldProps) {
  const {fontScale} = useWindowDimensions();
  const host = useRef<GlassHostRef>(null);
  // The last native change React has seen, so a stale value never overwrites newer typing.
  const [mostRecentEventCount, setMostRecentEventCount] = useState(0);
  useImperativeHandle(ref, () => ({
    focus: () => { if (host.current) Commands.focus(host.current as never); },
    blur: () => { if (host.current) Commands.blur(host.current as never); },
    measure: callback => host.current?.measure(callback),
    measureInWindow: callback => host.current?.measureInWindow(callback),
    measureLayout: (relativeTo, onSuccess, onFail) => host.current?.measureLayout(relativeTo, onSuccess, onFail),
  }), []);
  return <NativeSearchField {...props} ref={host} accessible={false}
    style={[{height: adaptiveHeight(44, 20, fontScale)}, style]} value={value}
    mostRecentEventCount={mostRecentEventCount} placeholder={placeholder} disabled={disabled}
    glassTint={tintColor} colorScheme={colorScheme} forceFallback={forceFallback}
    controlLabel={accessibilityLabel} controlTestID={testID}
    onSearchChange={event => {
      setMostRecentEventCount(event.nativeEvent.eventCount);
      if (!disabled) onChangeText(event.nativeEvent.text);
    }}
    onSearchSubmit={event => onSubmitEditing?.(event.nativeEvent.text)}
    onSearchFocus={() => onFocus?.()} onSearchBlur={() => onBlur?.()} />;
}
