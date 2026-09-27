#!/usr/bin/env node
// Runs named example UI tests on an iOS simulator and exits with their result.
//
//   node scripts/run-ios-ui-tests.mjs [--simulator <udid>] [--result <path.xcresult>] [--log <path>] testName…
//
// Without --simulator it uses the first available iPhone on the newest installed iOS runtime.
// Metro must already serve the example on port 8093 (Debug builds load JavaScript from it).
// xcodebuild can stay alive after the test run has finished, so once the run's summary line
// appears the process is given 30 s to exit and is then stopped; the summary decides the result.
// Failure diagnostics (a sysdiagnose per failure) are disabled: they are gigabytes each.
import {spawn, execFileSync} from 'node:child_process';
import {createWriteStream, mkdirSync, rmSync} from 'node:fs';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
function option(name) {
  const index = args.indexOf(name);
  if (index < 0) return undefined;
  const [, value] = args.splice(index, 2);
  if (!value) throw new Error(`${name} needs a value`);
  return value;
}
const simulator = option('--simulator') ?? newestIPhone();
const result = resolve(option('--result') ?? 'artifacts/UITests.xcresult');
const logPath = resolve(option('--log') ?? 'artifacts/ui-tests.log');
if (args.length === 0) throw new Error('Name at least one test, for example testVisualTiers');

function newestIPhone() {
  const {devices} = JSON.parse(execFileSync('xcrun', ['simctl', 'list', 'devices', 'available', '-j'], {encoding: 'utf8'}));
  const version = runtime => (runtime.match(/iOS-(\d+)-(\d+)/) ?? []).slice(1).map(Number);
  const runtimes = Object.keys(devices).filter(key => key.includes('.iOS-'))
    .sort((a, b) => {
      const [aMajor, aMinor] = version(a), [bMajor, bMinor] = version(b);
      return bMajor - aMajor || bMinor - aMinor;
    });
  for (const runtime of runtimes) {
    const phone = devices[runtime].find(device => device.name.startsWith('iPhone'));
    if (phone) {
      console.log(`Simulator: ${phone.name} (${runtime.split('.').pop()}) ${phone.udid}`);
      return phone.udid;
    }
  }
  throw new Error('No available iPhone simulator');
}

rmSync(result, {recursive: true, force: true});
mkdirSync(dirname(result), {recursive: true});
mkdirSync(dirname(logPath), {recursive: true});
const log = createWriteStream(logPath);
const xcodebuild = spawn('xcodebuild', [
  '-workspace', 'example/ios/LiquidGlassLab.xcworkspace', '-scheme', 'LiquidGlassLab',
  '-destination', `platform=iOS Simulator,id=${simulator}`,
  '-resultBundlePath', result, '-collect-test-diagnostics', 'never', '-parallel-testing-enabled', 'NO',
  ...(process.env.ALG_DERIVED_DATA ? ['-derivedDataPath', process.env.ALG_DERIVED_DATA] : []),
  ...args.map(test => `-only-testing:LiquidGlassLabUITests/GlassInteractionTests/${test}`),
  'CODE_SIGNING_ALLOWED=NO', 'COMPILER_INDEX_STORE_ENABLE=NO', 'test',
], {cwd: root, stdio: ['ignore', 'pipe', 'pipe']});

let summary;
let stopTimer;
const summaryPattern = /Test Suite 'Selected tests' (passed|failed)/;
function watch(chunk) {
  log.write(chunk);
  const text = chunk.toString();
  for (const line of text.split('\n')) {
    if (/^Test Case .*(passed|failed|skipped)|error:|Executed \d+ test/.test(line)) console.log(line);
  }
  const match = text.match(summaryPattern);
  if (match && !summary) {
    summary = match[1];
    stopTimer = setTimeout(() => {
      console.log('xcodebuild is still running after the test summary; stopping it.');
      xcodebuild.kill('SIGTERM');
    }, 30_000);
  }
}
xcodebuild.stdout.on('data', watch);
xcodebuild.stderr.on('data', watch);
xcodebuild.on('close', code => {
  clearTimeout(stopTimer);
  log.end();
  const passed = summary ? summary === 'passed' : code === 0;
  console.log(`UI tests ${passed ? 'passed' : 'failed'} (summary: ${summary ?? 'none'}, xcodebuild exit: ${code}). Log: ${logPath}`);
  process.exit(passed ? 0 : 1);
});
