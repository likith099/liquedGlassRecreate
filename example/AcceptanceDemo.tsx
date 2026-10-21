import React, {useEffect, useMemo, useRef, useState} from 'react';
import {FlatList, Pressable, ScrollView, Switch, Text, View, useColorScheme} from 'react-native';
import {SafeAreaView, useSafeAreaInsets} from 'react-native-safe-area-context';
import {NavigationContainer, NavigationIndependentTree, DarkTheme, DefaultTheme, useIsFocused} from '@react-navigation/native';
import {createNativeStackNavigator, type NativeStackScreenProps} from '@react-navigation/native-stack';
import {GlassIconButton, GlassIconGroup, GlassPillBar, GlassMorphButton, GlassPresence, GlassTabBar,
  GlassHeaderHost, useGlassHeader, GlassMetrics, type GlassHeaderItem} from '@likith99/react-native-adaptive-liquid-glass';

/**
 * 0.2.0 acceptance scenes: one controlled scene per request item, so recordings and
 * screenshots measure exactly one behaviour. Black page in dark mode, as the request's
 * reference measurements were taken.
 */
type Scene = 'menu' | 'stack' | 'tabs';
const sizes = ['mini', 'small', 'regular', 'large', 'extraLarge'] as const;

/** Busy-waits on the JS thread, as a heavy render or synchronous work would. */
function blockJS(milliseconds: number) {
  const end = Date.now() + milliseconds;
  while (Date.now() < end) { /* intentionally blocking */ }
}

function Label({children, testID}: {children: React.ReactNode; testID?: string}) {
  const dark = useColorScheme() === 'dark';
  return <Text testID={testID} style={{color: dark ? '#FFFFFF' : '#17181B', fontSize: 15, marginVertical: 6}}>{children}</Text>;
}

