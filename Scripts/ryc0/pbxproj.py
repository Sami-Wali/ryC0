#!/usr/bin/env python3
"""Reads LiveContainer.xcodeproj/project.pbxproj (and the xcconfig files it uses)
so the Linux build can follow the Xcode project instead of copying its values.

As a library (used by assemble.py):
    project = Project(repo_root)
    settings = project.settings('LiveProcess', overrides={...})
    settings.get('PRODUCT_BUNDLE_IDENTIFIER')

As a command:
    pbxproj.py snapshot [repo]   prints what the hand-written build depends on
                                 (targets, phases, synced folders, Release settings)
    pbxproj.py check [repo]      compares that with Scripts/ryc0/pbxproj-snapshot.txt
                                 and exits 1 with a diff when they differ

build.sh runs `check` first, so an upstream change to the Xcode project stops the
build until someone has looked at it and updated build.sh or assemble.py to match.
"""
import difflib
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SNAPSHOT = os.path.join(HERE, 'pbxproj-snapshot.txt')
CONFIGURATION = 'Release'


# Old-style (OpenStep) property list parser, which is the format of project.pbxproj.

class _Parser:
    TOKEN = re.compile(r'(?:[A-Za-z0-9_$+.:\-@~<>]|/(?![/*]))+')
    ESCAPES = {'n': '\n', 't': '\t', 'r': '\r', '"': '"', '\\': '\\', "'": "'"}

    def __init__(self, text):
        self.s = text
        self.i = 0

    def fail(self, message):
        line = self.s.count('\n', 0, self.i) + 1
        raise ValueError(f'project.pbxproj line {line}: {message}')

    def skip(self):
        s = self.s
        while self.i < len(s):
            if s[self.i].isspace():
                self.i += 1
            elif s.startswith('//', self.i):
                end = s.find('\n', self.i)
                self.i = len(s) if end < 0 else end
            elif s.startswith('/*', self.i):
                end = s.find('*/', self.i)
                if end < 0:
                    self.fail('unterminated comment')
                self.i = end + 2
            else:
                break

    def expect(self, char):
        self.skip()
        if self.s[self.i:self.i + 1] != char:
            self.fail(f'expected {char!r}, found {self.s[self.i:self.i + 20]!r}')
        self.i += 1

    def value(self):
        self.skip()
        c = self.s[self.i:self.i + 1]
        if c == '{':
            self.i += 1
            d = {}
            while True:
                self.skip()
                if self.s[self.i] == '}':
                    self.i += 1
                    return d
                key = self.value()
                self.expect('=')
                d[key] = self.value()
                self.expect(';')
        if c == '(':
            self.i += 1
            items = []
            while True:
                self.skip()
                if self.s[self.i] == ')':
                    self.i += 1
                    return items
                items.append(self.value())
                self.skip()
                if self.s[self.i] == ',':
                    self.i += 1
        if c == '"':
            self.i += 1
            out = []
            while True:
                ch = self.s[self.i]
                if ch == '"':
                    self.i += 1
                    return ''.join(out)
                if ch == '\\':
                    nxt = self.s[self.i + 1]
                    if nxt == 'U':
                        out.append(chr(int(self.s[self.i + 2:self.i + 6], 16)))
                        self.i += 6
                        continue
                    out.append(self.ESCAPES.get(nxt, nxt))
                    self.i += 2
                    continue
                out.append(ch)
                self.i += 1
        m = self.TOKEN.match(self.s, self.i)
        if not m:
            self.fail(f'unexpected {self.s[self.i:self.i + 20]!r}')
        self.i = m.end()
        return m.group(0)


def parse_pbxproj(text):
    if text.startswith('// !$*UTF8*$!'):
        text = text[text.index('\n'):]
    return _Parser(text).value()


# Build settings, resolved the way Xcode does for one target and configuration.

_VAR = re.compile(r'\$\(([A-Za-z0-9_]+)(?::([A-Za-z0-9_,]+))?\)|\$\{([A-Za-z0-9_]+)(?::([A-Za-z0-9_,]+))?\}')


def _c99ext(value):
    out = re.sub(r'[^A-Za-z0-9_]', '_', value)
    return '_' + out if out[:1].isdigit() else out


