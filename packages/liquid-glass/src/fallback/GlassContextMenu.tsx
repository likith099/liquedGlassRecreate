import React, {useEffect, useRef, useState} from 'react';
import {Modal, Platform, Pressable, ScrollView, StyleSheet, Text, View,
  useWindowDimensions} from 'react-native';
import {useFallbackColors} from '../fallbackTheme';
import type {GlassContextMenuProps, GlassMenuElement} from '../types';
import {enabledMenuAction} from '../menuTree';

type Anchor = {x: number; y: number; width: number; height: number};

/** Shared plain popup: preserves the source content and uses no glass or lift. */
export default function FallbackContextMenu({children, items, onAction, disabled = false,
  forceFallback: _fallback, previewCornerRadius: _radius, accessibilityLabel,
  accessibilityHint, accessibilityActions, onAccessibilityAction, testID,
  ...props}: GlassContextMenuProps) {
  const trigger = useRef<React.ElementRef<typeof View>>(null);
  const [anchor, setAnchor] = useState<Anchor | null>(null);
  const [submenu, setSubmenu] = useState<string | null>(null);
  const {width, height, fontScale} = useWindowDimensions();
  const {dark, surface, foreground: themed} = useFallbackColors();
  const json = JSON.stringify(items);
  const request = useRef(0);
  const close = () => {request.current += 1; setAnchor(null); setSubmenu(null);};
  useEffect(() => {
    request.current += 1; setAnchor(null); setSubmenu(null);
    return () => {request.current += 1;};
  }, [json, disabled, width, height, fontScale]);
  const open = () => {
    if (disabled || items.length === 0) return;
    const version = ++request.current;
    trigger.current?.measureInWindow((x, y, measuredWidth, measuredHeight) => {
      if (request.current !== version || measuredWidth <= 0 || measuredHeight <= 0) return;
      setSubmenu(null); setAnchor({x, y, width: measuredWidth, height: measuredHeight});
    });
  };
  const findSubmenu = (nodes: readonly GlassMenuElement[]): GlassMenuElement | undefined => {
    for (const node of nodes) {
      if (node.id === submenu && node.kind === 'submenu' && !node.disabled) return node;
      if (node.kind === 'section') {
        const found = findSubmenu(node.items);
        if (found) return found;
      }
    }
  };
  const group = submenu ? findSubmenu(items) : undefined;
  const nodes = group?.kind === 'submenu' ? group.items : items;
  const foreground = themed ?? (dark ? '#F5F5F9' : '#222737');
  const color = {color: foreground};
  const rows = (elements: readonly GlassMenuElement[]): React.ReactNode => elements.map(item => {
    if (item.kind === 'section') return <View key={item.id} style={styles.section}>
      {!!item.title && <Text style={[styles.sectionTitle, color]}>{item.title}</Text>}
      {rows(item.items)}
    </View>;
    return <Pressable key={item.id} disabled={item.disabled}
      accessibilityRole="menuitem" accessibilityLabel={item.title}
      accessibilityState={{disabled: !!item.disabled, ...(item.kind !== 'submenu' && item.checked !== undefined ? {checked: item.checked} : {})}}
      onPress={() => {
        if (item.kind === 'submenu') {setSubmenu(item.id); return;}
        const action = enabledMenuAction(items, item.id);
        close();
        if (!disabled && action) onAction(action.id);
      }} style={({pressed}) => [styles.row, {opacity: item.disabled ? 0.4 : 1,
        backgroundColor: pressed ? (dark ? '#40434B' : '#E3E5EB') : 'transparent'}]}>
      <Text style={[styles.title, color, item.kind !== 'submenu' && item.destructive && {color: dark ? '#FF8A80' : '#B3261E'}]}>{item.title}</Text>
      {item.kind === 'submenu' ? <Text style={color}>›</Text> : item.checked ? <Text style={color}>✓</Text> : null}
    </Pressable>;
  });
  // Keep the popup beside the source and constrain tall menus to a scrollable area.
  const margin = 16;
  const topInset = Platform.OS === 'ios' ? 60 : margin;
  const below = anchor ? Math.max(0, height - anchor.y - anchor.height - margin - 8) : 0;
  const above = anchor ? Math.max(0, anchor.y - topInset - 8) : 0;
  const placeBelow = below >= Math.min(240 * fontScale, above);
  const availableHeight = Math.max(48, placeBelow ? below : above);
  const menuWidth = Math.min(300, width - margin * 2);
  const placement = anchor ? {
    left: Math.max(margin, Math.min(anchor.x, width - menuWidth - margin)),
    ...(placeBelow ? {top: anchor.y + anchor.height + 8} : {bottom: height - anchor.y + 8}),
  } : {};
  return <>
    <Pressable {...props} ref={trigger} testID={testID} collapsable={false}
      accessibilityRole="button" accessibilityLabel={accessibilityLabel}
      accessibilityHint={accessibilityHint ?? 'Touch and hold for actions'}
      accessibilityState={{...props.accessibilityState, disabled: disabled || items.length === 0}}
      accessibilityActions={[...(accessibilityActions ?? []), {name: 'activate', label: 'Show actions'}, {name: 'longpress', label: 'Show actions'}]}
      onAccessibilityAction={event => {
        if (['activate', 'longpress'].includes(event.nativeEvent.actionName)) open();
        else onAccessibilityAction?.(event);
      }} onLongPress={open}>{children}</Pressable>
    <Modal visible={anchor !== null} transparent animationType="none" onRequestClose={close}>
      <View style={styles.overlay} accessibilityViewIsModal>
        <Pressable testID={testID ? `${testID}-dismiss` : undefined} accessibilityRole="button"
          accessibilityLabel="Dismiss menu" onPress={close} style={StyleSheet.absoluteFill} />
        <View testID={testID ? `${testID}-popup` : undefined} style={[styles.popup, placement,
          {width: menuWidth, maxHeight: availableHeight, backgroundColor: surface ?? (dark ? '#25272D' : '#FFFFFF')}]}>
          <ScrollView bounces={false} keyboardShouldPersistTaps="handled">
            {group && <Pressable accessibilityRole="button" accessibilityLabel="Back to actions"
              onPress={() => setSubmenu(null)} style={styles.row}><Text style={color}>‹ Back</Text></Pressable>}
            {rows(nodes)}
          </ScrollView>
        </View>
      </View>
    </Modal>
  </>;
}

const styles = StyleSheet.create({
  overlay: {flex: 1, backgroundColor: '#00000024'},
  popup: {position: 'absolute', borderRadius: 12, overflow: 'hidden', elevation: 8,
    shadowColor: '#000', shadowOpacity: 0.2, shadowRadius: 12, shadowOffset: {width: 0, height: 4}},
  row: {minHeight: 48, paddingHorizontal: 18, paddingVertical: 14, flexDirection: 'row', alignItems: 'center', gap: 12},
  title: {fontSize: 16, flex: 1},
  section: {borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: '#88888850'},
  sectionTitle: {fontSize: 13, paddingHorizontal: 18, paddingTop: 12, paddingBottom: 4},
});
