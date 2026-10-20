import React, {useRef, useState} from 'react';
import {FlatList, Pressable, Text, View, useColorScheme} from 'react-native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
import {GlassNavigationView, type GlassNavigationHandle} from '@likith99/react-native-adaptive-liquid-glass';
import ProgressiveBlurDemo from './ProgressiveBlurDemo';
import HeaderReviewDemo from './HeaderReviewDemo';
const people = ['Maya Chen', 'Noah Williams', 'Amara Patel', 'Leo Martin', 'Sofia Garcia', 'Ethan Park', 'Ava Wilson', 'Oliver Brown', 'Isla Ahmed', 'Lucas Kim', 'Mia Taylor', 'Elijah Davis', 'Zoe Harris', 'Arjun Shah', 'Nora Jones', 'Theo Clark', 'Lily Moore', 'Mateo Rivera', 'Ella Lewis', 'Finn Walker'];
export default function ScrollHeaderDemo({onClose}: {onClose: () => void}) {
  const list = useRef<FlatList<string>>(null);
  const navigation = useRef<GlassNavigationHandle>(null);
  const insets = useSafeAreaInsets(), dark = useColorScheme() === 'dark';
  const [query, setQuery] = useState(''), [added, setAdded] = useState(0), [status, setStatus] = useState('All contacts');
  const [inline, setInline] = useState(false), [showSearch, setShowSearch] = useState(false), [standalone, setStandalone] = useState(false);
  const [review, setReview] = useState(false);
  const ink = dark ? '#F5F5F9' : '#18202D';
  if (review) return <HeaderReviewDemo onClose={() => setReview(false)} />;
  if (standalone) return <ProgressiveBlurDemo onClose={() => setStandalone(false)} />;
  const action = (id: string) => {
    if (id === 'add') setAdded(n => n + 1);
    else if (id === 'search') setShowSearch(v => !v);
    else if (id === 'top') { navigation.current?.scrollToTop(); setStatus('Back at top'); }
    else if (id === 'review') setReview(true);
    else if (id === 'blur') setStandalone(true);
  };
  return <GlassNavigationView ref={navigation} testID="navigation-demo" title="Contacts" titleDisplayMode={inline ? 'inline' : 'large'}
    subtitle={added ? `${people.length + added} contacts` : undefined} scrollViewRef={list}
    onBack={onClose} handlesSystemBack topInset={insets.top} bottomInset={insets.bottom} onAction={action}
    leadingItems={[{id: 'search', symbol: 'magnifyingglass', androidIcon: 'alg_tab_search', accessibilityLabel: 'Toggle search', testID: 'nav-search-toggle'}]}
    trailingItems={[
      {id: 'more', symbol: 'ellipsis', androidIcon: 'demo_more', accessibilityLabel: 'More options', testID: 'nav-more', badge: {count: 5}, menu: {
        items: [{id: 'title-mode', title: inline ? 'Use large title' : 'Use compact title'}, {id: 'mark', title: 'Mark all read'}, {id: 'disabled', title: 'Unavailable action', disabled: true}],
        onAction: id => id === 'title-mode' ? setInline(v => !v) : setStatus('All marked read')}},
      {id: 'add', symbol: 'plus', androidIcon: 'demo_add', accessibilityLabel: 'Add contact', testID: 'nav-add'}]}
    toolbarItems={[{id: 'top', title: 'Top', accessibilityLabel: 'Scroll to top', testID: 'nav-top'},
      {id: 'review', title: 'Review', accessibilityLabel: 'Header features', testID: 'nav-review'},
      {id: 'blur', title: 'Blur only', accessibilityLabel: 'Open standalone blur', testID: 'nav-blur-only'}]}
    search={showSearch ? {value: query, onChangeText: setQuery, placeholder: 'Find contacts', cancelLabel: 'Cancel', hidesWhenScrolling: false} : undefined}>
    <FlatList nestedScrollEnabled ref={list} testID="navigation-contacts" style={{flex: 1}} contentInsetAdjustmentBehavior="automatic"
      keyboardShouldPersistTaps="handled" data={people.filter(name => name.toLowerCase().includes(query.toLowerCase()))} keyExtractor={name => name}
      ListHeaderComponent={<Text testID="nav-status" style={{paddingHorizontal: 20, paddingVertical: 8, color: ink}}>{status} · {people.length + added}</Text>}
      renderItem={({item, index}) => <Pressable accessibilityRole="button" accessibilityLabel={item} onPress={() => setStatus(`Selected ${item}`)}
        style={{height: 76, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, gap: 14}}>
        <View style={{width: 44, height: 44, borderRadius: 22, backgroundColor: ['#E16868', '#5C93D5', '#8D70D1'][index % 3], alignItems: 'center', justifyContent: 'center'}}><Text style={{color: 'white', fontSize: 19}}>{item[0]}</Text></View>
        <View><Text style={{color: ink, fontSize: 19, fontWeight: '600'}}>{item}</Text><Text style={{color: dark ? '#A6ABB8' : '#606775', fontSize: 14}}>Mobile · {100 + index}</Text></View>
      </Pressable>} />
  </GlassNavigationView>;
}
