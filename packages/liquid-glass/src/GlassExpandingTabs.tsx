import React, {memo, useCallback, useEffect, useMemo, useRef, useState} from 'react';
import {AccessibilityInfo, Animated, Easing, Pressable, ScrollView, StyleSheet, Text, View, processColor,
  useWindowDimensions, type ColorValue} from 'react-native';
import {useFallbackColors} from './fallbackTheme';
import {collapsedWidth, expandedWidth, pillMetrics, type PillMetrics} from './expandingTabsGeometry';
import {validateExpandingTabs} from './validateExpandingTabs';
import type {GlassExpandingTab, GlassExpandingTabsProps} from './types';
import {warnOnce} from './devWarnings';

type RGBA = [number, number, number, number];
const channels = (color: ColorValue): RGBA => {
  const argb = processColor(color) as number;
  return [(argb >> 16) & 255, (argb >> 8) & 255, argb & 255, ((argb >>> 24) & 255) / 255];
};
const css = ([r, g, b, a]: RGBA) => `rgba(${Math.round(r)}, ${Math.round(g)}, ${Math.round(b)}, ${a})`;
/** `amount` of `top` laid over an opaque `base`, as one opaque colour. */
const over = (base: ColorValue, top: ColorValue, amount: number): string => {
  const [r1, g1, b1] = channels(base), [r2, g2, b2] = channels(top);
  return css([r1 + (r2 - r1) * amount, g1 + (g2 - g1) * amount, b1 + (b2 - b1) * amount, 1]);
};

/** Duration of a selection change, in milliseconds. */
const SELECT_DURATION = 300;

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);
type Node = Animated.Value | Animated.AnimatedInterpolation<number> | Animated.AnimatedAddition;

/**
 * A capsule whose width follows `width`, drawn with transforms only: two end caps and a middle strip
 * that stretches. `open` is the largest width it takes.
 */
function Capsule({color, height, closed, open, progress}: {color: string; height: number; closed: number;
  open: number; progress: Animated.Value}) {
  const along = (from: number, to: number) =>
    progress.interpolate({inputRange: [0, 1], outputRange: [from, to], extrapolate: 'clamp'});
  const middle = Math.max(1, open - height);
  const cap = {width: height, height, borderRadius: height / 2, backgroundColor: color};
  return <>
    <View style={[styles.fill, cap]} />
    <Animated.View style={[styles.fill, {left: height / 2, width: middle, height, backgroundColor: color,
      transformOrigin: 'left', transform: [{scaleX: along((closed - height) / middle, (open - height) / middle)}]}]} />
    <Animated.View style={[styles.fill, cap, {transform: [{translateX: along(closed - height, open - height)}]}]} />
  </>;
}

type PillProps = {
  option: GlassExpandingTab; selected: boolean; position: string; disabled: boolean; testID?: string;
  ink: string; idleInk: string; idlePlate: string; washPlate: string; progress: Animated.Value; left: Node;
  metrics: PillMetrics; height: number; labelWidth: number; onLabelWidth: (value: string, width: number) => void;
  onPress: (value: string) => void;
};

/**
 * One pill, animated with transforms and opacity only, on the native driver. The UI thread updates
 * every pill in the same frame, so they move together. (Animating `width` or `left` from JavaScript
 * does not: on the New Architecture those updates reach the views out of step and the row shakes,
 * and Android's LayoutAnimation is off by default.)
 */
