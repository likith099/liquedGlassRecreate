import React from 'react';
import {Text, View} from 'react-native';
import Renderer, {act} from 'react-test-renderer';
import GlassActionCluster from '../../packages/liquid-glass/src/fallback/GlassActionCluster';
import GlassButton from '../../packages/liquid-glass/src/GlassButton';
import GlassView from '../../packages/liquid-glass/src/fallback/GlassView';
import {validateActions} from '../../packages/liquid-glass/src/validateActions';

const actions = [{id: 'save', title: 'Save'}, {id: 'delete', title: 'Delete', disabled: true}];

test('standard platform actions deliver IDs and expose disabled semantics', () => {
  const onAction = jest.fn();
  const onExpandedChange = jest.fn();
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassActionCluster actions={actions} expanded
    onAction={onAction} onExpandedChange={onExpandedChange} />);});
  const buttons = tree.root.findAllByType(GlassButton);
  act(() => buttons[0].props.onPress());
  expect(onAction).toHaveBeenCalledWith('save');
  expect(buttons[1].props.disabled).toBe(true);
  expect(tree.root.findAll(node => node.props.accessibilityState?.disabled === true).length).toBeGreaterThan(0);
  act(() => buttons[2].props.onPress());
  expect(onExpandedChange).toHaveBeenCalledWith(false);
  act(() => tree.update(<GlassActionCluster actions={actions} expanded={false}
    onAction={onAction} onExpandedChange={onExpandedChange} />));
  expect(tree.root.findAllByType(GlassButton)).toHaveLength(1);
  act(() => tree.unmount());
});

test('fallback retains React children and strips native-only props', () => {
  let tree!: Renderer.ReactTestRenderer;
  act(() => {tree = Renderer.create(<GlassView interactive material="clear" cornerRadius={18}>
    <Text>Child</Text></GlassView>);});
  expect(tree.root.findByType(Text).props.children).toBe('Child');
  const props = tree.root.findByType(View).props;
  expect(props.interactive).toBeUndefined();
  expect(props.material).toBeUndefined();
  act(() => tree.unmount());
});

test('rejects ambiguous SwiftUI morphing identities before crossing the native bridge', () => {
  expect(() => validateActions([{id: 'save', title: 'A'}, {id: 'save', title: 'B'}])).toThrow('unique');
  expect(() => validateActions([{id: '__toggle', title: 'A'}])).toThrow('reserved');
  expect(() => validateActions([{id: '', title: 'A'}])).toThrow('nonempty');
  expect(() => validateActions(actions)).not.toThrow();
});
