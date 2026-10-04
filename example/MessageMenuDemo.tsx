import React, {useEffect, useRef, useState} from 'react';
import {Appearance, FlatList, Image, Pressable, Text, TextInput, View, useColorScheme} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {GlassContextMenu, type GlassMenuElement} from '@likith99/react-native-adaptive-liquid-glass';

const items: GlassMenuElement[] = [
  {id: 'reply', title: 'Reply', systemImage: 'arrowshape.turn.up.left'},
  {id: 'copy', title: 'Copy', systemImage: 'doc.on.doc'},
  {id: 'unavailable', title: 'Unavailable', disabled: true},
  {kind: 'submenu', id: 'more', title: 'More', items: [{id: 'save', title: 'Save', systemImage: 'bookmark'}]},
  {id: 'delete', title: 'Delete', destructive: true, systemImage: 'trash'},
];
const initial = Array.from({length: 30}, (_, index) => ({id: String(index), own: index % 2 === 1}));

/** A recycling conversation, with actions deliberately applied after the native return finishes. */
export default function MessageMenuDemo({onClose}: {onClose: () => void}) {
  const systemScheme = useColorScheme();
  const [colorScheme, setColorScheme] = useState<'system' | 'light' | 'dark'>('system');
  // UIKit presents menu rows from the app window; match the app theme as well as preview traits.
  useEffect(() => {
    Appearance.setColorScheme(colorScheme === 'system' ? 'unspecified' : colorScheme);
    return () => Appearance.setColorScheme('unspecified');
  }, [colorScheme]);
  const dark = (colorScheme === 'system' ? systemScheme : colorScheme) === 'dark';
  const ink = dark ? '#FFFFFF' : '#171717';
  const [messages, setMessages] = useState(initial);
  const [open, setOpen] = useState(false);
  const [opens, setOpens] = useState(0);
  const [closes, setCloses] = useState(0);
  const [status, setStatus] = useState('No action');
  const [image, setImage] = useState(false);
  const composer = useRef<React.ElementRef<typeof TextInput>>(null);
  const list = useRef<FlatList>(null);
  return <SafeAreaView style={{flex: 1, backgroundColor: dark ? '#000000' : '#FFFFFF'}}>
    <View style={{padding: 16, gap: 8}}>
      <Pressable accessibilityRole="button" onPress={onClose}><Text style={{color: ink}}>Back</Text></Pressable>
      <Text style={{color: ink, fontSize: 24, fontWeight: '600'}}>Conversation</Text>
      <View style={{flexDirection: 'row', gap: 24}}>
        <Pressable testID="chat-theme" accessibilityRole="button" onPress={() =>
          setColorScheme(value => value === 'system' ? 'dark' : value === 'dark' ? 'light' : 'system')}>
          <Text style={{color: ink}}>Theme: {colorScheme}</Text>
        </Pressable>
        <Pressable testID="chat-image" accessibilityRole="button" onPress={() => setImage(value => !value)}>
          <Text style={{color: ink}}>{image ? 'Text message' : 'Image message'}</Text>
        </Pressable>
        <Pressable testID="chat-latest" accessibilityRole="button" onPress={() => {
          if (messages.length) list.current?.scrollToIndex({index: messages.length - 1, viewPosition: 1, animated: false});
        }}>
          <Text style={{color: ink}}>Latest</Text>
        </Pressable>
      </View>
      <Text testID="chat-status" style={{color: ink}}>{status}; opened {opens}; closed {closes}</Text>
    </View>
    <FlatList ref={list} testID="chat-list" data={messages} keyExtractor={item => item.id}
      initialScrollIndex={messages.length ? messages.length - 1 : undefined}
      getItemLayout={(_, index) => ({index, offset: 16 + index * 80, length: image && messages[index]?.id === '29' ? 196 : 80})}
      removeClippedSubviews={!open} windowSize={5} contentContainerStyle={{padding: 16}}
      ItemSeparatorComponent={() => <View style={{height: 14}} />}
      renderItem={({item}) => <View style={{height: image && item.id === '29' ? 182 : 66, justifyContent: 'center'}}>
        <GlassContextMenu testID={`chat-message-${item.id}`}
        accessibilityLabel={`Message ${item.id}`} items={items} menuPlacement="below" actionTiming="afterClose" colorScheme={colorScheme}
        previewCornerRadius={20} previewCornerRadii={item.own ? {bottomRight: 5} : {bottomLeft: 5}}
        style={{alignSelf: item.own ? 'flex-end' : 'flex-start', maxWidth: '78%'}}
        onOpen={() => {setOpen(true); setOpens(value => value + 1);}}
        onAction={id => {
          setStatus(`${id} ${item.id}`);
          if (id === 'reply') composer.current?.focus();
          if (id === 'delete') setMessages(value => value.filter(message => message.id !== item.id));
        }}
        onClose={() => {setOpen(false); setCloses(value => value + 1);}}>
        <View style={{borderRadius: 20, borderBottomRightRadius: item.own ? 5 : 20,
          borderBottomLeftRadius: item.own ? 20 : 5, overflow: 'hidden', padding: 14,
          backgroundColor: item.own ? '#2264D8' : dark ? '#29292D' : '#E9E9EB'}}>
          {image && item.id === '29'
            ? <Image source={require('./assets/tab-diamond-filled.png')} resizeMode="contain"
                style={{width: 180, height: 140, backgroundColor: '#CDD7FA'}} />
            : <Text style={{fontSize: 17, color: item.own ? '#FFFFFF' : ink}}>
                {item.id === '29' ? 'See you at the park' : `A note from the conversation — ${item.id}`}
              </Text>}
        </View>
      </GlassContextMenu></View>} />
    <TextInput ref={composer} testID="chat-composer" placeholder="Message" placeholderTextColor="#888888"
      style={{color: ink, borderColor: '#888888', borderWidth: 1, borderRadius: 22, margin: 16, padding: 12}} />
  </SafeAreaView>;
}