function Lab({open, onClose}: {open: (scene: Scene) => void; onClose: () => void}) {
  const dark = useColorScheme() === 'dark';
  const [select, setSelect] = useState(false), [stall, setStall] = useState(false), [morphs, setMorphs] = useState(0);
  const [visible, setVisible] = useState(true), [mounted, setMounted] = useState(true), [exits, setExits] = useState(0);
  const [favorite, setFavorite] = useState(false), [scope, setScope] = useState('forYou'), [status, setStatus] = useState('Ready');
  const stallNext = useRef(false);
  // G5: block JS right after the change. React Native mounts at the end of the JS task, so the
  // stall starts in the next task, once the end state has reached native.
  useEffect(() => { if (stallNext.current) { stallNext.current = false; setTimeout(() => blockJS(500), 0); } }, [morphs]);
  const toggleMorph = () => { stallNext.current = stall; setSelect(value => !value); setMorphs(n => n + 1); };
  const row = {flexDirection: 'row' as const, alignItems: 'center' as const, gap: 12, flexWrap: 'wrap' as const};
  const button = (label: string, testID: string, action: () => void) =>
    <Pressable testID={testID} accessibilityRole="button" onPress={action} style={{paddingVertical: 8, paddingRight: 16}}><Label>{label}</Label></Pressable>;
  return <SafeAreaView style={{flex: 1, backgroundColor: dark ? '#000000' : '#FFFFFF'}}>
    <ScrollView testID="acc-root" contentContainerStyle={{paddingHorizontal: GlassMetrics.pageMargin(440), paddingBottom: 80}}>
      {button('Close', 'acc-close', onClose)}
      <Label testID="acc-status">{status}</Label>

      <Label>G5 morph</Label>
      <View style={[row, {justifyContent: 'flex-end'}]} testID="acc-morph-row">
        <GlassMorphButton testID="acc-morph" anchor="trailing"
          content={select ? {kind: 'title', title: 'Select', accessibilityLabel: 'Select'} : {kind: 'symbol', symbol: 'ellipsis', androidIcon: 'demo_more', accessibilityLabel: 'More'}}
          onPress={toggleMorph} />
      </View>
      {button('Morph without touching it', 'acc-morph-trigger', toggleMorph)}
      <View style={row}><Switch testID="acc-stall" value={stall} onValueChange={setStall} /><Label>Block JS 500 ms after each morph</Label></View>
      <Label testID="acc-morph-count">{`Morphs: ${morphs}`}</Label>

      <Label>G6 presence</Label>
      <View style={[row, {minHeight: 56}]}>
        {mounted ? <GlassPresence visible={visible} onExited={() => setExits(n => n + 1)}>
          <GlassIconButton symbol="trash" androidIcon="alg_tab_library" accessibilityLabel="Remove" testID="acc-presence-item" onPress={() => setStatus('Remove')} />
        </GlassPresence> : null}
      </View>
      <View style={row}>
        {button(visible ? 'Hide' : 'Show', 'acc-presence-toggle', () => { setMounted(true); setVisible(v => !v); })}
        {button('Hide, then unmount mid-exit', 'acc-presence-unmount', () => { setVisible(false); setTimeout(() => setMounted(false), 40); })}
        {button('Remount', 'acc-presence-remount', () => { setExits(0); setVisible(true); setMounted(true); })}
      </View>
      <Label testID="acc-exits">{`Exits: ${exits}`}</Label>

      <Label>G8 control sizes</Label>
      <View style={row}>{sizes.map(size => <GlassIconButton key={size} controlSize={size} symbol="plus" androidIcon="demo_add"
        accessibilityLabel={`Size ${size}`} testID={`acc-size-${size}`} onPress={() => setStatus(size)} />)}</View>

      <Label>G2 symbols</Label>
      <View style={row}>
        <GlassIconButton testID="acc-chevron" accessibilityLabel="Back chevron" androidIcon="alg_back"
          symbol={{name: 'chevron.left', pointSize: 16.5, weight: 'semibold'}} onPress={() => setStatus('Chevron')} />
        <GlassIconButton testID="acc-chevron-large" accessibilityLabel="Back chevron, large scale" androidIcon="alg_back"
          symbol={{name: 'chevron.left', pointSize: 17, weight: 'semibold', scale: 'large'}} onPress={() => setStatus('Chevron large')} />
        <GlassIconButton testID="acc-chevron-medium-large" accessibilityLabel="Back chevron, medium weight, large scale" androidIcon="alg_back"
          symbol={{name: 'chevron.left', pointSize: 16.5, weight: 'medium', scale: 'large'}} onPress={() => setStatus('Chevron medium large')} />
        <GlassIconButton testID="acc-heart" accessibilityLabel={favorite ? 'Favorited' : 'Favorite'} androidIcon="alg_tab_favorites"
          symbol={favorite ? 'heart.fill' : 'heart'} contentTransition="replace" onPress={() => setFavorite(v => !v)} />
      </View>

      <Label>G3 groups</Label>
      <View style={row}>
        <GlassIconGroup testID="acc-group3" onPress={id => setStatus(`Group ${id}`)} items={[
          {id: 'list', symbol: 'calendar.day.timeline.left', androidIcon: 'alg_tab_library', accessibilityLabel: 'List', testID: 'acc-group3-list'},
          {id: 'search', symbol: 'magnifyingglass', androidIcon: 'alg_tab_search', accessibilityLabel: 'Search', testID: 'acc-group3-search'},
          {id: 'add', symbol: 'plus', androidIcon: 'demo_add', accessibilityLabel: 'Add', testID: 'acc-group3-add'}]} />
        <GlassIconGroup testID="acc-group2" onPress={id => setStatus(`Group ${id}`)} items={[
          {id: 'search', symbol: 'magnifyingglass', androidIcon: 'alg_tab_search', accessibilityLabel: 'Find', testID: 'acc-group2-search'},
          {id: 'more', symbol: 'ellipsis', androidIcon: 'demo_more', accessibilityLabel: 'Options', testID: 'acc-group2-more',
            menu: {items: [{id: 'sort', title: 'Sort'}, {id: 'edit', title: 'Edit'}], onAction: id => setStatus(`Menu ${id}`)}}]} />
      </View>

      <Label>G4 pills</Label>
      <View style={{marginHorizontal: -GlassMetrics.pageMargin(440)}}>
        <GlassPillBar testID="acc-pills" value={scope} onValueChange={setScope}
          items={[{id: 'forYou', label: 'For You', testID: 'acc-pill-forYou'}, {id: 'explore', label: 'Explore', testID: 'acc-pill-explore'},
            {id: 'plans', label: 'Plans', testID: 'acc-pill-plans'}, {id: 'library', label: 'Library', testID: 'acc-pill-library'}]}
          actions={[{id: 'search', symbol: 'magnifyingglass', androidIcon: 'alg_tab_search', accessibilityLabel: 'Search', testID: 'acc-pill-search'}]}
          onAction={id => setStatus(`Pill action ${id}`)} />
      </View>
      <Label testID="acc-scope">{`Scope: ${scope}`}</Label>

      <Label>G11 badge</Label>
      <View style={row}><GlassIconButton testID="acc-bell" symbol="bell" androidIcon="alg_tab_settings" accessibilityLabel="Notifications"
        badge={{count: 3}} badgeAccessibilityLabel="3 unread" onPress={() => setStatus('Bell')} /></View>

      <Label>Scenes</Label>
      {button('G7 header stack →', 'acc-open-stack', () => open('stack'))}
      {button('G9 tab minimize →', 'acc-open-tabs', () => open('tabs'))}
    </ScrollView>
  </SafeAreaView>;
}

