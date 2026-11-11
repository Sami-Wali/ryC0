import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import { run, snapshotSource, withNightlyLock } from '../../Scripts/nightly.mjs';

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