const Pill = memo(function Pill({option, selected, position, disabled, testID, ink, idleInk, idlePlate,
  washPlate, progress, left, metrics: m, height, labelWidth, onLabelWidth, onPress}: PillProps) {
  const [pressed, setPressed] = useState(false);
  const along = (from: number, to: number) =>
    progress.interpolate({inputRange: [0, 1], outputRange: [from, to], extrapolate: 'clamp'});
  const closed = collapsedWidth(m), open = expandedWidth(labelWidth, m);
  // Centred content: its inset grows from the closed to the open padding, linearly in progress.
  const labelX = along(m.paddingClosed + m.icon, m.paddingOpen + m.icon + m.gap);
  // The label is revealed from the icon outwards: a window as wide as the label moves right while
  // the text inside moves left by the same amount, so the text stays put and only its start shows.
  const hidden = along(labelWidth, 0);
  return <AnimatedPressable testID={testID} accessibilityRole="tab" accessibilityLabel={option.label}
    accessibilityValue={{text: position}} accessibilityState={{selected, disabled}} disabled={disabled}
    hitSlop={{top: Math.max(0, (m.touchTarget - height) / 2), bottom: Math.max(0, (m.touchTarget - height) / 2)}}
    onPress={() => onPress(option.value)} onPressIn={() => setPressed(true)} onPressOut={() => setPressed(false)}
    needsOffscreenAlphaCompositing={disabled}
    style={[styles.pill, {width: selected ? open : closed, height, opacity: disabled ? 0.45 : 1,
      transform: [{translateX: left}, {scale: pressed ? 0.97 : 1}]}]}>
    <Capsule color={idlePlate} height={height} closed={closed} open={open} progress={progress} />
    {/* The accent plate fades in over the neutral one. It is opaque, and composited as one layer, so
        its overlapping pieces show no seams. */}
    <Animated.View pointerEvents="none" needsOffscreenAlphaCompositing
      style={[styles.fill, {width: open, height, opacity: progress}]}>
      <Capsule color={washPlate} height={height} closed={closed} open={open} progress={progress} />
    </Animated.View>
    {/* Two stacked icon copies crossfade from the idle ink to the accent. */}
    <Animated.View pointerEvents="none" style={[styles.fill, {top: (height - m.icon) / 2, width: m.icon,
      height: m.icon, transform: [{translateX: along(m.paddingClosed, m.paddingOpen)}]}]}>
      {option.androidIcon && <>
        <Animated.Image source={{uri: option.androidIcon}}
          style={[styles.icon, {tintColor: idleInk, opacity: along(1, 0)}]} />
        <Animated.Image source={{uri: option.androidIcon}} style={[styles.icon, {tintColor: ink, opacity: progress}]} />
      </>}
    </Animated.View>
    <Animated.View pointerEvents="none" style={[styles.fill, styles.clip, {width: labelWidth, height,
      transform: [{translateX: Animated.subtract(labelX, hidden)}]}]}>
      {/* Visible only after halfway, so text never shows squeezed into a pill still too narrow. */}
      <Animated.Text numberOfLines={1} style={[styles.label, {width: labelWidth, color: ink,
        opacity: progress.interpolate({inputRange: [0, 0.5, 1], outputRange: [0, 0, 1], extrapolate: 'clamp'}),
        transform: [{translateX: hidden}]}]}>
        {option.label}
      </Animated.Text>
    </Animated.View>
    {/* Measures the label at its natural width before it is ever shown. */}
    <View pointerEvents="none" style={styles.measure} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      <Text numberOfLines={1} style={styles.label}
        onLayout={event => onLabelWidth(option.value, Math.ceil(event.nativeEvent.layout.width))}>{option.label}</Text>
    </View>
  </AnimatedPressable>;
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
  // One progress per pill, kept across renders and starting at its target: mounting never animates.
  const progress = useRef(new Map<string, Animated.Value>()).current;
  for (const option of options) {
    if (!progress.has(option.value)) progress.set(option.value, new Animated.Value(option.value === value ? 1 : 0));
  }
  const shown = useRef(value);
  useEffect(() => {
    // Only a selection change animates. Every pill starts from where it is, so a tap mid-animation
    // reverses without a jump.
    if (shown.current === value) return;
    shown.current = value;
    for (const option of options) {
      const node = progress.get(option.value)!;
      const toValue = option.value === value ? 1 : 0;
      if (reduceMotion) node.setValue(toValue);
      else Animated.timing(node, {toValue, duration: SELECT_DURATION, easing: Easing.inOut(Easing.ease),
        useNativeDriver: true}).start();
    }
  }, [options, progress, reduceMotion, value]);
  const [labelWidths, setLabelWidths] = useState<Record<string, number>>({});
  const onLabelWidth = useCallback((key: string, width: number) =>
    setLabelWidths(current => current[key] === width ? current : {...current, [key]: width}), []);
  const press = useCallback((next: string) => {
    if (disabled) return;
    if (next === value) onReselect?.(next);
    else onValueChange(next);
  }, [disabled, onReselect, onValueChange, value]);

  const iconSize = Math.round(pillMetrics.icon * Math.min(fontScale, 2));
  const metrics = useMemo((): PillMetrics => ({...pillMetrics, icon: iconSize}), [iconSize]);
  const height = Math.max(iconSize, Math.ceil(15 * 1.33 * fontScale)) + 2 * pillMetrics.paddingVertical;
  // Each pill's offset is the inset plus the widths and spacing before it, from the same animated
  // values the pills draw with, so the row stays packed in every frame.
  const lefts = useMemo(() => {
    let left: Node = new Animated.Value(contentInset);
    return options.map(option => {
      const placed = left;
      const width = progress.get(option.value)!.interpolate({inputRange: [0, 1], extrapolate: 'clamp',
        outputRange: [collapsedWidth(metrics), expandedWidth(labelWidths[option.value] ?? 0, metrics)]});
      left = Animated.add(Animated.add(left, width), metrics.spacing);
      return placed;
    });
  }, [contentInset, labelWidths, metrics, options, progress]);
  // The scroll extent is the row at its destination.
  const rowWidth = options.reduce((sum, option) => sum + (option.value === value
    ? expandedWidth(labelWidths[option.value] ?? 0, metrics) : collapsedWidth(metrics)), 0) +
    metrics.spacing * Math.max(0, options.length - 1) + 2 * contentInset;
  const plate = surface ?? (dark ? '#25272D' : '#F0F1F5');
  const idlePlate = css(channels(plate));
  const idleInk = dark ? 'rgba(158, 162, 174, 1)' : 'rgba(107, 112, 128, 1)';
  return <View {...props} testID={testID} accessibilityRole="tablist" style={style}>
    <ScrollView horizontal showsHorizontalScrollIndicator={false} bounces={false} overScrollMode="never"
      contentContainerStyle={{alignItems: 'center', flexGrow: 1}}>
      <View style={{width: rowWidth, height}}>
        {options.map((option, index) => {
          const accent = option.tintColor ?? tintColor ?? '#6159B7';
          return <Pill key={option.value} option={option} selected={option.value === value}
            position={`${index + 1} of ${options.length}`} disabled={disabled || !!option.disabled}
            testID={testID ? `${testID}-${option.value}` : undefined} ink={css(channels(accent))} idleInk={idleInk}
            idlePlate={idlePlate} washPlate={over(plate, accent, dark ? 0.26 : 0.16)}
            progress={progress.get(option.value)!} left={lefts[index]} metrics={metrics} height={height}
            labelWidth={labelWidths[option.value] ?? 0} onLabelWidth={onLabelWidth} onPress={press} />;
        })}
      </View>
    </ScrollView>
  </View>;
}

const styles = StyleSheet.create({
  pill: {position: 'absolute', left: 0, top: 0},
  fill: {position: 'absolute', left: 0, top: 0},
  clip: {overflow: 'hidden', justifyContent: 'center'},
  icon: {position: 'absolute', width: '100%', height: '100%'},
  label: {fontSize: 15, fontWeight: '700'},
  measure: {position: 'absolute', left: 0, top: 0, width: 400, opacity: 0, flexDirection: 'row'},
});
