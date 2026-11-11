import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import { nightlyRetentionPlan, pruneNightlies, run, snapshotSource, verifyPublishedNightly, withNightlyLock } from '../../Scripts/nightly.mjs';

async function repository(directory) {
  await mkdir(directory, { recursive: true });
  await run('git', ['init', '--quiet', directory]);
  await run('git', ['config', 'user.name', 'Nightly Test'], { cwd: directory });
  await run('git', ['config', 'user.email', 'nightly@example.invalid'], { cwd: directory });
}

async function commit(directory) {
  await run('git', ['add', '-A'], { cwd: directory });
  await run('git', ['-c', 'core.hooksPath=/dev/null', 'commit', '--quiet', '-m', 'Test source snapshot'], { cwd: directory });
  return run('git', ['rev-parse', 'HEAD'], { cwd: directory });
}

test('snapshot builds committed files without changing uncommitted edits', async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), 'ryc0-nightly-'));
  try {
    const source = path.join(temporary, 'source'), snapshot = path.join(temporary, 'snapshot');
    await repository(source);
    await writeFile(path.join(source, 'app.txt'), 'committed');
    const first = await commit(source);
    await writeFile(path.join(source, 'app.txt'), 'work in progress');
    await snapshotSource(source, snapshot, first);
    assert.equal(await readFile(path.join(snapshot, 'app.txt'), 'utf8'), 'committed');
    assert.equal(await readFile(path.join(source, 'app.txt'), 'utf8'), 'work in progress');
    const next = await commit(source);
    await snapshotSource(source, snapshot, next);
    assert.equal(await readFile(path.join(snapshot, 'app.txt'), 'utf8'), 'work in progress');
    assert.equal(await run('git', ['rev-parse', 'HEAD'], { cwd: source }), next);
    assert.equal(await run('git', ['rev-parse', 'HEAD'], { cwd: snapshot }), next);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test('submodules use the pinned commit instead of dirty working files', async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), 'ryc0-nightly-module-'));
  try {
    const dependency = path.join(temporary, 'dependency');
    const source = path.join(temporary, 'source'), snapshot = path.join(temporary, 'snapshot');
    await repository(dependency);
    await writeFile(path.join(dependency, 'library.txt'), 'pinned dependency');
    await commit(dependency);
    await repository(source);
    await run('git', ['-c', 'protocol.file.allow=always', 'submodule', 'add', '--quiet', dependency, 'library'], { cwd: source });
    const head = await commit(source);
    await writeFile(path.join(source, 'library/library.txt'), 'uncommitted dependency');
    await snapshotSource(source, snapshot, head);
    assert.equal(await readFile(path.join(snapshot, 'library/library.txt'), 'utf8'), 'pinned dependency');
    assert.equal(await readFile(path.join(source, 'library/library.txt'), 'utf8'), 'uncommitted dependency');
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test('overlapping nightly requests wait instead of losing the next commit', async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), 'ryc0-nightly-lock-'));
  const events = [];
  let release;
  const gate = new Promise((resolve) => { release = resolve; });
  let started;
  const firstStarted = new Promise((resolve) => { started = resolve; });
  try {
    const first = withNightlyLock(temporary, async () => {
      events.push('first-start');
      started();
      await gate;
      events.push('first-end');
    });
    await firstStarted;
    const second = withNightlyLock(temporary, async () => { events.push('second'); });
    await new Promise((resolve) => setTimeout(resolve, 25));
    assert.deepEqual(events, ['first-start']);
    release();
    await Promise.all([first, second]);
    assert.deepEqual(events, ['first-start', 'first-end', 'second']);
    await assert.rejects(readFile(path.join(temporary, 'publish.lock')), { code: 'ENOENT' });
  } finally {
    release();
    await rm(temporary, { recursive: true, force: true });
  }
});

function nightly(tag, published, overrides = {}) {
  return {
    tag_name: tag, published_at: published, prerelease: true, draft: false,
    assets: [{ name: `ryC0-${tag}.ipa`, state: 'uploaded', size: 10 }],
    ...overrides,
  };
}

