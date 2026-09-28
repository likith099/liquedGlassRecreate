import React, {useRef, useState} from 'react';
import {Pressable, ScrollView, StyleSheet, Text, View, useColorScheme} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {GlassIconButton, GlassScrollEdge, GlassSearchField, GlassToastProvider, useGlassToast,
  type GlassSearchFieldHandle} from '@likith99/react-native-adaptive-liquid-glass';

// Neutral placeholder rows.
const items = ['Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo', 'Foxtrot', 'Golf', 'Hotel', 'India', 'Juliett',
  'Kilo', 'Lima', 'Mike', 'November', 'Oscar', 'Papa', 'Quebec', 'Romeo', 'Sierra', 'Tango'];

function Content({onClose}: {onClose: () => void}) {
  const dark = useColorScheme() === 'dark';
  const color = dark ? '#F5F5F9' : '#222737';
  const [query, setQuery] = useState('');
  const [submitted, setSubmitted] = useState('No search submitted');
  const scroll = useRef<React.ComponentRef<typeof ScrollView>>(null);
  const search = useRef<GlassSearchFieldHandle>(null);
  const toast = useGlassToast();
  const results = items.filter(name => name.toLowerCase().includes(query.trim().toLowerCase()));
  return <SafeAreaView edges={['top', 'left', 'right']} style={{flex: 1, backgroundColor: dark ? '#11141B' : '#F7F8FC'}}>
    <Pressable testID="close-search-demo" accessibilityRole="button" onPress={onClose} style={styles.close}>
      <Text style={{color}}>‹ Back to component lab</Text>
    </Pressable>
    <View style={{paddingHorizontal: 16, gap: 8}}>
      <GlassSearchField ref={search} testID="item-search" accessibilityLabel="Search items" value={query}
        onChangeText={setQuery} onSubmitEditing={text => setSubmitted(`Submitted: ${text}`)} placeholder="Search items" />
      <Text testID="search-result-count" style={{color}}>{results.length} results</Text>
      <Text testID="search-submitted" style={{color}}>{submitted}</Text>
    </View>
    <ScrollView ref={scroll} testID="search-results" contentContainerStyle={{padding: 16, paddingBottom: 140, gap: 10}}>
      {results.map(name => <View key={name} style={[styles.row, {backgroundColor: dark ? '#262A36' : '#FFFFFF'}]}>
        <Text style={{color, fontSize: 17}}>{name}</Text>
      </View>)}
    </ScrollView>
    {/* A floating bar over the list: iOS 26 draws the scroll-edge effect beneath it. */}
    <GlassScrollEdge scrollViewRef={scroll} edge="bottom" effectStyle="soft"
      fallbackColor={dark ? '#11141B' : '#F7F8FC'} style={styles.bar}>
      <GlassIconButton testID="search-focus" systemImage="magnifyingglass" androidIcon="alg_tab_search"
        accessibilityLabel="Focus search" onPress={() => search.current?.focus()} />
      <GlassIconButton testID="copy-action" systemImage="doc.on.doc" androidIcon="demo_copy"
        accessibilityLabel="Copy results" onPress={() => toast.show(`Copied ${results.length} items`)} />
    </GlassScrollEdge>
  </SafeAreaView>;
}

export default function SearchDemo({onClose}: {onClose: () => void}) {
  return <GlassToastProvider bottomOffset={120}><Content onClose={onClose} /></GlassToastProvider>;
}

const styles = StyleSheet.create({
  close: {paddingHorizontal: 24, paddingVertical: 12},
  row: {minHeight: 64, borderRadius: 16, paddingHorizontal: 18, justifyContent: 'center'},
  bar: {position: 'absolute', left: 0, right: 0, bottom: 0, height: 110, paddingBottom: 30,
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 24},
});