// G7: a two-screen native stack under one persistent header host.
type Routes = {Home: undefined; All: undefined; Item: {name: string}; Details: {name: string}; System: undefined};
const Stack = createNativeStackNavigator<Routes>();
const stallPush = {next: false};
function HomeScreen({navigation, route}: NativeStackScreenProps<Routes, 'Home'>) {
  const dark = useColorScheme() === 'dark', focused = useIsFocused();
  const [stall, setStall] = useState(false), [menu, setMenu] = useState('None');
  const trailing = useMemo<GlassHeaderItem[]>(() => [{slot: 'primary', kind: 'symbol', symbol: 'ellipsis', androidIcon: 'demo_more',
    accessibilityLabel: 'More', testID: 'acc-header-primary', onPress: () => setMenu('More')},
    // A second trailing slot (placed left of the first) with a menu and a badge.
    {slot: 'sort', kind: 'symbol', symbol: 'arrow.up.arrow.down', androidIcon: 'demo_more', accessibilityLabel: 'Sort',
      testID: 'acc-header-sort', badge: {count: 2},
      menu: {items: [{id: 'name', title: 'Name'}, {id: 'date', title: 'Date'}], onAction: id => setMenu(`Sort ${id}`)}}], []);
  useGlassHeader({routeKey: route.key, active: focused, trailing});
  return <View style={{flex: 1, backgroundColor: dark ? '#000000' : '#FFFFFF', paddingTop: 120, paddingHorizontal: 20}}>
    <Text style={{color: dark ? '#FFF' : '#000', fontSize: 34, fontWeight: '700'}}>Library</Text>
    {['All', 'Shared', 'Recent'].map(name => <Pressable key={name} testID={`acc-row-${name}`} accessibilityRole="button"
      onPress={() => { stallPush.next = stall; navigation.navigate('All'); }} style={{paddingVertical: 14}}>
      <Text style={{color: dark ? '#FFF' : '#000', fontSize: 17}}>{name}</Text></Pressable>)}
    <Pressable testID="acc-row-System" accessibilityRole="button" onPress={() => navigation.navigate('System')} style={{paddingVertical: 14}}>
      <Text style={{color: dark ? '#FFF' : '#000', fontSize: 17}}>UIKit reference header</Text></Pressable>
    <View style={{flexDirection: 'row', alignItems: 'center', gap: 12, marginTop: 12}}>
      <Switch testID="acc-stall-push" value={stall} onValueChange={setStall} />
      <Text style={{color: dark ? '#FFF' : '#000'}}>Block JS 500 ms during push</Text>
    </View>
    <Text testID="acc-home-state" style={{color: dark ? '#FFF' : '#000', marginTop: 12}}>{`Header: ${menu}`}</Text>
  </View>;
}
function AllScreen({navigation, route}: NativeStackScreenProps<Routes, 'All'>) {
  const dark = useColorScheme() === 'dark', focused = useIsFocused();
  const [selecting, setSelecting] = useState(false);
  // Runs right after this screen's first commit, while the native push is under way.
  useEffect(() => { if (stallPush.next) { stallPush.next = false; setTimeout(() => blockJS(500), 0); } }, []);
  const leading = useMemo<GlassHeaderItem[]>(() => [{slot: 'back', kind: 'back', accessibilityLabel: 'Back', testID: 'acc-header-back', onPress: navigation.goBack}], [navigation]);
  const [shared, setShared] = useState(0);
  const trailing = useMemo<GlassHeaderItem[]>(() => [{slot: 'primary', kind: 'title', title: 'Select', accessibilityLabel: 'Select',
    testID: 'acc-header-primary', onPress: () => setSelecting(v => !v)},
    // Share's badge counts shares here; Item's Share has none. Same control: the glass stays, the badge changes.
    {kind: 'symbol', symbol: 'square.and.arrow.up', androidIcon: 'demo_forward', accessibilityLabel: 'Share', testID: 'acc-header-share',
      ...(shared > 0 ? {badge: {count: shared}} : {}), onPress: () => setShared(n => n + 1)}], [shared]);
  useGlassHeader({routeKey: route.key, active: focused, leading, trailing});
  return <View style={{flex: 1, backgroundColor: dark ? '#000000' : '#FFFFFF', paddingTop: 120, paddingHorizontal: 20}}>
    <Text testID="acc-all-title" style={{color: dark ? '#FFF' : '#000', fontSize: 34, fontWeight: '700'}}>All</Text>
    <Text testID="acc-all-state" style={{color: dark ? '#FFF' : '#000', marginTop: 12}}>{`${selecting ? 'Selecting' : 'Browsing'} · shared ${shared}`}</Text>
    {['Item 1', 'Item 2'].map(name => <Pressable key={name} testID={`acc-row-${name.replace(' ', '')}`} accessibilityRole="button"
      onPress={() => navigation.navigate('Item', {name})} style={{paddingVertical: 14}}>
      <Text style={{color: dark ? '#FFF' : '#000', fontSize: 17}}>{name}</Text></Pressable>)}
  </View>;
}
// A screen with a back button pushed from a screen with one: the back button and Share, present
// on both, keep their glass and stay still while Select morphs into Edit. Item names its slots
// differently from All on purpose; controls on both screens pair by side and content.
function ItemScreen({navigation, route}: NativeStackScreenProps<Routes, 'Item'>) {
  const dark = useColorScheme() === 'dark', focused = useIsFocused();
  const [state, setState] = useState('Viewing'), [editing, setEditing] = useState(false);
  // Edit mode, as in Contacts: back becomes Cancel and Edit becomes Done (both morph in place),
  // Share leaves; Done or Cancel brings them back.
  const leading = useMemo<GlassHeaderItem[]>(() => [editing
    ? {kind: 'title', title: 'Cancel', accessibilityLabel: 'Cancel', testID: 'acc-item-cancel', onPress: () => { setEditing(false); setState('Cancelled'); }}
    : {kind: 'back', accessibilityLabel: 'Back', testID: 'acc-item-back', onPress: navigation.goBack}], [navigation, editing]);
  const trailing = useMemo<GlassHeaderItem[]>(() => [{slot: 'primary', kind: 'title', title: editing ? 'Done' : 'Edit', accessibilityLabel: editing ? 'Done' : 'Edit',
    testID: 'acc-item-primary', onPress: () => { setState(editing ? 'Saved' : 'Editing'); setEditing(v => !v); }},
    ...(editing ? [] : [{slot: 'share', kind: 'symbol' as const, symbol: 'square.and.arrow.up', androidIcon: 'demo_forward', accessibilityLabel: 'Share', testID: 'acc-item-share', onPress: () => setState('Shared')}])], [editing]);
  useGlassHeader({routeKey: route.key, active: focused, leading, trailing});
  return <View style={{flex: 1, backgroundColor: dark ? '#000000' : '#FFFFFF', paddingTop: 120, paddingHorizontal: 20}}>
    <Text testID="acc-item-title" style={{color: dark ? '#FFF' : '#000', fontSize: 34, fontWeight: '700'}}>{route.params.name}</Text>
    <Text testID="acc-item-state" style={{color: dark ? '#FFF' : '#000', marginTop: 12}}>{state}</Text>
    <Pressable testID="acc-item-details" accessibilityRole="button" onPress={() => navigation.navigate('Details', {name: route.params.name})} style={{paddingVertical: 14}}>
      <Text style={{color: dark ? '#FFF' : '#000', fontSize: 17}}>Details</Text></Pressable>
  </View>;
}
// Different controls and counts: Item [back | Share, Edit] → Details [Close | ⋯]. Back and Edit
// morph by position into Close and ⋯; Share leaves. Popping reverses it.
function DetailsScreen({navigation, route}: NativeStackScreenProps<Routes, 'Details'>) {
  const dark = useColorScheme() === 'dark', focused = useIsFocused();
  const [state, setState] = useState('Details');
  const leading = useMemo<GlassHeaderItem[]>(() => [{kind: 'title', title: 'Close', accessibilityLabel: 'Close', testID: 'acc-details-close', onPress: navigation.goBack}], [navigation]);
  const trailing = useMemo<GlassHeaderItem[]>(() => [{kind: 'symbol', symbol: 'ellipsis', androidIcon: 'demo_more', accessibilityLabel: 'More', testID: 'acc-details-more', onPress: () => setState('More')}], []);
  useGlassHeader({routeKey: route.key, active: focused, leading, trailing});
  return <View style={{flex: 1, backgroundColor: dark ? '#000000' : '#FFFFFF', paddingTop: 120, paddingHorizontal: 20}}>
    <Text testID="acc-details-title" style={{color: dark ? '#FFF' : '#000', fontSize: 34, fontWeight: '700'}}>{`${route.params.name} details`}</Text>
    <Text testID="acc-details-state" style={{color: dark ? '#FFF' : '#000', marginTop: 12}}>{state}</Text>
  </View>;
}
function SystemScreen({route}: NativeStackScreenProps<Routes, 'System'>) {
  const dark = useColorScheme() === 'dark', focused = useIsFocused();
  useGlassHeader({routeKey: route.key, active: focused});
  return <View testID="acc-system" style={{flex: 1, backgroundColor: dark ? '#000000' : '#FFFFFF'}} />;
}
function StackScene({onClose}: {onClose: () => void}) {
  const dark = useColorScheme() === 'dark', insets = useSafeAreaInsets();
  return <View style={{flex: 1, backgroundColor: dark ? '#000' : '#FFF'}}>
    <NavigationIndependentTree><NavigationContainer theme={dark ? DarkTheme : DefaultTheme}>
      <GlassHeaderHost topInset={insets.top} colorScheme={dark ? 'dark' : 'light'}>
        <Stack.Navigator screenOptions={{headerShown: false}}>
          <Stack.Screen name="Home" component={HomeScreen} />
          <Stack.Screen name="All" component={AllScreen} />
          <Stack.Screen name="Item" component={ItemScreen} />
          <Stack.Screen name="Details" component={DetailsScreen} />
          {/* UIKit's own navigation bar: the reference back indicator for G2 measurements. */}
          <Stack.Screen name="System" component={SystemScreen} options={{headerShown: true, title: 'Reference', headerBackButtonDisplayMode: 'minimal'}} />
        </Stack.Navigator>
      </GlassHeaderHost>
    </NavigationContainer></NavigationIndependentTree>
    <Pressable testID="acc-stack-close" accessibilityRole="button" onPress={onClose} style={{position: 'absolute', bottom: insets.bottom + 12, left: 20, padding: 10}}>
      <Text style={{color: dark ? '#FFF' : '#000'}}>Close stack</Text></Pressable>
  </View>;
}

