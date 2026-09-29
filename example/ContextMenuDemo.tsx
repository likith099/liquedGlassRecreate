import React, {useEffect, useRef, useState} from 'react';
import {Platform, Pressable, ScrollView, Switch, Text, View, useColorScheme} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {GlassContextMenu, GlassLongPress, GlassMenuPanel, GlassSegmentedControl, type GlassMenuElement,
  type GlassMenuStyle} from '@likith99/react-native-adaptive-liquid-glass';

/** A custom Android menu style for the demo's switch; the default style needs no prop. */
const customMenuStyle: GlassMenuStyle = {
  cornerRadius: 28,
  backgroundColor: {light: '#FFF4E8', dark: '#241F33'},
  textColor: {light: '#3A2A12', dark: '#EDE7FF'},
  iconColor: {light: '#B26A00', dark: '#B9A7FF'},
  destructiveColor: {light: '#C62828', dark: '#FF8A80'},
};

const panelItems: GlassMenuElement[] = [
  {id: 'forward', title: 'Forward', systemImage: 'arrowshape.turn.up.right', androidIcon: 'demo_forward'},
  {id: 'copy', title: 'Copy', systemImage: 'doc.on.doc', androidIcon: 'demo_copy'},
  {id: 'star', title: 'Star', systemImage: 'star', androidIcon: 'demo_bookmark'},
  {kind: 'section', id: 'manage', title: '', items: [
    {id: 'select', title: 'Select more', systemImage: 'checklist', androidIcon: 'demo_more'},
    {id: 'delete', title: 'Delete', systemImage: 'trash', androidIcon: 'demo_delete', destructive: true},
  ]},
];