class Settings:
    """Layers of build settings, highest priority first. `$(inherited)` and a
    setting that refers to itself both mean the value from the layers below."""

    def __init__(self, layers, builtins):
        self.layers = layers
        self.builtins = builtins

    def raw(self, key, start=0):
        for n in range(start, len(self.layers)):
            if key in self.layers[n]:
                return self.layers[n][key], n
        if key in self.builtins:
            return self.builtins[key], len(self.layers)
        return None, len(self.layers)

    def get(self, key, default=None):
        value, level = self.raw(key)
        if value is None:
            return default
        return self._expand(value, key, level, 0)

    def expand(self, text):
        """Fills in $(VAR) references in text, like an Info.plist template."""
        return self._expand(text, None, 0, 0)

    def _expand(self, value, key, level, depth):
        if depth > 30:
            raise ValueError(f'build setting {key} refers to itself in a loop')
        if isinstance(value, list):
            value = ' '.join(value)

        def sub(m):
            name, mods = (m.group(1), m.group(2)) if m.group(1) else (m.group(3), m.group(4))
            if name == 'inherited' or (key is not None and name == key):
                lower, lower_level = self.raw(key, level + 1) if key else (None, 0)
                text = '' if lower is None else self._expand(lower, key, lower_level, depth + 1)
            else:
                found, found_level = self.raw(name)
                text = '' if found is None else self._expand(found, name, found_level, depth + 1)
            for mod in (mods or '').split(','):
                if mod == 'c99extidentifier':
                    text = _c99ext(text)
                elif mod == 'rfc1034identifier':
                    text = re.sub(r'[^A-Za-z0-9.-]', '-', text)
                elif mod:
                    raise ValueError(f'unsupported build setting modifier :{mod} in {key}')
            return text

        return _VAR.sub(sub, value).strip()

    def keys(self):
        seen = set()
        for layer in self.layers:
            seen.update(layer)
        return sorted(seen)


def parse_xcconfig(path, configuration=CONFIGURATION, _seen=None):
    """Reads an .xcconfig file, following #include and keeping only settings
    whose [config=...] condition matches."""
    _seen = _seen or set()
    if path in _seen:
        return {}
    _seen.add(path)
    out = {}
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.split('//', 1)[0].strip()
            if not line:
                continue
            inc = re.match(r'#include\??\s+"([^"]+)"', line)
            if inc:
                out.update(parse_xcconfig(os.path.join(os.path.dirname(path), inc.group(1)), configuration, _seen))
                continue
            m = re.match(r'([A-Za-z0-9_]+)((?:\[[^\]]*\])*)\s*=\s*(.*)$', line)
            if not m:
                raise ValueError(f'{path}: cannot parse line {line!r}')
            key, conds, value = m.groups()
            ok = True
            for cond in re.findall(r'\[([^\]=]+)=([^\]]*)\]', conds):
                if cond[0] == 'config' and cond[1] != configuration:
                    ok = False
                elif cond[0] == 'sdk' and not cond[1].startswith('iphoneos'):
                    ok = False
            if ok:
                out[key] = value
    return out


