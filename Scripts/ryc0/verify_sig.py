#!/usr/bin/env python3
"""Checks the code signatures in a signed app the way iOS does before it trusts
the code, for every part that doesn't need Apple's certificate chain:

- every Mach-O slice has a signature, and each CodeDirectory's page hashes match
  the file's bytes;
- the special slots match what they seal: Info.plist, the requirements, the
  bundle's CodeResources and the entitlements (XML and DER);
- a bundle's main executable is signed with the bundle's CFBundleIdentifier;
- each bundle's _CodeSignature/CodeResources matches the files it lists (hashes
  of resources, CodeDirectory hashes of nested code), and every file in the
  bundle is either listed or covered by a nested signature.

With --unsigned-ok, a Mach-O without a signature passes when its bundle seals it
as a resource, the way Xcode leaves TestJITLess.dylib (check.py says which ones
may be unsigned).

Usage: verify_sig.py [--unsigned-ok] <Payload folder or .app>
"""
import hashlib
import os
import plistlib
import struct
import sys

sys.dont_write_bytecode = True  # keep __pycache__ out of the source tree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import macho  # noqa: E402

HASHES = {1: hashlib.sha1, 2: hashlib.sha256, 3: hashlib.sha256, 4: hashlib.sha384}  # 3 is SHA-256 truncated
SLOT_NAMES = {1: 'Info.plist', 2: 'requirements', 3: 'CodeResources', 5: 'entitlements', 7: 'DER entitlements'}
# Files Apple's rules leave out of CodeResources in every bundle.
UNSEALED = {'Info.plist', 'PkgInfo', '_CodeSignature/CodeResources'}

failures = []
unsigned_ok = False


def fail(message):
    failures.append(message)
    print(f'  FAIL  {message}')


def be32(data, offset):
    return struct.unpack_from('>I', data, offset)[0]


class Signature:
    """The code signature of one Mach-O slice."""

    def __init__(self, image, path):
        self.path = path
        offset, size = image.signature
        blob = image.data[offset:offset + size]
        if be32(blob, 0) != 0xfade0cc0:
            raise ValueError('not an embedded signature SuperBlob')
        self.code = image.data[image.offset:]
        self.blobs = {}
        self.directories = []
        for i in range(be32(blob, 8)):
            kind, off = struct.unpack_from('>II', blob, 12 + i * 8)
            data = blob[off:off + be32(blob, off + 4)]
            self.blobs[kind] = data
            if be32(data, 0) == 0xfade0c02:
                self.directories.append(data)

    def cdhashes(self):
        return {HASHES[cd[37]](cd).digest()[:20] for cd in self.directories}

    def check(self, info_plist, code_resources):
        """Verifies every CodeDirectory; returns (identifier, summary)."""
        summary = []
        identifier = None
        for cd in self.directories:
            version, flags, hash_off, ident_off, n_special, n_code, code_limit = struct.unpack_from('>IIIIIII', cd, 8)
            hash_size, hash_type, _, page_shift = cd[36], cd[37], cd[38], cd[39]
            algo = HASHES[hash_type]
            identifier = cd[ident_off:cd.index(b'\0', ident_off)].decode()
            page = 1 << page_shift if page_shift else code_limit
            bad = [p for p in range(n_code)
                   if algo(self.code[p * page:min((p + 1) * page, code_limit)]).digest()[:hash_size]
                   != cd[hash_off + p * hash_size:hash_off + (p + 1) * hash_size]]
            if bad:
                fail(f'{self.path}: {len(bad)} of {n_code} code pages do not match ({algo().name})')
            sealed = {1: info_plist, 2: self.blobs.get(2), 3: code_resources, 5: self.blobs.get(5), 7: self.blobs.get(7)}
            bound = []
            for slot in range(1, n_special + 1):
                stored = cd[hash_off - slot * hash_size:hash_off - (slot - 1) * hash_size]
                if not any(stored):
                    continue
                source = sealed.get(slot)
                if source is None:
                    fail(f'{self.path}: special slot {slot} ({SLOT_NAMES.get(slot, "?")}) is set but nothing to match')
                elif algo(source).digest()[:hash_size] != stored:
                    fail(f'{self.path}: {SLOT_NAMES.get(slot, slot)} does not match its signature slot')
                else:
                    bound.append(SLOT_NAMES.get(slot, str(slot)))
            summary.append(f'{algo().name} v{version:#x} flags={flags:#x} {n_code} pages'
                           + (f' + {", ".join(bound)}' if bound else ''))
        if not self.directories:
            fail(f'{self.path}: no CodeDirectory')
        extras = [name for kind, name in ((5, 'entitlements'), (7, 'DER entitlements'), (0x10000, 'CMS'))
                  if kind in self.blobs]
        return identifier, '; '.join(summary) + (f' [{", ".join(extras)}]' if extras else '')


def read(path):
    with open(path, 'rb') as f:
        return f.read()


def bundle_of(path, bundles):
    """The innermost bundle folder holding path."""
    best = None
    for b in bundles:
        if path.startswith(b + os.sep) and (best is None or len(b) > len(best)):
            best = b
    return best


