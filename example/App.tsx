import React, {useEffect, useRef, useState} from 'react';
import {AccessibilityInfo, Animated, Platform, PlatformColor, Pressable, ScrollView, StatusBar,
  StyleSheet, Switch, Text, View, useColorScheme} from 'react-native';
import {SafeAreaProvider, SafeAreaView} from 'react-native-safe-area-context';
import AccessibilityDemo from './AccessibilityDemo';
import ToolbarDemo from './ToolbarDemo';
import TabNavigationDemo from './TabNavigationDemo';
import {GlassActionCluster, GlassButton, GlassContainer, GlassView, GlassSegmentedControl, GlassSlider, GlassMenuButton, isLiquidGlassSupported} from 'react-native-adaptive-liquid-glass';

const actions = [
  {id: 'heart', title: 'Favorite', systemImage: 'heart'},
  {id: 'bookmark', title: 'Save', systemImage: 'bookmark'},
  {id: 'share', title: 'Share', systemImage: 'square.and.arrow.up'},
];
const segments = [{value: 'all', label: 'All'}, {value: 'saved', label: 'Saved'}, {value: 'shared', label: 'Shared', disabled: true}];

function Lab({onOpenTabs, onOpenAccessibility}: {onOpenTabs: () => void; onOpenAccessibility: () => void}) {
  const [expanded, setExpanded] = useState(false);
  const [interactive, setInteractive] = useState(true);
  const [clear, setClear] = useState(false);
  const [fallback, setFallback] = useState(false);
  const [merged, setMerged] = useState(false);
  const [mergingEnabled, setMergingEnabled] = useState(false);
  const [tinted, setTinted] = useState(false);
  const [lastAction, setLastAction] = useState('Tap a control to explore');
  const [presses, setPresses] = useState(0);
  const [reduceMotion, setReduceMotion] = useState(false);
  const [selection, setSelection] = useState('all');
  const [controlsDisabled, setControlsDisabled] = useState(false);
  const [buttonLoading, setButtonLoading] = useState(false);
  const [controlsFallback, setControlsFallback] = useState(false);
  const [nativePresses, setNativePresses] = useState(0);
  const [sliderValue, setSliderValue] = useState(40);
  const [sliderStepped, setSliderStepped] = useState(true);
  const [sliderDisabled, setSliderDisabled] = useState(false);
  const [sliderLocked, setSliderLocked] = useState(false);
  const [menuChecked, setMenuChecked] = useState(false);
  const [menuDisabled, setMenuDisabled] = useState(false);
  const [menuFallback, setMenuFallback] = useState(false);
  const [menuStatus, setMenuStatus] = useState("No menu action");
  const [sliderEvent, setSliderEvent] = useState('Ready to slide');
  const movement = useRef(new Animated.Value(0)).current;
  const dark = useColorScheme() === 'dark';
  const foreground = dark ? '#F5F5F9' : '#222737';
  const secondary = dark ? '#B2B6C4' : '#666E82';
  const glassForeground = Platform.OS === 'ios' ? PlatformColor('labelColor') : foreground;
  useEffect(() => {
    let active = true;
    AccessibilityInfo.isReduceMotionEnabled().then(value => { if (active) setReduceMotion(value); });
    const sub = AccessibilityInfo.addEventListener('reduceMotionChanged', setReduceMotion);
    return () => {active = false; sub.remove();};
  }, []);
  useEffect(() => {
    const animation = Animated.spring(movement, {toValue: merged ? -48 : 0, useNativeDriver: true,
      damping: 18, stiffness: 130, mass: 1});
    if (reduceMotion) movement.setValue(merged ? -48 : 0); else animation.start();
    return () => animation.stop();
  }, [merged, movement, reduceMotion]);
  const material = clear ? 'clear' : 'regular';
  const tintColor = tinted ? '#A5A2FF60' : undefined;
  return <SafeAreaView style={[styles.safe, {backgroundColor: dark ? '#11141B' : '#F7F8FC'}]}>
    <StatusBar barStyle={dark ? 'light-content' : 'dark-content'} />
    <ScrollView contentContainerStyle={styles.page}>
      <Pressable testID="open-tabs-demo" accessibilityRole="button" onPress={onOpenTabs} style={{paddingVertical: 12}}>
        <Text style={{color: foreground, fontWeight: '600'}}>Open tab navigation →</Text>
      </Pressable>
      <Pressable testID="open-accessibility-demo" accessibilityRole="button" onPress={onOpenAccessibility} style={{paddingVertical: 12}}>
        <Text style={{color: foreground, fontWeight: '600'}}>Open adaptive controls →</Text>
      </Pressable>
      <View style={styles.topline}><View style={styles.dot} /><Text style={[styles.eyebrow, {color: secondary}]}>NATIVE MATERIALS / 01</Text></View>
      <Text style={[styles.title, {color: foreground}]}>Liquid, by nature.</Text>
      <Text style={[styles.subtitle, {color: secondary}]}>Real glass. Native motion. One React API.</Text>
      <View style={[styles.stage, {backgroundColor: dark ? '#34465B' : '#D9E5F2'}]}>
        <View pointerEvents="none" style={[styles.orb, styles.orbBlue]} />
        <View pointerEvents="none" style={[styles.orb, styles.orbPeach]} />
        <View pointerEvents="none" style={[styles.orb, styles.orbLilac]} />
        <View pointerEvents="none" style={styles.stageLines}><Text style={styles.stageWord}>flow</Text><Text style={styles.stageCaption}>LIGHT · DEPTH · MOVEMENT</Text></View>
        <View style={styles.stageTop}>
          <GlassView forceFallback={fallback} material={material} interactive={interactive} tintColor={tintColor}
            cornerRadius={25} testID="adaptive-surface" style={styles.badge}>
            <Text style={{color: glassForeground, fontSize: 13, fontWeight: '600'}}>✦  {fallback ? 'Standard surface' : 'Native surface'}</Text>
          </GlassView>
        </View>
        <View style={styles.stageBottom}>
          <GlassButton forceFallback={fallback} material={material} tintColor={tintColor}
            testID="glass-counter" accessibilityLabel="Try glass button"
            onPress={() => {setPresses(value => value + 1); setLastAction('React button pressed');}}>
            <Text style={{color: glassForeground, fontWeight: '600'}}>Touch the glass  ↗ {presses > 0 ? ` ${presses}` : ''}</Text>
          </GlassButton>
          <GlassActionCluster forceFallback={fallback} mergingEnabled={mergingEnabled} actions={actions} expanded={expanded}
            onExpandedChange={setExpanded} onAction={id => setLastAction(`${actions.find(action => action.id === id)?.title} selected`)}
            interactive={interactive} material={material} tintColor={tintColor} style={styles.cluster} />
        </View>
      </View>
      <View style={styles.status}><View style={[styles.dot, {backgroundColor: fallback ? '#888D9E' : '#3B9A76'}]} />
        <Text style={[styles.statusText, {color: secondary}]}>{fallback ? 'Standard component preview' : isLiquidGlassSupported() ? 'iOS 26 · UIKit + SwiftUI' : 'Standard platform components'}</Text>
      </View>
      <Text accessibilityLiveRegion="polite" testID="action-status" style={[styles.feedback, {color: foreground}]}>{lastAction}</Text>
      <View style={styles.sectionHeading}><Text style={[styles.sectionTitle, {color: foreground}]}>Make it yours</Text><Text style={[styles.sectionIndex, {color: secondary}]}>01 — LIVE PROPERTIES</Text></View>
      <View style={[styles.settings, {backgroundColor: dark ? '#1C2029' : '#FFFFFF'}]}>
        <Setting title="Touch response" detail="Native interactive material" value={interactive} onChange={setInteractive} color={foreground} muted={secondary} id="interactive-toggle" />
        <Setting title="Clear material" detail="Let more of the backdrop through" value={clear} onChange={setClear} color={foreground} muted={secondary} id="clear-toggle" />
        <Setting title="Violet tint" detail="Color blended into the glass" value={tinted} onChange={setTinted} color={foreground} muted={secondary} id="tint-toggle" />
        <Setting title="Standard fallback" detail="Preview the shared Android components" value={fallback} onChange={setFallback} color={foreground} muted={secondary} id="fallback-toggle" />
      </View>
      <View style={styles.sectionHeading}><Text style={[styles.sectionTitle, {color: foreground}]}>Native menus</Text></View>
      <GlassMenuButton title="Library actions" systemImage="ellipsis.circle" testID="native-menu"
        disabled={menuDisabled} forceFallback={menuFallback}
        items={[
          {id: 'favorite', title: 'Favorite item', systemImage: 'heart', checked: menuChecked},
          {id: 'share', title: 'Share item', systemImage: 'square.and.arrow.up'},
          {id: 'unavailable', title: 'Unavailable action', disabled: true},
          {id: 'remove', title: 'Remove item', systemImage: 'trash', destructive: true},
        ]}
        onAction={id => {if (id === 'favorite') setMenuChecked(value => !value); setMenuStatus(`Menu selected: ${id}`);}} />
      <Text testID="menu-status" accessibilityLiveRegion="polite" style={{color: secondary}}>{menuStatus}</Text>
      <Text testID="menu-checked" style={{color: secondary}}>Favorite: {menuChecked ? 'on' : 'off'}</Text>
      <Setting title="Disable menu" detail="Block menu activation" value={menuDisabled} onChange={setMenuDisabled}
        color={foreground} muted={secondary} id="menu-disabled-toggle" />
      <Setting title="Standard menu button" detail="Preview the standard iOS appearance" value={menuFallback} onChange={setMenuFallback}
        color={foreground} muted={secondary} id="menu-fallback-toggle" />
      <ToolbarDemo foreground={foreground} secondary={secondary} />
      <View style={styles.sectionHeading}><Text style={[styles.sectionTitle, {color: foreground}]}>Better together</Text><Text style={[styles.sectionIndex, {color: secondary}]}>02 — MERGING</Text></View>
      <Setting title="Glass merging" detail="Allow nearby glass elements to join" value={mergingEnabled}
        onChange={setMergingEnabled} color={foreground} muted={secondary} id="merging-enabled-toggle" />
      <View style={[styles.mergeStage, {backgroundColor: dark ? '#3E414F' : '#E7E0F3'}]}>
        <View pointerEvents="none" style={styles.mergeStripe} />
        <GlassContainer forceFallback={fallback} mergingEnabled={mergingEnabled} spacing={28} style={styles.mergeContainer}>
          <GlassView forceFallback={fallback} material={material} interactive={interactive} tintColor={tintColor} cornerRadius={34} style={styles.blob}><Text style={[styles.blobText, {color: glassForeground}]}>✦</Text></GlassView>
          <Animated.View style={{transform: [{translateX: movement}]}}>
            <GlassView forceFallback={fallback} material={material} interactive={interactive} tintColor={tintColor} cornerRadius={34} style={styles.blob}><Text style={[styles.blobText, {color: glassForeground}]}>＋</Text></GlassView>
          </Animated.View>
        </GlassContainer>
        <Pressable testID="merge-toggle" accessibilityRole="button" onPress={() => setMerged(value => !value)} style={styles.mergeButton}>
          <Text style={styles.mergeButtonText}>{merged ? 'Separate surfaces' : 'Bring together'}  ↔</Text>
        </Pressable>
      </View>
      <View style={styles.sectionHeading}><Text style={[styles.sectionTitle, {color: foreground}]}>Built to respond</Text><Text style={[styles.sectionIndex, {color: secondary}]}>03 — CONTROLS</Text></View>
      <View style={[styles.controlsStage, {backgroundColor: dark ? '#3E414F' : '#E7E0F3'}]}>
        <View pointerEvents="none" style={styles.controlsStripe} />
        <GlassSegmentedControl options={segments} value={selection} onValueChange={setSelection}
          forceFallback={controlsFallback} disabled={controlsDisabled} testID="native-segments" accessibilityLabel="Library filter" />
        <Text testID="selection-status" style={{color: foreground, fontSize: 13, marginVertical: 12}}>Showing: {selection}</Text>
        <GlassButton title="Add to collection" systemImage="plus" variant="prominent" testID="native-primary-button"
          disabled={controlsDisabled} loading={buttonLoading} forceFallback={controlsFallback}
          onPress={() => setNativePresses(count => count + 1)} />
        <GlassButton title="Reset filter" systemImage="arrow.counterclockwise" testID="native-reset-button"
          disabled={controlsDisabled} forceFallback={controlsFallback} onPress={() => setSelection('all')} />
        <Text testID="native-press-status" style={{color: foreground, fontSize: 13, marginTop: 8}}>Added: {nativePresses}</Text>
      </View>
      <Setting title="Disable controls" detail="Block presses and selection changes" value={controlsDisabled}
        onChange={setControlsDisabled} color={foreground} muted={secondary} id="controls-disabled-toggle" />
      <Setting title="Loading button" detail="Show progress and prevent duplicate taps" value={buttonLoading}
        onChange={setButtonLoading} color={foreground} muted={secondary} id="button-loading-toggle" />
      <Setting title="Standard controls" detail="Preview Android button and selector" value={controlsFallback}
        onChange={setControlsFallback} color={foreground} muted={secondary} id="controls-fallback-toggle" />
      <View style={styles.sectionHeading}><Text style={[styles.sectionTitle, {color: foreground}]}>Stay in motion</Text><Text style={[styles.sectionIndex, {color: secondary}]}>04 — SLIDER</Text></View>
      <View style={[styles.controlsStage, {backgroundColor: dark ? '#3E414F' : '#E7E0F3'}]}>
        <View pointerEvents="none" style={styles.controlsStripe} />
        <Text testID="slider-value" style={{fontSize: 26, fontWeight: '600', color: foreground}}>Level: {Math.round(sliderValue)}</Text>
        <GlassSlider testID="native-slider" accessibilityLabel="Level" value={sliderValue}
          minimumValue={0} maximumValue={100} step={sliderStepped ? 10 : 0} disabled={sliderDisabled}
          onValueChange={value => {if (!sliderLocked) setSliderValue(value);}}
          onSlidingStart={() => setSliderEvent('Dragging')}
          onSlidingComplete={value => setSliderEvent(`Completed: ${Math.round(value)}`)}
          onSlidingCancel={value => setSliderEvent(`Cancelled: ${Math.round(value)}`)} />
        <Text testID="slider-event" style={{fontSize: 13, color: foreground, marginBottom: 12}}>{sliderEvent}</Text>
        <GlassButton title="Reset level" testID="slider-reset" systemImage="arrow.counterclockwise"
          onPress={() => {setSliderValue(40); setSliderEvent('Reset to 40');}} />
      </View>
      <Setting title="Snap to tens" detail="Switch between stepped and continuous movement" value={sliderStepped}
        onChange={setSliderStepped} color={foreground} muted={secondary} id="slider-step-toggle" />
      <Setting title="Disable slider" detail="Prevent changes from touch and accessibility" value={sliderDisabled}
        onChange={setSliderDisabled} color={foreground} muted={secondary} id="slider-disabled-toggle" />
      <Setting title="Lock value" detail="Keep the value when a drag finishes" value={sliderLocked}
        onChange={setSliderLocked} color={foreground} muted={secondary} id="slider-lock-toggle" />
      <Text style={[styles.footer, {color: secondary}]}>Built with Apple’s public Liquid Glass APIs. Android uses familiar surfaces and ripple feedback.</Text>
    </ScrollView>
  </SafeAreaView>;
}
function Setting({title, detail, value, onChange, color, muted, id}: {title: string; detail: string; value: boolean; onChange: (value: boolean) => void; color: string; muted: string; id: string}) {
  return <View style={styles.setting}><View style={{flex: 1}}><Text style={[styles.settingTitle, {color}]}>{title}</Text><Text style={[styles.settingDetail, {color: muted}]}>{detail}</Text></View>
    <Switch testID={id} accessibilityLabel={title} value={value} onValueChange={onChange} trackColor={{true: '#7770D8'}} />
  </View>;
}
export default function App() {
  const [tabsOpen, setTabsOpen] = useState(false);
  const [accessibilityOpen, setAccessibilityOpen] = useState(false);
  return <SafeAreaProvider>{accessibilityOpen ? <AccessibilityDemo onClose={() => setAccessibilityOpen(false)} /> : tabsOpen ? <TabNavigationDemo onClose={() => setTabsOpen(false)} /> : <Lab onOpenTabs={() => setTabsOpen(true)} onOpenAccessibility={() => setAccessibilityOpen(true)} />}</SafeAreaProvider>;
}
const styles = StyleSheet.create({
  safe: {flex: 1}, page: {padding: 24, paddingBottom: 40, maxWidth: 620, width: '100%', alignSelf: 'center'},
  topline: {flexDirection: 'row', alignItems: 'center', gap: 8, marginTop: 8}, dot: {width: 6, height: 6, borderRadius: 3, backgroundColor: '#8A81C9'},
  eyebrow: {fontSize: 10, fontWeight: '700', letterSpacing: 2}, title: {fontSize: 34, fontWeight: '600', letterSpacing: -1.5, marginTop: 18},
  subtitle: {fontSize: 14, lineHeight: 22, marginTop: 6, marginBottom: 24},
  stage: {height: 340, borderRadius: 32, overflow: 'hidden'}, orb: {position: 'absolute', borderRadius: 200},
  orbBlue: {width: 280, height: 280, backgroundColor: '#75AAD1', top: 70, left: -95, transform: [{rotate: '30deg'}]},
  orbPeach: {width: 265, height: 200, backgroundColor: '#EEB89E', top: -65, right: -85, transform: [{rotate: '-35deg'}]},
  orbLilac: {width: 280, height: 160, backgroundColor: '#A4A0D1', bottom: -75, right: -60, transform: [{rotate: '-25deg'}]},
  stageLines: {position: 'absolute', top: 77, left: 28}, stageWord: {fontSize: 100, fontWeight: '200', color: '#FFFFFF90', letterSpacing: -8},
  stageCaption: {fontSize: 8, color: '#33465F', letterSpacing: 3, marginTop: -8, marginLeft: 9},
  stageTop: {padding: 20, alignItems: 'flex-start'}, badge: {height: 46, justifyContent: 'center', paddingHorizontal: 16},
  stageBottom: {position: 'absolute', bottom: 4, left: 16, right: 16, alignItems: 'flex-start'}, cluster: {alignSelf: 'stretch'},
  status: {flexDirection: 'row', alignItems: 'center', gap: 7, marginTop: 14}, statusText: {fontSize: 11, letterSpacing: 0.3},
  feedback: {fontSize: 13, marginTop: 12, minHeight: 20}, sectionHeading: {flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginTop: 28, marginBottom: 14},
  sectionTitle: {fontSize: 18, fontWeight: '600', letterSpacing: -0.5}, sectionIndex: {fontSize: 8, letterSpacing: 1}, settings: {borderRadius: 22, paddingHorizontal: 17},
  setting: {minHeight: 73, flexDirection: 'row', gap: 10, alignItems: 'center', paddingVertical: 12}, settingTitle: {fontSize: 14, fontWeight: '500'}, settingDetail: {fontSize: 11, marginTop: 4},
  mergeStage: {height: 200, borderRadius: 26, overflow: 'hidden', justifyContent: 'center', alignItems: 'center'},
  controlsStage: {borderRadius: 26, padding: 20, overflow: 'hidden'},
  controlsStripe: {width: 140, height: 500, position: 'absolute', backgroundColor: '#B3A3D466', right: 20, top: -80, transform: [{rotate: '30deg'}]},
  mergeStripe: {width: 95, height: 320, position: 'absolute', backgroundColor: '#C1ADDB', transform: [{rotate: '35deg'}]},
  mergeContainer: {flexDirection: 'row', gap: 54, width: 244, height: 96, alignItems: 'center', paddingLeft: 22},
  blob: {height: 68, width: 68, alignItems: 'center', justifyContent: 'center'}, blobText: {fontSize: 24},
  mergeButton: {marginTop: 12, padding: 10, paddingHorizontal: 16, borderRadius: 20, backgroundColor: '#FFFFFFD9'}, mergeButtonText: {fontSize: 12, fontWeight: '600', color: '#453957'}, footer: {fontSize: 11, lineHeight: 18, marginTop: 20},
});
