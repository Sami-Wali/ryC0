#!/usr/bin/env python3
"""Ad-hoc signs a built LiveContainer.app the way Xcode signs the archive the
official CI ships (no signing identity, "Sign to Run Locally"):

- every bundle's main executable and every loose dylib gets a code signature
  with no certificate: one SHA-256 CodeDirectory with 4 KiB pages, an empty
  requirement set and an empty CMS blob;
- the app and extension executables carry the entitlements from their target's
  CODE_SIGN_ENTITLEMENTS file, filled in with the Release settings (team
  AAAAA11111, the private ryC0 app group, the keychain groups), as
  XML and DER;
- each bundle's _CodeSignature/CodeResources seals its other files with Apple's
  iOS rules, and its executable's signature seals Info.plist and CodeResources;
- bundles are signed innermost first, and what Xcode embeds without "Code Sign
  On Copy" (TestJITLess.dylib) stays unsigned.

These signatures can't be installed as they are: a sideloader replaces them with
its own. xtool and other sideloaders read the entitlements from them to decide
what to register (app groups, keychain groups, increased memory limit), which is
why the build signs at all.

Settings come from the environment (see env.sh): RYC0_REPO, RYC0_BUNDLE_ID.

Usage: codesign.py <path to LiveContainer.app>
"""
import hashlib
import os
import plistlib
import re
import struct
import sys

sys.dont_write_bytecode = True  # keep __pycache__ out of the source tree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import macho  # noqa: E402
import pbxproj  # noqa: E402

CSMAGIC_REQUIREMENTS = 0xfade0c01
CSMAGIC_CODEDIRECTORY = 0xfade0c02
CSMAGIC_EMBEDDED_SIGNATURE = 0xfade0cc0
CSMAGIC_EMBEDDED_ENTITLEMENTS = 0xfade7171
CSMAGIC_EMBEDDED_DER_ENTITLEMENTS = 0xfade7172
CSMAGIC_BLOBWRAPPER = 0xfade0b01
CS_ADHOC = 0x2
CD_VERSION = 0x20400  # with the executable segment fields
CD_HEADER_SIZE = 88
HASH_SHA256 = 2
PAGE_SHIFT = 12  # 4 KiB pages, what codesign uses for iOS
SEGMENT_ALIGN = 0x4000  # arm64 VM pages

MH_EXECUTE = 2
LC_SEGMENT_64 = 0x19
LC_UUID = 0x1b
ZEROFILL_TYPES = {0x1, 0xc, 0x12}  # S_ZEROFILL, S_GB_ZEROFILL, S_THREAD_LOCAL_ZEROFILL

# CS_EXECSEG_* flags the kernel takes from a main executable's entitlements.
EXECSEG_MAIN_BINARY = 0x1
EXECSEG_ENTITLEMENT_FLAGS = {
    'get-task-allow': 0x10,
    'com.apple.private.cs.debugger': 0x20,
    'dynamic-codesigning': 0x40,
    'com.apple.private.skip-library-validation': 0x80,
    'com.apple.private.amfi.can-load-cdhash': 0x100,
    'com.apple.private.amfi.can-execute-cdhash': 0x200,
}

# Apple's resource rules for iOS bundles: v1 ("files") and v2 ("files2"). Nested
# frameworks and extensions have no "nested" rule on iOS, so their files are
# sealed like any other resource.
RULES = {
    '^.*': True,
    '^.*\\.lproj/': {'optional': True, 'weight': 1000.0},
    '^.*\\.lproj/locversion.plist$': {'omit': True, 'weight': 1100.0},
    '^Base\\.lproj/': {'weight': 1010.0},
    '^version.plist$': True,
}
RULES2 = {
    '.*\\.dSYM($|/)': {'weight': 11.0},
    '^(.*/)?\\.DS_Store$': {'omit': True, 'weight': 2000.0},
    '^.*': True,
    '^.*\\.lproj/': {'optional': True, 'weight': 1000.0},
    '^.*\\.lproj/locversion.plist$': {'omit': True, 'weight': 1100.0},
    '^Base\\.lproj/': {'weight': 1010.0},
    '^Info\\.plist$': {'omit': True, 'weight': 20.0},
    '^PkgInfo$': {'omit': True, 'weight': 20.0},
    '^embedded\\.provisionprofile$': {'weight': 20.0},
    '^version\\.plist$': {'weight': 20.0},
}
CODE_BUNDLE_SUFFIXES = ('.app', '.appex', '.framework', '.xpc')


