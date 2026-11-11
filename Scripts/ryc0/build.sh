#!/usr/bin/env bash
# Builds a ryC0 IPA on Linux, without Xcode, from this checkout.
#
#   Scripts/ryc0/build.sh
#       The app with all its extensions: build/ryc0/ryC0.ipa
#   RYC0_BUNDLE_ID=com.example.app RYC0_EXTENSIONS=0 RYC0_DISPLAY_NAME="My Name" \
#   RYC0_IPA_NAME=Custom.ipa Scripts/ryc0/build.sh
#       Another bundle ID (extension IDs follow it), no extensions, another name.
#
# See env.sh for every setting and what the build needs installed.
#
# It mirrors the Release configuration of LiveContainer.xcodeproj. Sources are
# collected by folder, so files added upstream are picked up; the target folders
# are listed below. Before building, pbxproj.py compares the Xcode project with
# pbxproj-snapshot.txt and stops if it changed, because a setting this script
# doesn't copy would only show up as a crash on the device.
#
# Output: $RYC0_BUILD_DIR/<name>.ipa, with the staged app, objects and logs in
# $RYC0_BUILD_DIR/<name>/. Like the official IPA it is ad-hoc signed, with each
# target's entitlements, so a sideloader can see what to register; it still has
# to be signed when installing it (xtool install or another sideloader).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$RYC0_REPO"
started=$SECONDS
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
GIT_COMMIT="$(git log -1 --format=%h 2>/dev/null || echo unknown)"

if ! "$PYTHON" "$RYC0_SCRIPTS/pbxproj.py" check "$RYC0_REPO"; then
    [[ "${RYC0_ALLOW_PBXPROJ_DRIFT:-0}" == 1 ]] || exit 1
    echo "warning: building anyway because RYC0_ALLOW_PBXPROJ_DRIFT=1" >&2
