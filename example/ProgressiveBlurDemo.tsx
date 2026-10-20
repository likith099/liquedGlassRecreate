import React, {useRef, useState} from 'react';
import {FlatList, Pressable, Text, View, useColorScheme} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {GlassProgressiveBlur} from '@likith99/react-native-adaptive-liquid-glass';
const people = ['Maya Chen', 'Noah Williams', 'Amara Patel', 'Leo Martin', 'Sofia Garcia', 'Ethan Park', 'Ava Wilson', 'Oliver Brown', 'Isla Ahmed', 'Lucas Kim', 'Mia Taylor', 'Elijah Davis', 'Zoe Harris', 'Arjun Shah', 'Nora Jones', 'Theo Clark', 'Lily Moore', 'Mateo Rivera', 'Ella Lewis', 'Finn Walker'];
export default function ProgressiveBlurDemo({onClose}: {onClose: () => void}) {
  const list = useRef<FlatList<string>>(null);
  const dark = useColorScheme() === 'dark';
  const ink = dark ? '#F5F5F9' : '#18202D', background = dark ? '#12141A' : '#F7F8FC';
  const [fallback, setFallback] = useState<'blur' | 'solid'>('blur');
  const [added, setAdded] = useState(0);
  const action = (id: string, title: string, onPress: () => void) => <Pressable testID={id} accessibilityRole="button" onPress={onPress} style={{padding: 12}}><Text style={{color: ink}}>{title}</Text></Pressable>;
  return <SafeAreaView style={{flex: 1, backgroundColor: background}}>
    {action('close-scroll-header', '‹ Back to navigation demo', onClose)}
    <View style={{flex: 1}}>
      <FlatList ref={list} testID="header-contacts" data={people} keyExtractor={name => name}
        contentContainerStyle={{paddingTop: 112, paddingBottom: 24}}
        renderItem={({item, index}) => <View style={{height: 76, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 24, gap: 14}}>
          <View style={{width: 44, height: 44, borderRadius: 22, backgroundColor: ['#E16868', '#5C93D5', '#8D70D1'][index % 3], alignItems: 'center', justifyContent: 'center'}}><Text style={{color: 'white', fontSize: 19}}>{item[0]}</Text></View>
          <View><Text style={{color: ink, fontSize: 19, fontWeight: '600'}}>{item}</Text><Text style={{color: dark ? '#A6ABB8' : '#606775', fontSize: 14}}>Mobile · {100 + index}</Text></View>
        </View>} />
      <GlassProgressiveBlur testID="contacts-header" scrollViewRef={list} fallback={fallback} fallbackColor={background}
        style={{position: 'absolute', top: 0, left: 0, right: 0, height: 100, paddingHorizontal: 24, paddingTop: 12}}>
        <View style={{flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center'}}>
          <Text testID="contacts-title" style={{color: ink, fontSize: 32, fontWeight: '700'}}>Contacts</Text>
          {action('header-add', '+ Add', () => setAdded(n => n + 1))}
        </View>
        <Text testID="header-added" style={{color: ink}}>All contacts · {people.length + added}</Text>
      </GlassProgressiveBlur>
    </View>
    <View style={{flexDirection: 'row', flexWrap: 'wrap'}}>
      {action('header-scroll', 'Scroll under header', () => list.current?.scrollToOffset({offset: 84, animated: true}))}
      {action('header-reset', 'Back to top', () => list.current?.scrollToOffset({offset: 0, animated: true}))}
      {action('header-fallback', `Android: ${fallback}`, () => setFallback(v => v === 'blur' ? 'solid' : 'blur'))}
    </View>
  </SafeAreaView>;
}
