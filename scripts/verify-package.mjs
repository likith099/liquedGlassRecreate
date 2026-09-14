import {cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const artifacts = path.join(root, 'artifacts');
mkdirSync(artifacts, {recursive: true});
const requestedConsumer = process.env.ALG_CONSUMER_DIR;
if (requestedConsumer && (!/^\/private\/tmp\/alg-consumer-[a-zA-Z0-9]+$/.test(requestedConsumer) || !existsSync(path.join(requestedConsumer, 'package.json')) || realpathSync(requestedConsumer) !== requestedConsumer)) throw new Error('ALG_CONSUMER_DIR must be an existing standalone alg-consumer directory in /private/tmp');
const consumer = requestedConsumer ?? mkdtempSync('/private/tmp/alg-consumer-');
function run(command, args, cwd = consumer, env = {}) {
  const result = spawnSync(command, args, {cwd, env: {...process.env, ...env}, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024});
  if (result.status !== 0) throw new Error(`${command} ${args.join(' ')} failed\n${result.stdout}\n${result.stderr}`);
  return result.stdout;
}
console.log(`Consumer: ${consumer}`);
const packed = JSON.parse(run('npm', ['pack', '--workspace', 'react-native-adaptive-liquid-glass', '--json', '--pack-destination', artifacts], root))[0];
if (packed.files.some(file => file.path.includes('/build/') || file.path.includes('node_modules'))) throw new Error('Generated files leaked into package');
const archive = path.join(artifacts, packed.filename);
const sha256 = createHash('sha256').update(readFileSync(archive)).digest('hex');
// A unique file dependency prevents npm reusing an older archive with the same version.
const tarball = path.join(artifacts, `consumer-${sha256}.tgz`);
cpSync(archive, tarball);
const pkg = JSON.parse(readFileSync(path.join(root, 'example/package.json'), 'utf8'));
pkg.dependencies['react-native-adaptive-liquid-glass'] = `file:${tarball}`;
for (const dependency of ['@react-navigation/native', '@react-navigation/bottom-tabs', 'react-native-screens']) delete pkg.dependencies[dependency];
pkg.scripts = {};
writeFileSync(path.join(consumer, 'package.json'), JSON.stringify(pkg, null, 2));
for (const name of ['ios', 'android', 'index.js', 'app.json', 'babel.config.js']) {
  cpSync(path.join(root, 'example', name), path.join(consumer, name), {recursive: true, filter: src =>
    !['Pods', 'build', '.gradle', '.cxx', 'local.properties', 'xcuserdata', '.xcode.env.local'].includes(path.basename(src))});
}
// The demo hoists node_modules one level above its app; a standalone app does not.
for (const [file, from, to] of [
  ['ios/LiquidGlassLab.xcodeproj/project.pbxproj', '../../packages/liquid-glass/ios/', '../node_modules/react-native-adaptive-liquid-glass/ios/'],
  ['android/settings.gradle', '../../node_modules/', '../node_modules/'],
  ['android/app/build.gradle', '../../../node_modules/', '../../node_modules/'],
]) {
  const target = path.join(consumer, file);
  writeFileSync(target, readFileSync(target, 'utf8').replaceAll(from, to));
}
writeFileSync(path.join(consumer, 'metro.config.js'), "const {getDefaultConfig} = require('@react-native/metro-config'); module.exports = getDefaultConfig(__dirname);\n");
writeFileSync(path.join(consumer, 'tsconfig.json'), JSON.stringify({extends: '@react-native/typescript-config', include: ['App.tsx']}));
writeFileSync(path.join(consumer, 'App.tsx'), `import React, {useState} from 'react';
import {Text, View} from 'react-native';
import {GlassView, GlassContainer, GlassButton, GlassPressable, GlassSegmentedControl, GlassSlider, GlassActionCluster, GlassMenuButton, GlassToolbar, GlassTabBar} from 'react-native-adaptive-liquid-glass';
export default function App() {
  const [value, setValue] = useState(0.4);
  const [selected, setSelected] = useState<string | null>('a');
  const [expanded, setExpanded] = useState(false);
  const [tab, setTab] = useState('home');
  return <View style={{flex: 1, padding: 30, paddingTop: 100}}>
    <GlassContainer><GlassView style={{padding: 16}}><Text>Installed from tarball</Text></GlassView></GlassContainer>
    <GlassButton title="Native button" onPress={() => setValue(0.5)} />
    <GlassPressable onPress={() => setValue(0.2)}><Text>React children</Text></GlassPressable>
    <GlassSegmentedControl options={[{value: 'a', label: 'A'}, {value: 'b', label: 'B'}]} value={selected} onValueChange={setSelected} />
    <GlassMenuButton title="Actions" items={[{id: 'save', title: 'Save'}]} onAction={() => {}} />
    <GlassToolbar items={[{id: 'save', title: 'Save'}, {kind: 'submenu', id: 'order', title: 'Order', items: [{id: 'name', title: 'Name', checked: true}]}]} onAction={() => {}} />
    <GlassTabBar items={[{id: 'home', title: 'Home', icon: 'home'}, {id: 'inbox', title: 'Inbox', icon: 'inbox', badge: 3}]} value={tab} onValueChange={setTab} />
    <GlassSlider value={value} onValueChange={setValue} />
    <GlassActionCluster actions={[{id: 'save', title: 'Save', systemImage: 'bookmark'}]} expanded={expanded} onExpandedChange={setExpanded} onAction={() => {}} />
  </View>;
}
`);
console.log('Installing the packed package with an independent dependency tree…');
run('npm', ['install', '--ignore-scripts', '--no-audit', '--no-fund']);
const installed = path.join(consumer, 'node_modules/react-native-adaptive-liquid-glass');
if (!realpathSync(installed).startsWith(consumer)) throw new Error('Consumer unexpectedly points at workspace source');
const config = JSON.parse(run('node', ['node_modules/react-native/cli.js', 'config']));
const linked = config.dependencies['react-native-adaptive-liquid-glass'];
if (!linked?.platforms.ios?.podspecPath.startsWith(installed) || !linked?.platforms.android?.sourceDir.startsWith(installed)) throw new Error('Native autolinking failed');
if (!linked.platforms.android.componentDescriptors.includes('ALGTabsComponentDescriptor')) throw new Error('Tab component descriptor missing from Android autolinking');
if (!existsSync(path.join(installed, 'ios/ALGTabsComponentView.mm')) || !existsSync(path.join(installed, 'android/src/main/res/drawable/alg_tab_home.xml'))) throw new Error('Tab native source/resources missing from archive');
run('node', ['node_modules/typescript/bin/tsc', '--noEmit']);
for (const platform of ['ios', 'android']) {
  run('node', ['node_modules/react-native/cli.js', 'bundle', '--platform', platform, '--dev', 'false', '--entry-file', 'index.js', '--bundle-output', path.join(artifacts, `consumer.${platform}.js`), '--max-workers', '2']);
}
console.log('Both platform bundles and consumer typecheck passed; compiling the installed iOS source…');
run('pod', ['install'], path.join(consumer, 'ios'));
run('xcodebuild', ['-workspace', 'ios/LiquidGlassLab.xcworkspace', '-scheme', 'LiquidGlassLab', '-configuration', 'Debug', '-sdk', 'iphonesimulator', '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath', path.join(artifacts, 'ConsumerDerivedData'), '-jobs', '2', 'COMPILER_INDEX_STORE_ENABLE=NO', 'ARCHS=arm64', 'ONLY_ACTIVE_ARCH=YES', 'CODE_SIGNING_ALLOWED=NO', 'build']);
console.log('Compiling the installed Android source (requires ANDROID_HOME and JAVA_HOME)…');
run('./gradlew', [':app:assembleDebug', '-PreactNativeArchitectures=arm64-v8a', '--console=plain'], path.join(consumer, 'android'));
writeFileSync(path.join(artifacts, 'package-smoke.json'), JSON.stringify({consumer, tarball: archive, installedTarball: tarball, sha256, fileCount: packed.files.length, typecheck: 'passed', iosBundle: 'passed', androidBundle: 'passed', iosNativeBuild: 'passed', androidNativeBuild: 'passed', expoDependency: existsSync(path.join(consumer, 'node_modules/expo')), navigationDependency: existsSync(path.join(consumer, 'node_modules/@react-navigation/native'))}, null, 2));
console.log('Standalone package verification passed. See artifacts/package-smoke.json');