class Project:
    def __init__(self, repo):
        self.repo = repo
        self.path = os.path.join(repo, 'LiveContainer.xcodeproj', 'project.pbxproj')
        with open(self.path, encoding='utf-8') as f:
            self.data = parse_pbxproj(f.read())
        self.objects = self.data['objects']
        self.root = self.objects[self.data['rootObject']]

    def obj(self, ident):
        return self.objects[ident]

    def name_of(self, ident):
        o = self.objects.get(ident)
        if o is None:
            return ident
        return o.get('name') or o.get('path') or ident

    def targets(self):
        return [self.obj(t) for t in self.root['targets']]

    def target(self, name):
        for t in self.targets():
            if t['name'] == name:
                return t
        raise KeyError(f'no target named {name} in {self.path}')

    def _config(self, owner, configuration):
        for c in self.obj(owner['buildConfigurationList'])['buildConfigurations']:
            if self.obj(c)['name'] == configuration:
                return self.obj(c)
        raise KeyError(f'no {configuration} configuration')

    def _group_path(self, ident):
        """Path of a group or file reference, relative to the repo."""
        parents = {}
        for k, o in self.objects.items():
            for child in o.get('children', []):
                parents[child] = k
        parts = []
        while ident in self.objects:
            o = self.objects[ident]
            if o.get('path'):
                parts.append(o['path'])
            if o.get('sourceTree') not in (None, '<group>'):
                break
            ident = parents.get(ident)
        return os.path.join(*reversed(parts)) if parts else ''

    def _xcconfig(self, config):
        if 'baseConfigurationReference' in config:
            rel = self._group_path(config['baseConfigurationReference'])
        elif 'baseConfigurationReferenceAnchor' in config:
            rel = os.path.join(self._group_path(config['baseConfigurationReferenceAnchor']),
                               config.get('baseConfigurationReferenceRelativePath', ''))
        else:
            return {}
        return parse_xcconfig(os.path.join(self.repo, rel))

    def settings(self, target_name, overrides=None, configuration=CONFIGURATION):
        target = self.target(target_name)
        tconf = self._config(target, configuration)
        pconf = self._config(self.root, configuration)
        layers = [overrides or {}, tconf['buildSettings'], self._xcconfig(tconf),
                  pconf['buildSettings'], self._xcconfig(pconf)]
        builtins = {
            'TARGET_NAME': target['name'],
            'PROJECT_NAME': 'LiveContainer',
            'CONFIGURATION': configuration,
            'SRCROOT': self.repo,
            'PROJECT_DIR': self.repo,
            'DEVELOPMENT_LANGUAGE': self.root.get('developmentRegion', 'en'),
            'PRODUCT_NAME': '$(TARGET_NAME)',
            'PRODUCT_MODULE_NAME': '$(PRODUCT_NAME:c99extidentifier)',
            'EXECUTABLE_NAME': '$(EXECUTABLE_PREFIX)$(PRODUCT_NAME)$(EXECUTABLE_SUFFIX)',
            'CURRENT_PROJECT_VERSION': '1',
            'MARKETING_VERSION': '1.0',
        }
        return Settings(layers, builtins)

    # What `snapshot` prints: everything about the project the Linux build mirrors.
    def snapshot(self):
        lines = [f'project developmentRegion={self.root.get("developmentRegion")}']
        pconf = self._config(self.root, CONFIGURATION)['buildSettings']
        for k in sorted(pconf):
            if not k.startswith(('CLANG_WARN', 'GCC_WARN', 'CLANG_ANALYZER')):
                lines.append(f'project {k} = {_fmt(pconf[k])}')
        for t in self.targets():
            name = t['name']
            lines.append(f'target {name} type={t.get("productType")}')
            for dep in t.get('dependencies', []):
                d = self.obj(dep)
                if 'target' in d:
                    lines.append(f'  depends {self.obj(d["target"])["name"]}')
            for g in t.get('fileSystemSynchronizedGroups', []):
                lines.append(f'  synced folder {self.name_of(g)}')
            for ph in t.get('buildPhases', []):
                p = self.obj(ph)
                files = []
                for bf in p.get('files', []):
                    b = self.obj(bf)
                    ref = b.get('fileRef') or b.get('productRef')
                    attrs = (b.get('settings') or {}).get('ATTRIBUTES')
                    files.append(self.name_of(ref) + (f'[{",".join(attrs)}]' if attrs else ''))
                extra = ''
                if p['isa'] == 'PBXCopyFilesBuildPhase':
                    extra = f' dst={p.get("dstSubfolderSpec")}:{p.get("dstPath", "")}'
                if p['isa'] == 'PBXShellScriptBuildPhase':
                    extra = ' script=' + repr(p.get('shellScript', ''))
                lines.append(f'  phase {p["isa"]} {p.get("name", "")}{extra} files={files}')
            settings = self._config(t, CONFIGURATION)['buildSettings']
            for k in sorted(settings):
                lines.append(f'  {k} = {_fmt(settings[k])}')
        for k, o in sorted(self.objects.items()):
            if o['isa'] == 'PBXFileSystemSynchronizedRootGroup':
                lines.append(f'synced folder {o.get("path")}')
                for e in o.get('exceptions', []):
                    ex = self.obj(e)
                    who = self.obj(ex['target'])['name'] if 'target' in ex else self.name_of(ex.get('buildPhase', ''))
                    lines.append(f'  {ex["isa"]} {who}: {sorted(ex.get("membershipExceptions", []))}'
                                 + (f' attrs={ex["attributesByRelativePath"]}' if 'attributesByRelativePath' in ex else ''))
        return '\n'.join(lines) + '\n'


def _fmt(v):
    return ' '.join(v) if isinstance(v, list) else v


def main(argv):
    if len(argv) < 2 or argv[1] not in ('snapshot', 'check'):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    repo = os.path.abspath(argv[2] if len(argv) > 2 else os.path.join(HERE, '..', '..'))
    current = Project(repo).snapshot()
    if argv[1] == 'snapshot':
        sys.stdout.write(current)
        return 0
    try:
        with open(SNAPSHOT, encoding='utf-8') as f:
            expected = f.read()
    except FileNotFoundError:
        print(f'error: {SNAPSHOT} is missing; create it with: {argv[0]} snapshot > {SNAPSHOT}', file=sys.stderr)
        return 1
    if current == expected:
        return 0
    sys.stderr.writelines(difflib.unified_diff(expected.splitlines(True), current.splitlines(True),
                                               'pbxproj-snapshot.txt', 'project.pbxproj (now)'))
    print('\nerror: LiveContainer.xcodeproj changed since Scripts/ryc0 was last synced with it.\n'
          'Check whether build.sh or assemble.py need the same change, then refresh the snapshot:\n'
          f'  python3 Scripts/ryc0/pbxproj.py snapshot > Scripts/ryc0/pbxproj-snapshot.txt\n'
          'Set RYC0_ALLOW_PBXPROJ_DRIFT=1 to build anyway.', file=sys.stderr)
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
