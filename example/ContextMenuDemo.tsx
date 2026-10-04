import React, {useEffect, useRef, useState} from 'react';
import {Platform, Pressable, ScrollView, Switch, Text, View, useColorScheme, useWindowDimensions} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import MessageMenuDemo from './MessageMenuDemo';
import {GlassContextMenu, GlassSegmentedControl, type GlassMenuElement,
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

function Bubble({dark}: {dark: boolean}) {
  return <View style={{paddingVertical: 14, paddingHorizontal: 18, borderRadius: 20, backgroundColor: dark ? '#3B4A8C' : '#A6BBFF'}}>
    <Text style={{color: '#0B1026', fontSize: 17}}>Hi</Text>
  </View>;
}

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
  const {height: screenHeight} = useWindowDimensions();
  const [side, setSide] = useState<string | null>('received');
  const [panelStatus, setPanelStatus] = useState('No panel action');
  const [panelOnLongPress, setPanelOnLongPress] = useState(false);
  const [conversation, setConversation] = useState(false);
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
  if (conversation) return <MessageMenuDemo onClose={() => setConversation(false)} />;
  return <SafeAreaView style={{flex: 1, backgroundColor: dark ? '#11141B' : '#F7F8FC'}}>
    {/* Room below the last message so it can be scrolled to the top of the screen. */}
    <ScrollView contentContainerStyle={{padding: 24, paddingBottom: screenHeight * 0.85, gap: 20}}>
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
      <Pressable testID="open-chat-menu-demo" accessibilityRole="button" onPress={() => setConversation(true)}>
        <Text style={{color}}>Open conversation menu demo</Text>
      </Pressable>
      <Text style={{color, fontSize: 22, fontWeight: '700', marginTop: 12}}>Message preview</Text>
      <Text style={{color}}>Touch and hold the message, then slide to an action. Scroll to try
        different positions.</Text>
      <View style={{flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between'}}>
        <Text style={{color}}>Open on long press</Text>
        <Switch testID="panel-longpress" accessibilityLabel="Open on long press" value={panelOnLongPress}
          onValueChange={setPanelOnLongPress} />
      </View>
      <GlassSegmentedControl testID="panel-side" accessibilityLabel="Message side" value={side}
        onValueChange={setSide} options={[{value: 'received', label: 'Received'}, {value: 'sent', label: 'Sent'}]} />
      <Text testID="panel-status" style={{color}}>{panelStatus}</Text>
      <View style={{marginTop: 24, marginBottom: 24}}>
        <GlassContextMenu testID="panel-message" accessibilityLabel="Message: Hi" items={panelItems}
          menuPlacement="below" previewCornerRadius={20} disabled={!panelOnLongPress}
          style={{alignSelf: side === 'sent' ? 'flex-end' : 'flex-start'}}
          androidMenuStyle={customStyle ? customMenuStyle : undefined}
          onAction={id => setPanelStatus(`Panel selected: ${id}`)}>
          <Bubble dark={dark} />
        </GlassContextMenu>
      </View>
    </ScrollView>
  </SafeAreaView>;
}
