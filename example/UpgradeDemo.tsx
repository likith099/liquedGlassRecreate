import {Screen, ScreenContainer} from 'react-native-screens';
import React, {useMemo, useRef, useState} from 'react';
import {Pressable, ScrollView, Text, View, useColorScheme} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {GlassIconButton, GlassIconGroup, GlassPillBar, GlassMorphButton, GlassPresence, GlassContainer, GlassView,
  GlassTabBar, GlassHeaderHost, useGlassHeader, GlassBackgroundExtension, type GlassHeaderItem} from '@likith99/react-native-adaptive-liquid-glass';
function HeaderPage({detail, setDetail}: {detail: boolean; setDetail: (next: boolean) => void}) {
  const leading = useMemo<GlassHeaderItem[]>(() => detail ? [{slot: 'back', kind: 'back', accessibilityLabel: 'Back to overview', testID: 'upgrade-header-back', onPress: () => setDetail(false)}] : [], [detail, setDetail]);
  const trailing = useMemo<GlassHeaderItem[]>(() => [{slot: 'primary',
    ...(detail ? {kind: 'title' as const, title: 'Done'} : {kind: 'symbol' as const, symbol: 'ellipsis', androidIcon: 'demo_more'}),
    accessibilityLabel: detail ? 'Done' : 'More', testID: 'upgrade-header-primary', onPress: () => setDetail(!detail)}], [detail, setDetail]);
  useGlassHeader({routeKey: detail ? 'detail' : 'overview', active: true, leading, trailing});
  return <View style={{height: 60}} />;
}
export default function UpgradeDemo({onClose}: {onClose: () => void}) {
  const dark = useColorScheme() === 'dark'; const ink = dark ? '#FFFFFF' : '#17181B';
  const [saved, setSaved] = useState(false); const [scope, setScope] = useState('all');
  const [editing, setEditing] = useState(false); const [visible, setVisible] = useState(true);
  const [exits, setExits] = useState(0); const [status, setStatus] = useState('Ready');
  const [detail, setDetail] = useState(false); const [tab, setTab] = useState('home');
  const [surfaces, setSurfaces] = useState(true);
  const scroll = useRef<React.ComponentRef<typeof ScrollView>>(null);
  const text = (value: string, testID?: string) => <Text testID={testID} style={{color: ink, fontSize: 16}}>{value}</Text>;
  const command = (label: string, id: string, action: () => void) => <Pressable testID={id} accessibilityRole="button" onPress={action} style={{padding: 10}}>{text(label)}</Pressable>;
  return <SafeAreaView style={{flex: 1, backgroundColor: dark ? '#141820' : '#F7F8FC'}}>
    {command('Back to lab', 'upgrade-close', onClose)}
    <ScrollView ref={scroll} contentContainerStyle={{padding: 20, gap: 16}}>
      {text('0.2.0 controls')}{text(status, 'upgrade-status')}
      <View style={{flexDirection: 'row', gap: 16}}>
        <GlassIconButton symbol={{name: 'chevron.left', pointSize: 16.5, weight: 'semibold'}} controlSize="regular"
          accessibilityLabel="Back symbol" testID="upgrade-back-symbol" androidIcon="alg_tab_home" onPress={() => setStatus('Back symbol')} />
        <GlassIconButton symbol={saved ? 'heart.fill' : 'heart'} contentTransition="replace" pressEffect="bounce" badge={{count: 77}}
          accessibilityLabel="Favorite" testID="upgrade-badge" androidIcon="alg_tab_favorites" onPress={() => setSaved(!saved)} />
        <GlassIconButton symbol="sun.max" material="clear" accessibilityLabel="Clear glass" testID="upgrade-clear" androidIcon="alg_tab_settings" onPress={() => setStatus('Clear glass')} />
      </View>
      <GlassIconGroup testID="upgrade-group" items={[
        {id: 'save', symbol: saved ? 'heart.fill' : 'heart', androidIcon: 'alg_tab_favorites', accessibilityLabel: saved ? 'Saved' : 'Save', testID: 'upgrade-save', contentTransition: 'replace', pressEffect: 'bounce'},
        {id: 'share', symbol: 'square.and.arrow.up', androidIcon: 'alg_tab_library', accessibilityLabel: 'Share', testID: 'upgrade-share', badge: {count: 3}},
        {id: 'more', symbol: 'ellipsis', androidIcon: 'demo_more', accessibilityLabel: 'Group menu', testID: 'upgrade-more', menu: {items: [{id: 'pin', title: 'Pin item'}], onAction: id => setStatus(id)}},
      ]} onPress={id => {setStatus(id); if (id === 'save') setSaved(!saved);}} />
      <GlassPillBar testID="upgrade-pills" items={[{id: 'all', label: 'All', testID: 'upgrade-pill-all'}, {id: 'saved', label: 'Saved', badge: 2, testID: 'upgrade-pill-saved'}, {id: 'recent', label: 'Recent', badge: {indicator: true}, testID: 'upgrade-pill-recent'}, {id: 'archive', label: 'Archive', testID: 'upgrade-pill-archive'}]}
        value={scope} onValueChange={id => {setScope(id); setStatus(id);}} contentInset={0}
        actions={[{id: 'search', symbol: 'magnifyingglass', androidIcon: 'alg_tab_search', accessibilityLabel: 'Search', testID: 'upgrade-search'}]} onAction={setStatus} />
      <GlassMorphButton testID="upgrade-morph" content={editing ? {kind: 'title', title: 'Done', accessibilityLabel: 'Done', badge: {count: 5}} : {kind: 'symbol', symbol: 'ellipsis', androidIcon: 'demo_more', accessibilityLabel: 'Edit', badge: {count: 5}}} onPress={() => setEditing(!editing)} />
      <View style={{flexDirection: 'row', gap: 16, alignItems: 'center'}}>
        {text('Badge on plain glass:')}
        <GlassView badge={{count: 9}} badgeColor="#FF9500" testID="upgrade-surface-badge" style={{width: 72, height: 48, alignItems: 'center', justifyContent: 'center'}}>{text('Glass')}</GlassView>
      </View>
      {text('Badge styles:')}
      <View style={{flexDirection: 'row', gap: 16}}>
        <GlassIconButton symbol="envelope" androidIcon="alg_tab_inbox" badge={{indicator: true}} accessibilityLabel="Inbox"
          testID="upgrade-badge-dot" onPress={() => setStatus('Dot')} />
        <GlassIconButton symbol="tray" androidIcon="demo_archive" badge={{text: 'New'}} badgeColor="#FFD60A" badgeTextColor="#1C1C1E"
          accessibilityLabel="Updates" testID="upgrade-badge-text" onPress={() => setStatus('Text')} />
        <GlassIconButton symbol="bubble.left" androidIcon="demo_forward" badge={{count: 120}} badgeColor="#0A84FF"
          badgeAccessibilityLabel="120 unread messages" accessibilityLabel="Messages" testID="upgrade-badge-cap" onPress={() => setStatus('Capped')} />
      </View>
      {command('Toggle presence', 'upgrade-toggle-presence', () => setVisible(!visible))}
      <GlassPresence visible={visible} onExited={() => setExits(n => n + 1)} style={{alignSelf: 'flex-start'}}>
        <GlassIconButton symbol="trash" androidIcon="alg_tab_library" accessibilityLabel="Delete" testID="upgrade-present" onPress={() => setStatus('Delete')} />
      </GlassPresence>{text(`Exits: ${exits}`, 'upgrade-exits')}
      <GlassContainer style={{height: 50, alignItems: 'flex-end'}}>
        {editing ? <GlassView key="title" glassID="shared" style={{width: 90, height: 44, alignItems: 'center', justifyContent: 'center'}}>{text('Done')}</GlassView> : <GlassIconButton key="icon" glassID="shared" symbol="ellipsis" androidIcon="demo_more" accessibilityLabel="Matched glass" onPress={() => setEditing(true)} />}
      </GlassContainer>
      {text('Persistent header pilot')}
      <View style={{height: 65}}><GlassHeaderHost><HeaderPage detail={detail} setDetail={setDetail} /></GlassHeaderHost></View>
      <GlassBackgroundExtension style={{height: 60}}><View style={{height: 60, backgroundColor: '#5268A0'}}>{text('Background extension')}</View></GlassBackgroundExtension>
      {command('Toggle 20 surfaces', 'upgrade-toggle-surfaces', () => setSurfaces(!surfaces))}
      <ScreenContainer style={{height: 270}}>
        <Screen activityState={surfaces ? 2 : 0} style={{position: 'absolute', inset: 0}}>
          <View testID="upgrade-surfaces" collapsable={false} style={{flexDirection: 'row', flexWrap: 'wrap', gap: 4, backgroundColor: '#34465B', padding: 8}}>
            {Array.from({length: 20}, (_, i) => <GlassView key={i} tintColor="#A5A2FF30" style={{width: 55, height: 32, alignItems: 'center', justifyContent: 'center'}}>{text(String(i))}</GlassView>)}
          </View>
          {/* Control for G1: UIKit-owned button glass on the same detached screen. */}
          <View testID="upgrade-control-buttons" collapsable={false} style={{flexDirection: 'row', gap: 8, backgroundColor: '#34465B', paddingHorizontal: 8, paddingBottom: 8}}>
            {['star', 'heart', 'bell', 'bookmark', 'flag'].map(name => <GlassIconButton key={name} symbol={name} androidIcon="demo_add" accessibilityLabel={`Control ${name}`} onPress={() => {}} />)}
          </View>
          <View testID="upgrade-untinted-surfaces" collapsable={false} style={{flexDirection: 'row', gap: 4, backgroundColor: '#34465B', paddingHorizontal: 8, paddingBottom: 8}}>
            {Array.from({length: 5}, (_, i) => <GlassView key={i} style={{width: 55, height: 32, alignItems: 'center', justifyContent: 'center'}}>{text(`u${i}`)}</GlassView>)}
          </View>
        </Screen>
        <Screen activityState={surfaces ? 0 : 2} style={{position: 'absolute', inset: 0, backgroundColor: '#34465B'}}>{text('Covered screen')}</Screen>
      </ScreenContainer>
      <View style={{height: 400}}>{text('Scroll to exercise tab minimization')}</View>
    </ScrollView>
    <GlassTabBar testID="upgrade-tabs" items={[{id: 'home', title: 'Home', icon: 'home', badge: {text: 'New'}, scrollViewRef: scroll}, {id: 'saved', title: 'Saved', icon: 'favorites', badge: 7, badgeColor: '#FF3B30', badgeTextColor: '#FFFFFF', scrollViewRef: scroll}]}
      value={tab} onValueChange={setTab} minimizeBehavior="onScrollDown" bottomAccessory={<View style={{padding: 10}}><Text numberOfLines={1} maxFontSizeMultiplier={1.2} style={{color: ink, fontSize: 16}}>Now reading · Chapter one</Text></View>} style={{height: 120}} />
  </SafeAreaView>;
}