test('retention keeps the newest complete Nightly and protects stable or draft releases', () => {
  const old = nightly('nightly-20261111-11111111', '2026-11-11T08:00:00Z');
  const newest = nightly('nightly-20261111-22222222', '2026-11-11T09:00:00Z');
  const incomplete = nightly('nightly-20261111-33333333', '2026-11-11T10:00:00Z', { assets: [] });
  assert.deepEqual(nightlyRetentionPlan([
    old, incomplete, newest,
    nightly('nightly-20261111-44444444', '2026-11-10T08:00:00Z', { prerelease: false }),
    nightly('nightly-20261111-55555555', '2026-11-10T08:00:00Z', { draft: true }),
    nightly('v1.1', '2026-11-10T08:00:00Z'),
  ]), { keep: newest.tag_name, remove: [old.tag_name] });
  assert.equal(nightlyRetentionPlan([incomplete]), null);
});

test('cleanup deletes old Nightlies and owned build folders while retaining build sources', async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), 'ryc0-nightly-retention-'));
  const old = nightly('nightly-20261111-11111111', '2026-11-11T08:00:00Z');
  const newest = nightly('nightly-20261111-22222222', '2026-11-11T09:00:00Z');
  const stable = nightly('nightly-20261111-55555555', '2026-11-10T08:00:00Z', { prerelease: false });
  const deleted = [];
  try {
    for (const folder of [old.tag_name, newest.tag_name, stable.tag_name, 'source', 'nightly-20261111-aaaaaaaa']) {
      await mkdir(path.join(temporary, folder));
    }
    await writeFile(path.join(temporary, old.tag_name, 'build.log'), 'old build');
    await writeFile(path.join(temporary, newest.tag_name, 'release.json'), '{}');
    await writeFile(path.join(temporary, stable.tag_name, 'release.json'), '{}');
    await pruneNightlies(temporary, async (command, args) => {
      if (args[0] === 'api') return JSON.stringify([[old, stable], [newest]]);
      assert.equal(command, 'gh');
      assert.deepEqual(args.slice(0, 2), ['release', 'delete']);
      assert.ok(args.includes('--cleanup-tag'));
      deleted.push(args[2]);
      return '';
    });
    assert.deepEqual(deleted, [old.tag_name]);
    await assert.rejects(readFile(path.join(temporary, old.tag_name, 'build.log')), { code: 'ENOENT' });
    assert.equal(await readFile(path.join(temporary, newest.tag_name, 'release.json'), 'utf8'), '{}');
    assert.equal(await readFile(path.join(temporary, stable.tag_name, 'release.json'), 'utf8'), '{}');
    await mkdir(path.join(temporary, 'source/still-present'));
    await mkdir(path.join(temporary, 'nightly-20261111-aaaaaaaa/still-present'));
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test('an incomplete or mismatched upload cannot pass verification', async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), 'ryc0-nightly-upload-'));
  const tag = 'nightly-20261111-22222222';
  const ipa = path.join(temporary, `ryC0-${tag}.ipa`);
  try {
    await writeFile(ipa, 'IPA');
    const release = nightly(tag, '2026-11-11T09:00:00Z');
    const execute = async () => JSON.stringify(release);
    await assert.rejects(verifyPublishedNightly(tag, ipa, execute), /previous Nightly releases have been kept/);
    release.assets[0].size = 3;
    release.assets[0].digest = 'sha256:wrong';
    await assert.rejects(verifyPublishedNightly(tag, ipa, execute), /previous Nightly releases have been kept/);
    release.assets[0].digest = `sha256:${createHash('sha256').update('IPA').digest('hex')}`;
    release.assets[0].state = 'starter';
    await assert.rejects(verifyPublishedNightly(tag, ipa, execute), /previous Nightly releases have been kept/);
    release.assets[0].state = 'uploaded';
    await verifyPublishedNightly(tag, ipa, execute);
    await pruneNightlies(temporary, async (command, args) => {
      assert.equal(args[0], 'api');
      return JSON.stringify([[{ ...release, assets: [] }]]);
    });
    assert.equal(await readFile(ipa, 'utf8'), 'IPA');
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});
