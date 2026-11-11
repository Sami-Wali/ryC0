#!/usr/bin/env node
import { spawn, spawnSync } from 'node:child_process';
import { copyFile, mkdir, open, readFile, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repository = 'Sami-Wali/ryC0';
const output = path.join(root, 'build/nightly');
// Git exports repository-specific variables to hooks. They must not redirect
// commands intended for the isolated build checkout into the user's checkout.
const environment = { ...process.env };
const localVariables = spawnSync('git', ['rev-parse', '--local-env-vars'], { encoding: 'utf8', cwd: root });
for (const key of localVariables.stdout?.trim().split('\n') ?? []) delete environment[key];

export function run(command, args, { cwd = root, env = {}, log, quiet = false } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd, env: { ...environment, ...env },
      stdio: ['ignore', log ?? 'pipe', log ?? (quiet ? 'pipe' : 'inherit')],
    });
    let text = '';
    child.stdout?.on('data', (chunk) => { text += chunk; });
    child.once('error', reject);
    child.once('close', (code, signal) => {
      if (code === 0) resolve(text.trim());
      else reject(new Error(`${command} ${args[0] ?? ''} failed (${signal ?? code}).${log ? ' See the nightly build log.' : ''}`));
    });
  });
}

export async function snapshotSource(source, destination, commit) {
  await mkdir(path.dirname(destination), { recursive: true });
  try {
    await stat(path.join(destination, '.git'));
  } catch {
    await run('git', ['clone', '--shared', '--no-checkout', '--quiet', source, destination]);
  }
  await run('git', ['checkout', '--detach', '--quiet', commit], { cwd: destination });
  const entries = await run('git', ['ls-files', '--stage', '-z'], { cwd: destination });
  for (const entry of entries.split('\0')) {
    const module = /^160000 ([a-f0-9]+) 0\t(.+)$/s.exec(entry);
    if (module) {
      await snapshotSource(path.join(source, module[2]), path.join(destination, module[2]), module[1]);
    }
  }
}

async function withLock(action) {
  await mkdir(output, { recursive: true });
  const name = path.join(output, 'publish.lock');
  let lock;
  try {
    lock = await open(name, 'wx');
  } catch (error) {
    if (error.code !== 'EEXIST') throw error;
    const owner = Number(await readFile(name, 'utf8'));
    if (!Number.isInteger(owner) || owner < 1) throw new Error('A nightly build is starting. Retry when it finishes.');
    try {
      process.kill(owner, 0);
    } catch (probe) {
      if (probe.code !== 'ESRCH') throw probe;
      await rm(name);
      return withLock(action);
    }
    throw new Error(`A nightly build is already running (process ${owner}).`);
  }
  try {
    await lock.writeFile(String(process.pid));
    return await action();
  } finally {
    await lock.close();
    await rm(name, { force: true });
  }
}

async function install() {
  if (process.platform !== 'darwin') throw new Error('Install nightly builds on your Mac.');
  const existing = await run('git', ['config', '--get', 'core.hooksPath'], { quiet: true }).catch(() => '');
  if (existing && existing !== '.githooks') throw new Error(`Existing Git hooks are configured at ${existing}; preserve them before installing.`);
  await run('gh', ['auth', 'status']);
  await run('git', ['config', '--local', 'ryc0.nodePath', process.execPath]);
  await run('git', ['config', '--local', 'core.hooksPath', '.githooks']);
  console.log('Local Nightly enabled after commits and local merges. Builds run on this Mac.');
}

