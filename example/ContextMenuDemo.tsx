import React, {useEffect, useRef, useState} from 'react';
import {Pressable, ScrollView, Switch, Text, View, useColorScheme} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {GlassContextMenu, type GlassMenuElement} from '@likith99/react-native-adaptive-liquid-glass';

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
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(() => () => clearTimeout(timer.current), []);
  const items: GlassMenuElement[] = replacement ? [{id: 'new', title: 'New action'}] : [
    {id: 'edit', title: 'Edit message', systemImage: 'pencil'},
    {id: 'forward', title: 'Forward message', systemImage: 'arrowshape.turn.up.right'},
    {id: 'save', title: 'Save message', systemImage: 'bookmark', checked: saved},
    {kind: 'submenu', id: 'more', title: 'More message actions', items: [
      {id: 'copy', title: 'Copy message', systemImage: 'doc.on.doc'},
    ]},
    {id: 'blocked', title: 'Unavailable message action', disabled: true},
    {id: 'delete', title: 'Delete message', systemImage: 'trash', destructive: true},
  ];
  return <SafeAreaView style={{flex: 1, backgroundColor: dark ? '#11141B' : '#F7F8FC'}}>
    <ScrollView contentContainerStyle={{padding: 24, gap: 20}}>
      <Pressable testID="close-context-demo" accessibilityRole="button" onPress={onClose}><Text style={{color}}>← Back</Text></Pressable>
      <Text style={{color, fontSize: 28, fontWeight: '700'}}>Message actions</Text>
      <Text style={{color}}>Touch and hold the message. It stays visible while you choose an action.</Text>
      {mounted && <GlassContextMenu testID="message-context" accessibilityLabel="Message: See you at the park"
        disabled={disabled} forceFallback={fallback} items={items} previewCornerRadius={22}
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
    </ScrollView>
  </SafeAreaView>;
}