class SignError(Exception):
    pass


def align(value, to):
    return (value + to - 1) // to * to


def blob(magic, payload):
    return struct.pack('>II', magic, 8 + len(payload)) + payload


# Entitlements

def _der_length(n):
    if n < 0x80:
        return bytes([n])
    raw = n.to_bytes((n.bit_length() + 7) // 8, 'big')
    return bytes([0x80 | len(raw)]) + raw


def _der(tag, payload):
    return bytes([tag]) + _der_length(len(payload)) + payload


def der_value(value):
    """Apple's DER form of a property list value (CoreEntitlements)."""
    if isinstance(value, bool):
        return _der(0x01, b'\xff' if value else b'\x00')
    if isinstance(value, int):
        return _der(0x02, value.to_bytes(max(1, (value.bit_length() + 8) // 8), 'big', signed=True))
    if isinstance(value, str):
        return _der(0x0c, value.encode())
    if isinstance(value, list):
        return _der(0x30, b''.join(der_value(v) for v in value))
    if isinstance(value, dict):
        entries = (_der(0x30, der_value(k) + der_value(value[k])) for k in sorted(value, key=str.encode))
        return _der(0xb0, b''.join(entries))  # [16] constructed: the dictionary
    raise SignError(f'entitlement value {value!r} has a type DER entitlements cannot hold')


def entitlements_blobs(entitlements):
    """(XML blob, DER blob) for a signature's entitlement slots."""
    xml = plistlib.dumps(entitlements, fmt=plistlib.FMT_XML, sort_keys=True)
    der = _der(0x70, der_value(1) + der_value(entitlements))  # [APPLICATION 16] { version 1, dictionary }
    return blob(CSMAGIC_EMBEDDED_ENTITLEMENTS, xml), blob(CSMAGIC_EMBEDDED_DER_ENTITLEMENTS, der)


def execseg_flags(filetype, entitlements):
    flags = EXECSEG_MAIN_BINARY if filetype == MH_EXECUTE else 0
    for key, flag in EXECSEG_ENTITLEMENT_FLAGS.items():
        if (entitlements or {}).get(key) is True:
            flags |= flag
    return flags


# Mach-O

class MachO:
    """A thin 64-bit Mach-O file opened for signing."""

    def __init__(self, path):
        self.path = path
        with open(path, 'rb') as f:
            self.data = bytearray(f.read())
        magic, _, _, self.filetype, self.ncmds, self.sizeofcmds, _, _ = struct.unpack_from('<IiiIIIII', self.data, 0)
        if magic != macho.MH_MAGIC_64:
            raise SignError(f'{path}: only thin 64-bit Mach-O files can be signed here')
        self.signature_cmd = self.linkedit = self.text = self.uuid = None
        first_section = len(self.data)
        pos = 32
        for _ in range(self.ncmds):
            cmd, size = struct.unpack_from('<II', self.data, pos)
            if cmd == LC_SEGMENT_64:
                name = bytes(self.data[pos + 8:pos + 24]).rstrip(b'\0')
                if name == b'__LINKEDIT':
                    self.linkedit = pos
                elif name == b'__TEXT':
                    self.text = pos
                for n in range(struct.unpack_from('<I', self.data, pos + 64)[0]):
                    section = pos + 72 + n * 80
                    offset = struct.unpack_from('<I', self.data, section + 48)[0]
                    kind = struct.unpack_from('<I', self.data, section + 64)[0] & 0xff
                    if offset and kind not in ZEROFILL_TYPES:
                        first_section = min(first_section, offset)
            elif cmd == macho.LC_CODE_SIGNATURE:
                self.signature_cmd = pos
            elif cmd == LC_UUID:
                self.uuid = bytes(self.data[pos + 8:pos + 24])
            pos += size
        self.header_room = first_section - (32 + self.sizeofcmds)
        if self.linkedit is None or self.text is None:
            raise SignError(f'{path}: no __TEXT or __LINKEDIT segment')

    def segment(self, pos):
        """(fileoff, filesize) of the segment command at pos."""
        return struct.unpack_from('<QQ', self.data, pos + 40)

    def reserve_signature(self, size):
        """Makes room for a signature of `size` bytes at the end of __LINKEDIT,
        replacing an existing one; returns its file offset."""
        linkedit_off, linkedit_size = self.segment(self.linkedit)
        if self.signature_cmd is not None:
            dataoff, datasize = struct.unpack_from('<II', self.data, self.signature_cmd + 8)
            if dataoff + datasize != len(self.data):
                raise SignError(f'{self.path}: the existing signature is not at the end of the file')
            del self.data[dataoff:]
        else:
            if linkedit_off + linkedit_size != len(self.data):
                raise SignError(f'{self.path}: __LINKEDIT does not end the file')
            if self.header_room < 16 or any(self.data[32 + self.sizeofcmds:32 + self.sizeofcmds + 16]):
                raise SignError(f'{self.path}: no room after the load commands for LC_CODE_SIGNATURE')
            self.signature_cmd = 32 + self.sizeofcmds
            self.ncmds += 1
            self.sizeofcmds += 16
            struct.pack_into('<II', self.data, 16, self.ncmds, self.sizeofcmds)
            dataoff = align(len(self.data), 16)
            self.data.extend(bytes(dataoff - len(self.data)))
        struct.pack_into('<IIII', self.data, self.signature_cmd, macho.LC_CODE_SIGNATURE, 16, dataoff, size)
        filesize = dataoff + size - linkedit_off
        struct.pack_into('<Q', self.data, self.linkedit + 32, align(filesize, SEGMENT_ALIGN))  # vmsize
        struct.pack_into('<Q', self.data, self.linkedit + 48, filesize)
        return dataoff


def code_signature(code, filetype, text_segment, identifier, entitlements=None, info_plist=None,
                   code_resources=None, page_shift=PAGE_SHIFT):
    """The embedded signature SuperBlob for `code` (the file up to the signature,
    with its load commands already describing the signature)."""
    requirements = struct.pack('>III', CSMAGIC_REQUIREMENTS, 12, 0)
    ent_xml = ent_der = None
    if entitlements is not None:
        ent_xml, ent_der = entitlements_blobs(entitlements)
    special = {1: info_plist, 2: requirements, 3: code_resources, 5: ent_xml, 7: ent_der}
    n_special = max(slot for slot, data in special.items() if data is not None)
    page = 1 << page_shift
    n_code = (len(code) + page - 1) // page
    ident = identifier.encode() + b'\0'
    hash_offset = CD_HEADER_SIZE + len(ident) + n_special * 32
    length = hash_offset + n_code * 32
    if len(code) >= 1 << 32:
        raise SignError(f'{identifier}: code over 4 GiB')
    header = struct.pack('>IIIIIIIIIBBBBIIIIQQQQ', CSMAGIC_CODEDIRECTORY, length, CD_VERSION, CS_ADHOC,
                         hash_offset, CD_HEADER_SIZE, n_special, n_code, len(code), 32, HASH_SHA256, 0, page_shift,
                         0, 0, 0, 0, 0, text_segment[0], text_segment[1], execseg_flags(filetype, entitlements))
    slots = b''.join(hashlib.sha256(special[s]).digest() if special.get(s) is not None else bytes(32)
                     for s in range(n_special, 0, -1))
    pages = b''.join(hashlib.sha256(code[p * page:(p + 1) * page]).digest() for p in range(n_code))
    directory = header + ident + slots + pages
    blobs = [(0, directory), (2, requirements)]
    blobs += [(5, ent_xml), (7, ent_der)] if entitlements is not None else []
    blobs.append((0x10000, struct.pack('>II', CSMAGIC_BLOBWRAPPER, 8)))  # no CMS for ad-hoc
    offset = 12 + 8 * len(blobs)
    index = b''
    for kind, data in blobs:
        index += struct.pack('>II', kind, offset)
        offset += len(data)
    return struct.pack('>III', CSMAGIC_EMBEDDED_SIGNATURE, offset, len(blobs)) + index + b''.join(d for _, d in blobs)


def signature_size(code_size, identifier, entitlements, info_plist, code_resources, page_shift=PAGE_SHIFT):
    """Bytes code_signature() returns for this much code (it doesn't depend on
    the code's contents)."""
    return len(code_signature(bytes(code_size), MH_EXECUTE, (0, 0), identifier, entitlements,
                              info_plist, code_resources, page_shift))


def loose_identifier(path, image):
    """codesign's default identifier for code outside a bundle: the file name
    without its extension, then "-" and the hex of b"UUID" + LC_UUID."""
    stem = os.path.splitext(os.path.basename(path))[0]
    return f'{stem}-{(b"UUID" + image.uuid).hex()}' if image.uuid else stem


def sign_macho(path, identifier=None, entitlements=None, info_plist=None, code_resources=None):
    image = MachO(path)
    identifier = identifier or loose_identifier(path, image)
    if image.signature_cmd is not None:
        dataoff = struct.unpack_from('<I', image.data, image.signature_cmd + 8)[0]
    else:
        dataoff = align(len(image.data), 16)
    size = align(signature_size(dataoff, identifier, entitlements, info_plist, code_resources), 16)
    if image.reserve_signature(size) != dataoff:
        raise SignError(f'{path}: the signature moved while reserving room for it')
    text = image.segment(image.text)
    sig = code_signature(bytes(image.data[:dataoff]), image.filetype, text, identifier, entitlements,
                         info_plist, code_resources)
    image.data.extend(sig + bytes(size - len(sig)))
    mode = os.stat(path).st_mode
    with open(path, 'wb') as f:
        f.write(image.data)
    os.chmod(path, mode)
    return identifier


# Bundles

def _rule(rules, path):
    best, best_weight = None, -1.0
    for pattern, value in rules.items():
        if re.search(pattern, path):
            weight = value.get('weight', 1.0) if isinstance(value, dict) else 1.0
            if weight > best_weight:
                best, best_weight = value, weight
    return best if isinstance(best, dict) else {}


def code_resources(bundle, executable):
    """_CodeSignature/CodeResources for a bundle whose nested code is signed."""
    files, files2 = {}, {}
    for root, dirs, names in os.walk(bundle):
        dirs.sort()
        for name in sorted(names):
            full = os.path.join(root, name)
            rel = os.path.relpath(full, bundle)
            if full == executable or rel.startswith('_CodeSignature/'):
                continue
            if os.path.islink(full):
                raise SignError(f'{full}: symlinks are not supported')
            with open(full, 'rb') as f:
                data = f.read()
            sha1, sha256 = hashlib.sha1(data).digest(), hashlib.sha256(data).digest()
            rule = _rule(RULES, rel)
            if not rule.get('omit'):
                files[rel] = {'hash': sha1, 'optional': True} if rule.get('optional') else sha1
            rule = _rule(RULES2, rel)
            if not rule.get('omit'):
                files2[rel] = {'hash2': sha256, **({'optional': True} if rule.get('optional') else {})}
    xml = plistlib.dumps({'files': files, 'files2': files2, 'rules': RULES, 'rules2': RULES2},
                         fmt=plistlib.FMT_XML, sort_keys=True)
    return re.sub(rb'<real>(\d+)\.0</real>', rb'<real>\1</real>', xml)  # codesign writes 1000, not 1000.0


def nested_bundles(bundle):
    """Code bundles directly inside bundle (not inside a nested one)."""
    out = []
    for root, dirs, _ in os.walk(bundle):
        for d in sorted(dirs):
            path = os.path.join(root, d)
            if d.endswith(CODE_BUNDLE_SUFFIXES) and os.path.isfile(os.path.join(path, 'Info.plist')):
                out.append(path)
        dirs[:] = [d for d in dirs if os.path.join(root, d) not in out]
    return out


class Signer:
    def __init__(self, repo, bundle_id):
        self.project = pbxproj.Project(repo)
        self.repo = repo
        # AppIdentifierPrefix is what Xcode puts before keychain groups: the team and a dot.
        self.overrides = {'LIVECONTAINER_BUNDLE_IDENTIFIER': bundle_id,
                          'AppIdentifierPrefix': '$(DEVELOPMENT_TEAM).', 'TeamIdentifierPrefix': '$(DEVELOPMENT_TEAM).'}
        self.targets = {t['name'] for t in self.project.targets()}
        self.unsigned = unsigned_copies(self.project)
        self.log = []

    def entitlements(self, target):
        """The target's CODE_SIGN_ENTITLEMENTS with its build settings filled in,
        or None if it has none."""
        if target not in self.targets:
            return None
        settings = self.project.settings(target, self.overrides)
        name = settings.get('CODE_SIGN_ENTITLEMENTS')
        if not name:
            return None
        with open(os.path.join(self.repo, name), 'rb') as f:
            entitlements = plistlib.load(f)
        filled = _substitute(entitlements, settings)
        left = re.findall(r'\$[({][A-Za-z_]+', repr(filled))
        if left:
            raise SignError(f'{name}: unresolved {", ".join(sorted(set(left)))}')
        return filled

    def sign_bundle(self, bundle, target):
        for nested in nested_bundles(bundle):
            self.sign_bundle(nested, os.path.splitext(os.path.basename(nested))[0])
        with open(os.path.join(bundle, 'Info.plist'), 'rb') as f:
            info = plistlib.load(f)
        executable = os.path.join(bundle, info['CFBundleExecutable'])
        inner = nested_bundles(bundle)
        for root, dirs, names in os.walk(bundle):
            dirs[:] = sorted(d for d in dirs if os.path.join(root, d) not in inner)
            for name in sorted(names):
                path = os.path.join(root, name)
                if path == executable or not macho.is_macho(path):
                    continue
                if name in self.unsigned:
                    self.log.append(f'{os.path.relpath(path, self.app)}: left unsigned, like Xcode (no Code Sign On Copy)')
                    continue
                identifier = sign_macho(path)
                self.log.append(f'{os.path.relpath(path, self.app)}: {identifier}')
        resources = code_resources(bundle, executable)
        os.makedirs(os.path.join(bundle, '_CodeSignature'), exist_ok=True)
        with open(os.path.join(bundle, '_CodeSignature', 'CodeResources'), 'wb') as f:
            f.write(resources)
        entitlements = self.entitlements(target)
        with open(os.path.join(bundle, 'Info.plist'), 'rb') as f:
            info_plist = f.read()
        sign_macho(executable, info['CFBundleIdentifier'], entitlements, info_plist, resources)
        what = f'{len(entitlements)} entitlements' if entitlements is not None else 'no entitlements'
        self.log.append(f'{os.path.relpath(executable, self.app)}: {info["CFBundleIdentifier"]}, {what}')

    def sign_app(self, app):
        self.app = app
        self.sign_bundle(app, 'LiveContainer')


def _substitute(value, settings):
    if isinstance(value, str):
        return settings.expand(value)
    if isinstance(value, list):
        return [_substitute(v, settings) for v in value]
    if isinstance(value, dict):
        return {k: _substitute(v, settings) for k, v in value.items()}
    return value


def unsigned_copies(project):
    """Names of the loose files the app target embeds without Code Sign On Copy.
    Xcode signs frameworks and extensions when their own targets build, but a
    plain dylib only when it is copied with that attribute."""
    out = set()
    for phase in project.target('LiveContainer').get('buildPhases', []):
        p = project.obj(phase)
        if p['isa'] != 'PBXCopyFilesBuildPhase':
            continue
        for ident in p.get('files', []):
            f = project.obj(ident)
            name = os.path.basename(project.name_of(f.get('fileRef') or f.get('productRef')))
            attributes = (f.get('settings') or {}).get('ATTRIBUTES', [])
            if 'CodeSignOnCopy' not in attributes and not name.endswith(CODE_BUNDLE_SUFFIXES + ('.xcframework',)):
                out.add(name)
    return out


def main():
    if len(sys.argv) != 2 or not os.path.isdir(sys.argv[1]):
        sys.exit(__doc__.strip())
    app = os.path.abspath(sys.argv[1])
    signer = Signer(os.environ['RYC0_REPO'], os.environ['RYC0_BUNDLE_ID'])
    try:
        signer.sign_app(app)
    except SignError as e:
        sys.exit(f'error: {e}')
    for line in signer.log:
        print(f'  {line}')


if __name__ == '__main__':
    main()
