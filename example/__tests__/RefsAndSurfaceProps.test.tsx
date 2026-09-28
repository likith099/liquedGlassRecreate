import React from 'react';
import {Text} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import {
  GlassActionCluster, GlassButton, GlassContainer, GlassContextMenu, GlassIconButton, GlassMenuButton, GlassPressable,
  GlassSegmentedControl, GlassSlider, GlassTabBar, GlassToolbar, GlassView, type GlassHostRef,
  type GlassMenuHandle,
} from '../../packages/liquid-glass/src';
import NativeMenu from '../../packages/liquid-glass/src/specs/ALGMenuNativeComponent';
import GlassViewGeneric from '../../packages/liquid-glass/src/GlassView.tsx';
import GlassContainerGeneric from '../../packages/liquid-glass/src/GlassContainer.tsx';
import GlassButtonGeneric from '../../packages/liquid-glass/src/GlassButton.tsx';
import GlassSegmentedGeneric from '../../packages/liquid-glass/src/GlassSegmentedControl.tsx';
import GlassActionClusterGeneric from '../../packages/liquid-glass/src/GlassActionCluster.tsx';

const noop = () => {};
const menu = [{id: 'rename', title: 'Rename'}];
const options = [{value: 'a', label: 'A'}, {value: 'b', label: 'B'}];
const actions = [{id: 'save', title: 'Save'}];
const tabs = [{id: 'home', title: 'Home'}, {id: 'inbox', title: 'Inbox'}];

type Case = [string, (ref: React.RefObject<GlassHostRef | null>) => React.ReactElement];
const cases: Case[] = [
  ['GlassView', ref => <GlassView ref={ref} />],
  ['GlassView forceFallback', ref => <GlassView ref={ref} forceFallback />],
  ['GlassView generic', ref => <GlassViewGeneric ref={ref} />],
  ['GlassContainer', ref => <GlassContainer ref={ref} mergingEnabled={false} />],
  ['GlassContainer forceFallback', ref => <GlassContainer ref={ref} forceFallback />],
  ['GlassContainer generic', ref => <GlassContainerGeneric ref={ref} />],
  ['GlassPressable', ref => <GlassPressable ref={ref}><Text>Tap</Text></GlassPressable>],
  ['GlassButton', ref => <GlassButton ref={ref} title="Save" onPress={noop} />],
  ['GlassButton forceFallback', ref => <GlassButton ref={ref} title="Save" onPress={noop} forceFallback />],
  ['GlassButton generic', ref => <GlassButtonGeneric ref={ref} title="Save" onPress={noop} />],
  ['GlassSegmentedControl', ref => <GlassSegmentedControl ref={ref} options={options} value="a" onValueChange={noop} />],
  ['GlassSegmentedControl generic', ref =>
    <GlassSegmentedGeneric ref={ref} options={options} value="a" onValueChange={noop} />],
  ['GlassSlider', ref => <GlassSlider ref={ref} value={0.5} onValueChange={noop} />],
  ['GlassActionCluster', ref => <GlassActionCluster ref={ref} actions={actions} expanded={false}
    onAction={noop} onExpandedChange={noop} />],
  ['GlassActionCluster generic', ref => <GlassActionClusterGeneric ref={ref} actions={actions} expanded={false}
    onAction={noop} onExpandedChange={noop} />],
  ['GlassToolbar', ref => <GlassToolbar ref={ref} items={menu} onAction={noop} />],
  ['GlassContextMenu', ref => <GlassContextMenu ref={ref} items={menu} onAction={noop}><Text>Message</Text></GlassContextMenu>],
  ['GlassTabBar', ref => <GlassTabBar ref={ref} items={tabs} value="home" onValueChange={noop} />],
];

test.each(cases)('%s forwards its ref to a host view', (_name, render) => {
  const ref = React.createRef<GlassHostRef>();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(render(ref), {createNodeMock: () => ({measure: noop})});});
  expect(ref.current).not.toBeNull();
  act(() => tree.unmount());
  expect(ref.current).toBeNull();
});

test('GlassPressable forwards interactive and colorScheme, and disabled always wins', () => {
  let tree!: Renderer.ReactTestRenderer;
  const surface = () => tree.root.findByType(GlassView).props;
  act(() => {tree = Renderer.create(<GlassPressable colorScheme="dark"><Text>Card</Text></GlassPressable>);});
  expect(surface().interactive).toBe(true);
  expect(surface().colorScheme).toBe('dark');
  act(() => tree.update(<GlassPressable interactive={false}><Text>Card</Text></GlassPressable>));
  expect(surface().interactive).toBe(false);
  act(() => tree.update(<GlassPressable interactive disabled><Text>Card</Text></GlassPressable>));
  expect(surface().interactive).toBe(false);
  act(() => tree.unmount());
});

test('GlassContainer warns once in development when spacing is passed without mergingEnabled', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(noop);
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassContainer spacing={20} mergingEnabled />);});
  expect(warn).not.toHaveBeenCalled();
  act(() => tree.update(<GlassContainer spacing={20} />));
  act(() => tree.update(<GlassContainer spacing={24} />));
  expect(warn).toHaveBeenCalledTimes(1);
  expect(warn.mock.calls[0][0]).toContain('mergingEnabled');
  act(() => tree.unmount());
  warn.mockRestore();
});

test.each([
  ['GlassMenuButton', (ref: React.Ref<GlassMenuHandle>) => <GlassMenuButton ref={ref} title="More" items={menu} onAction={noop} />],
  ['GlassIconButton', (ref: React.Ref<GlassMenuHandle>) =>
    <GlassIconButton ref={ref} systemImage="ellipsis" accessibilityLabel="More" menu={{items: menu, onAction: noop}} />],
] as const)('%s ref exposes open() and host measurement', (_name, render) => {
  const ref = React.createRef<GlassMenuHandle>();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(render(ref));});
  expect(typeof ref.current?.open).toBe('function');
  // The Jest preset mocks native components; the handle must delegate to that host instance.
  const instance = tree.root.findByType(NativeMenu as never).instance;
  instance.measure = jest.fn();
  ref.current?.measure(noop);
  expect(instance.measure).toHaveBeenCalledTimes(1);
  act(() => tree.unmount());
});
