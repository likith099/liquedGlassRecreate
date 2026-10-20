import React, {createContext, useContext, useId, useLayoutEffect, useMemo, useRef, useState} from 'react';
import {View, useWindowDimensions, type ViewProps} from 'react-native';
import NativeControl from './NativeControl';
import {controlItems, controlAction} from './controlConfig';
import {GlassMetrics} from './GlassMetrics';
import type {GlassControlItem, GlassMorphContent, GlassViewProps} from './types';
export type GlassHeaderItem = GlassMorphContent & {slot?: string; onPress?: () => void; disabled?: boolean; testID?: string};
export interface GlassHeaderOptions {
  /** Use the navigator's route.key. Omit only for a single mounted screen. */
  routeKey?: string;
  /** Pass the navigator's focus state; background screen renders must not activate their header. */
  active?: boolean;
  leading?: readonly GlassHeaderItem[];
  trailing?: readonly GlassHeaderItem[];
}
export interface GlassHeaderHostProps extends ViewProps {
  children: React.ReactNode;
  /** Safe-area top inset supplied by the application. */
  topInset?: number;
  colorScheme?: GlassViewProps['colorScheme'];
}
type Registration = {token: string; options: GlassHeaderOptions};
type Registry = {set: (token: string, options: GlassHeaderOptions | null) => void};
const Context = createContext<Registry | null>(null);
/** Persistent native controls above a stack. Register each screen with its route key and focus state. */
export function GlassHeaderHost({children, topInset = 0, colorScheme = 'system', style, ...props}: GlassHeaderHostProps) {
  const {width} = useWindowDimensions();
  const [registrations, setRegistrations] = useState<Registration[]>([]);
  const registry = useMemo<Registry>(() => ({set(token, options) {
    setRegistrations(current => {
      if (!options) return current.filter(entry => entry.token !== token);
      const index = current.findIndex(entry => entry.token === token);
      if (index < 0) return [...current, {token, options}];
      const next = [...current]; next[index] = {token, options}; return next;
    });
  }}), []);
  const active = registrations.filter(entry => entry.options.active !== false).at(-1);
  // Every registered screen's items are sent at once. On iOS the native host picks the
  // incoming screen's set inside the stack's transition (route key = screenId), so an
  // interactive swipe back scrubs the morph without JavaScript.
  const controls: GlassControlItem[] = [];
  const handlers = new Map<string, (() => void) | undefined>();
  const itemsFor = (entry: Registration) => (['leading', 'trailing'] as const).flatMap(side => (entry.options[side] ?? []).map((item, index) => {
    const slot = `${side}:${item.slot ?? index}`;
    const control: GlassControlItem = {...item, id: `${routeOf(entry)}\u0001${slot}`,
      ...(item.kind === 'back' ? {symbol: {name: 'chevron.backward', weight: 'semibold' as const, pointSize: GlassMetrics.symbol.backPointSize, scale: 'large' as const}, androidIcon: 'alg_back'} : {})};
    controls.push(control); handlers.set(control.id, item.onPress);
    return {...controlItems([control])[0], side, slot, title: item.kind === 'title' ? item.title : undefined};
  }));
  const routes = registrations.map(entry => ({key: routeOf(entry), items: itemsFor(entry)}));
  const activeKey = active ? routeOf(active) : undefined;
  const items = routes.find(route => route.key === activeKey)?.items ?? [];
  return <Context.Provider value={registry}><View {...props} style={[{flex: 1}, style]}>{children}
    <NativeControl minimumHeight={44} pointerEvents="box-none" style={{position: 'absolute', left: 0, right: 0, top: topInset, width: '100%', height: 44}}
      configJSON={JSON.stringify({mode: 'header', items, routes, active: activeKey, height: 44, contentInset: GlassMetrics.pageMargin(width), colorScheme})}
      onControlAction={({nativeEvent: {id, action}}) => controlAction(controls, id, action, chosen => handlers.get(chosen)?.())} />
  </View></Context.Provider>;
}
/** Route key used for native matching: the navigator's route.key, or a per-hook token. */
function routeOf(entry: Registration) { return entry.options.routeKey ?? entry.token; }
export function useGlassHeader(options: GlassHeaderOptions) {
  const registry = useContext(Context);
  if (!registry) throw new Error('useGlassHeader must be used inside GlassHeaderHost.');
  const token = useId();
  const latest = useRef(options); latest.current = options;
  // A screen update changes the registry once; provider renders do not repeat registration.
  useLayoutEffect(() => { registry.set(token, latest.current); }, [registry, token, options.routeKey, options.active, options.leading, options.trailing]);
  useLayoutEffect(() => () => registry.set(token, null), [registry, token]);
}
