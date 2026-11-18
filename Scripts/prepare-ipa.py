#!/usr/bin/env python3
"""Prepare a local Xcode archive for sideloading without a signing account."""

import os
from pathlib import Path
import plistlib
import sys

sys.dont_write_bytecode = True
repo = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(repo / 'Scripts/ryc0'))
from codesign import Signer  # noqa: E402


def main():
    apps = list(Path(sys.argv[1]).glob('*.app'))
    if len(apps) != 1:
        raise SystemExit('Expected one application in Payload.')
    app = apps[0]
    build = os.environ.get('RYC0_NIGHTLY_BUILD_NUMBER')
    if build and (not build.isdecimal() or not 1 <= int(build) <= 9999):
        raise SystemExit('The nightly build number must be between 1 and 9999.')

    for bundle in [app, *app.glob('PlugIns/*.appex')]:
        info_path = bundle / 'Info.plist'
        with info_path.open('rb') as stream:
            info = plistlib.load(stream)
        if build:
            info['CFBundleVersion'] = build
        if bundle == app:
            if value := os.environ.get('RYC0_NIGHTLY_VERSION_INFO'):
                info['LCVersionInfo'] = value
            if value := os.environ.get('RYC0_NIGHTLY_COMMIT'):
                info['RYC0NightlyCommit'] = value
        with info_path.open('wb') as stream:
            plistlib.dump(info, stream, fmt=plistlib.FMT_BINARY)

    for profile in app.rglob('embedded.mobileprovision'):
        profile.unlink()
    with (app / 'Info.plist').open('rb') as stream:
        bundle_id = plistlib.load(stream)['CFBundleIdentifier']
    signer = Signer(str(repo), bundle_id)
    signer.overrides['DEVELOPMENT_TEAM'] = 'AAAAA11111'
    signer.sign_app(str(app))
    for line in signer.log:
        print(line)


if __name__ == '__main__':
    main()
