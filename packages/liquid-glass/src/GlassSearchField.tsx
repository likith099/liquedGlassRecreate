import React, {useImperativeHandle, useRef} from 'react';
import {TextInput} from 'react-native';
import {useFallbackColors} from './fallbackTheme';
import type {GlassSearchFieldProps} from './types';

/** Android: a React Native TextInput on the opaque fallback surface, with the same API. */
export default function GlassSearchField({ref, value, onChangeText, onSubmitEditing, onFocus, onBlur,
  placeholder = 'Search', disabled = false, tintColor, colorScheme = 'system', forceFallback: _fallback,
  accessibilityLabel, style, ...props}: GlassSearchFieldProps) {
  const input = useRef<React.ComponentRef<typeof TextInput>>(null);
  const {dark, surface, foreground} = useFallbackColors(colorScheme);
  useImperativeHandle(ref, () => ({
    focus: () => input.current?.focus(),
    blur: () => input.current?.blur(),
    measure: callback => input.current?.measure(callback),
    measureInWindow: callback => input.current?.measureInWindow(callback),
    measureLayout: (relativeTo, onSuccess, onFail) => input.current?.measureLayout(relativeTo, onSuccess, onFail),
  }), []);
  return <TextInput {...props} ref={input} value={value} onChangeText={onChangeText}
    onSubmitEditing={event => onSubmitEditing?.(event.nativeEvent.text)} onFocus={() => onFocus?.()}
    onBlur={() => onBlur?.()} placeholder={placeholder} editable={!disabled} returnKeyType="search"
    // Like Android's SearchView: queries are not capitalised.
    autoCapitalize="none"
    accessibilityLabel={accessibilityLabel ?? placeholder} selectionColor={tintColor}
    placeholderTextColor={dark ? '#9EA2AE' : '#6B7080'}
    style={[{minHeight: 44, borderRadius: 22, paddingHorizontal: 18, fontSize: 17,
      backgroundColor: surface ?? (dark ? '#25272D' : '#F0F1F5'), color: foreground ?? (dark ? '#F4F4FA' : '#242630'),
      opacity: disabled ? 0.5 : 1}, style]} />;
}
