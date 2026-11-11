#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { mkdir, mkdtemp, rename, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const outputDirectory = path.join(root, 'build');

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd: root, stdio: 'inherit' });
    child.once('error', (error) => reject(new Error(`Cannot run ${command}: ${error.message}`)));
    child.once('exit', (code, signal) => {
      if (code === 0) resolve();
      else reject(new Error(`${command} ${signal ? `was stopped by ${signal}` : `failed (exit ${code})`}.`));
    });
  });
}

async function build() {
  if (!['darwin', 'linux'].includes(process.platform)) {
    throw new Error('Building requires macOS with Xcode or Linux with the toolchain in Scripts/ryc0/README.md.');
  }

  if (process.platform === 'darwin') {
    await run('xcodebuild', ['-version']);
  }
  if (process.env.RYC0_SKIP_SUBMODULE_UPDATE !== '1') {
    await run('git', ['submodule', 'update', '--init', '--recursive']);
  }

  if (process.platform === 'linux') {
    await run('bash', [path.join(root, 'Scripts/ryc0/build.sh')]);
    return;
  }

  await mkdir(outputDirectory, { recursive: true });
  const staging = await mkdtemp(path.join(outputDirectory, '.package-'));
  try {
    const archive = path.join(staging, 'ryC0.xcarchive');
    console.log('\nBuilding ryC0 for iPhone and iPad…');
    await run('xcodebuild', [
      '-quiet', 'archive',
      '-project', path.join(root, 'LiveContainer.xcodeproj'),
      '-scheme', 'LiveContainer',
      '-configuration', 'Release',
      '-sdk', 'iphoneos',
      '-destination', 'generic/platform=iOS',
      '-derivedDataPath', path.join(outputDirectory, 'DerivedData'),
      '-archivePath', archive,
      'CODE_SIGNING_ALLOWED=NO',
    ]);

    // A fresh Payload prevents removed extensions or resources from surviving.
    const payload = path.join(staging, 'Payload');
    const packagedIPA = path.join(staging, 'ryC0.ipa');
    await run('ditto', ['--norsrc', '--noextattr', path.join(archive, 'Products/Applications'), payload]);
    await run('python3', [path.join(root, 'Scripts/prepare-ipa.py'), payload]);
    await run('python3', [path.join(root, 'Scripts/ryc0/verify_sig.py'), '--unsigned-ok', payload]);
    await run('ditto', ['-c', '-k', '--norsrc', '--noextattr', '--keepParent', payload, packagedIPA]);

    const output = path.join(outputDirectory, 'ryC0.ipa');
    await rename(packagedIPA, output);
    console.log(`\nBuilt: ${output}\nSign this IPA with your sideloading tool to install it.`);
  } finally {
    await rm(staging, { recursive: true, force: true });
  }
}

const args = process.argv.slice(2);
if (args.length === 0 || (args.length === 1 && ['help', '--help', '-h'].includes(args[0]))) {
  console.log(`Usage: node Scripts/build-manager.mjs build

Builds a Release IPA, including extensions, and initializes Git submodules.
macOS: requires Xcode; writes build/ryC0.ipa for signing with a sideloading tool.
Linux: uses Scripts/ryc0/build.sh; see Scripts/ryc0/README.md for requirements.`);
} else if (args.length === 1 && args[0] === 'build') {
  try {
    await build();
  } catch (error) {
    console.error(`\nBuild failed: ${error.message}`);
    process.exitCode = 1;
  }
} else {
  console.error('Usage: node Scripts/build-manager.mjs build');
  process.exitCode = 1;
}
