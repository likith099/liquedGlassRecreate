import React, {useEffect, useRef, useState} from 'react';
import {Platform, Pressable, ScrollView, Switch, Text, View, useColorScheme} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {GlassContextMenu, GlassMenuPanel, GlassSegmentedControl, type GlassMenuElement, type GlassMenuStyle} from '@likith99/react-native-adaptive-liquid-glass';

/** A custom Android menu style for the demo's switch; the default style needs no prop. */
const customMenuStyle: GlassMenuStyle = {
  cornerRadius: 28,
  backgroundColor: {light: '#FFF4E8', dark: '#241F33'},
  textColor: {light: '#3A2A12', dark: '#EDE7FF'},
  iconColor: {light: '#B26A00', dark: '#B9A7FF'},
  destructiveColor: {light: '#C62828', dark: '#FF8A80'},
};

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
  const [panelShown, setPanelShown] = useState(false);
  const [placement, setPlacement] = useState<string | null>('below-right');
  const [panelStatus, setPanelStatus] = useState('No panel action');
  const [panelOnLongPress, setPanelOnLongPress] = useState(false);
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
    <ScrollView contentContainerStyle={{padding: 24, gap: 20}}>
      <Pressable testID="close-context-demo" accessibilityRole="button" onPress={onClose}><Text style={{color}}>← Back</Text></Pressable>
      <Text style={{color, fontSize: 28, fontWeight: '700'}}>Message actions</Text>
      <Text style={{color}}>Touch and hold the message. It stays visible while you choose an action.</Text>
      {mounted && <GlassContextMenu testID="message-context" accessibilityLabel="Message: See you at the park"
        disabled={disabled} forceFallback={fallback} items={items} previewCornerRadius={22}
        androidMenuStyle={customStyle ? customMenuStyle : undefined}
        onAction={id => {setStatus(`Context selected: ${id}`); setCount(value => value + 1); if (id === 'save') setSaved(value => !value);}}>
        <View style={{padding: 22, borderRadius: 22, backgroundColor: dark ? '#254E6A' : '#D9EAF7'}}>
          <Text style={{color, fontSize: 20}}>See you at the park</Text>
          <Text style={{color, marginTop: 8}}>Bring your camera — the light is beautiful.</Text>
        </View>
      </GlassContextMenu>}
      <Text testID="context-status" style={{color}}>{status}</Text>
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
      {/* The app positions the panel: here absolutely, against the message it belongs to. */}
      <View style={{marginTop: placement?.startsWith('above') && panelShown ? 330 : 64,
        marginBottom: placement?.startsWith('below') && panelShown ? 330 : 24, zIndex: 1}}>
        {panelShown && placement?.startsWith('below') && <Text testID="panel-reactions"
          style={{position: 'absolute', bottom: 72, fontSize: 28, letterSpacing: 6,
            [placement === 'below-right' ? 'right' : 'left']: 0}}>👍❤️😂😮</Text>}
        {/* With "Open on long press", the app opens the panel from its own long press on the message;
            a tap on the message closes it again. The panel itself has no trigger. */}
        <Pressable testID="panel-message" accessibilityRole={panelOnLongPress ? 'button' : undefined}
          accessibilityLabel="Message: Hi" accessibilityHint={panelOnLongPress ? 'Touch and hold for actions' : undefined}
          disabled={!panelOnLongPress} delayLongPress={350}
          onLongPress={() => setPanelShown(true)} onPress={() => setPanelShown(false)}
          style={({pressed}) => ({alignSelf: placement?.endsWith('right') ? 'flex-end' : 'flex-start',
            paddingVertical: 14, paddingHorizontal: 18, borderRadius: 20, backgroundColor: dark ? '#3B4A8C' : '#A6BBFF',
            transform: [{scale: pressed && panelOnLongPress ? 0.96 : 1}]})}>
          <Text style={{color: '#0B1026', fontSize: 17}}>Hi</Text>
        </Pressable>
        {panelShown && placement && <GlassMenuPanel testID="menu-panel" accessibilityLabel="Message actions"
          style={{position: 'absolute', [placement.startsWith('below') ? 'top' : 'bottom']: 58,
            [placement.endsWith('right') ? 'right' : 'left']: 0}}
          transformOrigin={`${placement.startsWith('below') ? 'top' : 'bottom'} ${placement.endsWith('right') ? 'right' : 'left'}`}
          menuStyle={customStyle ? customMenuStyle : undefined}
          items={[
            {id: 'forward', title: 'Forward', systemImage: 'arrowshape.turn.up.right', androidIcon: 'demo_forward'},
            {id: 'copy', title: 'Copy', systemImage: 'doc.on.doc', androidIcon: 'demo_copy'},
            {id: 'star', title: 'Star', systemImage: 'star', androidIcon: 'demo_bookmark'},
            {kind: 'section', id: 'manage', title: '', items: [
              {id: 'select', title: 'Select more', systemImage: 'checklist', androidIcon: 'demo_more'},
              {id: 'delete', title: 'Delete', systemImage: 'trash', androidIcon: 'demo_delete', destructive: true},
            ]},
          ]}
          onAction={id => {setPanelStatus(`Panel selected: ${id}`); setPanelShown(false);}} />}
      </View>
    </ScrollView>
  </SafeAreaView>;
}
