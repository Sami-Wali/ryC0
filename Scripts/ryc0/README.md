# Building on Linux

These scripts build the ryC0 IPA on Linux without Xcode, matching what
LiveContainer's official CI builds with Xcode. They follow the Release configuration of
`LiveContainer.xcodeproj` and read `project.pbxproj` for bundle IDs, versions,
entitlements and Info.plist settings, so the Xcode project stays the reference.

## Requirements

- `clang`/`clang++` (LLVM) and `swiftc` (the swift.org Linux toolchain) on `PATH`,
  plus `python3`, `zip`, `llvm-strip` and ImageMagick.
- The Darwin SDK bundle installed by [xtool](https://github.com/xtool-org/xtool)
  (`xtool setup`), by default at `~/.swiftpm/swift-sdks/darwin.artifactbundle`. It
  provides the iPhoneOS SDK, Apple's Swift libraries, `ld64.lld` and the SwiftUI and
  App Intents macro plugins. `@Observable` expands with the Linux toolchain's own
  `libObservationMacros.so`, found next to `swiftc` (`RYC0_SWIFT_PLUGINS` names
  another folder).
- Rust via rustup with `rustup target add aarch64-apple-ios` for the archive path validator.
- The submodules: `git submodule update --init --recursive`.

## Building

```sh
Scripts/ryc0/build.sh
```

builds `build/ryc0/ryC0.ipa` with every extension. Settings come from the
environment (all of them are listed in `env.sh`):

| Variable | Default | Meaning |
| --- | --- | --- |
| `RYC0_BUNDLE_ID` | `com.ry0.ryC0` | Main app bundle ID; the extension IDs are derived from it |
| `RYC0_EXTENSIONS` | `1` | `0` leaves out every `.appex` |
| `RYC0_DISPLAY_NAME` | (from Info.plist) | Home Screen name, and the share extension's (the name the share sheet shows) |
| `RYC0_URL_SCHEME` | `ryc0` | URL scheme the app declares first and makes its own links with |
| `RYC0_IPA_NAME` | `ryC0.ipa` | Output file in `build/ryc0/` |
| `RYC0_MIN_IOS` | `17.0` | Deployment target of every binary |
| `RYC0_RECORDED_SDK` | `26.2` | SDK version the binaries and Info.plists record (see below) |
| `RYC0_ADHOC_SIGN` | `1` | `0` leaves the IPA unsigned |
| `RYC0_JOBS` | number of CPUs | Parallel compile jobs |

For example, a test build without extensions under a separate App ID:

```sh
RYC0_BUNDLE_ID=com.ry0.ryC0.test RYC0_EXTENSIONS=0 RYC0_DISPLAY_NAME="ryC0 Test" \
RYC0_URL_SCHEME=ryc0-test RYC0_IPA_NAME=ryC0-Test.ipa Scripts/ryc0/build.sh
```

`RYC0_BUNDLE_ID` sets the app's bundle ID and the IDs of its extensions and in-house frameworks. The app group and keychain groups use the fixed ryC0 namespace from `xcconfigs/Global.xcconfig`, so variants signed by the same team can share ryC0 data. Use a separate URL scheme for a variant installed alongside ryC0. The main app and extensions read the host scheme from the main Info.plist.

By default the build is ad-hoc signed so the app group, keychain, and other requested entitlements travel with the IPA. To install, sign with a provisioning profile that authorizes the app and the extensions. Import the .p12 certificate that signed ryC0 from its Settings for JIT-less mode.

Objects, logs and the staged app are kept in `build/ryc0/<name>/`.

## Files

- `env.sh`: finds the toolchain and holds the settings above.
- `build.sh`: compiles each product from its source folders in parallel, links,
  strips like an Xcode archive, then calls the scripts below and zips the IPA.
- `assemble.py`: Info.plists, resources, the string catalog (`.strings` and
  `.stringsdict` per language, English filling gaps), loose icon PNGs, the
  prebuilt OpenSSL and CydiaSubstrate frameworks, and the license texts the About
  page shows (`Licenses/`, copied as the Xcode target's Run Script copies them:
  from each project's `LICENSE` file, and from `Resources/Licenses` for zsign,
  Feather and CFastFind, whose licenses the source doesn't otherwise hold).
- `pbxproj.py`: reads the Xcode project. `pbxproj.py check` compares it with
  `pbxproj-snapshot.txt`; `build.sh` stops when they differ, since a project change
  this build doesn't copy would only show up as a crash on a device. After looking
  at what changed upstream (and updating `build.sh` or `assemble.py` to match), run
  `python3 Scripts/ryc0/pbxproj.py snapshot > Scripts/ryc0/pbxproj-snapshot.txt`.
- `codesign.py`: the ad-hoc signing. It signs innermost first, seals each
  bundle's files in `_CodeSignature/CodeResources` with Apple's iOS rules, fills
  in each target's `CODE_SIGN_ENTITLEMENTS` file with the Release settings, and
  leaves `TestJITLess.dylib` unsigned, as Xcode does for a dylib embedded without
  "Code Sign On Copy". Run on the files of the official IPA, it reproduces
  Xcode's signatures and CodeResources byte for byte (at Xcode's page size).
- `check.py`: checks the bundle layout, every Mach-O (arm64, minimum iOS, SDK
  version, embedded dependencies, the libraries loaded at launch, extension entry
  points, symbols looked up by name, signatures and entitlements), the
  Info.plists, the App Intents metadata and
  the string tables, that nothing of SideStore or AltStore is left in the bundle,
  the license texts the About page names, and ryC0's identity: the build's
  scheme (`RYC0_URL_SCHEME`) first and no `livecontainer` scheme, the name (the
  share extension's too), the keychain groups and app group, and no user-facing string
  that still says LiveContainer (the About page's credits, `lc.about.*`, and links
  to LiveContainer's own pages aside). `build.sh` runs it on every build.
- `verify_sig.py`: checks every code signature and CodeResources seal against the
  files they cover. `build.sh` runs it on every signed build.
- `sign-adhoc.sh` and `tools/zsign-adhoc.cpp`: re-sign a copy of an IPA with
  zsign built for Linux (`RYC0_ZSIGN_SRC` names zsign's `src/` folder), the signer
  built from its source, then run `verify_sig.py` on it. Only a test of re-signing: never
  install or share that copy.
- `gen/LaunchAppExtension/Metadata.appintents`: the App Intents metadata Xcode
  extracts from LaunchAppExtension's Swift code, which Shortcuts reads to list
  its "Launch App" action. No Linux tool can extract it, so it is kept by hand;
  `sources.sha256` records the code it describes, and `build.sh` stops when that
  code changes. After updating the metadata, run
  `sha256sum LaunchAppExtension/*.swift > Scripts/ryc0/gen/LaunchAppExtension/sources.sha256`.
- `macho.py`: the small Mach-O reader the other scripts share.
- `art/AppIcon.svg`: the app icon, drawn as a full-bleed square (iOS masks it).
  `art/render-icon.sh` renders it into the asset catalog's icons (with the dark,
  tinted and grey variants) and into `art/icon-preview.png`, the icon masked the
  way iOS shows it. The build resizes the asset catalog's icon into loose PNGs.

## Differences from an Xcode build

- The headers and Swift modules come from the SDK in the bundle (iOS 27.1), but
  every binary and Info.plist records `RYC0_RECORDED_SDK`, the SDK of the official
  build (Xcode 26.2). iOS picks "linked on or after" behavior by the main
  executable's SDK, for LiveContainer and for every guest app that doesn't spoof
  its own, so a newer SDK would change how guest apps run (for example, apps
  built with the SDK after iOS 26 must adopt UIScene). Liquid Glass needs 26 or
  later.
- No asset catalog compiler: the app icon is a set of loose PNGs (no dark or
  tinted variants), and the asset catalog colors are missing, so the code's system
  color fallbacks are used.
- Signatures use 4 KiB pages everywhere; Xcode uses 16 KiB for the Swift
  extensions. iOS accepts both, and installing replaces them.
