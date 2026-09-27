import React from 'react';
import {AccessibilityInfo, PlatformColor, StyleSheet, Text, View} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import GlassView from '../../packages/liquid-glass/src/GlassView.ios';
import GlassTabBar from '../../packages/liquid-glass/src/GlassTabBar';
import NativeSurface from '../../packages/liquid-glass/src/specs/ALGSurfaceNativeComponent';
import NativeTabs from '../../packages/liquid-glass/src/specs/ALGTabsNativeComponent';
import Fallback from '../../packages/liquid-glass/src/fallback/GlassView';
import NativeGlassButton from '../../packages/liquid-glass/src/fallback/NativeGlassButton';
import {GlassFallbackThemeProvider} from '../../packages/liquid-glass/src/fallbackTheme';
import {useGlassTier, type GlassTier} from '../../packages/liquid-glass/src/glassTier';
import {staticColor, validateTabs} from '../../packages/liquid-glass/src/validateTabs';

let mockGlassSupported = false;
jest.mock('../../packages/liquid-glass/src/support', () => ({isLiquidGlassSupported: () => mockGlassSupported}));
afterEach(() => { mockGlassSupported = false; jest.restoreAllMocks(); });

const noop = () => {};
const background = (tree: Renderer.ReactTestRenderer, type: React.ElementType) =>
  StyleSheet.flatten(tree.root.findByType(type as never).findByType(View).props.style).backgroundColor;

function TierProbe({onTier}: {onTier: (tier: GlassTier) => void}) {
  onTier(useGlassTier());
  return null;
}

test('useGlassTier follows the OS tier and Reduce Transparency live', async () => {
  let listener: ((enabled: boolean) => void) | undefined;
  jest.spyOn(AccessibilityInfo, 'isReduceTransparencyEnabled').mockResolvedValue(false);
  jest.spyOn(AccessibilityInfo, 'addEventListener').mockImplementation(((_event: string, handler: (enabled: boolean) => void) => {
    listener = handler;
    return {remove: noop};
  }) as never);
  const tiers: GlassTier[] = [];
  let tree!: Renderer.ReactTestRenderer;
  await act(async () => {tree = Renderer.create(<TierProbe onTier={tier => tiers.push(tier)} />);});
  expect(tiers.at(-1)).toBe('blur');
  await act(async () => listener?.(true));
  expect(tiers.at(-1)).toBe('solid');
  mockGlassSupported = true;
  await act(async () => listener?.(false));
  expect(tiers.at(-1)).toBe('glass');
  act(() => tree.unmount());
});

test('fallbackMaterial="solid" uses the opaque surface below iOS 26 only', () => {
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassView fallbackMaterial="solid"><Text>Row</Text></GlassView>);});
  expect(tree.root.findAllByType(Fallback)).toHaveLength(1);
  expect(tree.root.findAllByType(NativeSurface)).toHaveLength(0);
  mockGlassSupported = true;
  act(() => tree.update(<GlassView fallbackMaterial="solid"><Text>Row</Text></GlassView>));
  expect(tree.root.findAllByType(NativeSurface)).toHaveLength(1);
  act(() => tree.unmount());
});

test('fallback colours keep their defaults and follow a theme provider', () => {
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<Fallback colorScheme="dark" />);});
  expect(background(tree, Fallback)).toBe('#25272D');
  const theme = {surface: {light: '#FFFFFF', dark: '#101820'}, foreground: {light: '#000000', dark: '#FAFAFA'}};
  act(() => tree.update(<GlassFallbackThemeProvider value={theme}><Fallback colorScheme="dark" /></GlassFallbackThemeProvider>));
  expect(background(tree, Fallback)).toBe('#101820');
  act(() => tree.update(<GlassFallbackThemeProvider value={theme}>
    <NativeGlassButton title="Save" onPress={noop} colorScheme="light" /></GlassFallbackThemeProvider>));
  expect(StyleSheet.flatten(tree.root.findByType(Text).props.style).color).toBe('#000000');
  act(() => tree.unmount());
});

test('tab artwork and per-tab colours are serialized as static ARGB values', () => {
  let tree!: Renderer.ReactTestRenderer;
  const items = [{id: 'home', title: 'Home', image: 'BrandSpark', selectedTintColor: '#FF0000', inactiveTintColor: 'gray'},
    {id: 'inbox', title: 'Inbox'}];
  act(() => {tree = Renderer.create(<GlassTabBar items={items} value="home" onValueChange={noop} />);});
  const [home, inbox] = JSON.parse(tree.root.findByType(NativeTabs as never).props.itemsJSON);
  expect(home.image).toBe('BrandSpark');
  expect(typeof home.selectedTint).toBe('number');
  expect(typeof home.inactiveTint).toBe('number');
  expect(home.selectedTintColor).toBeUndefined();
  expect(inbox.selectedTint).toBeUndefined();
  act(() => tree.unmount());
  expect(() => validateTabs([{id: 'home', title: 'Home', selectedTintColor: PlatformColor('systemBlue')}], 'home'))
    .toThrow('static colour');
  expect(staticColor('#00000080', 'inactiveTintColor')).toBe(0x80000000);
});