fi
# LaunchAppExtension's App Intents metadata (gen/LaunchAppExtension) is written by
# hand, since only Xcode can extract it. Stop when the intent's source changed.
INTENT_SOURCES="$RYC0_SCRIPTS/gen/LaunchAppExtension/sources.sha256"
if [[ "$RYC0_EXTENSIONS" == 1 ]] && ! sha256sum LaunchAppExtension/*.swift | diff -u "$INTENT_SOURCES" - >&2; then
    echo "error: LaunchAppExtension's Swift sources changed since gen/LaunchAppExtension/Metadata.appintents was" \
        "written. Update it to match (or copy it from an Xcode build of this commit), then run" \
        "sha256sum LaunchAppExtension/*.swift > Scripts/ryc0/gen/LaunchAppExtension/sources.sha256" >&2
    [[ "${RYC0_ALLOW_PBXPROJ_DRIFT:-0}" == 1 ]] || exit 1
    echo "warning: building anyway because RYC0_ALLOW_PBXPROJ_DRIFT=1" >&2
fi

NAME="${RYC0_IPA_NAME%.ipa}"
WORK="$RYC0_BUILD_DIR/$NAME"
APP="$WORK/Payload/LiveContainer.app"
CACHE="$RYC0_BUILD_DIR/cache"
rm -rf "$WORK" "$RYC0_BUILD_DIR/$RYC0_IPA_NAME"
mkdir -p "$WORK"/{obj,gen,include,modules,logs,failed} "$APP/Frameworks" "$CACHE"

echo "Building $RYC0_IPA_NAME: $RYC0_BUNDLE_ID, extensions=$RYC0_EXTENSIONS, iOS $RYC0_MIN_IOS," \
    "SDK $RYC0_SDK_VERSION (recorded as $RYC0_RECORDED_SDK), ad-hoc signing=$RYC0_ADHOC_SIGN, $RYC0_JOBS jobs"

# Which folders each product is built from. A folder holding a kind of file its
# product doesn't compile stops the build instead of leaving the file out.
declare -A FOLDERS=(
    [LiveContainerShared]="LiveContainer"
    [LiveContainerSwiftUI]="LiveContainerSwiftUI MultitaskSupport"
    [TweakLoader]="TweakLoader"
    [TestJITLess]="TestJITLess"
    [ZSign]="ZSign"
    [LiveProcess]="LiveProcess"
    [ShareExtension]="ShareExtension"
    [LaunchAppExtension]="LaunchAppExtension"
    [ActivityWidget]="ActivityWidget"
)
declare -A KINDS=(
    [LiveContainerShared]="m c" [LiveContainerSwiftUI]="swift m" [TweakLoader]="m" [TestJITLess]="m"
    [ZSign]="cpp mm" [LiveProcess]="m" [ShareExtension]="swift m"
    [LaunchAppExtension]="swift m" [ActivityWidget]="swift"
)
PRODUCTS=(LiveContainerShared LiveContainerSwiftUI TweakLoader TestJITLess ZSign)
if [[ "$RYC0_EXTENSIONS" == 1 ]]; then
    PRODUCTS+=(LiveProcess ShareExtension LaunchAppExtension ActivityWidget)
fi

# sources <product> <extension>: that product's files of one kind, sorted.
sources() {
    local dirs
    read -ra dirs <<< "${FOLDERS[$1]}"
    find "${dirs[@]}" -type f -name "*.$2" ! -path LiveContainer/main.c | LC_ALL=C sort
}

for product in "${!FOLDERS[@]}"; do
    read -ra dirs <<< "${FOLDERS[$product]}"
    while IFS= read -r file; do
        ext="${file##*.}"
        [[ " ${KINDS[$product]} " == *" $ext "* ]] ||
            ryc0_die "$file: $product is not set up to compile .$ext files (Scripts/ryc0/build.sh)"
    done < <(find "${dirs[@]}" -type f \( -name '*.swift' -o -name '*.m' -o -name '*.mm' -o -name '*.c' \
        -o -name '*.cpp' -o -name '*.cc' -o -name '*.s' -o -name '*.S' \) ! -path LiveContainer/main.c)
    unsupported="$(find "${dirs[@]}" \( -name '*.storyboard' -o -name '*.xib' -o -name '*.xcassets' -o -name '*.xcstrings' \
        -o -name '*.xcdatamodeld' -o -name '*.metal' -o -name '*.intentdefinition' \))"
    [[ -z "$unsupported" ]] || ryc0_die "the Linux build can't compile these resources yet: $unsupported"
done

# Xcode's header maps let any project header be included by name; list every
# folder that holds headers instead. gen/ gets the generated *-Swift.h headers and
# include/openssl points at OpenSSL's headers (Linux paths are case-sensitive).
INCLUDES=(-I "$WORK/gen" -I "$WORK/include")
while IFS= read -r dir; do
    INCLUDES+=(-I "$RYC0_REPO/$dir")
done < <(find LiveContainer LiveContainerSwiftUI MultitaskSupport TweakLoader TestJITLess ZSign \
    LiveProcess ShareExtension LaunchAppExtension litehook/src litehook/external -name '*.h' -printf '%h\n' | LC_ALL=C sort -u)
ln -sfn "$RYC0_OPENSSL/OpenSSL.framework/Headers" "$WORK/include/openssl"
XCC=()
for flag in "${INCLUDES[@]}"; do XCC+=(-Xcc "$flag"); done

# Compiler flags (Release: -Os, NS_BLOCK_ASSERTIONS). compile() adds ARC and weak
# references for Objective-C files.
CFLAGS=(-target "arm64-apple-ios$RYC0_MIN_IOS" -isysroot "$RYC0_SDK" -Os -g0 -std=gnu17
    -fmodules "-fmodules-cache-path=$CACHE/clang-modules" -DNS_BLOCK_ASSERTIONS=1 "${INCLUDES[@]}")
SHARED_CFLAGS=("${CFLAGS[@]}" -fcommon)                  # OTHER_CFLAGS of LiveContainerShared
VERSION_DEFINES=(-DCONFIG_TYPE='"Release"' -DCONFIG_BRANCH="\"$GIT_BRANCH\"" -DCONFIG_COMMIT="\"$GIT_COMMIT\"")
UI_CFLAGS=("${CFLAGS[@]}" "${VERSION_DEFINES[@]}")       # OTHER_CFLAGS of LiveContainerSwiftUI
EXT_CFLAGS=("${CFLAGS[@]}" -fapplication-extension)
# ZSign's C++ and Objective-C++ build without modules: with them, clang hides
# Foundation's methods from gnu++20 Objective-C++. compile() adds ARC for .mm.
CXXFLAGS=(-target "arm64-apple-ios$RYC0_MIN_IOS" -isysroot "$RYC0_SDK" -Os -g0 -std=gnu++20 -stdlib=libc++
    -DNS_BLOCK_ASSERTIONS=1 -F "$RYC0_OPENSSL" "${INCLUDES[@]}")

SWIFTFLAGS=(-target "arm64-apple-ios$RYC0_MIN_IOS" -sdk "$RYC0_SDK" -resource-dir "$RYC0_SWIFT_RESOURCES"
    -module-cache-path "$CACHE/swift-modules" -swift-version 5 -O -wmo
    -parse-as-library  # LCBootstrap looks up the SwiftUI app's `main` by name
    -Xfrontend -enable-cross-import-overlays
    -load-plugin-executable "$RYC0_MACROS#SwiftUIMacros"
    -load-plugin-library "$RYC0_SWIFT_PLUGINS/libObservationMacros.so"
    -load-plugin-executable "$RYC0_MACROS#AppIntentsMacros"
    "${XCC[@]}")
# SWIFT_APPROACHABLE_CONCURRENCY and SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY,
# set on ShareExtension and LaunchAppExtension.
APPROACHABLE=(-enable-upcoming-feature DisableOutwardActorInference
    -enable-upcoming-feature GlobalActorIsolatedTypesUsability -enable-upcoming-feature InferIsolatedConformances
    -enable-upcoming-feature InferSendableFromCaptures -enable-upcoming-feature NonisolatedNonsendingByDefault
    -enable-upcoming-feature MemberImportVisibility)

# Every link records RYC0_RECORDED_SDK (env.sh), the SDK of the official build.
# Without it, binaries linked through swiftc claim the deployment target as their
# SDK and lose the iOS 26+ design; with the real SDK (27.x) iOS would apply its
# newer "linked on or after" rules to ryC0 and the guest apps it runs.
PLATFORM=(-Xlinker -platform_version -Xlinker ios -Xlinker "$RYC0_MIN_IOS" -Xlinker "$RYC0_RECORDED_SDK")
BASE_LINKFLAGS=(-target "arm64-apple-ios$RYC0_MIN_IOS" -isysroot "$RYC0_SDK" "--ld-path=$RYC0_LD" -mlinker-version=1200
    "${PLATFORM[@]}")
LINKFLAGS=("${BASE_LINKFLAGS[@]}" -fobjc-arc -fobjc-link-runtime)
CLINK=("$CLANG" "${LINKFLAGS[@]}")
CXXLINK=("$CLANGXX" "${LINKFLAGS[@]}" -stdlib=libc++)
SLINK=("$SWIFTC" -target "arm64-apple-ios$RYC0_MIN_IOS" -sdk "$RYC0_SDK" -resource-dir "$RYC0_SWIFT_RESOURCES"
    "-ld-path=$RYC0_LD" -Xclang-linker -mlinker-version=1200 "${PLATFORM[@]}" -Xlinker "$RYC0_CLANG_RT")
FRAMEWORK_RPATHS=(-Xlinker -rpath -Xlinker @executable_path/Frameworks -Xlinker -rpath -Xlinker @loader_path/Frameworks)
EXTENSION_RPATHS=(-Xlinker -rpath -Xlinker @executable_path/Frameworks -Xlinker -rpath -Xlinker @executable_path/../../Frameworks)
DYLIB_VERSIONS=(-Xlinker -compatibility_version -Xlinker 1 -Xlinker -current_version -Xlinker 1)

# Parallel jobs. Each job's output goes to logs/<name>.log; a failing job prints
# its log and leaves a marker, and `finish` stops the build if any job failed.
job() {
    local name=$1; shift
    while (( $(jobs -rp | wc -l) >= RYC0_JOBS )); do wait -n || true; done
    (
        if ! "$@" > "$WORK/logs/$name.log" 2>&1; then
            { echo "error: $name failed:"; echo "  $*" | cut -c1-600
              grep -v 'does not support linking for platform' "$WORK/logs/$name.log" | tail -n 40; } >&2
            touch "$WORK/failed/$name"
        fi
    ) &
}
finish() {
    wait
    local failed
    failed="$(ls "$WORK/failed")"
    [[ -z "$failed" ]] || ryc0_die "$(wc -l <<< "$failed") step(s) failed: $(tr '\n' ' ' <<< "$failed")(logs in $WORK/logs)"
    echo "  $1 ($((SECONDS - started))s)"
}

# compile <product> <flags array name> <files...>: one object per file.
compile() {
    local product=$1 src obj
    local -n flags=$2
    shift 2
    mkdir -p "$WORK/obj/$product"
    for src in "$@"; do
        obj="$WORK/obj/$product/${src//\//_}.o"
        case "$src" in
            *.cpp) job "$product-${src//\//_}" "$CLANGXX" "${flags[@]}" -c "$src" -o "$obj" ;;
            *.mm)  job "$product-${src//\//_}" "$CLANGXX" "${flags[@]}" -fobjc-arc -fobjc-weak -c "$src" -o "$obj" ;;
            *.m)   job "$product-${src//\//_}" "$CLANG" "${flags[@]}" -fobjc-arc -fobjc-weak -c "$src" -o "$obj" ;;
            *)     job "$product-${src//\//_}" "$CLANG" "${flags[@]}" -c "$src" -o "$obj" ;;
        esac
    done
}

# swift_module <product> <bridging header> <extra swiftc flags...> -- <files...>
# One whole-module job; its code generation runs on RYC0_JOBS threads, one object
# per source file, as Xcode does for whole-module builds.
swift_module() {
    local product=$1 header=$2 extra=()
    shift 2
    while [[ $1 != -- ]]; do extra+=("$1"); shift; done
    shift
    mkdir -p "$WORK/obj/$product"
    "$PYTHON" - "$WORK/obj/$product" "$RYC0_REPO" "$@" > "$WORK/obj/$product.swift-outputs.json" <<'PY'
import json, os, sys
out, repo, files = sys.argv[1], sys.argv[2], sys.argv[3:]
name = lambda f: os.path.relpath(os.path.abspath(f), repo).replace('/', '_')
json.dump({f: {'object': os.path.join(out, name(f) + '.o')} for f in files}, sys.stdout, indent=1)
PY
    # The module itself isn't needed, but emitting the ObjC header writes one, so
    # give it a path inside the build folder (otherwise it lands in the repo root).
    local bridging=()
    if [[ -n "$header" ]]; then bridging=(-import-objc-header "$header"); fi
    job "$product-swift" "$SWIFTC" "${SWIFTFLAGS[@]}" "${extra[@]}" -module-name "$product" \
        "${bridging[@]}" -emit-objc-header-path "$WORK/gen/$product-Swift.h" \
        -emit-module-path "$WORK/modules/$product.swiftmodule" \
        -num-threads "$RYC0_JOBS" -output-file-map "$WORK/obj/$product.swift-outputs.json" -c "$@"
}

# objects <array name> <product>: that product's object files.
objects() { local -n list=$1; list=("$WORK/obj/$2"/*.o); }
has() { [[ " ${PRODUCTS[*]} " == *" $1 "* ]]; }

# 1. Everything that doesn't need a generated Swift header, with the Swift modules.
mapfile -t ui_swift < <(sources LiveContainerSwiftUI swift)
swift_module LiveContainerSwiftUI LiveContainerSwiftUI/LiveContainerSwiftUI-Bridging-Header.h -- "${ui_swift[@]}"
job archive-paths "$RYC0_SCRIPTS/build-archive-paths.sh" Rust/archive_paths.rs "$WORK/obj/LiveContainerSwiftUI/archive-paths.o" iphoneos arm64
mapfile -t files < <(sources LiveContainerShared m; sources LiveContainerShared c)
compile LiveContainerShared SHARED_CFLAGS "${files[@]}" litehook/src/litehook.c
compile LiveContainer CFLAGS LiveContainer/main.c
mapfile -t files < <(sources TweakLoader m); compile TweakLoader CFLAGS "${files[@]}"
mapfile -t files < <(sources TestJITLess m); compile TestJITLess CFLAGS "${files[@]}"
mapfile -t files < <(sources ZSign cpp; sources ZSign mm); compile ZSign CXXFLAGS "${files[@]}"
if has LiveProcess; then
    mapfile -t files < <(sources LiveProcess m); compile LiveProcess EXT_CFLAGS "${files[@]}"
fi
for ext in ShareExtension LaunchAppExtension; do
    has $ext || continue
    mapfile -t files < <(sources $ext swift)
    swift_module $ext "$ext/$ext-Bridging-Header.h" -application-extension "${APPROACHABLE[@]}" -- "${files[@]}"
    mapfile -t files < <(sources $ext m); compile $ext EXT_CFLAGS "${files[@]}"
done
if has ActivityWidget; then
    swift_module ActivityWidget "" -application-extension -- ActivityWidget/ActivityWidget.swift \
        LiveContainerSwiftUI/Activities/GuestActivityAttributes.swift
fi
finish "compiled"

# 2. LiveContainerSwiftUI's Objective-C, which imports LiveContainerSwiftUI-Swift.h.
mapfile -t files < <(sources LiveContainerSwiftUI m); compile LiveContainerSwiftUI UI_CFLAGS "${files[@]}"
finish "compiled LiveContainerSwiftUI's Objective-C"

# 3. Link. LiveContainerShared first, since the others link against it.
# Only link what the code uses, as Xcode's build does: UIKit must not load before
# LCBootstrap has set up the guest app (SDK spoofing, then the guest's own
# libraries), and LiveProcess keeps it from loading at all (LiveProcess/main.m).
# check.py fails the build if any of these binaries links UIKit.
F="$APP/Frameworks"
mkdir -p "$F/LiveContainerShared.framework" "$F/LiveContainerSwiftUI.framework"
objects o LiveContainerShared
job link-LiveContainerShared "${CLINK[@]}" -dynamiclib "${DYLIB_VERSIONS[@]}" "${FRAMEWORK_RPATHS[@]}" \
    -install_name @rpath/LiveContainerShared.framework/LiveContainerShared \
    -framework Foundation -framework Security "${o[@]}" "$RYC0_CLANG_RT" \
    -o "$F/LiveContainerShared.framework/LiveContainerShared"
finish "linked LiveContainerShared"

# OTHER_LDFLAGS of the LiveContainer target: its entry point is in main.c, which
# loads LiveContainerShared and calls LiveContainerMain. It is plain C, linked
# without the Objective-C flags so it loads nothing but libSystem, and it exports
# only the header, like an executable stripped by Xcode.
objects o LiveContainer
job link-LiveContainer "$CLANG" "${BASE_LINKFLAGS[@]}" -Xlinker -e -Xlinker _LiveContainerMainC \
    -Xlinker -exported_symbol -Xlinker __mh_execute_header \
    -Xlinker -rpath -Xlinker @executable_path/Frameworks "${o[@]}" "$RYC0_CLANG_RT" -o "$APP/LiveContainer"
objects o LiveContainerSwiftUI
job link-LiveContainerSwiftUI "${SLINK[@]}" -emit-library -module-name LiveContainerSwiftUI "${DYLIB_VERSIONS[@]}" \
    "${FRAMEWORK_RPATHS[@]}" -Xlinker -install_name -Xlinker @rpath/LiveContainerSwiftUI.framework/LiveContainerSwiftUI \
    -Xlinker -U -Xlinker '_OBJC_CLASS_$_RBSTarget' -F "$F" -framework LiveContainerShared -framework IOKit -larchive \
    "${o[@]}" -o "$F/LiveContainerSwiftUI.framework/LiveContainerSwiftUI"
objects o TweakLoader
job link-TweakLoader "${CLINK[@]}" -dynamiclib "${DYLIB_VERSIONS[@]}" -install_name @rpath/TweakLoader.dylib \
    -Xlinker -U -Xlinker '_OBJC_CLASS_$_FBSSceneParameters' -Xlinker -U -Xlinker '_OBJC_CLASS_$_LSApplicationWorkspace' \
    -Xlinker -U -Xlinker '_OBJC_CLASS_$_DOCConfiguration' -framework Foundation -framework UIKit \
    "${o[@]}" "$RYC0_CLANG_RT" -o "$F/TweakLoader.dylib"
objects o TestJITLess
job link-TestJITLess "${CLINK[@]}" -dynamiclib "${DYLIB_VERSIONS[@]}" -install_name @rpath/TestJITLess.dylib \
    -framework Foundation "${o[@]}" "$RYC0_CLANG_RT" -o "$F/TestJITLess.dylib"
objects o ZSign
job link-ZSign "${CXXLINK[@]}" -dynamiclib "${DYLIB_VERSIONS[@]}" \
    -install_name @rpath/ZSign.dylib -F "$RYC0_OPENSSL" -framework OpenSSL -framework Foundation \
    "${o[@]}" "$RYC0_CLANG_RT" -o "$F/ZSign.dylib"
if has LiveProcess; then
    # DEAD_CODE_STRIPPING = NO in the Xcode project; nothing here is dead-stripped.
    mkdir -p "$APP/PlugIns/LiveProcess.appex"
    objects o LiveProcess
    job link-LiveProcess "${CLINK[@]}" -fapplication-extension -Xlinker -e -Xlinker _NSExtensionMain \
        "${EXTENSION_RPATHS[@]}" -F "$F" -framework LiveContainerShared -framework Foundation \
        "${o[@]}" "$RYC0_CLANG_RT" -o "$APP/PlugIns/LiveProcess.appex/LiveProcess"
fi
if has ShareExtension; then
    mkdir -p "$APP/PlugIns/ShareExtension.appex"
    objects o ShareExtension
    job link-ShareExtension "${SLINK[@]}" -emit-executable -application-extension \
        -Xlinker -e -Xlinker _NSExtensionMain "${EXTENSION_RPATHS[@]}" -F "$F" -framework LiveContainerShared \
        "${o[@]}" -o "$APP/PlugIns/ShareExtension.appex/ShareExtension"
fi
if has LaunchAppExtension; then
    # An ExtensionKit extension, but the Xcode project embeds it in PlugIns with
    # the others. Like every extension Xcode links, it starts in NSExtensionMain,
    # not in the Swift @main. assemble.py adds its Metadata.appintents.
    mkdir -p "$APP/PlugIns/LaunchAppExtension.appex"
    objects o LaunchAppExtension
    job link-LaunchAppExtension "${SLINK[@]}" -emit-executable -application-extension \
        -Xlinker -e -Xlinker _NSExtensionMain "${EXTENSION_RPATHS[@]}" -F "$F" -framework LiveContainerShared \
        "${o[@]}" -o "$APP/PlugIns/LaunchAppExtension.appex/LaunchAppExtension"
fi
if has ActivityWidget; then
    mkdir -p "$APP/PlugIns/ActivityWidget.appex"
    objects o ActivityWidget
    job link-ActivityWidget "${SLINK[@]}" -emit-executable -application-extension \
        -Xlinker -e -Xlinker _NSExtensionMain "${EXTENSION_RPATHS[@]}" \
        "${o[@]}" -o "$APP/PlugIns/ActivityWidget.appex/ActivityWidget"
fi
finish "linked"

# 4. Strip like an Xcode archive (STRIP_STYLE): executables fully, dylibs of
# their local symbols, and only debug symbols where the project says "debugging"
# (LiveContainerShared and LiveProcess; LiveContainerMain is looked up by name).
strip_style() {
    case "$1" in
        */LiveContainerShared|*/LiveProcess) echo -S ;;
        "$APP/LiveContainer"|*.appex/*) echo --strip-all ;;
        *) echo -x ;;
    esac
}
while IFS= read -r -d '' bin; do
    if [[ "$(head -c 4 "$bin" | od -An -tx1 | tr -d ' \n')" == cffaedfe ]]; then
        llvm-strip "$(strip_style "$bin")" "$bin" || ryc0_die "llvm-strip failed on $bin"
    fi
done < <(find "$APP" -type f -print0)
echo "  stripped"

# 5. Info.plists, resources, strings, icons and the prebuilt frameworks.
# LCVersionInfo is what the Xcode target's Run Script writes.
export RYC0_VERSION_INFO="Release ($GIT_BRANCH/$GIT_COMMIT)"
"$PYTHON" "$RYC0_SCRIPTS/assemble.py" "$APP"

# 6. Ad-hoc sign like Xcode's archive, so the entitlements travel with the IPA.
if [[ "$RYC0_ADHOC_SIGN" == 1 ]]; then
    "$PYTHON" "$RYC0_SCRIPTS/codesign.py" "$APP"
fi

# 7. Check the bundle and its signatures before packaging it.
"$PYTHON" "$RYC0_SCRIPTS/check.py" "$APP"
if [[ "$RYC0_ADHOC_SIGN" == 1 ]]; then
    "$PYTHON" "$RYC0_SCRIPTS/verify_sig.py" --unsigned-ok "$APP"
fi

# 8. Package.
(cd "$WORK" && zip -qrX -y "$RYC0_BUILD_DIR/$RYC0_IPA_NAME" Payload)
echo "Built $RYC0_BUILD_DIR/$RYC0_IPA_NAME ($(du -h "$RYC0_BUILD_DIR/$RYC0_IPA_NAME" | cut -f1)) in $((SECONDS - started))s"
