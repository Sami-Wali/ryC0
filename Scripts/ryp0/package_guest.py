#!/usr/bin/env python3
"""Package an unsigned public ryP0 device build as a ryC0 guest resource."""
import argparse
import plistlib
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("app", type=Path)
args = parser.parse_args()
app = args.app.resolve()

with (app / "Info.plist").open("rb") as file:
    info = plistlib.load(file)
if (info.get("CFBundleIdentifier") != "com.ry0.ryP0"
        or info.get("RyP0BuildVariant") != "public"
        or "iPhoneOS" not in info.get("CFBundleSupportedPlatforms", [])
        or not (app / info["CFBundleExecutable"]).is_file()):
    parser.error("expected the public ryP0 build for iPhoneOS")

output = Path(__file__).resolve().parents[2] / "Resources" / "ryP0.ipa"
staging = output.with_suffix(".ipa.tmp")
try:
    with ZipFile(staging, "w", compression=ZIP_DEFLATED) as archive:
        for file in sorted(app.rglob("*")):
            relative = file.relative_to(app)
            # The outer host signs the executable. Installed guests cannot
            # register their own widget extension with SpringBoard.
            if set(relative.parts) & {"_CodeSignature", "embedded.mobileprovision", "PlugIns"}:
                continue
            if file.is_symlink():
                parser.error(f"unexpected symlink in ryP0: {relative}")
            if file.is_file():
                archive.write(file, Path("Payload", "ryP0.app", relative))
    staging.replace(output)
finally:
    staging.unlink(missing_ok=True)
