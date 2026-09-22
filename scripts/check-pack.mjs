// Inspect exactly what `npm publish` would upload, and refuse anything unexpected.
// Run standalone so the release workflow does not depend on shell quoting or on
// the precise shape of npm's --json output, which has changed between versions.
import {execFileSync} from 'node:child_process';
import {parsePackResult} from './lib/pack-result.mjs';

const PACKAGE = '@likith99/react-native-adaptive-liquid-glass';

let raw;
try {
  raw = execFileSync('npm', ['pack', '--workspace', PACKAGE, '--dry-run', '--json'], {
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  });
} catch (error) {
  console.error('npm pack failed');
  console.error(error.stdout || '');
  console.error(error.stderr || '');
  process.exit(1);
}

const entry = parsePackResult(raw, PACKAGE);

const paths = entry.files.map(file => file.path);
const forbidden = paths.filter(p =>
  /^android\/(build|\.gradle)\//.test(p) || p.split('/').includes('node_modules'));
const required = ['package.json', 'README.md', 'LICENSE'];
const missing = required.filter(name => !paths.includes(name));

console.log(`package:  ${entry.name}@${entry.version}`);
console.log(`files:    ${paths.length}`);
console.log(`unpacked: ${entry.unpackedSize ?? 'unknown'} bytes`);

if (forbidden.length) {
  console.error(`Refusing to publish. Build output in the tarball:\n  ${forbidden.join('\n  ')}`);
  process.exit(1);
}
if (missing.length) {
  console.error(`Refusing to publish. Missing required files: ${missing.join(', ')}`);
  process.exit(1);
}
console.log('Package contents look correct.');
