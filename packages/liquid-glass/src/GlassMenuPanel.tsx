import React, {useEffect, useMemo, useRef, useState} from 'react';
import {AccessibilityInfo, Animated, Image, Platform, Pressable, StyleSheet, Text, View, useColorScheme,
  type ColorValue} from 'react-native';
import GlassView from './GlassView';
import NativeSymbol from './specs/ALGSymbolNativeComponent';
import {enabledMenuAction, validateMenuItems} from './menuTree';
import type {GlassMenuElement, GlassMenuItem, GlassMenuPanelProps, GlassMenuSubmenu, GlassSchemeColor} from './types';

const ios = Platform.OS === 'ios';
/** Defaults per appearance: iOS follows UIKit menus, Android the package's Material menu. */
const defaults = {
  light: {text: ios ? '#000000' : '#1B1B1F', icon: ios ? '#000000' : '#46464F',
    destructive: ios ? '#FF3B30' : '#BA1A1A', background: ios ? undefined : '#FFFFFF'},
  dark: {text: ios ? '#FFFFFF' : '#E3E3E8', icon: ios ? '#FFFFFF' : '#B9BAC2',
    destructive: ios ? '#FF453A' : '#FFB4AB', background: ios ? undefined : '#1A1B20'},
};
const pick = (color: GlassSchemeColor | undefined, dark: boolean): ColorValue | undefined =>
  color !== null && typeof color === 'object' && 'light' in color && 'dark' in color
    ? (dark ? color.dark : color.light) : color as ColorValue | undefined;

type Row =
  | {kind: 'item'; item: GlassMenuItem | GlassMenuSubmenu}
  | {kind: 'title'; key: string; title: string}
  | {kind: 'divider'; key: string}
  | {kind: 'back'; title: string};

/** Sections become an optional title between dividers; submenus are rows that open in place. */
function rowsOf(elements: readonly GlassMenuElement[]): Row[] {
  const rows: Row[] = [];
  for (const element of elements) {
    if (element.kind === 'section') {
      if (rows.length && rows[rows.length - 1].kind !== 'divider') rows.push({kind: 'divider', key: `${element.id}-before`});
      if (element.title) rows.push({kind: 'title', key: element.id, title: element.title});
      rows.push(...rowsOf(element.items));
      rows.push({kind: 'divider', key: `${element.id}-after`});
    } else rows.push({kind: 'item', item: element});
  }
  while (rows.length && rows[rows.length - 1].kind === 'divider') rows.pop();
  return rows;
}

function Icon({systemImage, androidIcon, color, size}: {systemImage?: string; androidIcon?: string;
  color: ColorValue; size: number}) {
  if (ios) {
    return systemImage ? <NativeSymbol systemImage={systemImage} tint={color} pointSize={size * 0.85}
      style={{width: size, height: size}} /> : <View style={{width: size, height: size}} />;
  }
  return androidIcon ? <Image source={{uri: androidIcon}} style={{width: size, height: size, tintColor: color}} />
    : <View style={{width: size, height: size}} />;
}

/**
 * A menu drawn where you put it, with no trigger or automatic placement: position it with `style`
 * (for example absolutely, below or above the element it belongs to) and unmount it to close it.
 * It shows the same items as the package's other menus on a glass surface: Liquid Glass with
 * native touch response on iOS 26, system blur on iOS 15–25, and an opaque surface on Android,
 * under Reduce Transparency and with `forceFallback`. Submenus open in place with a back row.
 */
