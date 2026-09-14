import React, {useEffect, useRef, useState} from 'react';
import {Pressable, Switch, Text, View} from 'react-native';
import {GlassMenuButton, GlassToolbar, type GlassMenuElement, type GlassToolbarItem} from 'react-native-adaptive-liquid-glass';

export default function ToolbarDemo({foreground, secondary}: {foreground: string; secondary: string}) {
  const [selected, setSelected] = useState('name');
  const [status, setStatus] = useState('No toolbar action');
  const [disabled, setDisabled] = useState(false);
  const [narrow, setNarrow] = useState(false);
  const [standard, setStandard] = useState(false);
  const [merging, setMerging] = useState(false);
  const [replaced, setReplaced] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => () => {if (timer.current) clearTimeout(timer.current);}, []);
  const groups: readonly GlassMenuElement[] = [
    {kind: 'section', id: 'order', title: 'Order', items: [
      {id: 'name', title: 'By name', checked: selected === 'name'},
      {id: 'recent', title: 'Most recent', checked: selected === 'recent'},
    ]},
    {kind: 'section', id: 'maintenance', title: 'Maintenance', items: [
      {id: 'locked', title: 'Locked action', disabled: true},
      {id: 'clear', title: 'Clear history', destructive: true},
    ]},
  ];
  const items: readonly GlassToolbarItem[] = [
    {id: replaced ? 'archive' : 'save', title: replaced ? 'Archive' : 'Save', systemImage: replaced ? 'archivebox' : 'square.and.arrow.down'},
    {kind: 'submenu', id: 'sort', title: 'Sort', systemImage: 'arrow.up.arrow.down', items: groups},
    {id: 'export', title: 'Export entire collection', placement: 'overflow'},
    {id: 'blocked', title: 'Unavailable toolbar action', disabled: true, placement: 'overflow'},
  ];
  const onAction = (id: string) => {
    if (id === 'name' || id === 'recent') setSelected(id);
    setStatus(`Toolbar selected: ${id}`);
  };
  const toggle = (label: string, id: string, value: boolean, onValueChange: (value: boolean) => void) =>
    <View style={{flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', minHeight: 48}}>
      <Text style={{color: foreground}}>{label}</Text>
      <Switch testID={id} accessibilityLabel={label} value={value} onValueChange={onValueChange} />
    </View>;
  return <View style={{marginTop: 28}}>
    <Text style={{color: foreground, fontSize: 22, fontWeight: '700', marginBottom: 16}}>Toolbars and grouped menus</Text>
    <GlassToolbar items={items} onAction={onAction} maxVisibleItems={2} testID="native-toolbar"
      disabled={disabled} forceFallback={standard} mergingEnabled={merging}
      style={narrow ? {width: 120} : undefined} />
    <GlassMenuButton title="Organize library" items={[
      {kind: 'submenu', id: 'organize', title: 'Order options', items: groups},
      {kind: 'submenu', id: 'locked-group', title: 'Locked group', disabled: true,
        items: [{id: 'locked-child', title: 'Locked child'}]},
    ]} onAction={onAction} testID="hierarchy-menu" forceFallback={standard} disabled={disabled} />
    <Text testID="toolbar-status" accessibilityLiveRegion="polite" style={{color: secondary}}>{status}</Text>
    <Text testID="toolbar-selection" style={{color: secondary}}>Order: {selected}</Text>
    {toggle('Disable toolbar and menus', 'toolbar-disabled-toggle', disabled, setDisabled)}
    {toggle('Narrow toolbar', 'toolbar-narrow-toggle', narrow, setNarrow)}
    {toggle('Standard toolbar appearance', 'toolbar-fallback-toggle', standard, setStandard)}
    {toggle('Shared toolbar glass', 'toolbar-merging-toggle', merging, setMerging)}
    {toggle('Replace Save with Archive', 'toolbar-replace-toggle', replaced, setReplaced)}
    <Pressable testID="toolbar-timed-replace" accessibilityRole="button" style={{paddingVertical: 14}}
      onPress={() => {if (timer.current) clearTimeout(timer.current); timer.current = setTimeout(() => setReplaced(value => !value), 20000);}}>
      <Text style={{color: foreground}}>Replace action in 20 seconds</Text>
    </Pressable>
  </View>;
}
