# Toolchain and build settings for the Linux build. build.sh and sign-adhoc.sh
# source this file; it is not meant to be run on its own.
#
# Needs: clang, clang++ and swiftc on PATH (LLVM clang and the swift.org Linux
# toolchain), python3, zip, ImageMagick (magick or convert), and the Darwin SDK
# bundle that xtool installs (`xtool setup`), which provides the iPhoneOS SDK,
# Apple's Swift resources, ld64.lld and the macro plugins.
#
# Everything below can be overridden from the environment.

# Variant of the app to build.
: "${RYC0_BUNDLE_ID:=com.ry0.ryC0}"    # main app; extension IDs are derived from it
: "${RYC0_EXTENSIONS:=1}"                       # 0 leaves out every .appex
: "${RYC0_DISPLAY_NAME:=}"                      # empty keeps CFBundleDisplayName from Info.plist
# The app reads its URL scheme from its Info.plist.
: "${RYC0_URL_SCHEME:=ryc0}"
: "${RYC0_IPA_NAME:=ryC0.ipa}"                   # file name of the IPA in $RYC0_BUILD_DIR
: "${RYC0_MIN_IOS:=17.0}"                       # deployment target of every binary we build
# SDK version the binaries record (LC_BUILD_VERSION) and Info.plist names. iOS
# turns on "linked on or after" behavior by it, for ryC0's own UI and for
# every guest app that doesn't spoof its own SDK, so it stays at what the official
# build uses (Xcode 26.2) rather than the newer SDK the headers come from.
: "${RYC0_RECORDED_SDK:=26.2}"
: "${RYC0_ADHOC_SIGN:=1}"                       # 1 ad-hoc signs with entitlements like Xcode's archive; 0 leaves it unsigned

RYC0_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${RYC0_REPO:=$(cd "$RYC0_SCRIPTS/../.." && pwd)}"
: "${RYC0_BUILD_DIR:=$RYC0_REPO/build/ryc0}"
: "${RYC0_JOBS:=$(nproc 2>/dev/null || echo 4)}"

: "${RYC0_SDK_BUNDLE:=$HOME/.swiftpm/swift-sdks/darwin.artifactbundle}"
: "${CLANG:=clang}"
: "${CLANGXX:=clang++}"
: "${SWIFTC:=swiftc}"
: "${PYTHON:=python3}"

ryc0_die() { echo "error: $*" >&2; exit 1; }

# Newest iPhoneOS SDK in the bundle, unless RYC0_SDK names one.
if [[ -z "${RYC0_SDK:-}" ]]; then
    RYC0_SDK="$(find "$RYC0_SDK_BUNDLE/Developer/Platforms/iPhoneOS.platform/Developer/SDKs" -maxdepth 1 \
        -name 'iPhoneOS[0-9]*.sdk' 2>/dev/null | sort -V | tail -n 1)"
fi
[[ -n "$RYC0_SDK" && -f "$RYC0_SDK/SDKSettings.json" ]] ||
    ryc0_die "no iPhoneOS SDK found in $RYC0_SDK_BUNDLE (install it with xtool setup, or set RYC0_SDK_BUNDLE or RYC0_SDK)"
RYC0_SDK_VERSION="$("$PYTHON" -c 'import json,sys; print(json.load(open(sys.argv[1]))["Version"])' "$RYC0_SDK/SDKSettings.json")"

RYC0_TOOLCHAIN="$RYC0_SDK_BUNDLE/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib"
# The unwrapped linker: the wrapper next to it turns -r links into archives, and the
# system ld64.lld can't read the SDK's .tbd stubs.
RYC0_LD="$RYC0_SDK_BUNDLE/toolset/bin/orig/ld64.lld"
# Compiler runtime with ___isPlatformVersionAtLeast, which @available needs.
RYC0_CLANG_RT="$(ls "$RYC0_TOOLCHAIN"/clang/*/lib/darwin/libclang_rt.ios.a 2>/dev/null | sort -V | tail -n 1)"
RYC0_SWIFT_RESOURCES="$RYC0_TOOLCHAIN/swift"
RYC0_MACROS="$RYC0_SDK_BUNDLE/OpenAppleMacrosServer"
# Swift's own macros (@Observable) come from the Linux toolchain's plugins; the
# bundle has only Apple's macOS builds of them, and OpenAppleMacrosServer only
# stands in for SwiftUI's and App Intents'.
: "${RYC0_SWIFT_PLUGINS:=$(dirname "$(readlink -f "$(command -v "$SWIFTC")")")/../lib/swift/host/plugins}"
RYC0_OPENSSL="$RYC0_REPO/OpenSSL/Frameworks/iphoneos"

