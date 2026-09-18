import React, {useState} from 'react';
import {I18nManager, Pressable, ScrollView, Switch, Text, View, useColorScheme, useWindowDimensions} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {GlassActionCluster, GlassButton, GlassSegmentedControl, GlassSlider, GlassTabBar, GlassMenuButton, GlassToolbar} from 'react-native-adaptive-liquid-glass';

const options = [{value: 'all', label: 'All'}, {value: 'saved', label: 'Saved'}, {value: 'shared', label: 'Shared', disabled: true}];
export default function AccessibilityDemo({onClose}: {onClose: () => void}) {
  const dark = useColorScheme() === 'dark';
  const {fontScale} = useWindowDimensions();
  const color = dark ? '#F5F5F9' : '#222737';
  const [disabled, setDisabled] = useState(false);
  const [loading, setLoading] = useState(false);
  const [reject, setReject] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [selection, setSelection] = useState<string | null>('all');
  const [count, setCount] = useState(0);
  const [event, setEvent] = useState('No action');
  const [tab, setTab] = useState('home');
  const [level, setLevel] = useState(40);
  const setting = (title: string, id: string, value: boolean, onValueChange: (next: boolean) => void) =>
    <View style={{flexDirection: 'row', alignItems: 'center', gap: 12, minHeight: 48}}>
      <Text style={{color, flex: 1}}>{title}</Text>
      <Switch testID={id} accessibilityLabel={title} value={value} onValueChange={onValueChange} />
    </View>;
  return <SafeAreaView style={{flex: 1, backgroundColor: dark ? '#11141B' : '#F7F8FC'}}>
    <ScrollView contentContainerStyle={{padding: 20, gap: 16}}>
      <Pressable testID="close-accessibility-demo" accessibilityRole="button" onPress={onClose} style={{minHeight: 48, justifyContent: 'center'}}>
        <Text style={{color}}>Back to component lab</Text>
      </Pressable>
      <Text accessibilityRole="header" style={{color, fontSize: 24, fontWeight: '700'}}>Adaptive controls</Text>
      <Text testID="adaptive-environment" style={{color}}>Text scale: {fontScale.toFixed(2)} · {dark ? 'dark' : 'light'} · {I18nManager.isRTL ? 'RTL' : 'LTR'}</Text>
      <Text style={{color}}>Change device text size, appearance, motion, transparency, or language settings to explore these controls.</Text>
      {setting('Disable controls', 'adaptive-disabled', disabled, setDisabled)}
      {setting('Loading button', 'adaptive-loading', loading, setLoading)}
      {setting('Keep current selection', 'adaptive-reject', reject, setReject)}
      <GlassButton title="Add to collection" testID="adaptive-button" disabled={disabled} loading={loading} onPress={() => setCount(value => value + 1)} />
      <Text testID="adaptive-count" style={{color}}>Added: {count}</Text>
      <GlassSegmentedControl testID="adaptive-segments" accessibilityLabel="Collection filter" options={options} value={selection} disabled={disabled}
        onValueChange={value => {setEvent(`Filter: ${value}`); if (!reject) setSelection(value);}} />
      <Text testID="adaptive-selection" style={{color}}>Selected: {selection}</Text>
      <GlassActionCluster actions={[{id: 'save', title: 'Save', systemImage: 'bookmark', disabled}, {id: 'locked', title: 'Locked action', systemImage: 'lock', disabled: true}]}
        expanded={expanded} onExpandedChange={setExpanded} onAction={id => setEvent(`Action: ${id}`)} />
      <Text testID="adaptive-event" accessibilityLiveRegion="polite" style={{color}}>{event}</Text>
      <GlassSlider testID="adaptive-slider" accessibilityLabel="Adaptive level" value={level} minimumValue={0} maximumValue={100} step={10} disabled={disabled} onValueChange={setLevel} />
      <GlassMenuButton title="Collection actions" testID="adaptive-menu" items={[{id: 'save', title: 'Save'}, {id: 'locked', title: 'Locked action', disabled: true}]} disabled={disabled} onAction={id => setEvent(`Menu: ${id}`)} />
      <GlassToolbar testID="adaptive-toolbar" items={[{id: 'save', title: 'Save'}, {id: 'sort', title: 'Sort collection'}, {id: 'locked', title: 'Locked action', disabled: true}]} disabled={disabled} onAction={id => setEvent(`Toolbar: ${id}`)} />
      <GlassTabBar testID="adaptive-tabs" items={[{id: 'home', title: 'Home', icon: 'home'}, {id: 'inbox', title: 'Inbox', icon: 'inbox', badge: 3}, {id: 'locked', title: 'Locked', icon: 'settings', disabled: true}]}
        value={tab} disabled={disabled} onValueChange={setTab} />
    </ScrollView>
  </SafeAreaView>;
}
