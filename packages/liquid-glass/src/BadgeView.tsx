import React from 'react';
import {StyleSheet, Text, View, type ColorValue} from 'react-native';
import {badgeSpoken, badgeText} from './iconOptions';
import type {GlassControlBadge} from './types';

/**
 * A static badge that matches the native glass badge (systemRed capsule, white 11pt semibold, a
 * dot for `indicator`, `99+` cap for counts). Used on glass that has no press to ride — a plain
 * surface — where the glass-button family draws and animates its badge natively instead.
 */
export function BadgeView({badge, color, textColor}: {badge: GlassControlBadge; color?: ColorValue; textColor?: ColorValue}) {
  const text = badgeText(badge);
  if (text === undefined) return null;
  const dot = text === '';
  const height = dot ? 8 : 18;
  return (
    <View
      pointerEvents="none"
      style={{
        minWidth: height,
        height,
        borderRadius: height / 2,
        backgroundColor: color ?? '#FF3B30',
        alignItems: 'center',
        justifyContent: 'center',
        paddingHorizontal: dot ? 0 : 5,
      }}>
      {!dot && (
        <Text allowFontScaling={false} numberOfLines={1} style={{color: textColor ?? '#FFFFFF', fontSize: 11, fontWeight: '600'}}>
          {text}
        </Text>
      )}
    </View>
  );
}

/** Pins a static badge to the top-right corner, poking slightly past the edge like the native one. */
export function CornerBadge({badge, color, textColor, accessibilityLabel}: {badge?: GlassControlBadge | null; color?: ColorValue;
  textColor?: ColorValue; accessibilityLabel?: string}) {
  if (!badge) return null;
  return (
    <View pointerEvents="none" accessible accessibilityLabel={badgeSpoken(badge, accessibilityLabel)} style={{position: 'absolute', top: 0, right: 0, transform: [{translateX: 5}, {translateY: -5}]}}>
      <BadgeView badge={badge} color={color} textColor={textColor} />
    </View>
  );
}

/**
 * Wraps a sized glass element so a static corner badge can overflow its top-right edge. The glass
 * fills the wrapper, so the wrapper carries the layout — a badged surface needs an explicit size.
 */
export function withCornerBadge(
  element: React.ReactElement<{style?: unknown}>,
  badge: GlassControlBadge | null | undefined,
  color: ColorValue | undefined,
  style: unknown,
  text?: {textColor?: ColorValue; accessibilityLabel?: string},
) {
  if (!badge) return element;
  // The glass fills the wrapper (so the badge can overflow the corner) but keeps its own style for
  // content layout, radius and appearance; the wrapper carries the element's size.
  return (
    <View style={style as object} pointerEvents="box-none">
      {React.cloneElement(element, {style: [StyleSheet.absoluteFill, style as object]})}
      <CornerBadge badge={badge} color={color} textColor={text?.textColor} accessibilityLabel={text?.accessibilityLabel} />
    </View>
  );
}
