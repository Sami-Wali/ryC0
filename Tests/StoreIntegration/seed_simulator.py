#!/usr/bin/env python3
"""Seed only the isolated storetest app for repeatable end-to-end UI tests."""
import argparse
import datetime
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import zipfile

p = argparse.ArgumentParser()
p.add_argument('simulator')
p.add_argument('fixtures', type=Path)
a = p.parse_args()
bundle = 'com.ry0.ryC0.storetest'
subprocess.run(['xcrun','simctl','terminate',a.simulator,bundle],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
root = Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.simulator,bundle,'data'],text=True).strip())
pref = root/f'Library/Preferences/{bundle}.plist'
pref.parent.mkdir(exist_ok=True,parents=True)
saved = plistlib.loads(pref.read_bytes()) if pref.exists() else {}
saved['RYC0HasCompletedOnboarding'] = True
saved.pop('ryc0.switcher.dismissed',None)
saved.pop('RYC0ProvisionedRyP0', None)
pref.write_bytes(plistlib.dumps(saved))
apps = root/'Documents/Applications'
shutil.rmtree(apps,ignore_errors=True)
shutil.rmtree(root/'Library/Application Support/ReceivedApps',ignore_errors=True)
for index in range(1, 6):
    folder=apps/f'com.ry0.storefixture.{index}.app'
    folder.mkdir(exist_ok=True,parents=True)
    with zipfile.ZipFile(a.fixtures/f'{index}.ipa') as archive:
        for name in archive.namelist():
            if not name.endswith('/'):
                (folder/Path(name).name).write_bytes(archive.read(name))
    (folder/'LCAppInfo.plist').write_bytes(plistlib.dumps({
        'fixLocalNotification': index == 1,
        'lastLaunched':datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)-datetime.timedelta(seconds=index)}))
suite = pref.parent / 'Unknown.plist'
suite_data = plistlib.loads(suite.read_bytes()) if suite.exists() else {}
suite_data['RYC0HomeScreenLayout'] = json.dumps({
    'pages': [['settings']],
    'dock': [f'app:com.ry0.storefixture.{i}:com.ry0.storefixture.{i}.app' for i in range(1, 6)],
    'folders': {},
}).encode()
suite_data['RYC0DockPage'] = 0
suite.write_bytes(plistlib.dumps(suite_data))
events = root / 'Documents/.ryC0Events'
events.mkdir(exist_ok=True)
now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
(events / 'GuestNotifications.plist').write_bytes(plistlib.dumps([
    {'id': 'shown', 'request': 'one', 'container': 'fixture', 'app': 'com.ry0.storefixture.1.app',
     'date': now - datetime.timedelta(minutes=1), 'title': 'Fixture Reminder', 'body': 'A local alert'},
    {'id': 'scheduled', 'request': 'two', 'container': 'fixture', 'app': 'com.ry0.storefixture.1.app',
     'date': now + datetime.timedelta(days=1), 'title': 'Scheduled for tomorrow', 'body': 'Still pending'},
]))
print(root)
