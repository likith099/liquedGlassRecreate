import React from 'react';
import {Modal, Platform, Text} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import GlassMenuPanel from '../../packages/liquid-glass/src/GlassMenuPanel';
import GlassLongPress from '../../packages/liquid-glass/src/GlassLongPress';
import GlassContextMenu from '../../packages/liquid-glass/src/GlassContextMenu';
import computeFocusMenuLayout from '../../packages/liquid-glass/src/focusMenuLayout';
import * as NativeMenuSpec from '../../packages/liquid-glass/src/specs/ALGMenuNativeComponent';
import type {FocusMenuLayoutInput, GlassMenuElement, GlassMenuPanelHandle} from '../../packages/liquid-glass/src/types';

const noop = () => {};
const five: GlassMenuElement[] = [
  {id: 'forward', title: 'Forward', systemImage: 'arrowshape.turn.up.right'},
  {id: 'copy', title: 'Copy'},
  {id: 'star', title: 'Star'},
  {kind: 'section', id: 'manage', title: '', items: [
    {id: 'select', title: 'Select more'},
    {id: 'delete', title: 'Delete', destructive: true},
  ]},
];
const host = (tree: Renderer.ReactTestRenderer) => tree.root.findByType(NativeMenuSpec.default as never);
function withIOSVersion(version: string, run: () => void) {
  const original = Platform.Version;
  Object.defineProperty(Platform, 'Version', {value: version, configurable: true});
  try { run(); } finally { Object.defineProperty(Platform, 'Version', {value: original, configurable: true}); }
}

describe('GlassMenuPanel.measure: the size of Apple\'s menu before it opens (measured on iOS 26.5)', () => {
  test('rows, untitled and titled sections at the default and Medium text sizes', () => {
    expect(Platform.OS).toBe('ios');
    // 10 + 10 padding, five 42-point rows, one 21-point separator.
    expect(GlassMenuPanel.measure(five, {fontScale: 1})).toEqual({width: 250, height: 251});
    // Medium: 40-point rows.
    expect(GlassMenuPanel.measure(five, {fontScale: 0.941})).toEqual({width: 250, height: 241});
    const titled: GlassMenuElement[] = [...five.slice(0, 3), {kind: 'section', id: 'manage', title: 'Manage',
      items: [{id: 'select', title: 'Select more'}, {id: 'delete', title: 'Delete'}]}];
    expect(GlassMenuPanel.measure(titled, {fontScale: 1}).height).toBeCloseTo(20 + 5 * 42 + 49.333, 2);
  });
  test('accessibility sizes widen the menu; maxHeight caps it; nearest measured size wins', () => {
    expect(GlassMenuPanel.measure(five, {fontScale: 2.143})).toEqual({width: 400, height: 20 + 5 * 80 + 21});
    expect(GlassMenuPanel.measure(five, {fontScale: 1, maxHeight: 200}).height).toBe(200);
    expect(GlassMenuPanel.measure(five, {fontScale: 1.02})).toEqual(GlassMenuPanel.measure(five, {fontScale: 1}));
    // Trailing and leading separators are not drawn.
    expect(GlassMenuPanel.measure([{kind: 'section', id: 's', title: '', items: [{id: 'a', title: 'A'}]}], {fontScale: 1}).height).toBe(62);
  });
});