async function publish(auto) {
  if (process.platform !== 'darwin') {
    if (auto) return;
    throw new Error('Nightly builds require your Mac and Xcode.');
  }
  const branch = await run('git', ['symbolic-ref', '--quiet', '--short', 'HEAD'], { quiet: true }).catch(() => '');
  if (!branch) {
    if (auto) return;
    throw new Error('Check out a branch before publishing a nightly.');
  }
  const commit = await run('git', ['rev-parse', 'HEAD']);
  const date = (await run('git', ['show', '-s', '--format=%cs', commit])).replaceAll('-', '');
  const tag = `nightly-${date}-${commit.slice(0, 8)}`;
  const directory = path.join(output, tag);

  return withLock(async () => {
    await run('gh', ['auth', 'status']);
    const existing = await run('gh', ['release', 'view', tag, '--repo', repository, '--json', 'url,assets'], { quiet: true }).catch(() => '');
    if (existing && JSON.parse(existing).assets.some((asset) => asset.name.endsWith('.ipa'))) {
      console.log(`Nightly already published: ${JSON.parse(existing).url}`);
      return;
    }
    const origin = await run('git', ['remote', 'get-url', '--push', 'origin']);
    if (!/^https:\/\/github\.com\/Sami-Wali\/ryC0(?:\.git)?\/?$/.test(origin)
        && !/^git@github\.com:Sami-Wali\/ryC0(?:\.git)?$/.test(origin)) {
      throw new Error('origin must point to Sami-Wali/ryC0 before publishing.');
    }
    await mkdir(directory, { recursive: true });
    const source = path.join(output, 'source');
    await run('git', ['submodule', 'update', '--init', '--recursive']);
    await snapshotSource(root, source, commit);
    const count = Number(await run('git', ['rev-list', '--count', commit]));
    const baseBuild = Number(await run('/usr/libexec/PlistBuddy', ['-c', 'Print :CFBundleVersion', path.join(source, 'LiveContainer/Info.plist')]));
    const build = String(baseBuild + count);
    const logPath = path.join(directory, 'build.log');
    console.log(`Building ${tag} on this Mac. Log: ${logPath}`);
    const log = await open(logPath, 'w');
    try {
      await run(process.execPath, [path.join(source, 'Scripts/build-manager.mjs'), 'build'], {
        cwd: source, log: log.fd,
        env: {
          RYC0_SKIP_SUBMODULE_UPDATE: '1', RYC0_NIGHTLY_BUILD_NUMBER: build,
          RYC0_NIGHTLY_COMMIT: commit, RYC0_NIGHTLY_VERSION_INFO: `Nightly (${branch}/${commit.slice(0, 8)})`,
        },
      });
    } finally {
      await log.close();
    }
    const ipa = path.join(directory, `ryC0-${tag}.ipa`);
    await copyFile(path.join(source, 'build/ryC0.ipa'), ipa);
    // Publishing the exact SHA prevents edits made during the build from
    // changing what is uploaded, and uses a normal, non-forced branch push.
    await run('git', ['push', '--set-upstream', 'origin', `${commit}:refs/heads/${branch}`]);
    const notes = path.join(directory, 'release-notes.md');
    await writeFile(notes, `Nightly built locally on macOS.\n\nCommit: ${commit}\nBranch: ${branch}\nBuild: ${build}\n\nSign the IPA with your sideloading tool before installing.\n`);
    let url;
    if (existing) {
      await run('gh', ['release', 'upload', tag, ipa, '--repo', repository, '--clobber']);
      url = JSON.parse(existing).url;
    } else {
      url = await run('gh', ['release', 'create', tag, ipa, '--repo', repository,
        '--target', commit, '--prerelease', '--latest=false', '--title', `ryC0 ${tag}`,
        '--notes-file', notes]);
    }
    await writeFile(path.join(directory, 'release.json'), JSON.stringify({ commit, branch, tag, build, ipa, url }, null, 2) + '\n');
    console.log(`Nightly published: ${url}`);
  });
}

async function main() {
  const [command = 'help', ...args] = process.argv.slice(2);
  if (command === 'install') await install();
  else if (command === 'publish') await publish(args.includes('--auto'));
  else if (['help', '--help', '-h'].includes(command)) {
    console.log('Usage: node Scripts/nightly.mjs install|publish\n\ninstall: enable local Nightly after commits and merges on this Mac.\npublish: build the committed source locally, push it, and publish a GitHub prerelease.');
  } else throw new Error(`Unknown command: ${command}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => { console.error(`Nightly failed: ${error.message}`); process.exitCode = 1; });
}
