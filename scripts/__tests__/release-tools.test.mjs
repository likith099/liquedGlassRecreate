import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, mkdirSync, writeFileSync, rmSync, symlinkSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {parsePackResult, packageName} from '../lib/pack-result.mjs';
import {requiredChecks, deferredChecks, validateAcceptance} from '../check-release-acceptance.mjs';

const entry = {name: packageName, version: '0.1.2', files: [{path: 'LICENSE'}]};
for (const [shape, value] of Object.entries({array: [entry], bare: entry, keyed: {[packageName]: entry}})) {
  test(`pack result: ${shape}`, () => assert.deepEqual(parsePackResult('npm notice\n' + JSON.stringify(value)), entry));
}
test('pack result rejects wrong package and missing file lists', () => {
  assert.throws(() => parsePackResult(JSON.stringify([{...entry, name: 'unrelated'}])));
  assert.throws(() => parsePackResult(JSON.stringify({name: packageName})));
  assert.throws(() => parsePackResult('not JSON'));
});
function completeRecord() {
  return {schemaVersion: 2, scope: 'iphone-first', version: '0.1.2', sourceDigest: 'tested-source', checks:
    Object.fromEntries(Object.entries({...requiredChecks, ...deferredChecks}).map(([id, configuration]) => [id, {
      status: 'passed', reviewer: 'Reviewer', device: 'Recorded device', os: 'Recorded OS', date: '2026-09-20',
      summary: 'Acceptance reviewed', configuration: configuration ?? 'Debug', evidence: ['https://example.com/results'],
    }]))};
}
const context = {version: '0.1.2', digest: 'tested-source', ref: 'refs/tags/v0.1.2'};
test('complete acceptance passes only for matching source, version and tag', () => {
  assert.deepEqual(validateAcceptance(completeRecord(), context), []);
  for (const override of [{version: '0.1.3'}, {digest: 'changed-source'}, {ref: 'refs/heads/main'}]) {
    assert.ok(validateAcceptance(completeRecord(), {...context, ...override}).length);
  }
});
test('every category needs a result or an explicit permitted deferral', () => {
  for (const id of Object.keys({...requiredChecks, ...deferredChecks})) {
    const record = completeRecord(); record.checks[id].status = 'pending';
    assert.ok(validateAcceptance(record, context).some(error => error.startsWith(id + ':')));
    delete record.checks[id];
    assert.ok(validateAcceptance(record, context).some(error => error.startsWith(id + ':')));
  }
});
test('Debug profiling, unsigned evidence gaps and local-only artifacts cannot satisfy acceptance', () => {
  const record = completeRecord();
  record.checks['ios-current-profile'].configuration = 'Debug';
  record.checks['ios-distribution'].evidence = [];
  record.checks['rtl-ios'].evidence = ['artifacts/rtl.txt'];
  record.checks.talkback.reviewer = '';
  const errors = validateAcceptance(record, context);
  for (const id of ['ios-current-profile', 'ios-distribution', 'rtl-ios', 'talkback']) assert.ok(errors.some(e => e.startsWith(id)));
});

test('local evidence must be a tracked report, including after path normalization', () => {
  const directory = mkdtempSync(path.join(tmpdir(), 'alg-evidence-'));
  try {
    execFileSync('git', ['init', '-q', directory]);
    for (const folder of ['release', 'artifacts']) mkdirSync(path.join(directory, folder));
    for (const file of ['release/review.md', 'release/untracked.md', 'artifacts/local.md']) {
      writeFileSync(path.join(directory, file), 'Reviewed evidence');
    }
    symlinkSync('../artifacts/local.md', path.join(directory, 'release/linked.md'));
    execFileSync('git', ['add', 'release/review.md', 'release/linked.md'], {cwd: directory});
    const record = completeRecord();
    record.checks.talkback.evidence = ['release/review.md'];
    assert.deepEqual(validateAcceptance(record, {...context, directory}), []);
    for (const item of ['release/untracked.md', 'release', 'release/../artifacts/local.md', 'release/linked.md']) {
      record.checks.talkback.evidence = [item];
      assert.ok(validateAcceptance(record, {...context, directory}).some(e => e.startsWith('talkback:')));
    }
  } finally { rmSync(directory, {recursive: true, force: true}); }
});

test('owner-deferred manual/device checks do not block the iPhone-first release', () => {
  const record = completeRecord();
  for (const id of Object.keys(deferredChecks)) {
    record.checks[id].status = 'deferred';
    record.checks[id].summary = 'Owner deferred this check; no pass claimed';
  }
  assert.deepEqual(validateAcceptance(record, context), []);
  record.checks['ios-source-review'].status = 'deferred';
  assert.ok(validateAcceptance(record, context).some(e => e.startsWith('ios-source-review:')));
});

test('deferrals still require a reviewer, explanation and durable record', () => {
  const record = completeRecord();
  record.checks.ipad.status = 'deferred';
  record.checks.ipad.summary = '';
  record.checks.ipad.evidence = [];
  assert.ok(validateAcceptance(record, context).some(e => e.startsWith('ipad:')));
  record.scope = 'unknown';
  assert.ok(validateAcceptance(record, context).some(e => e.includes('scope')));
});
