import React from 'react';
import {View, useColorScheme} from 'react-native';
import type {BottomTabBarProps} from '@react-navigation/bottom-tabs';
import {GlassTabBar, type GlassTabIcon, type GlassTabItem} from '@likith99/react-native-adaptive-liquid-glass';

type Props = BottomTabBarProps & {disabled?: boolean; disabledRoutes?: readonly string[]; reversed?: boolean;
  brandColors?: boolean; toBottomEdge?: boolean};
const icons: Record<string, GlassTabIcon> = {Home: 'home', Library: 'library', Search: 'search', Inbox: 'inbox', Settings: 'settings'};
// Per-tab colours, a bar-wide inactive colour, an asset-catalog image (Settings) and bundled
// image sources (Library), shown with the demo's brand-colours switch.
const brand: Record<string, string> = {Home: '#F57C00', Library: '#2E7D32', Search: '#6A1B9A', Inbox: '#1565C0', Settings: '#C62828'};
const selectedSymbols: Record<string, string> = {Home: 'house.circle.fill', Library: 'books.vertical.fill',
  Inbox: 'tray.fill', Settings: 'gearshape.fill'};

/** Example adapter: route keys are native IDs; React Navigation remains authoritative. */
export default function NativeNavigationTabBar({state, descriptors, navigation, insets,
  disabled, disabledRoutes = [], reversed = false, brandColors = false, toBottomEdge = false}: Props) {
  const dark = useColorScheme() === 'dark';
  const routes = reversed ? [...state.routes].reverse() : state.routes;
  const items: GlassTabItem[] = routes.map(route => {
    const options = descriptors[route.key].options;
    const badge = options.tabBarBadge;
    return {id: route.key, title: typeof options.tabBarLabel === 'string' ? options.tabBarLabel : options.title ?? route.name,
      accessibilityLabel: options.tabBarAccessibilityLabel ?? `${route.name} tab`, icon: icons[route.name], selectedSystemImage: selectedSymbols[route.name],
      ...(brandColors ? {selectedTintColor: brand[route.name],
        ...(route.name === 'Settings' ? {image: 'BrandSpark'} : {}),
        ...(route.name === 'Library' ? {image: require('../assets/tab-diamond.png'),
          selectedImage: require('../assets/tab-diamond-filled.png')} : {})} : {}),
      disabled: disabledRoutes.includes(route.name), badge: typeof badge === 'number' ? badge : badge ? 'dot' : undefined};
  });
  const press = (id: string) => {
    const route = state.routes.find(candidate => candidate.key === id);
    if (!route) return;
    const event = navigation.emit({type: 'tabPress', target: route.key, canPreventDefault: true});
    if (!event.defaultPrevented && route.key !== state.routes[state.index]?.key) {
      navigation.navigate(route.name, route.params);
    }
  };
  // Insets live outside the native host, preventing Material/UIKit double padding.
  // toBottomEdge: the host reaches the screen edge and UIKit places the bar within the bottom inset.
  return <View style={{paddingBottom: toBottomEdge ? 0 : insets.bottom, paddingLeft: insets.left, paddingRight: insets.right}}>
    <GlassTabBar testID="navigation-tabs" style={toBottomEdge ? {height: 80 + insets.bottom} : undefined} items={items} value={state.routes[state.index]?.key ?? null}
      disabled={disabled} onValueChange={press} onTabReselect={press}
      {...(brandColors ? {inactiveTintColor: '#8A8F98',
        androidBackgroundColor: dark ? '#1E1B16' : '#F4F1EA', androidIndicatorColor: dark ? '#3A3428' : '#E3DCCB'} : {})} />
  </View>;
}
