#!/usr/bin/env python3
"""Turns the binaries build.sh linked into a complete LiveContainer.app, doing the
resource steps Xcode would:

- Info.plist for the app and every framework and extension in it, with the build
  variables filled in from project.pbxproj and its xcconfig files, the
  INFOPLIST_KEY_* settings merged for targets that generate their Info.plist, and
  the keys Xcode adds to every bundle (MinimumOSVersion, platform, device family,
  required arm64, and the SDK the binaries record, RYC0_RECORDED_SDK).
- Localizable.xcstrings compiled into <lang>.lproj/Localizable.strings and
  .stringsdict, with English filling in any string a language is missing.
- The app's resources from the Resources folder, the *.lproj folders the Xcode Run
  Script copies, and LCVersionInfo, which that script adds.
- No asset catalog compiler exists on Linux, so the app icon and images become loose
  PNG files. Asset catalog colors are skipped (the code falls back to system colors).
- The prebuilt OpenSSL and CydiaSubstrate frameworks, without headers.
- The license texts the About page shows, in Licenses/, as the Xcode target's Run
  Script copies them.
- RYC0_URL_SCHEME as the main app's first URL scheme, and RYC0_DISPLAY_NAME as the
  name of the app and of its share extension, which the share sheet shows.
- LaunchAppExtension's Metadata.appintents, which Xcode extracts from the
  extension's App Intents code and no Linux tool can; it is kept by hand in
  gen/LaunchAppExtension (build.sh stops when that code changes).

Settings come from the environment (see env.sh): RYC0_REPO, RYC0_BUNDLE_ID,
RYC0_DISPLAY_NAME, RYC0_URL_SCHEME, RYC0_MIN_IOS, RYC0_SDK, RYC0_SDK_VERSION,
RYC0_RECORDED_SDK, RYC0_OPENSSL, RYC0_VERSION_INFO.

Usage: assemble.py <path to LiveContainer.app>
"""
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True  # keep __pycache__ out of the source tree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pbxproj  # noqa: E402

ENV = os.environ
REPO = ENV['RYC0_REPO']
MIN_IOS = ENV['RYC0_MIN_IOS']
SDK_VERSION = ENV['RYC0_SDK_VERSION']
RECORDED_SDK = ENV['RYC0_RECORDED_SDK']
GEN = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'gen')
PROJECT = pbxproj.Project(REPO)
# The app's bundle ID comes from this xcconfig variable; extensions append to it.
OVERRIDES = {'LIVECONTAINER_BUNDLE_IDENTIFIER': ENV['RYC0_BUNDLE_ID'],
             'RYC0_SOURCE_URL': ENV.get('RYC0_SOURCE_URL', 'https://github.com/Sami-Wali/ryC0')}
URL_SCHEME = ENV.get('RYC0_URL_SCHEME') or 'ryc0'
# The license texts the About page shows (LCLicense.swift), named as the app's
# Licenses folder holds them, from each project's own LICENSE file. The Xcode
# target's Run Script copies the same files, and every .txt in Resources/Licenses
# (the licenses the source doesn't otherwise hold) after them.
LICENSES = {
    'ryC0.txt': 'LICENSE',
    'OpenSSL.txt': 'OpenSSL/LICENSE.txt',
    'ElleKit.txt': 'Resources/Frameworks/CydiaSubstrate.framework/LICENSE',
    'litehook.txt': 'litehook/LICENSE',
}
LICENSES_FOLDER = 'Resources/Licenses'
PACKAGE_TYPES = {
    'com.apple.product-type.application': 'APPL',
    'com.apple.product-type.framework': 'FMWK',
    'com.apple.product-type.app-extension': 'XPC!',
    'com.apple.product-type.extensionkit-extension': 'XPC!',
}


def fail(message):
    sys.exit(f'error: {message}')


def note(message):
    print(f'  {message}')


def write_plist(path, data):
    with open(path, 'wb') as f:
        plistlib.dump(data, f, fmt=plistlib.FMT_BINARY, sort_keys=True)


def read_plist(path):
    with open(path, 'rb') as f:
        return plistlib.load(f)


# Info.plist

def sdk_build():
    try:
        return read_plist(os.path.join(ENV['RYC0_SDK'], 'System/Library/CoreServices/SystemVersion.plist'))['ProductBuildVersion']
    except (OSError, KeyError):
        return None


SDK_BUILD = sdk_build()


def substitute(value, settings):
    if isinstance(value, str):
        return settings.expand(value)
    if isinstance(value, list):
        return [substitute(v, settings) for v in value]
    if isinstance(value, dict):
        return {k: substitute(v, settings) for k, v in value.items()}
    return value


