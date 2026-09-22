import {spawnSync} from 'node:child_process';
import {existsSync, mkdirSync, openSync, closeSync, readFileSync, writeFileSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const platform = process.argv[2];
if (!['ios', 'android'].includes(platform)) throw new Error('Usage: node scripts/verify-release-builds.mjs ios|android');
const artifacts = path.join(root, 'artifacts'); mkdirSync(artifacts, {recursive: true});
const log = path.join(artifacts, `release-${platform}-build.log`);
const fd = openSync(log, 'w');
let result;
try {
  result = platform === 'ios' ? spawnSync('xcodebuild', [
    '-workspace', 'example/ios/LiquidGlassLab.xcworkspace', '-scheme', 'LiquidGlassLab', '-configuration', 'Release',
    '-destination', 'generic/platform=iOS', '-derivedDataPath', 'artifacts/ReleaseDerivedData',
    '-archivePath', 'artifacts/LiquidGlassLab.xcarchive', '-jobs', '2', 'COMPILER_INDEX_STORE_ENABLE=NO',
    'CODE_SIGNING_ALLOWED=NO', 'archive',
  ], {cwd: root, stdio: ['ignore', fd, fd]}) : spawnSync('./gradlew', [
    ':app:assembleRelease', ':app:bundleRelease', '-PreactNativeDevServerPort=8093', '--max-workers=2', '--console=plain',
  ], {cwd: path.join(root, 'example/android'), stdio: ['ignore', fd, fd]});
} finally { closeSync(fd); }
if (result.status !== 0) {
  console.error(readFileSync(log, 'utf8').slice(-9000));
  throw new Error(`${platform} Release build failed (${result.status}): ${result.error ?? log}`);
}
const output = platform === 'ios' ? 'artifacts/LiquidGlassLab.xcarchive/Products/Applications/LiquidGlassLab.app/main.jsbundle' :
  'example/android/app/build/outputs/bundle/release/app-release.aab';
if (!existsSync(path.join(root, output))) throw new Error(`Missing Release artifact: ${output}`);
const record = {platform, configuration: 'Release', exitCode: result.status, output, log,
  distributionAccepted: false, note: platform === 'ios' ? 'Unsigned archive: signing/export/install acceptance still required.' :
    'Demo uses debug signing: Play/upload-key distribution acceptance still required.'};
writeFileSync(path.join(artifacts, `release-${platform}-build.json`), JSON.stringify(record, null, 2)+'\n');
console.log(`${platform} Release build passed; ${record.note}`);