export default function GlassMenuPanel({ref, items, onAction, width = 250, menuStyle, colorScheme = 'system',
  disabled = false, forceFallback = false, transformOrigin = 'top left', animateIn = true, style,
  accessibilityLabel, ...props}: GlassMenuPanelProps) {
  validateMenuItems(items);
  if (!(Number.isFinite(width) && width > 0)) throw new Error('GlassMenuPanel width must be a positive number.');
  const system = useColorScheme();
  const dark = (colorScheme === 'system' ? system : colorScheme) === 'dark';
  const scheme = dark ? defaults.dark : defaults.light;
  const colors = {
    text: pick(menuStyle?.textColor, dark) ?? scheme.text,
    icon: pick(menuStyle?.iconColor, dark) ?? scheme.icon,
    destructive: pick(menuStyle?.destructiveColor, dark) ?? scheme.destructive,
    background: pick(menuStyle?.backgroundColor, dark) ?? scheme.background,
  };
  const radius = menuStyle?.cornerRadius ?? (ios ? 22 : 16);
  const rowHeight = ios ? 44 : 48;
  const iconSize = ios ? 20 : 24;

  // Submenus open in place; replaced items close an open submenu that no longer exists.
  const [openSubmenu, setOpenSubmenu] = useState<string | null>(null);
  const submenu = useMemo(() => {
    const find = (elements: readonly GlassMenuElement[]): GlassMenuSubmenu | undefined => {
      for (const element of elements) {
        if (element.kind === 'submenu' && element.id === openSubmenu) return element;
        if (element.kind === 'section') { const found = find(element.items); if (found) return found; }
      }
    };
    return openSubmenu ? find(items) : undefined;
  }, [items, openSubmenu]);
  const rows: Row[] = submenu
    ? [{kind: 'back', title: submenu.title}, {kind: 'divider', key: 'back'}, ...rowsOf(submenu.items)]
    : rowsOf(items);

  // Grows in from `transformOrigin`. Scale only: glass does not render inside a fading view.
  const scale = useRef(new Animated.Value(animateIn ? 0.9 : 1)).current;
  useEffect(() => {
    if (!animateIn) return;
    let active = true;
    AccessibilityInfo.isReduceMotionEnabled().then(reduce => {
      if (!active) return;
      if (reduce) scale.setValue(1);
      else Animated.spring(scale, {toValue: 1, damping: 22, stiffness: 320, mass: 1, useNativeDriver: true}).start();
    });
    return () => { active = false; };
  }, [animateIn, scale]);

  const highlight = dark ? 'rgba(255, 255, 255, 0.12)' : 'rgba(0, 0, 0, 0.08)';
  const hairline = dark ? 'rgba(255, 255, 255, 0.16)' : 'rgba(0, 0, 0, 0.12)';
  const renderRow = (row: Row) => {
    if (row.kind === 'divider') return <View key={`divider-${row.key}`} style={[styles.divider, {backgroundColor: hairline}]} />;
    if (row.kind === 'title') {
      return <Text key={`title-${row.key}`} accessibilityRole="header" style={[styles.sectionTitle, {color: colors.icon}]}>{row.title}</Text>;
    }
    if (row.kind === 'back') {
      return <Pressable key="back" accessibilityRole="button" accessibilityLabel={`Back, ${row.title}`}
        onPress={() => setOpenSubmenu(null)}
        style={({pressed}) => [styles.row, {minHeight: rowHeight}, pressed && {backgroundColor: highlight}]}>
        {ios ? <Icon systemImage="chevron.left" color={colors.icon} size={iconSize} />
          : <Text style={[styles.glyph, {color: colors.icon, width: iconSize}]}>‹</Text>}
        <Text numberOfLines={1} style={[styles.title, styles.bold, {color: colors.text}]}>{row.title}</Text>
      </Pressable>;
    }
    const {item} = row;
    const isSubmenu = item.kind === 'submenu';
    const enabled = !disabled && !item.disabled;
    const checked = !isSubmenu && (item as GlassMenuItem).checked;
    const destructive = !isSubmenu && (item as GlassMenuItem).destructive;
    const ink = destructive ? colors.destructive : colors.text;
    return <Pressable key={item.id} testID={props.testID ? `${props.testID}-${item.id}` : undefined}
      accessibilityRole="menuitem" accessibilityLabel={item.title}
      accessibilityHint={isSubmenu ? 'Opens a submenu' : undefined}
      accessibilityState={{disabled: !enabled, ...(checked !== undefined ? {checked: !!checked} : {})}}
      disabled={!enabled}
      onPress={() => {
        if (isSubmenu) { setOpenSubmenu(item.id); return; }
        // Only enabled leaves of the current items can act.
        const action = enabledMenuAction(items, item.id);
        if (!disabled && action) onAction(action.id);
      }}
      style={({pressed}) => [styles.row, {minHeight: rowHeight, opacity: enabled ? 1 : 0.38},
        pressed && {backgroundColor: highlight}]}>
      <Icon systemImage={item.systemImage} androidIcon={item.androidIcon}
        color={destructive ? colors.destructive : colors.icon} size={iconSize} />
      <Text numberOfLines={1} style={[styles.title, {color: ink}]}>{item.title}</Text>
      {isSubmenu && (ios ? <Icon systemImage="chevron.right" color={colors.icon} size={iconSize * 0.8} />
        : <Text style={[styles.glyph, {color: colors.icon}]}>›</Text>)}
      {checked && (ios ? <Icon systemImage="checkmark" color={colors.icon} size={iconSize * 0.8} />
        : <Text style={[styles.glyph, {color: colors.icon}]}>✓</Text>)}
    </Pressable>;
  };

  return <Animated.View {...props} ref={ref} accessibilityRole="menu" accessibilityLabel={accessibilityLabel}
    style={[{width, transformOrigin, transform: [{scale}]}, style]}>
    <GlassView interactive colorScheme={colorScheme} cornerRadius={radius} forceFallback={forceFallback}
      tintColor={ios && colors.background !== undefined ? colors.background : undefined}
      fallbackStyle={colors.background !== undefined ? {backgroundColor: colors.background} : undefined}
      style={styles.surface}>
      {rows.map(renderRow)}
    </GlassView>
  </Animated.View>;
}

const styles = StyleSheet.create({
  surface: {paddingVertical: 6, overflow: 'hidden'},
  row: {flexDirection: 'row', alignItems: 'center', gap: 14, paddingHorizontal: 16},
  title: {flex: 1, fontSize: ios ? 17 : 16},
  bold: {fontWeight: '600'},
  sectionTitle: {fontSize: 13, fontWeight: '600', paddingHorizontal: 16, paddingTop: 8, paddingBottom: 4},
  divider: {height: StyleSheet.hairlineWidth, marginVertical: 6},
  glyph: {fontSize: 18},
});