def infoplist_keys(settings):
    """The INFOPLIST_KEY_* build settings as Info.plist entries, typed the way
    Xcode types them."""
    out = {}
    for name in settings.keys():
        if not name.startswith('INFOPLIST_KEY_'):
            continue
        key = name[len('INFOPLIST_KEY_'):]
        value = settings.get(name, '')
        if value == '':
            continue  # Xcode leaves out empty values
        if key.endswith('Dictionary'):
            # A build setting can't hold a dictionary, and Xcode drops these: the
            # project sets NSLocationTemporaryUsageDescriptionDictionary to a
            # string, where CoreLocation expects a dictionary.
            continue
        if key.endswith('_Generation'):
            fail(f'{name} is not supported by assemble.py yet; add it')
        key = re.sub(r'_iPad$', '~ipad', re.sub(r'_iPhone$', '~iphone', key))
        if key.startswith('UISupportedInterfaceOrientations'):
            value = value.split()
        elif value in ('YES', 'NO'):
            value = value == 'YES'
        out[key] = value
    return out


def bundle_keys(settings):
    """Keys Xcode adds to every bundle's Info.plist when it processes it. The SDK
    keys name the SDK the binaries record (RYC0_RECORDED_SDK); its build number is
    only known when that is the SDK in use."""
    keys = {
        'CFBundleSupportedPlatforms': ['iPhoneOS'],
        'MinimumOSVersion': MIN_IOS,
        'UIDeviceFamily': [int(x) for x in settings.get('TARGETED_DEVICE_FAMILY', '1,2').split(',')],
        'UIRequiredDeviceCapabilities': ['arm64'],
        'DTPlatformName': 'iphoneos',
        'DTPlatformVersion': RECORDED_SDK,
        'DTSDKName': f'iphoneos{RECORDED_SDK}',
    }
    if SDK_BUILD and RECORDED_SDK == SDK_VERSION:
        keys['DTSDKBuild'] = SDK_BUILD
    return keys


def make_info_plist(target_name, bundle_dir):
    target = PROJECT.target(target_name)
    settings = PROJECT.settings(target_name, OVERRIDES)
    package_type = PACKAGE_TYPES[target['productType']]
    info = {}
    if settings.get('GENERATE_INFOPLIST_FILE') == 'YES':
        info.update({
            'CFBundleDevelopmentRegion': settings.get('DEVELOPMENT_LANGUAGE'),
            'CFBundleExecutable': settings.get('EXECUTABLE_NAME'),
            'CFBundleIdentifier': settings.get('PRODUCT_BUNDLE_IDENTIFIER'),
            'CFBundleInfoDictionaryVersion': '6.0',
            'CFBundleName': settings.get('PRODUCT_NAME'),
            'CFBundlePackageType': package_type,
            'CFBundleShortVersionString': settings.get('MARKETING_VERSION'),
            'CFBundleVersion': settings.get('CURRENT_PROJECT_VERSION'),
        })
        info.update(infoplist_keys(settings))
    template = settings.get('INFOPLIST_FILE')
    if template:
        info.update(substitute(read_plist(os.path.join(REPO, template)), settings))
    info.update(bundle_keys(settings))
    exe = info.get('CFBundleExecutable')
    if not exe or not os.path.isfile(os.path.join(bundle_dir, exe)):
        fail(f'{bundle_dir}: CFBundleExecutable {exe!r} was not built')
    return info


def main_app_plist(app):
    info = make_info_plist('LiveContainer', app)
    # No Assets.car: name loose icon files the way actool lists them, keeping the
    # array shapes LCUtils.m edits for the grey multi-LiveContainer icon.
    info.pop('CFBundleIconName', None)
    info['CFBundleIcons'] = {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['AppIcon60x60']}}
    # AppIcon83.5x83.5 is the iPad Pro and other all-screen iPads' Home Screen size.
    info['CFBundleIcons~ipad'] = {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['AppIcon60x60', 'AppIcon76x76', 'AppIcon83.5x83.5']}}
    info['CFBundleIconFile'] = 'AppIcon'
    names = alternate_icon_names()
    if names:
        info['CFBundleIcons']['CFBundleAlternateIcons'] = {
            name: {'CFBundleIconFiles': [f'AppIcon{name}60x60']} for name in names}
        info['CFBundleIcons~ipad']['CFBundleAlternateIcons'] = {
            name: {'CFBundleIconFiles': [f'AppIcon{name}60x60', f'AppIcon{name}76x76', f'AppIcon{name}83.5x83.5']}
            for name in names}
    # What the Xcode target's Run Script adds: "$CONFIGURATION ($BRANCH/$COMMIT)".
    info['LCVersionInfo'] = ENV.get('RYC0_VERSION_INFO') or 'Release (unknown/unknown)'
    if ENV.get('RYC0_DISPLAY_NAME'):
        info['CFBundleDisplayName'] = ENV['RYC0_DISPLAY_NAME']
    set_url_scheme(info)
    write_plist(os.path.join(app, 'Info.plist'), info)
    with open(os.path.join(app, 'PkgInfo'), 'w') as f:
        f.write('APPL????')
    note(f'Info.plist: {info["CFBundleIdentifier"]}, "{info.get("CFBundleDisplayName")}", {URL_SCHEME}://, '
         f'{info["LCVersionInfo"]}')


