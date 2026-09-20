import React from 'react';
import {View} from 'react-native';
import type {BottomTabBarProps} from '@react-navigation/bottom-tabs';
import {GlassTabBar, type GlassTabIcon, type GlassTabItem} from '@likith99/react-native-adaptive-liquid-glass';

type Props = BottomTabBarProps & {disabled?: boolean; disabledRoutes?: readonly string[]; reversed?: boolean};
const icons: Record<string, GlassTabIcon> = {Home: 'home', Library: 'library', Search: 'search', Inbox: 'inbox', Settings: 'settings'};

/** Example adapter: route keys are native IDs; React Navigation remains authoritative. */
export default function NativeNavigationTabBar({state, descriptors, navigation, insets,
  disabled, disabledRoutes = [], reversed = false}: Props) {
  const routes = reversed ? [...state.routes].reverse() : state.routes;
  const items: GlassTabItem[] = routes.map(route => {
    const options = descriptors[route.key].options;
    const badge = options.tabBarBadge;
    return {id: route.key, title: typeof options.tabBarLabel === 'string' ? options.tabBarLabel : options.title ?? route.name,
      accessibilityLabel: options.tabBarAccessibilityLabel ?? `${route.name} tab`, icon: icons[route.name],
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
  return <View style={{paddingBottom: insets.bottom, paddingLeft: insets.left, paddingRight: insets.right}}>
    <GlassTabBar testID="navigation-tabs" items={items} value={state.routes[state.index]?.key ?? null}
      disabled={disabled} onValueChange={press} onTabReselect={press} />
  </View>;
}
