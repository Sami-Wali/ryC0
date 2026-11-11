#!/usr/bin/env python3
"""Real, throttled HTTPS IPA fixtures for the isolated simulator test host."""
import argparse
import http.server
from pathlib import Path
import ssl
import subprocess
import tempfile
import time
import zipfile

p = argparse.ArgumentParser()
p.add_argument('--cert')
p.add_argument('--key')
p.add_argument('--prepare-only', action='store_true')
p.add_argument('--port', type=int, default=18764)
a = p.parse_args()
if not a.prepare_only and not (a.cert and a.key):
    p.error('--cert and --key are required to serve fixtures')
root = Path(tempfile.mkdtemp(prefix='ryc0-store-fixtures-'))
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
source = root/'Fixture.m'
source.write_text('#import <UIKit/UIKit.h>\nint main(int argc,char **argv) { return 0; }\n')
executable = root/'Fixture'
subprocess.run(['xcrun','clang','-arch','arm64','-target','arm64-apple-ios17.5-simulator','-isysroot',sdk,
                '-framework','UIKit',str(source),'-o',str(executable)],check=True)
import plistlib
for i in range(1,10):
    name=f'Fixture {i}'
    bundle_id=f'com.ry0.storefixture.{i}'
    with zipfile.ZipFile(root/f'{i}.ipa','w',compression=zipfile.ZIP_STORED) as z:
        z.writestr('Payload/Fixture.app/Info.plist',plistlib.dumps({
            'CFBundleIdentifier':bundle_id,'CFBundleDisplayName':name,'CFBundleName':name,
            'CFBundleExecutable':'Fixture','CFBundleShortVersionString':'1.0','CFBundleVersion':'1',
            'CFBundlePackageType':'APPL','MinimumOSVersion':'17.5','UIDeviceFamily':[1,2]}))
        z.write(executable,'Payload/Fixture.app/Fixture')
        z.writestr('Payload/Fixture.app/padding.bin',bytes(2*1024*1024))
if a.prepare_only:
    print(root)
    raise SystemExit
class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self,*args,**kwargs): super().__init__(*args,directory=root,**kwargs)
    def copyfile(self, source, output):
        try:
            while data:=source.read(8192):
                output.write(data); output.flush()
                if self.path.endswith('.ipa'): time.sleep(0.012)
        except (BrokenPipeError, ConnectionResetError, ssl.SSLError): pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',a.port),Handler)
context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); context.load_cert_chain(a.cert,a.key)
server.socket=context.wrap_socket(server.socket,server_side=True)
print(f'Fixture server https://localhost:{a.port}, files in {root}',flush=True)
server.serve_forever()