def set_url_scheme(info):
    """RYC0_URL_SCHEME in place of the scheme the Info.plist declares first, which
    the app reads as its own (LCSharedUtils.hostAppUrlScheme), and in the
    queried schemes, where the app asks about itself."""
    types = info.get('CFBundleURLTypes') or [{}]
    schemes = types[0].get('CFBundleURLSchemes') or []
    if not schemes:
        fail('Info.plist: the first CFBundleURLTypes entry declares no URL scheme')
    old = schemes[0]
    schemes[0] = URL_SCHEME
    info['LSApplicationQueriesSchemes'] = [URL_SCHEME if s == old else s
                                           for s in info.get('LSApplicationQueriesSchemes', [])]


def nested_bundles(app):
    """(target name, bundle path) for every framework and extension build.sh made."""
    out = []
    for folder, suffix in (('Frameworks', '.framework'), ('PlugIns', '.appex'), ('Extensions', '.appex')):
        root = os.path.join(app, folder)
        if not os.path.isdir(root):
            continue
        for entry in sorted(os.listdir(root)):
            if entry.endswith(suffix) and entry[:-len(suffix)] in {t['name'] for t in PROJECT.targets()}:
                out.append((entry[:-len(suffix)], os.path.join(root, entry)))
    return out


# Prebuilt frameworks, embedded the way Xcode's "Remove Headers on Copy" does.

def copy_prebuilt(app):
    prebuilt = [os.path.join(ENV['RYC0_OPENSSL'], 'OpenSSL.framework'),  # OpenSSL.xcframework's ios-arm64 slice
                os.path.join(REPO, 'Resources/Frameworks/CydiaSubstrate.framework')]
    for src in prebuilt:
        dst = os.path.join(app, 'Frameworks', os.path.basename(src))
        shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(src, dst, ignore=shutil.ignore_patterns('Headers', 'PrivateHeaders', 'Modules', '_CodeSignature'))
        note(f'Frameworks/{os.path.basename(src)} (prebuilt)')


# License texts

def copy_licenses(app):
    dst = os.path.join(app, 'Licenses')
    os.makedirs(dst, exist_ok=True)
    sources = dict(LICENSES)
    folder = os.path.join(REPO, LICENSES_FOLDER)
    for entry in sorted(os.listdir(folder)):
        if entry.endswith('.txt'):
            sources[entry] = os.path.join(LICENSES_FOLDER, entry)
    for name, src in sources.items():
        path = os.path.join(REPO, src)
        if not os.path.isfile(path):
            fail(f'{src} is missing (the license text for Licenses/{name})')
        shutil.copyfile(path, os.path.join(dst, name))
    note(f'Licenses/: {", ".join(sorted(sources))}')


# String catalog

FORMAT_SPEC = re.compile(r'%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?(hh|h|ll|l|q|z|t|j)?([@dDuUxXoOfeEgGcCsSpaA])')


def value_type(text, key):
    found = FORMAT_SPEC.findall(text)
    if len(found) != 1:
        fail(f'Localizable.xcstrings: plural form of {key!r} needs exactly one format specifier, has {len(found)}')
    return ''.join(found[0])


def plural_forms(variations, key):
    if set(variations) != {'plural'}:
        fail(f'Localizable.xcstrings: {key!r} uses {sorted(variations)} variations; only plural is supported')
    return {form: v['stringUnit']['value'] for form, v in variations['plural'].items()}


