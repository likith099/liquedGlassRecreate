import React, {createContext, useCallback, useContext, useEffect, useMemo, useRef, useState} from 'react';
import {AccessibilityInfo, Animated, StyleSheet, Text, View, type StyleProp, type ViewStyle} from 'react-native';
import GlassBadge from './GlassBadge';
import {useFallbackColors} from './fallbackTheme';

export interface GlassToastOptions {
  /** Milliseconds on screen. Defaults to 2000. */
  duration?: number;
}
export interface GlassToastController {
  /** Shows a short confirmation, replacing any toast on screen, and announces it to screen readers. */
  show(message: string, options?: GlassToastOptions): void;
}
export interface GlassToastProviderProps {
  children: React.ReactNode;
  /** Distance from the bottom of the provider, for example above a tab bar. Defaults to 100. */
  bottomOffset?: number;
  colorScheme?: 'system' | 'light' | 'dark';
  /** Style for the toast's position container. */
  style?: StyleProp<ViewStyle>;
}

const ToastContext = createContext<GlassToastController | null>(null);

/** Hosts toasts for its subtree; place it near the root, inside any safe-area handling. */
export function GlassToastProvider({children, bottomOffset = 100, colorScheme = 'dark', style}: GlassToastProviderProps) {
  const [toast, setToast] = useState<{message: string; id: number} | null>(null);
  const {dark, foreground} = useFallbackColors(colorScheme);
  // Entrance progress, 0 hidden to 1 shown. It drives a slide, never opacity: a visual effect view
  // does not render while an ancestor's alpha is below 1.
  const progress = useRef(new Animated.Value(0)).current;
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reduceMotion = useRef(false);
  useEffect(() => {
    let active = true;
    AccessibilityInfo.isReduceMotionEnabled().then(enabled => { if (active) reduceMotion.current = enabled; });
    const subscription = AccessibilityInfo.addEventListener('reduceMotionChanged', enabled => { reduceMotion.current = enabled; });
    return () => { active = false; subscription.remove(); if (timer.current) clearTimeout(timer.current); };
  }, []);
  const animate = useCallback((to: number, done?: () => void) => {
    if (reduceMotion.current) { progress.setValue(to); done?.(); return; }
    Animated.spring(progress, {toValue: to, damping: 22, stiffness: 260, useNativeDriver: true})
      .start(({finished}) => { if (finished) done?.(); });
  }, [progress]);
  const show = useCallback((message: string, {duration = 2000}: GlassToastOptions = {}) => {
    if (timer.current) clearTimeout(timer.current);
    setToast(current => ({message, id: (current?.id ?? 0) + 1}));
    AccessibilityInfo.announceForAccessibility(message);
    animate(1);
    timer.current = setTimeout(() => animate(0, () => setToast(null)), Math.max(0, duration));
  }, [animate]);
  const controller = useMemo(() => ({show}), [show]);
  return <ToastContext.Provider value={controller}>
    {children}
    {toast && <View pointerEvents="none" style={[styles.host, {bottom: bottomOffset}, style]}>
      {/* Announced through announceForAccessibility; hidden from focus to avoid a second reading. */}
      <Animated.View importantForAccessibility="no-hide-descendants" accessibilityElementsHidden style={{transform: [
        {translateY: progress.interpolate({inputRange: [0, 1], outputRange: [bottomOffset + 60, 0]})},
        {scale: progress.interpolate({inputRange: [0, 1], outputRange: [0.9, 1]})}]}}>
        {/* A strong tint keeps the toast legible over any content, including the glass itself. */}
        <GlassBadge key={toast.id} testID="glass-toast" colorScheme={colorScheme} cornerRadius={20}
          tintColor={dark ? '#1C1D24D9' : '#FFFFFFD9'} tintGlass style={styles.toast}><Text numberOfLines={2}
            style={[styles.text, {color: foreground ?? (dark ? '#F4F4FA' : '#242630')}]}>{toast.message}</Text></GlassBadge>
      </Animated.View>
    </View>}
  </ToastContext.Provider>;
}

/** The toast controller from the nearest GlassToastProvider. */
export function useGlassToast(): GlassToastController {
  const controller = useContext(ToastContext);
  if (!controller) throw new Error('useGlassToast must be used inside a GlassToastProvider.');
  return controller;
}

const styles = StyleSheet.create({
  host: {position: 'absolute', left: 16, right: 16, alignItems: 'center'},
  toast: {alignSelf: 'center', minHeight: 40, paddingHorizontal: 18, paddingVertical: 10},
  text: {fontSize: 15, fontWeight: '600', textAlign: 'center'},
});
