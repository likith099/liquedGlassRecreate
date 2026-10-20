import React, {useRef, useState} from 'react';
import {Platform, FlatList, Pressable, RefreshControl, Text, View, useColorScheme} from 'react-native';
import {NavigationContainer, NavigationIndependentTree, DarkTheme, DefaultTheme, useScrollToTop} from '@react-navigation/native';
import {createNativeStackNavigator, type NativeStackScreenProps} from '@react-navigation/native-stack';
import {createBottomTabNavigator} from '@react-navigation/bottom-tabs';
import {GlassNavigationView, type GlassNavigationHandle} from '@likith99/react-native-adaptive-liquid-glass';
import NativeNavigationTabBar from './navigation/NativeNavigationTabBar';
const Stack = createNativeStackNavigator<{Gallery: undefined; Detail: undefined}>();
const Tabs = createBottomTabNavigator();
const names = Array.from({length: 50}, (_, i) => `Contact ${i + 1}`);
function Gallery({navigation, close}: {navigation: NativeStackScreenProps<{Gallery: undefined; Detail: undefined}, 'Gallery'>['navigation']; close: () => void}) {
  const list = useRef<FlatList<string>>(null), header = useRef<GlassNavigationHandle>(null);
  useScrollToTop(header);
  const dark = useColorScheme() === 'dark', ink = dark ? 'white' : '#18202D';
  const [mode, setMode] = useState<'large' | 'inlineLarge' | 'inline'>('large');
  const [morph, setMorph] = useState(true), [hard, setHard] = useState(true), [slots, setSlots] = useState(false);
  const [compact, setCompact] = useState(22), [refreshing, setRefreshing] = useState(false), [refreshes, setRefreshes] = useState(0);
  const [query, setQuery] = useState(''), [search, setSearch] = useState(false), [scope, setScope] = useState('all'), [badge, setBadge] = useState(5);
  const [placement, setPlacement] = useState<'stacked' | 'integratedButton'>('stacked');
  const [accessory, setAccessory] = useState(false);
  const slot = (text: string, height: number) => <View style={{height, justifyContent: 'center'}}><Text style={{color: ink}}>{text}</Text></View>;
  const options = [
    {id: 'large', title: 'Large below bar'}, {id: 'inlineLarge', title: 'Large in bar', subtitle: morph ? undefined : 'UIKit shows it below the bar while a back button is present'}, {id: 'inline', title: 'Compact only'},
    {id: 'morph', title: morph ? 'Native title transition' : 'Single title morph'},
    {id: 'font', title: 'Toggle compact title size'}, {id: 'edge', title: hard ? 'Soft edge' : 'Hard edge'},
    {id: 'slots', title: slots ? 'Text title' : 'Custom title and subtitles'},
    {id: 'accessory', title: accessory ? 'Hide pinned filter' : 'Show pinned filter'},
    {id: 'placement', title: 'Toggle search placement'},
    {id: 'badge', title: 'Update badge in 2 seconds', keepsMenuPresented: true},
  ];
  const choose = (id: string) => {
    if (['large', 'inlineLarge', 'inline'].includes(id)) setMode(id as typeof mode);
    else if (id === 'morph') setMorph(v => !v);
    else if (id === 'font') setCompact(v => v === 22 ? 17 : 22);
    else if (id === 'edge') setHard(v => !v);
    else if (id === 'slots') setSlots(v => !v);
    else if (id === 'accessory') setAccessory(v => !v);
    else if (id === 'placement') { setPlacement(v => v === 'stacked' ? 'integratedButton' : 'stacked'); setSearch(true); }
    else if (id === 'badge') setTimeout(() => setBadge(v => v + 1), 2000);
  };
  return <GlassNavigationView ref={header} title="Contacts" titleTestID="review-title" scrollViewRef={list}
    titleDisplayMode={mode} titleTransition={morph ? 'morph' : 'native'} titlePosition="leading" titleFont={{compactSize: compact}}
    edgeEffect={{top: hard ? 'hard' : 'soft'}} onBack={close} backTestID="review-close" handlesSystemBack androidCollapsing
    titleView={slots ? slot('◉  Custom contact', 36) : undefined}
    subtitleView={slots ? slot('Available now', 20) : undefined}
    largeSubtitleView={slots ? slot('Your contacts nearby', 24) : undefined}
    accessory={accessory ? <View testID="review-accessory" style={{height: 44, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20}}>
      <Pressable accessibilityRole="button" onPress={() => setScope(v => v === 'all' ? 'nearby' : 'all')}><Text style={{color: ink}}>Filter: {scope}</Text></Pressable>
    </View> : undefined}
    trailingItems={[
      {id: 'search', systemItem: 'search', accessibilityLabel: 'Search contacts', testID: 'review-search'},
      {id: 'options', symbol: 'slider.horizontal.3', androidIcon: 'demo_more', accessibilityLabel: 'Header options', testID: 'review-options', badge: {count: badge}, menu: {items: options, onAction: choose}},
      {id: 'top', symbol: 'arrow.up', title: 'Top', accessibilityLabel: 'Top', testID: 'review-top'}]}
    onAction={id => id === 'search' ? setSearch(v => !v) : header.current?.scrollToTop()}
    search={search ? {value: query, onChangeText: setQuery, active: true, onActiveChange: active => { if (!active) setSearch(false); },
      testID: 'review-search-field', placeholder: 'Find contacts', hidesWhenScrolling: false, placement,
      scopes: {items: [{id: 'all', title: 'All'}, {id: 'nearby', title: 'Nearby'}], value: scope, onChange: setScope}} : undefined}>
    <FlatList ref={list} nestedScrollEnabled style={{flex: 1}} testID="review-list" contentInsetAdjustmentBehavior="automatic" keyboardShouldPersistTaps="handled"
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={() => { setRefreshing(true); setTimeout(() => { setRefreshing(false); setRefreshes(v => v + 1); }, 800); }} />}
      data={names.filter(n => n.toLowerCase().includes(query.toLowerCase()))} keyExtractor={name => name}
      ListHeaderComponent={<Text testID="review-state" style={{color: ink, padding: 16}}>{mode} · {morph ? 'morph' : 'native'} · {hard ? 'hard' : 'soft'} · refresh {refreshes}</Text>}
      renderItem={({item}) => <Pressable accessibilityRole="button" accessibilityLabel={item} onPress={() => navigation.navigate('Detail')} style={{height: 64, justifyContent: 'center', paddingHorizontal: 20}}><Text style={{color: ink, fontSize: 18}}>{item}</Text></Pressable>} />
  </GlassNavigationView>;
}
function Detail({navigation}: NativeStackScreenProps<{Gallery: undefined; Detail: undefined}, 'Detail'>) {
  const unbound = useRef(null), [insets, setInsets] = useState({top: 0, bottom: 0});
  const dark = useColorScheme() === 'dark';
  return <GlassNavigationView title="Conversation" titleDisplayMode="inline" scrollViewRef={unbound} onBack={() => navigation.goBack()} backTestID="review-detail-back"
    onBarInsetsChange={setInsets} edgeEffect="hidden" handlesSystemBack
    titleView={<View style={{height: 40, justifyContent: 'center'}}><Text style={{color: dark ? 'white' : 'black'}}>◉  Contact 1</Text></View>}>
    <View style={{flex: 1, paddingTop: Platform.OS === 'ios' ? insets.top : 0, paddingBottom: Platform.OS === 'ios' ? insets.bottom : 0}}>
      <FlatList inverted contentInsetAdjustmentBehavior="never" data={['Newest message', 'Older message']} renderItem={({item}) => <Text style={{color: dark ? 'white' : 'black', padding: 24}}>{item}</Text>} />
    </View>
  </GlassNavigationView>;
}
function PilotStack({close}: {close: () => void}) {
  return <Stack.Navigator screenOptions={{headerShown: false, fullScreenGestureEnabled: true}}>
    <Stack.Screen name="Gallery">{props => <Gallery navigation={props.navigation} close={close} />}</Stack.Screen>
    <Stack.Screen name="Detail" component={Detail} />
  </Stack.Navigator>;
}
export default function HeaderReviewDemo({onClose}: {onClose: () => void}) {
  const dark = useColorScheme() === 'dark';
  return <NavigationIndependentTree><NavigationContainer theme={dark ? DarkTheme : DefaultTheme}>
    <Tabs.Navigator screenOptions={{headerShown: false}} tabBar={props => <NativeNavigationTabBar {...props} />}>
      <Tabs.Screen name="Home">{() => <PilotStack close={onClose} />}</Tabs.Screen>
      <Tabs.Screen name="Library">{() => <PilotStack close={onClose} />}</Tabs.Screen>
    </Tabs.Navigator>
  </NavigationContainer></NavigationIndependentTree>;
}