def compile_entry(key, loc):
    """One catalog localization as ('strings', text) or ('stringsdict', dict)."""
    if 'variations' in loc:
        forms = plural_forms(loc['variations'], key)
        spec = value_type(forms.get('other') or next(iter(forms.values())), key)
        return 'stringsdict', {
            'NSStringLocalizedFormatKey': '%#@value@',
            'value': {'NSStringFormatSpecTypeKey': 'NSStringPluralRuleType', 'NSStringFormatValueTypeKey': spec, **forms},
        }
    text = loc['stringUnit']['value']
    if 'substitutions' not in loc:
        return 'strings', text
    entry = {}
    for name, sub in loc['substitutions'].items():
        num, spec = sub.get('argNum', 1), sub.get('formatSpecifier', 'lld')
        forms = plural_forms(sub['variations'], key)
        entry[name] = {'NSStringFormatSpecTypeKey': 'NSStringPluralRuleType', 'NSStringFormatValueTypeKey': spec,
                       **{f: t.replace('%arg', f'%{num}${spec}') for f, t in forms.items()}}
        text = re.sub(r'%#@' + re.escape(name) + '@', f'%{num}$#@{name}@', text)
    entry['NSStringLocalizedFormatKey'] = text
    return 'stringsdict', entry


def compile_string_catalog(app, path):
    with open(path, encoding='utf-8') as f:
        catalog = json.load(f)
    source = catalog.get('sourceLanguage', 'en')
    entries = catalog['strings']
    languages = sorted({lang for e in entries.values() for lang in e.get('localizations', {})} | {source})
    fallbacks = []
    for lang in languages:
        strings, plurals, filled = {}, {}, 0
        for key, entry in entries.items():
            locs = entry.get('localizations', {})
            loc = locs.get(lang)
            if loc is None:
                loc = locs.get(source)
                filled += 1
            if loc is None:
                strings[key] = key  # Xcode's fallback for a key nobody localized
                continue
            kind, value = compile_entry(key, loc)
            (strings if kind == 'strings' else plurals)[key] = value
        folder = os.path.join(app, f'{lang}.lproj')
        os.makedirs(folder, exist_ok=True)
        write_plist(os.path.join(folder, 'Localizable.strings'), strings)
        if plurals:
            write_plist(os.path.join(folder, 'Localizable.stringsdict'), plurals)
        if filled and lang != source:
            fallbacks.append(f'{lang} {filled}')
    note(f'{os.path.basename(path)}: {len(entries)} keys in {len(languages)} languages')
    if fallbacks:
        note(f'untranslated strings filled in from {source}: {", ".join(fallbacks)}')


# The icons Settings > Home Screen offers instead of the app icon

ALTERNATE_ICONS = os.path.join(REPO, 'Resources', 'AppIcons')


def alternate_icon_names():
    """The name iOS switches to for each icon Scripts/ryc0/art/render-icon.sh
    rendered into Resources/AppIcons, like Blue for AppIconBlue60x60@2x.png."""
    if not os.path.isdir(ALTERNATE_ICONS):
        return []
    found = (re.fullmatch(r'AppIcon(\w+)60x60@2x\.png', f) for f in os.listdir(ALTERNATE_ICONS))
    return sorted({m.group(1) for m in found if m})


def copy_alternate_icons(app):
    """Copies the icons into the app's root, where iOS looks for the files
    CFBundleAlternateIcons names."""
    if not os.path.isdir(ALTERNATE_ICONS):
        return
    files = sorted(f for f in os.listdir(ALTERNATE_ICONS) if f.endswith('.png'))
    for name in files:
        shutil.copyfile(os.path.join(ALTERNATE_ICONS, name), os.path.join(app, name))
    note(f'Resources/AppIcons: {len(files)} alternate icon PNGs ({", ".join(alternate_icon_names())})')


# Asset catalog (no actool on Linux)

def magick(*args):
    tool = shutil.which('magick') or shutil.which('convert')
    subprocess.run([tool, *args], check=True)


def app_icon_source(appiconset):
    with open(os.path.join(appiconset, 'Contents.json'), encoding='utf-8') as f:
        images = json.load(f)['images']
    for image in images:
        if image.get('filename') and not image.get('appearances') and image.get('idiom') in ('universal', 'ios-marketing'):
            return os.path.join(appiconset, image['filename'])
    fail(f'{appiconset}: no light-appearance universal icon')