for tool in "$CLANG" "$CLANGXX" "$SWIFTC" "$PYTHON" zip llvm-strip; do
    command -v "$tool" >/dev/null || ryc0_die "$tool is not on PATH"
done
command -v magick >/dev/null || command -v convert >/dev/null || ryc0_die "ImageMagick (magick or convert) is not on PATH"
[[ -x "$RYC0_LD" ]] || ryc0_die "missing linker $RYC0_LD"
[[ -f "$RYC0_CLANG_RT" ]] || ryc0_die "missing libclang_rt.ios.a under $RYC0_TOOLCHAIN/clang"
[[ -d "$RYC0_SWIFT_RESOURCES/iphoneos" ]] || ryc0_die "missing Swift resources in $RYC0_SWIFT_RESOURCES"
[[ -x "$RYC0_MACROS" ]] || ryc0_die "missing macro plugin server $RYC0_MACROS"
[[ -f "$RYC0_SWIFT_PLUGINS/libObservationMacros.so" ]] ||
    ryc0_die "missing libObservationMacros.so in $RYC0_SWIFT_PLUGINS (set RYC0_SWIFT_PLUGINS to the toolchain's lib/swift/host/plugins)"
[[ -f "$RYC0_OPENSSL/OpenSSL.framework/OpenSSL" ]] ||
    ryc0_die "OpenSSL submodule is not checked out (git submodule update --init --recursive)"
[[ -f "$RYC0_REPO/litehook/src/litehook.c" ]] ||
    ryc0_die "litehook submodule is not checked out (git submodule update --init --recursive)"
[[ "$RYC0_EXTENSIONS" == 0 || "$RYC0_EXTENSIONS" == 1 ]] || ryc0_die "RYC0_EXTENSIONS must be 0 or 1"
[[ "$RYC0_ADHOC_SIGN" == 0 || "$RYC0_ADHOC_SIGN" == 1 ]] || ryc0_die "RYC0_ADHOC_SIGN must be 0 or 1"
[[ "$RYC0_RECORDED_SDK" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || ryc0_die "RYC0_RECORDED_SDK '$RYC0_RECORDED_SDK' is not a version"
[[ "$(printf '%s\n' "$RYC0_RECORDED_SDK" "$RYC0_SDK_VERSION" | sort -V | tail -n 1)" == "$RYC0_SDK_VERSION" ]] ||
    ryc0_die "RYC0_RECORDED_SDK $RYC0_RECORDED_SDK is newer than the SDK in use ($RYC0_SDK_VERSION)"
[[ "$RYC0_BUNDLE_ID" =~ ^[A-Za-z0-9.-]+$ ]] || ryc0_die "RYC0_BUNDLE_ID '$RYC0_BUNDLE_ID' is not a valid bundle ID"
[[ "$RYC0_URL_SCHEME" =~ ^[a-z][a-z0-9.+-]*$ && "$RYC0_URL_SCHEME" != *livecontainer* ]] ||
    ryc0_die "RYC0_URL_SCHEME '$RYC0_URL_SCHEME' must be a lowercase URL scheme, and distinct from LiveContainer"
[[ "$RYC0_IPA_NAME" =~ ^[A-Za-z0-9._+-]+\.ipa$ && ! "$RYC0_IPA_NAME" =~ ^(cache|tools|adhoc)\.ipa$ ]] ||
    ryc0_die "RYC0_IPA_NAME '$RYC0_IPA_NAME' must be a plain file name ending in .ipa"

export RYC0_BUNDLE_ID RYC0_EXTENSIONS RYC0_DISPLAY_NAME RYC0_URL_SCHEME RYC0_IPA_NAME RYC0_MIN_IOS RYC0_RECORDED_SDK RYC0_ADHOC_SIGN \
    RYC0_REPO RYC0_BUILD_DIR RYC0_SDK RYC0_SDK_VERSION RYC0_OPENSSL