// G9: tab bar minimizes when its tab's list scrolls down.
function TabsScene({onClose}: {onClose: () => void}) {
  const dark = useColorScheme() === 'dark';
  const list = useRef<FlatList<number>>(null);
  const [tab, setTab] = useState('home');
  return <View style={{flex: 1, backgroundColor: dark ? '#000' : '#FFF'}}>
    <FlatList ref={list} testID="acc-tabs-list" data={Array.from({length: 80}, (_, i) => i)} keyExtractor={n => String(n)}
      contentInsetAdjustmentBehavior="automatic" ListHeaderComponent={<Pressable testID="acc-tabs-close" accessibilityRole="button" onPress={onClose} style={{padding: 20, paddingTop: 70}}>
        <Text style={{color: dark ? '#FFF' : '#000'}}>Close tabs</Text></Pressable>}
      renderItem={({item}) => <Text style={{color: dark ? '#FFF' : '#000', padding: 16, fontSize: 17}}>{`Row ${item + 1}`}</Text>} />
    <GlassTabBar testID="acc-tabs" value={tab} onValueChange={setTab} minimizeBehavior="onScrollDown"
      items={[{id: 'home', title: 'Home', icon: 'home', scrollViewRef: list}, {id: 'saved', title: 'Saved', icon: 'favorites', scrollViewRef: list},
        {id: 'search', title: 'Search', icon: 'search', scrollViewRef: list}]} />
  </View>;
}

export default function AcceptanceDemo({onClose}: {onClose: () => void}) {
  const [scene, setScene] = useState<Scene>('menu');
  if (scene === 'stack') return <StackScene onClose={() => setScene('menu')} />;
  if (scene === 'tabs') return <TabsScene onClose={() => setScene('menu')} />;
  return <Lab open={setScene} onClose={onClose} />;
}
