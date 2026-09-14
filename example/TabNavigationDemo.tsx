import React, {createContext, useContext, useState} from 'react';
import {Pressable, ScrollView, StyleSheet, Switch, Text, View, useColorScheme} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {DarkTheme, DefaultTheme, NavigationContainer, NavigationIndependentTree} from '@react-navigation/native';
import {createBottomTabNavigator, type BottomTabScreenProps} from '@react-navigation/bottom-tabs';
import NativeNavigationTabBar from './navigation/NativeNavigationTabBar';

type Routes = {Home: undefined; Library: undefined; Search: undefined; Inbox: undefined; Settings: undefined};
const Tab = createBottomTabNavigator<Routes>();
type Controls = {
  reject: boolean; setReject: (value: boolean) => void;
  disabled: boolean; setDisabled: (value: boolean) => void;
  inboxDisabled: boolean; setInboxDisabled: (value: boolean) => void;
  reversed: boolean; setReversed: (value: boolean) => void;
  replaced: boolean; setReplaced: (value: boolean) => void;
  badges: boolean; setBadges: (value: boolean) => void;
  event: string; events: number;
};
const Settings = createContext<Controls | null>(null);
function DemoScreen({route, navigation}: BottomTabScreenProps<Routes>) {
  const controls = useContext(Settings)!;
  const [count, setCount] = useState(0);
  const dark = useColorScheme() === 'dark';
  const color = dark ? '#F2F3F7' : '#222737';
  const toggle = (title: string, id: string, value: boolean, onValueChange: (next: boolean) => void) =>
    <View style={styles.row}><Text style={{color, flex: 1}}>{title}</Text>
      <Switch testID={id} accessibilityLabel={title} value={value} onValueChange={onValueChange} /></View>;
  return <ScrollView contentContainerStyle={styles.screen}>
    <Text testID="tab-screen-title" style={[styles.title, {color}]}>{route.name} screen</Text>
    <Text testID="screen-counter" style={{color}}>{route.name} count: {count}</Text>
    <Pressable testID="screen-increment" accessibilityRole="button" onPress={() => setCount(value => value + 1)} style={styles.action}>
      <Text style={{color}}>Increment this screen</Text>
    </Pressable>
    <Pressable testID="tabs-go-inbox" accessibilityRole="button" onPress={() => navigation.navigate('Inbox')} style={styles.action}>
      <Text style={{color}}>Go to Inbox programmatically</Text>
    </Pressable>
    <Text testID="tab-event" accessibilityLiveRegion="polite" style={{color}}>{controls.event}</Text>
    <Text testID="tab-event-count" style={{color}}>Tab events: {controls.events}</Text>
    {toggle('Prevent Inbox navigation', 'tabs-reject-toggle', controls.reject, controls.setReject)}
    {toggle('Disable Inbox tab', 'tabs-inbox-disabled-toggle', controls.inboxDisabled, controls.setInboxDisabled)}
    {toggle('Disable all tab taps', 'tabs-disabled-toggle', controls.disabled, controls.setDisabled)}
    {toggle('Reverse tab order', 'tabs-reverse-toggle', controls.reversed, controls.setReversed)}
    {toggle('Replace Library with Search', 'tabs-replace-toggle', controls.replaced, controls.setReplaced)}
    {toggle('Show badges', 'tabs-badges-toggle', controls.badges, controls.setBadges)}
  </ScrollView>;
}
export default function TabNavigationDemo({onClose}: {onClose: () => void}) {
  const [reject, setReject] = useState(false);
  const [disabled, setDisabled] = useState(false);
  const [inboxDisabled, setInboxDisabled] = useState(false);
  const [reversed, setReversed] = useState(false);
  const [replaced, setReplaced] = useState(false);
  const [badges, setBadges] = useState(true);
  const [event, setEvent] = useState('No tab press');
  const [events, setEvents] = useState(0);
  const dark = useColorScheme() === 'dark';
  return <SafeAreaView edges={['top', 'left', 'right']} style={{flex: 1, backgroundColor: dark ? '#11141B' : '#F7F8FC'}}>
    <Pressable testID="close-tabs-demo" accessibilityRole="button" onPress={onClose} style={styles.close}>
      <Text style={{color: dark ? '#F2F3F7' : '#222737'}}>‹ Back to component lab</Text>
    </Pressable>
    <Settings.Provider value={{reject,setReject,disabled,setDisabled,inboxDisabled,setInboxDisabled,
      reversed,setReversed,replaced,setReplaced,badges,setBadges,event,events}}>
      <NavigationIndependentTree>
        <NavigationContainer theme={dark ? DarkTheme : DefaultTheme}>
          <Tab.Navigator initialRouteName="Home" backBehavior="history"
            screenOptions={{headerShown: false, animation: 'none'}}
            tabBar={props => <NativeNavigationTabBar {...props} disabled={disabled}
              disabledRoutes={inboxDisabled ? ['Inbox'] : []} reversed={reversed} />}>
            {(['Home', replaced ? 'Search' : 'Library', 'Inbox', 'Settings'] as const).map(name =>
              <Tab.Screen key={name} name={name} component={DemoScreen}
                options={{tabBarBadge: badges ? (name === 'Inbox' ? 3 : name === 'Settings' ? 'dot' : undefined) : undefined}}
                listeners={{tabPress: e => {
                  setEvents(value => value + 1);
                  if (reject && name === 'Inbox') {e.preventDefault(); setEvent('Prevented: Inbox');}
                  else setEvent(`Tab pressed: ${name}`);
                }}} />)}
          </Tab.Navigator>
        </NavigationContainer>
      </NavigationIndependentTree>
    </Settings.Provider>
  </SafeAreaView>;
}
const styles = StyleSheet.create({
  screen: {padding: 24, gap: 12}, title: {fontSize: 26, fontWeight: '700'},
  row: {minHeight: 46, flexDirection: 'row', alignItems: 'center', gap: 12},
  action: {paddingVertical: 12}, close: {paddingHorizontal: 24, paddingVertical: 12},
});