export default function ContextMenuDemo({onClose}: {onClose: () => void}) {
  const dark = useColorScheme() === 'dark';
  const color = dark ? '#F5F5F9' : '#222737';
  const [status, setStatus] = useState('No context action');
  const [count, setCount] = useState(0);
  const [disabled, setDisabled] = useState(false);
  const [fallback, setFallback] = useState(false);
  const [saved, setSaved] = useState(false);
  const [replacement, setReplacement] = useState(false);
  const [mounted, setMounted] = useState(true);
  const [customStyle, setCustomStyle] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [panelShown, setPanelShown] = useState(false);
  const [placement, setPlacement] = useState<string | null>('below-right');
  const [panelStatus, setPanelStatus] = useState('No panel action');
  const [panelOnLongPress, setPanelOnLongPress] = useState(false);
  const panelHeight = GlassMenuPanel.measure(panelItems);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(() => () => clearTimeout(timer.current), []);
  const items: GlassMenuElement[] = replacement ? [{id: 'new', title: 'New action'}] : [
    {id: 'edit', title: 'Edit message', systemImage: 'pencil', androidIcon: 'demo_edit'},
    {id: 'forward', title: 'Forward message', systemImage: 'arrowshape.turn.up.right', androidIcon: 'demo_forward'},
    {id: 'save', title: 'Save message', systemImage: 'bookmark', androidIcon: 'demo_bookmark', checked: saved},
    {kind: 'submenu', id: 'more', title: 'More message actions', androidIcon: 'demo_more', items: [
      {id: 'copy', title: 'Copy message', systemImage: 'doc.on.doc', androidIcon: 'demo_copy'},
    ]},
    {id: 'blocked', title: 'Unavailable message action', disabled: true},
    {id: 'delete', title: 'Delete message', systemImage: 'trash', androidIcon: 'demo_delete', destructive: true},
  ];
  return <SafeAreaView style={{flex: 1, backgroundColor: dark ? '#11141B' : '#F7F8FC'}}>
    <ScrollView contentContainerStyle={{padding: 24, paddingBottom: 200, gap: 20}}>
      <Pressable testID="close-context-demo" accessibilityRole="button" onPress={onClose}><Text style={{color}}>← Back</Text></Pressable>
      <Text style={{color, fontSize: 28, fontWeight: '700'}}>Message actions</Text>
      <Text style={{color}}>Touch and hold the message. It stays visible while you choose an action.</Text>
      {mounted && <GlassContextMenu testID="message-context" accessibilityLabel="Message: See you at the park"
        disabled={disabled} forceFallback={fallback} items={items}
        previewCornerRadii={{topLeft: 22, topRight: 22, bottomLeft: 22, bottomRight: 6}}
        onOpen={() => setMenuOpen(true)} onClose={() => setMenuOpen(false)}
        androidMenuStyle={customStyle ? customMenuStyle : undefined}
        onAction={id => {setStatus(`Context selected: ${id}`); setCount(value => value + 1); if (id === 'save') setSaved(value => !value);}}>
        <View style={{padding: 22, borderTopLeftRadius: 22, borderTopRightRadius: 22, borderBottomLeftRadius: 22, borderBottomRightRadius: 6,
          backgroundColor: dark ? '#254E6A' : '#D9EAF7'}}>
          <Text style={{color, fontSize: 20}}>See you at the park</Text>
          <Text style={{color, marginTop: 8}}>Bring your camera — the light is beautiful.</Text>
        </View>
      </GlassContextMenu>}
      <Text testID="context-status" style={{color}}>{status}</Text>
      <Text testID="context-open" style={{color}}>Context menu open: {menuOpen ? 'yes' : 'no'}</Text>
      <Text testID="context-count" style={{color}}>Context actions: {count}</Text>
      <Text testID="context-saved" style={{color}}>Message saved: {saved ? 'on' : 'off'}</Text>
      <View style={{flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between'}}>
        <Text style={{color}}>Plain menu fallback</Text>
        <Switch testID="context-fallback" accessibilityLabel="Plain menu fallback" value={fallback} onValueChange={setFallback} />
      </View>
      {Platform.OS === 'android' && <View style={{flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between'}}>
        <Text style={{color}}>Custom menu style</Text>
        <Switch testID="context-style" accessibilityLabel="Custom menu style" value={customStyle} onValueChange={setCustomStyle} />
      </View>}
      <View style={{flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between'}}>
        <Text style={{color}}>Disable context menu</Text>
        <Switch testID="context-disabled" accessibilityLabel="Disable context menu" value={disabled} onValueChange={setDisabled} />
      </View>
      <Pressable testID="context-replace" accessibilityRole="button" onPress={() => {
        clearTimeout(timer.current); setStatus('Replacement pending');
        timer.current = setTimeout(() => {setReplacement(true); setStatus('Context items replaced');}, 8000);
      }}><Text style={{color}}>Replace actions in 8 seconds</Text></Pressable>
      <Pressable testID="context-unmount" accessibilityRole="button" onPress={() => {
        clearTimeout(timer.current); setStatus('Removal pending');
        timer.current = setTimeout(() => {setMounted(false); setStatus('Message removed');}, 8000);
      }}><Text style={{color}}>Remove message in 8 seconds</Text></Pressable>
      <Text style={{color, fontSize: 22, fontWeight: '700', marginTop: 12}}>Menu panel</Text>
      <Text style={{color}}>The same menu without a long press, placed by the app. Pick where it sits
        relative to the message.</Text>
      <View style={{flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between'}}>
        <Text style={{color}}>Show menu panel</Text>
        <Switch testID="panel-toggle" accessibilityLabel="Show menu panel" value={panelShown} onValueChange={setPanelShown} />
      </View>
      <View style={{flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between'}}>
        <Text style={{color}}>Open on long press</Text>
        <Switch testID="panel-longpress" accessibilityLabel="Open on long press" value={panelOnLongPress}
          onValueChange={value => {setPanelOnLongPress(value); setPanelShown(false);}} />
      </View>
      <GlassSegmentedControl testID="panel-placement" accessibilityLabel="Menu placement" value={placement}
        onValueChange={setPlacement} options={[
          {value: 'below-left', label: 'Below left'}, {value: 'below-right', label: 'Below right'},
          {value: 'above-left', label: 'Above left'}, {value: 'above-right', label: 'Above right'},
        ]} />
      <Text testID="panel-status" style={{color}}>{panelStatus}</Text>
      {/* The app positions the panel: here absolutely, against the message it belongs to, in room
          reserved from its measured height so the message never moves under the finger. The room
          is padding, so the panel stays inside this view: Android clips accessibility (and so
          TalkBack) to a parent's bounds. */}
      <View style={{marginTop: 64, marginBottom: 24, zIndex: 1,
        paddingTop: placement?.startsWith('above') ? panelHeight + 12 : 0,
        paddingBottom: placement?.startsWith('below') ? panelHeight + 12 : 0}}>
        {panelShown && placement?.startsWith('below') && <Text testID="panel-reactions"
          style={{position: 'absolute', top: -56, fontSize: 28, letterSpacing: 6,
            [placement === 'below-right' ? 'right' : 'left']: 0}}>👍❤️😂😮</Text>}
        {/* With "Open on long press", the message is wrapped in GlassLongPress: holding it opens the
            panel, and the same finger can slide onto a row and lift to choose it. A tap closes it. */}
        <GlassLongPress disabled={!panelOnLongPress} minimumDuration={350} haptic="medium"
          onLongPress={({frame}) => {setPanelShown(true); setPanelStatus(`Long press at ${Math.round(frame.width)}×${Math.round(frame.height)}`);}}
          style={{alignSelf: placement?.endsWith('right') ? 'flex-end' : 'flex-start'}}>
          <Pressable testID="panel-message" accessibilityRole={panelOnLongPress ? 'button' : undefined}
            accessibilityLabel="Message: Hi" accessibilityHint={panelOnLongPress ? 'Touch and hold for actions' : undefined}
            disabled={!panelOnLongPress} onPress={() => {setPanelShown(false); setPanelStatus('Message tapped');}}
            style={{paddingVertical: 14, paddingHorizontal: 18, borderRadius: 20, backgroundColor: dark ? '#3B4A8C' : '#A6BBFF'}}>
            <Text style={{color: '#0B1026', fontSize: 17}}>Hi</Text>
          </Pressable>
        </GlassLongPress>
        {panelShown && placement && <GlassMenuPanel testID="menu-panel" accessibilityLabel="Message actions"
          style={{position: 'absolute', [placement.startsWith('below') ? 'top' : 'bottom']: 58,
            [placement.endsWith('right') ? 'right' : 'left']: 0}}
          appearFrom={placement.startsWith('below') ? 'top' : 'bottom'} autoFocus
          androidMenuStyle={customStyle ? customMenuStyle : undefined} items={panelItems}
          onRequestClose={() => setPanelShown(false)}
          onAction={id => {setPanelStatus(`Panel selected: ${id}`); setPanelShown(false);}} />}
      </View>
    </ScrollView>
  </SafeAreaView>;
}