describe('computeFocusMenuLayout: the R2.5 test vectors', () => {
  const phone = {window: {width: 440, height: 956}, insets: {left: 0, right: 0, bottom: 36}, topLimit: 117, menuHeight: 294};
  const layout = (bubble: [number, number, number, number], isOwn: boolean, extra: Partial<FocusMenuLayoutInput> = {}) =>
    computeFocusMenuLayout({...phone, bubble: {x: bubble[0], y: bubble[1], width: bubble[2], height: bubble[3]}, isOwn, ...extra});
  test.each([
    ['001 received, near bottom', [17, 807, 200, 45], false, 571, {x: 17, y: 626, width: 248, height: 294}],
    ['004 sent, near bottom', [250, 718, 175, 94], true, 522, {x: 177, y: 626, width: 248, height: 294}],
    ['002 received, middle', [17, 394, 220, 43], false, 394, {x: 17, y: 447, width: 248, height: 294}],
    ['003 received, near top', [17, 146, 300, 67], false, 146, {x: 17, y: 223, width: 248, height: 294}],
    ['005 sent, partly under header', [200, 72, 225, 95], true, 129, {x: 177, y: 234, width: 248, height: 294}],
    ['E partly behind the composer', [17, 880, 200, 40], false, 576, {x: 17, y: 626, width: 248, height: 294}],
    ['F too tall', [17, 200, 300, 600], false, 16, {x: 17, y: 626, width: 248, height: 294}],
  ] as const)('%s', (_name, bubble, isOwn, messageY, menu) => {
    const result = layout(bubble as unknown as [number, number, number, number], isOwn);
    expect(result.bubble.y).toBe(messageY);
    expect(result.bubble.x).toBe(bubble[0]);
    expect(result.menu).toEqual(menu);
    expect(result.clipTop).toBe(117);
  });
  test('a menu taller than the space is capped at the top limit', () => {
    const result = layout([17, 500, 200, 40], false, {menuHeight: 900});
    expect(result.menu.y).toBe(129);
    expect(result.menu.height).toBe(791);
  });
  test('the left edge is clamped inside the safe area', () => {
    expect(layout([2, 400, 200, 40], false).menu.x).toBe(8);
  });
  test('landscape: a sent message hugs the right safe edge', () => {
    const result = computeFocusMenuLayout({bubble: {x: 700, y: 150, width: 194, height: 40}, isOwn: true,
      window: {width: 956, height: 440}, insets: {left: 62, right: 62, bottom: 21}, topLimit: 80, menuHeight: 150});
    expect(result.menu.x).toBe(956 - 62 - 8 - 248);
  });
  test('invariant: the menu is 10 points below the message and inside the limits, anywhere on screen', () => {
    for (const isOwn of [false, true]) {
      for (let y = -200; y <= 1100; y += 7) {
        const result = layout([isOwn ? 250 : 17, y, 175, 45], isOwn);
        expect(result.menu.y).toBe(result.bubble.y + 45 + 10);
        expect(result.bubble.y).toBeGreaterThanOrEqual(129);
        expect(result.menu.y + result.menu.height).toBeLessThanOrEqual(920);
      }
    }
  });
});

