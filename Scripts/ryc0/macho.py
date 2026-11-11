"""Just enough Mach-O parsing for check.py, verify_sig.py and codesign.py: load
commands, sections, the export trie and the code signature. Handles thin and fat
files."""
import struct

MH_MAGIC_64 = 0xfeedfacf
FAT_MAGIC = 0xcafebabe
CPU_ARM64 = 0x0100000c
FILETYPES = {2: 'executable', 6: 'dylib', 8: 'bundle'}
PLATFORMS = {2: 'iOS', 1: 'macOS', 6: 'Mac Catalyst', 7: 'iOS Simulator'}

LC_SEGMENT_64 = 0x19
LC_CODE_SIGNATURE = 0x1d
LC_ID_DYLIB = 0xd
LC_LOAD_DYLIB = 0xc
LC_LOAD_WEAK_DYLIB = 0x80000018
LC_REEXPORT_DYLIB = 0x8000001f
LC_RPATH = 0x8000001c
LC_DYLD_INFO = 0x22
LC_DYLD_INFO_ONLY = 0x80000022
LC_DYLD_EXPORTS_TRIE = 0x80000033
LC_MAIN = 0x80000028
LC_BUILD_VERSION = 0x32
LC_VERSION_MIN_IPHONEOS = 0x25


def is_macho(path):
    try:
        with open(path, 'rb') as f:
            head = f.read(4)
    except OSError:
        return False
    return len(head) == 4 and (struct.unpack('<I', head)[0] == MH_MAGIC_64 or struct.unpack('>I', head)[0] == FAT_MAGIC)


def version(packed):
    major, minor, patch = packed >> 16, (packed >> 8) & 0xff, packed & 0xff
    return f'{major}.{minor}.{patch}' if patch else f'{major}.{minor}'


def _uleb(data, i):
    result = shift = 0
    while True:
        b = data[i]
        i += 1
        result |= (b & 0x7f) << shift
        shift += 7
        if b < 0x80:
            return result, i


class Image:
    """One architecture slice of a Mach-O file."""

    def __init__(self, data, offset, path):
        self.data, self.offset, self.path = data, offset, path
        magic, self.cputype, _, self.filetype, ncmds, _, self.flags, _ = struct.unpack_from('<IiiIIIII', data, offset)
        if magic != MH_MAGIC_64:
            raise ValueError(f'{path}: not a 64-bit Mach-O slice')
        self.commands = []
        pos = offset + 32
        for _ in range(ncmds):
            cmd, size = struct.unpack_from('<II', data, pos)
            self.commands.append((cmd, pos, size))
            pos += size

    def command(self, cmd):
        return next(((pos, size) for c, pos, size in self.commands if c == cmd), None)

    def _string(self, pos, size, name_offset_at=8):
        name_off = struct.unpack_from('<I', self.data, pos + name_offset_at)[0]
        raw = self.data[pos + name_off:pos + size]
        return raw.split(b'\0', 1)[0].decode()

    @property
    def build_version(self):
        """(platform, minos, sdk) from LC_BUILD_VERSION or LC_VERSION_MIN_IPHONEOS."""
        c = self.command(LC_BUILD_VERSION)
        if c:
            platform, minos, sdk = struct.unpack_from('<III', self.data, c[0] + 8)
            return PLATFORMS.get(platform, str(platform)), version(minos), version(sdk)
        c = self.command(LC_VERSION_MIN_IPHONEOS)
        if c:
            minos, sdk = struct.unpack_from('<II', self.data, c[0] + 8)
            return 'iOS', version(minos), version(sdk)
        return None

    @property
    def install_name(self):
        c = self.command(LC_ID_DYLIB)
        return self._string(*c) if c else None

    @property
    def dylibs(self):
        return [self._string(pos, size) for cmd, pos, size in self.commands
                if cmd in (LC_LOAD_DYLIB, LC_LOAD_WEAK_DYLIB, LC_REEXPORT_DYLIB)]

    @property
    def rpaths(self):
        return [self._string(pos, size) for cmd, pos, size in self.commands if cmd == LC_RPATH]

    @property
    def has_main(self):
        return self.command(LC_MAIN) is not None

    @property
    def entry_offset(self):
        """LC_MAIN's entry point, as an offset from the start of the slice."""
        c = self.command(LC_MAIN)
        return struct.unpack_from('<Q', self.data, c[0] + 8)[0] if c else None

    def sections(self):
        """(segment, section, file offset, size) of every section."""
        out = []
        for cmd, pos, _ in self.commands:
            if cmd != LC_SEGMENT_64:
                continue
            for n in range(struct.unpack_from('<I', self.data, pos + 64)[0]):
                s = pos + 72 + n * 80
                sect, seg = (self.data[s + i:s + i + 16].split(b'\0', 1)[0].decode() for i in (0, 16))
                size, = struct.unpack_from('<Q', self.data, s + 40)
                offset, = struct.unpack_from('<I', self.data, s + 48)
                out.append((seg, sect, offset, size))
        return out

    @property
    def signature(self):
        """(offset, size) of the code signature in the file, or None."""
        c = self.command(LC_CODE_SIGNATURE)
        if not c:
            return None
        dataoff, datasize = struct.unpack_from('<II', self.data, c[0] + 8)
        return self.offset + dataoff, datasize

    def signature_blobs(self):
        """{slot type: blob} from the embedded signature (empty when unsigned)."""
        if not self.signature:
            return {}
        offset, size = self.signature
        superblob = self.data[offset:offset + size]
        blobs = {}
        for n in range(struct.unpack_from('>I', superblob, 8)[0]):
            kind, at = struct.unpack_from('>II', superblob, 12 + n * 8)
            blobs[kind] = superblob[at:at + struct.unpack_from('>I', superblob, at + 4)[0]]
        return blobs

    def exports(self):
        """Names in the export trie: what dlsym and the dynamic linker can see."""
        return set(self.export_offsets())

    def export_offsets(self):
        """{name: offset from the image's start} for the export trie (None for
        re-exports)."""
        c = self.command(LC_DYLD_EXPORTS_TRIE)
        if c:
            off, size = struct.unpack_from('<II', self.data, c[0] + 8)
        else:
            c = self.command(LC_DYLD_INFO_ONLY) or self.command(LC_DYLD_INFO)
            if not c:
                return set()
            off, size = struct.unpack_from('<II', self.data, c[0] + 40)
        trie = self.data[self.offset + off:self.offset + off + size]
        names, stack = {}, [(0, '')] if trie else []
        while stack:
            node, prefix = stack.pop()
            terminal_size, i = _uleb(trie, node)
            if terminal_size:
                flags, j = _uleb(trie, i)
                names[prefix] = None if flags & 0x8 else _uleb(trie, j)[0]  # 0x8: EXPORT_SYMBOL_FLAGS_REEXPORT
            i += terminal_size
            children = trie[i]
            i += 1
            for _ in range(children):
                end = trie.index(b'\0', i)
                edge = trie[i:end].decode()
                child, i = _uleb(trie, end + 1)
                stack.append((child, prefix + edge))
        return names


def images(path):
    """Every arm64 (or other) slice in a Mach-O file."""
    with open(path, 'rb') as f:
        data = f.read()
    if struct.unpack_from('>I', data, 0)[0] == FAT_MAGIC:
        count = struct.unpack_from('>I', data, 4)[0]
        out = []
        for n in range(count):
            _, _, offset, _, _ = struct.unpack_from('>iiIII', data, 8 + n * 20)
            out.append(Image(data, offset, path))
        return out
    return [Image(data, 0, path)]

