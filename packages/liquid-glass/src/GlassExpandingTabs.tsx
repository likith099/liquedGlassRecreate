import React, {memo, useCallback, useEffect, useRef, useState} from 'react';
import {AccessibilityInfo, Animated, Image, Pressable, ScrollView, StyleSheet, View, processColor,
  useWindowDimensions, type ColorValue} from 'react-native';
import {useFallbackColors} from './fallbackTheme';
import {collapsedWidth, expandedWidth, pillMetrics} from './expandingTabsGeometry';
import {validateExpandingTabs} from './validateExpandingTabs';
import type {GlassExpandingTab, GlassExpandingTabsProps} from './types';
import {warnOnce} from './devWarnings';

/** `rgba()` for a static colour, so Animated can interpolate it. */
function rgba(color: ColorValue, alpha = 1): string {
  const argb = processColor(color) as number;
  return `rgba(${(argb >> 16) & 255}, ${(argb >> 8) & 255}, ${argb & 255}, ${(((argb >>> 24) & 255) / 255) * alpha})`;
}

type PillProps = {
  option: GlassExpandingTab; selected: boolean; position: string; disabled: boolean; testID?: string;
  ink: string; idleInk: string; idlePlate: string; wash: string; reduceMotion: boolean; fontScale: number;
  onPress: (value: string) => void;
};

/** One pill with its own progress; everything it draws is interpolated from that value. */
const Pill = memo(function Pill({option, selected, position, disabled, testID, ink, idleInk, idlePlate, wash,
  reduceMotion, fontScale, onPress}: PillProps) {
  // Starts at its target: the first frame draws the selected pill open without animating.
  const progress = useRef(new Animated.Value(selected ? 1 : 0)).current;
  const [labelWidth, setLabelWidth] = useState(0);
  const wasSelected = useRef(selected);
  useEffect(() => {
    // Only a change of this pill's own selection moves it; mounting never animates.
    if (wasSelected.current === selected) return;
    wasSelected.current = selected;
    const toValue = selected ? 1 : 0;
    if (reduceMotion) { progress.setValue(toValue); return; }
    // Springs from the current value, so a tap mid-animation reverses without a jump.
    Animated.spring(progress, {toValue, damping: 20, stiffness: 190, mass: 1, useNativeDriver: false}).start();
  }, [progress, reduceMotion, selected]);
  const m = pillMetrics;
  const along = (from: number | string, to: number | string) =>
    progress.interpolate({inputRange: [0, 1], outputRange: [from, to] as never, extrapolate: 'clamp'});
  const iconSize = Math.round(m.icon * Math.min(fontScale, 2));
  const height = Math.max(iconSize, Math.ceil(15 * 1.33 * fontScale)) + 2 * m.paddingVertical;
  return <Pressable testID={testID} accessibilityRole="tab" accessibilityLabel={option.label}
    accessibilityValue={{text: position}} accessibilityState={{selected, disabled}} disabled={disabled}
    hitSlop={{top: Math.max(0, (m.touchTarget - height) / 2), bottom: Math.max(0, (m.touchTarget - height) / 2)}}
    onPress={() => onPress(option.value)}
    style={({pressed}) => ({transform: [{scale: pressed ? 0.97 : 1}], opacity: disabled ? 0.45 : 1})}>
    <Animated.View style={[styles.pill, {height, borderRadius: height / 2,
      width: along(collapsedWidth(), expandedWidth(labelWidth)), backgroundColor: along(idlePlate, wash)}]}>
      {/* Two stacked icon copies crossfade from the idle ink to the accent. */}
      <View style={{width: iconSize, height: iconSize}}>
        {option.androidIcon && <>
          <Animated.Image source={{uri: option.androidIcon}}
            style={[styles.icon, {tintColor: idleInk, opacity: along(1, 0)}]} />
          <Animated.Image source={{uri: option.androidIcon}}
            style={[styles.icon, {tintColor: ink, opacity: along(0, 1)}]} />
        </>}
      </View>
      <Animated.View style={{width: along(0, m.gap)}} />
      {/* Revealed from the icon outwards by a growing clip box; visible only after halfway. */}
      <Animated.View style={{width: along(0, labelWidth), overflow: 'hidden'}}>
        <Animated.Text numberOfLines={1} style={[styles.label, {color: ink, opacity: progress.interpolate({
          inputRange: [0, 0.5, 1], outputRange: [0, 0, 1], extrapolate: 'clamp'})}]}>
          {option.label}
        </Animated.Text>
      </Animated.View>
    </Animated.View>
    {/* Measures the label at its natural width before it is ever shown. */}
    <View pointerEvents="none" style={styles.measure} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      <Animated.Text numberOfLines={1} style={styles.label}
        onLayout={event => setLabelWidth(Math.ceil(event.nativeEvent.layout.width))}>{option.label}</Animated.Text>
    </View>
  </Pressable>;
});

