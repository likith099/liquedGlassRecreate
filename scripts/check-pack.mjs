// Inspect exactly what `npm publish` would upload, and refuse anything unexpected.
// Run standalone so the release workflow does not depend on shell quoting or on
// the precise shape of npm's --json output, which has changed between versions.
import {execFileSync} from 'node:child_process';

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

// npm has at times prefixed the JSON with notices; take the first array/object.
const start = raw.search(/[[{]/);
if (start === -1) {
  console.error('npm pack produced no JSON. Raw output follows:');
  console.error(raw.slice(0, 2000));
  process.exit(1);
}

let parsed;
try {
  parsed = JSON.parse(raw.slice(start));
} catch (error) {
  console.error(`Could not parse npm pack JSON: ${error.message}`);
  console.error(raw.slice(0, 2000));
  process.exit(1);
}

const entry = Array.isArray(parsed) ? parsed[0] : parsed;
if (!entry || !Array.isArray(entry.files)) {
  console.error('npm pack JSON has no file list. Parsed value follows:');
  console.error(JSON.stringify(entry, null, 2).slice(0, 2000));
  process.exit(1);
}

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
