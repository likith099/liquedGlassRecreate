import React, {useState} from 'react';
import {Text, View} from 'react-native';
import {GlassBadge, GlassExpandingTabs, GlassIconButton} from '@likith99/react-native-adaptive-liquid-glass';

/** Badges over imagery, expanding filter pills and a floating action button. */
export default function BadgesDemo({foreground, secondary}: {foreground: string; secondary: string}) {
  const [status, setStatus] = useState('No action');
  const [filter, setFilter] = useState('overview');
  return <View style={{marginTop: 28, gap: 14}}>
    <Text style={{color: foreground, fontSize: 22, fontWeight: '700'}}>Badges and actions</Text>
    {/* Stand-in for a photo: bright and dark regions under the badges. */}
    <View style={{height: 120, borderRadius: 20, overflow: 'hidden', flexDirection: 'row'}}>
      <View style={{flex: 1, backgroundColor: '#F4D35E'}} />
      <View style={{flex: 1, backgroundColor: '#1B263B'}} />
      <View style={{position: 'absolute', left: 14, top: 14, gap: 10}}>
        <GlassBadge testID="badge-tinted" tintColor="#F57C0080" tintGlass solidColor="#F57C00">New</GlassBadge>
        <GlassBadge testID="badge-dark" colorScheme="dark" solidColor="#101820">Updating…</GlassBadge>
      </View>
    </View>
    <GlassExpandingTabs testID="filter-tabs" value={filter} onValueChange={setFilter} contentInset={0}
      options={[{value: 'overview', label: 'Overview', systemImage: 'square.grid.2x2', androidIcon: 'demo_grid', tintColor: '#F57C00'},
        {value: 'favorites', label: 'Favorites', systemImage: 'heart', androidIcon: 'alg_tab_favorites', tintColor: '#C62828'},
        {value: 'recent', label: 'Recent', systemImage: 'clock', androidIcon: 'demo_schedule', tintColor: '#1565C0'},
        {value: 'shared', label: 'Shared', systemImage: 'person.2', androidIcon: 'demo_group', tintColor: '#2E7D32'},
        {value: 'archive', label: 'Archive', systemImage: 'archivebox', androidIcon: 'demo_archive'}]} />
    <Text testID="filter-selection" style={{color: secondary}}>Filter: {filter}</Text>
    <View style={{flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between'}}>
      <Text testID="badge-status-text" style={{color: secondary}}>{status}</Text>
      <GlassIconButton testID="fab" systemImage="plus" androidIcon="demo_add" accessibilityLabel="Add item"
        size={56} variant="prominent" tintColor="#6159B7" onPress={() => setStatus('FAB pressed')} />
    </View>
  </View>;
}