/** Android: the same pill model on React Native Animated. iOS uses the native SwiftUI control. */
export default function GlassExpandingTabs({options, value, onValueChange, onReselect, material: _material,
  mergingEnabled: _merging, contentInset = 16, tintColor, disabled = false, testID, style, ...props}: GlassExpandingTabsProps) {
  validateExpandingTabs(options, value);
  for (const option of options) {
    if (!option.androidIcon) {
      warnOnce(`expanding-tabs-icon-${option.value}`, `GlassExpandingTabs option "${option.value}" has no ` +
        'androidIcon, so its collapsed pill is empty on Android. Pass a drawable resource name.');
    }
  }
  const {fontScale} = useWindowDimensions();
  const {dark, surface} = useFallbackColors();
  const [reduceMotion, setReduceMotion] = useState(false);
  useEffect(() => {
    let active = true;
    AccessibilityInfo.isReduceMotionEnabled().then(enabled => { if (active) setReduceMotion(enabled); });
    const subscription = AccessibilityInfo.addEventListener('reduceMotionChanged', setReduceMotion);
    return () => { active = false; subscription.remove(); };
  }, []);
  const press = useCallback((next: string) => {
    if (disabled) return;
    if (next === value) onReselect?.(next);
    else onValueChange(next);
  }, [disabled, onReselect, onValueChange, value]);
  const idlePlate = rgba(surface ?? (dark ? '#25272D' : '#F0F1F5'));
  const idleInk = dark ? 'rgba(158, 162, 174, 1)' : 'rgba(107, 112, 128, 1)';
  return <View {...props} testID={testID} accessibilityRole="tablist" style={style}>
    <ScrollView horizontal showsHorizontalScrollIndicator={false} bounces={false} overScrollMode="never"
      contentContainerStyle={{paddingHorizontal: contentInset, gap: pillMetrics.spacing, alignItems: 'center'}}>
      {options.map((option, index) => {
        const accent = option.tintColor ?? tintColor ?? '#6159B7';
        return <Pill key={option.value} option={option} selected={option.value === value}
          position={`${index + 1} of ${options.length}`} disabled={disabled || !!option.disabled}
          testID={testID ? `${testID}-${option.value}` : undefined} ink={rgba(accent)} idleInk={idleInk}
          idlePlate={idlePlate} wash={rgba(accent, dark ? 0.26 : 0.16)} reduceMotion={reduceMotion}
          fontScale={fontScale} onPress={press} />;
      })}
    </ScrollView>
  </View>;
}

const styles = StyleSheet.create({
  pill: {flexDirection: 'row', alignItems: 'center', justifyContent: 'center', overflow: 'hidden'},
  icon: {position: 'absolute', width: '100%', height: '100%'},
  label: {fontSize: 15, fontWeight: '700'},
  measure: {position: 'absolute', left: 0, top: 0, width: 400, opacity: 0, flexDirection: 'row'},
});