def compile_asset_catalog(app, catalog, icon_name):
    skipped = []
    for entry in sorted(os.listdir(catalog)):
        path = os.path.join(catalog, entry)
        name, kind = os.path.splitext(entry)
        if kind == '.appiconset' and name == icon_name:
            src = app_icon_source(path)
            for out, px in (('AppIcon60x60@2x.png', 120), ('AppIcon60x60@3x.png', 180),
                            ('AppIcon76x76@2x~ipad.png', 152), ('AppIcon83.5x83.5@2x~ipad.png', 167),
                            ('AppIcon.png', 1024)):
                magick(src, '-resize', f'{px}x{px}', '-strip', os.path.join(app, out))
            note(f'{entry}: loose AppIcon PNGs (no dark or tinted variants without Assets.car)')
        elif kind == '.imageset':
            with open(os.path.join(path, 'Contents.json'), encoding='utf-8') as f:
                images = json.load(f)['images']
            for image in images:
                if 'filename' not in image:
                    continue
                scale = image.get('scale', '1x')
                out = os.path.join(app, f'{name}.png' if scale == '1x' else f'{name}@{scale}.png')
                if not os.path.exists(out):
                    shutil.copyfile(os.path.join(path, image['filename']), out)
        elif kind in ('.colorset', '.appiconset'):
            skipped.append(entry)
        elif os.path.isdir(path):
            fail(f'{path}: assemble.py does not handle {kind or "folder"} entries in asset catalogs')
    if skipped:
        note(f'skipped (needs Assets.car): {", ".join(skipped)}')


# The app's resources, as the Xcode project assigns them.

def app_resources():
    """Files in synced folders that the Xcode project adds to the LiveContainer
    target (the Resources folder belongs to no target and lists its members)."""
    app_target = PROJECT.target('LiveContainer')
    owned = {g for t in PROJECT.targets() for g in t.get('fileSystemSynchronizedGroups', [])}
    out = []
    for ident, o in PROJECT.objects.items():
        if o['isa'] != 'PBXFileSystemSynchronizedRootGroup' or ident in owned:
            continue
        for ex in o.get('exceptions', []):
            ex = PROJECT.obj(ex)
            if ex['isa'] == 'PBXFileSystemSynchronizedBuildFileExceptionSet' and \
                    PROJECT.obj(ex['target']) is app_target:
                out += [os.path.join(REPO, o['path'], m) for m in ex['membershipExceptions']]
    return out


def copy_resources(app):
    settings = PROJECT.settings('LiveContainer', OVERRIDES)
    icon_name = settings.get('ASSETCATALOG_COMPILER_APPICON_NAME', 'AppIcon')
    for src in app_resources():
        name = os.path.basename(src)
        if name.endswith('.xcassets'):
            compile_asset_catalog(app, src, icon_name)
        elif name.endswith('.xcstrings'):
            compile_string_catalog(app, src)
        elif os.path.isdir(src):
            shutil.copytree(src, os.path.join(app, name), dirs_exist_ok=True)
        else:
            shutil.copyfile(src, os.path.join(app, name))
    # The Run Script's `cp -n -r Resources/*.lproj`: InfoPlist.strings for each language.
    res = os.path.join(REPO, 'Resources')
    for entry in sorted(os.listdir(res)):
        if entry.endswith('.lproj'):
            for root, _, files in os.walk(os.path.join(res, entry)):
                dst_dir = os.path.join(app, os.path.relpath(root, res))
                os.makedirs(dst_dir, exist_ok=True)
                for f in files:
                    if not os.path.exists(os.path.join(dst_dir, f)):
                        shutil.copyfile(os.path.join(root, f), os.path.join(dst_dir, f))
    copy_alternate_icons(app)


def check_no_variables(app):
    bad = []
    for root, _, files in os.walk(app):
        for f in files:
            if f == 'Info.plist':
                path = os.path.join(root, f)
                if re.search(rb'\$[({][A-Za-z_]', open(path, 'rb').read()):
                    bad.append(os.path.relpath(path, app))
    if bad:
        fail('unresolved $(...) build variables left in ' + ', '.join(bad))


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__.strip())
    app = os.path.abspath(sys.argv[1])
    copy_prebuilt(app)
    for target_name, bundle in nested_bundles(app):
        info = make_info_plist(target_name, bundle)
        if target_name == 'ShareExtension' and ENV.get('RYC0_DISPLAY_NAME'):
            info['CFBundleDisplayName'] = ENV['RYC0_DISPLAY_NAME']  # the share sheet names the app by it
        write_plist(os.path.join(bundle, 'Info.plist'), info)
        note(f'{os.path.relpath(bundle, app)}: {info["CFBundleIdentifier"]}')
        intents = os.path.join(GEN, target_name, 'Metadata.appintents')
        if os.path.isdir(intents):
            shutil.copytree(intents, os.path.join(bundle, 'Metadata.appintents'), dirs_exist_ok=True)
            note(f'{os.path.relpath(bundle, app)}/Metadata.appintents (from Scripts/ryc0/gen/{target_name})')
    copy_resources(app)
    copy_licenses(app)
    main_app_plist(app)
    check_no_variables(app)


if __name__ == '__main__':
    main()