def check_binaries(root, bundles):
    """Checks every Mach-O; returns {path: set of cdhashes} for CodeResources."""
    cdhashes = {}
    main_executables = {}
    for b in bundles:
        info_path = os.path.join(b, 'Info.plist')
        if os.path.isfile(info_path):
            with open(info_path, 'rb') as f:
                info = plistlib.load(f)
            main_executables[os.path.join(b, info.get('CFBundleExecutable', ''))] = (b, info)
    for dirpath, _, files in os.walk(root):
        for name in sorted(files):
            path = os.path.join(dirpath, name)
            if not macho.is_macho(path):
                continue
            rel = os.path.relpath(path, root)
            owner = main_executables.get(path)
            info_plist = read(os.path.join(owner[0], 'Info.plist')) if owner else None
            resources_path = os.path.join(owner[0], '_CodeSignature', 'CodeResources') if owner else None
            code_resources = read(resources_path) if resources_path and os.path.isfile(resources_path) else None
            hashes = set()
            for image in macho.images(path):
                if not image.signature:
                    if unsigned_ok and owner is None:
                        print(f'  ok    {rel}: unsigned, sealed as a resource')
                    else:
                        fail(f'{rel}: not signed')
                    continue
                try:
                    sig = Signature(image, rel)
                except ValueError as e:
                    fail(f'{rel}: {e}')
                    continue
                identifier, summary = sig.check(info_plist, code_resources)
                hashes |= sig.cdhashes()
                if owner and identifier != owner[1].get('CFBundleIdentifier'):
                    fail(f'{rel}: signed as {identifier}, but the bundle is {owner[1].get("CFBundleIdentifier")}')
                print(f'  ok    {rel}: {identifier}: {summary}')
            cdhashes[path] = hashes
    return cdhashes


def check_resources(bundle, bundles, cdhashes):
    rel_bundle = os.path.basename(bundle)
    path = os.path.join(bundle, '_CodeSignature', 'CodeResources')
    if not os.path.isfile(path):
        return fail(f'{rel_bundle}: no _CodeSignature/CodeResources')
    with open(path, 'rb') as f:
        resources = plistlib.load(f)
    files2 = resources.get('files2', {})
    nested = [b for b in bundles if b != bundle and bundle_of(b, bundles) == bundle]
    with open(os.path.join(bundle, 'Info.plist'), 'rb') as f:
        executable = os.path.join(bundle, plistlib.load(f).get('CFBundleExecutable', ''))
    checked = 0
    for name, entry in files2.items():
        target = os.path.join(bundle, name)
        if not isinstance(entry, dict) or 'symlink' in entry:
            continue
        if 'cdhash' in entry:
            code = target
            if os.path.isdir(target):
                with open(os.path.join(target, 'Info.plist'), 'rb') as f:
                    code = os.path.join(target, plistlib.load(f)['CFBundleExecutable'])
            if entry['cdhash'] not in cdhashes.get(code, set()):
                fail(f'{rel_bundle}: CodeResources has a stale cdhash for {name}')
        elif 'hash2' in entry:
            if not os.path.isfile(target):
                if not entry.get('optional'):
                    fail(f'{rel_bundle}: CodeResources lists {name}, which is missing')
                continue
            if hashlib.sha256(read(target)).digest() != entry['hash2']:
                fail(f'{rel_bundle}: {name} does not match its CodeResources hash')
        checked += 1
    unsealed = []
    for dirpath, _, files in os.walk(bundle):
        for name in files:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, bundle)
            if full == executable or rel in UNSEALED or rel in files2:
                continue
            if any(full.startswith(n + os.sep) for n in nested):
                continue
            unsealed.append(rel)
    if unsealed:
        fail(f'{rel_bundle}: {len(unsealed)} files not sealed by CodeResources: {", ".join(sorted(unsealed)[:10])}')
    print(f'  ok    {rel_bundle}/_CodeSignature/CodeResources: {checked} entries match')


def main():
    global unsigned_ok
    args = sys.argv[1:]
    if args[:1] == ['--unsigned-ok']:
        unsigned_ok = True
        args = args[1:]
    if len(args) != 1 or not os.path.isdir(args[0]):
        sys.exit(__doc__.strip())
    root = os.path.abspath(args[0])
    bundles = []
    for dirpath, dirs, _ in os.walk(root):
        for d in dirs:
            if d.endswith(('.app', '.appex', '.framework')):
                bundles.append(os.path.join(dirpath, d))
    if root.endswith(('.app', '.appex', '.framework')):
        bundles.append(root)
    print(f'Verifying signatures in {root}')
    cdhashes = check_binaries(root, bundles)
    for bundle in sorted(bundles):
        if not bundle.endswith('.framework') or os.path.isdir(os.path.join(bundle, '_CodeSignature')):
            check_resources(bundle, bundles, cdhashes)
    if failures:
        sys.exit(f'error: {len(failures)} signature problem(s)')
    print(f'All {sum(1 for h in cdhashes.values() if h)} signed binaries and {len(bundles)} bundles verified')


if __name__ == '__main__':
    main()
