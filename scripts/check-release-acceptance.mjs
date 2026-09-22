import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {readFileSync, realpathSync, statSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

// iPhone-first release: the owner subsequently authorized runtime/regression
// verification and publishing. Manual/device deferrals remain separate.
export const requiredChecks = {
  'ios-source-review': null, 'ios-swiftui-runtime': null,
  'ios-fallback-runtime': null, 'packed-consumer': 'Release',
};
export const deferredChecks = {
  'ios-current-profile': 'Release', 'ios-older-profile': 'Release', 'android-profile': 'Release',
  'ios-15-17-runtime': null, 'android-minimum-runtime': null,
  voiceover: null, talkback: null, 'rtl-ios': null, 'rtl-android': null,
  ipad: null, 'ios-accessibility-settings': null, 'android-accessibility-settings': null,
  'ios-distribution': 'Release', 'android-distribution': 'Release',
};
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function trackedEvidence(directory, item) {
  try {
    const target = realpathSync(path.resolve(directory, item));
    const relative = path.relative(realpathSync(directory), target);
    if (relative.startsWith('..' + path.sep) || path.isAbsolute(relative) ||
        /^(artifacts|\.agent)(\/|$)/.test(relative) || !statSync(target).isFile()) return false;
    execFileSync('git', ['ls-files', '--error-unmatch', '--', relative],
      {cwd: directory, stdio: 'ignore'});
    return true;
  } catch { return false; }
}

export function sourceDigest(directory = root) {
  const files = execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard', '--',
    'packages/liquid-glass', 'example', 'scripts', '.github', 'package.json', 'package-lock.json'],
  {cwd: directory, encoding: 'utf8'}).split('\0').filter(Boolean);
  const hash = createHash('sha256');
  for (const name of [...new Set(files)].sort()) {
    hash.update(name); hash.update('\0');
    hash.update(readFileSync(path.join(directory, name))); hash.update('\0');
  }
  return hash.digest('hex');
}

export function validateAcceptance(record, {version, digest, ref, directory = root}) {
  const errors = [];
  if (record.schemaVersion !== 2) errors.push('Unsupported acceptance schema');
  if (record.scope !== 'iphone-first') errors.push('Release scope must be iphone-first');
  if (record.version !== version) errors.push(`Acceptance version must be ${version}`);
  if (record.sourceDigest !== digest) errors.push('Acceptance source digest is stale or missing');
  if (ref !== undefined && ref !== `refs/tags/v${version}`) errors.push('Publishing requires the matching version tag');
  for (const [id, configuration] of Object.entries({...requiredChecks, ...deferredChecks})) {
    const check = record.checks?.[id];
    const deferred = Object.hasOwn(deferredChecks, id) && check?.status === 'deferred';
    if (check?.status !== 'passed' && !deferred) { errors.push(`${id}: pass or documented permitted deferral required`); continue; }
    if (!check.reviewer?.trim() || !check.device?.trim() || !check.os?.trim() || !check.summary?.trim() ||
        !check.date || !Number.isFinite(Date.parse(check.date))) errors.push(`${id}: reviewer/device/OS/date/summary required`);
    if (!deferred && configuration && check.configuration !== configuration) errors.push(`${id}: ${configuration} evidence required`);
    if (!Array.isArray(check.evidence) || !check.evidence.length) errors.push(`${id}: evidence required`);
    for (const item of check.evidence ?? []) {
      if (typeof item !== 'string' || !item.trim()) { errors.push(`${id}: invalid evidence`); continue; }
      if (item.startsWith('https://')) {
        try { new URL(item); } catch { errors.push(`${id}: invalid evidence URL`); }
      } else {
        if (!trackedEvidence(directory, item)) {
          errors.push(`${id}: evidence must survive a clean clone (tracked report or durable HTTPS URL)`);
        }
      }
    }
  }
  return errors;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const digest = sourceDigest();
  if (process.argv.includes('--print-digest')) console.log(digest);
  else {
    const record = JSON.parse(readFileSync(path.join(root, 'release/acceptance.json'), 'utf8'));
    const pkg = JSON.parse(readFileSync(path.join(root, 'packages/liquid-glass/package.json'), 'utf8'));
    const errors = validateAcceptance(record, {version: pkg.version, digest, ref: process.env.GITHUB_REF});
    if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
    else console.log(`iPhone-first release review recorded for ${pkg.version} (${digest}); deferred checks are not passes`);
  }
}