describe('GlassMenuPanel: an invisible native anchor for Apple\'s menu', () => {
  test('iOS 17.4+: the anchor is the native menu host; open() presents it; only enabled items act', () => {
    withIOSVersion('26.5', () => {
      const open = jest.spyOn(NativeMenuSpec.Commands, 'open').mockImplementation(noop);
      const onAction = jest.fn();
      const ref = React.createRef<GlassMenuPanelHandle>();
      const items: GlassMenuElement[] = [...five, {id: 'locked', title: 'Locked', disabled: true}];
      let tree!: Renderer.ReactTestRenderer;
      act(() => {tree = Renderer.create(<GlassMenuPanel ref={ref} testID="panel" items={items} onAction={onAction}
        style={{position: 'absolute', top: 626, left: 17, width: 250, height: 251}} />);});
      const native = host(tree);
      expect(native.props).toMatchObject({menuAnchor: true, pointerEvents: 'none', accessible: false, title: '',
        controlTestID: 'panel', disabled: false});
      expect(JSON.parse(native.props.itemsJSON)).toEqual(items);
      expect(native.props.style).toEqual([{minWidth: 1, minHeight: 1}, {position: 'absolute', top: 626, left: 17, width: 250, height: 251}]);
      act(() => ref.current?.open());
      expect(open).toHaveBeenCalledTimes(1);
      expect(open.mock.calls[0][0]).toBe(native.instance);
      for (const id of ['copy', 'locked', 'manage', 'unknown', 'delete']) act(() => native.props.onMenuAction({nativeEvent: {id}}));
      expect(onAction.mock.calls).toEqual([['copy'], ['delete']]);
      act(() => tree.update(<GlassMenuPanel items={items} onAction={onAction} disabled />));
      expect(host(tree).props.disabled).toBe(true);
      act(() => host(tree).props.onMenuAction({nativeEvent: {id: 'copy'}}));
      expect(onAction).toHaveBeenCalledTimes(2);
      act(() => tree.unmount());
      open.mockRestore();
    });
  });
  test('before iOS 17.4, open() shows the plain fallback menu over the anchor', () => {
    withIOSVersion('17.0', () => {
      const onAction = jest.fn();
      const ref = React.createRef<GlassMenuPanelHandle>();
      let tree!: Renderer.ReactTestRenderer;
      act(() => {tree = Renderer.create(<GlassMenuPanel ref={ref} testID="panel" items={five} onAction={onAction}
        style={{position: 'absolute', top: 300, left: 20, width: 250, height: 251}} />);});
      // The anchor measures itself in the window; the test renderer has no layout, so give it one.
      const anchor = tree.root.findAll(node => node.props.testID === 'panel' && node.instance?.measureInWindow)[0];
      anchor.instance.measureInWindow = (callback: (x: number, y: number, w: number, h: number) => void) => callback(20, 300, 250, 251);
      expect(tree.root.findAllByType(NativeMenuSpec.default as never)).toHaveLength(0);
      expect(tree.root.findByType(Modal).props.visible).toBe(false);
      act(() => ref.current?.open());
      expect(tree.root.findByType(Modal).props.visible).toBe(true);
      const copy = tree.root.findAll(node => node.props.accessibilityLabel === 'Copy' && !!node.props.onPress)[0];
      act(() => copy.props.onPress());
      expect(onAction.mock.calls).toEqual([['copy']]);
      expect(tree.root.findByType(Modal).props.visible).toBe(false);
      act(() => tree.unmount());
    });
  });
  test('rejects invalid items', () => {
    const error = jest.spyOn(console, 'error').mockImplementation(noop);
    expect(() => act(() => { Renderer.create(<GlassMenuPanel items={[{id: 'a', title: ''}]} onAction={noop} />); })).toThrow();
    error.mockRestore();
  });
});

test('GlassContextMenu passes menuPlacement (default "system"), per-corner radii and open/close events', () => {
  const onOpen = jest.fn(); const onClose = jest.fn(); let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassContextMenu items={[{id: 'a', title: 'A'}]} onAction={noop}><Text>Bubble</Text></GlassContextMenu>);});
  expect(host(tree).props.menuPlacement).toBe('system');
  act(() => tree.update(<GlassContextMenu items={[{id: 'a', title: 'A'}]} onAction={noop} menuPlacement="below"
    onOpen={onOpen} onClose={onClose} previewCornerRadii={{topLeft: 18, bottomRight: 4}}><Text>Bubble</Text></GlassContextMenu>));
  expect(host(tree).props).toMatchObject({menuPlacement: 'below', previewCornerTopLeft: 18, previewCornerTopRight: -1,
    previewCornerBottomLeft: -1, previewCornerBottomRight: 4});
  act(() => host(tree).props.onMenuOpen()); act(() => host(tree).props.onMenuClose());
  expect([onOpen.mock.calls.length, onClose.mock.calls.length]).toEqual([1, 1]);
  act(() => tree.unmount());
});

test('GlassLongPress passes its options and reports the native frame', () => {
  const onLongPress = jest.fn(); let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassLongPress minimumDuration={350.4} haptic="medium" onLongPress={onLongPress}>
    <Text>Message</Text></GlassLongPress>);});
  const native = tree.root.findAll(node => node.props.minimumDuration !== undefined && typeof node.type === 'string')[0];
  expect(native.props).toMatchObject({minimumDuration: 350, allowableMovement: 10, disabled: false, haptic: 'medium'});
  act(() => native.props.onLongPress({nativeEvent: {x: 1, y: 2, width: 3, height: 4}}));
  expect(onLongPress).toHaveBeenCalledWith({frame: {x: 1, y: 2, width: 3, height: 4}});
  act(() => tree.unmount());
  const error = jest.spyOn(console, 'error').mockImplementation(noop);
  expect(() => act(() => { Renderer.create(<GlassLongPress minimumDuration={-1} />); })).toThrow('minimumDuration');
  error.mockRestore();
});
