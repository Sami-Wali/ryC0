#!/bin/bash
set -euo pipefail

source_file=$1
output=$2
platform=$3
shift 3

if ! command -v rustc >/dev/null; then
    export PATH="$PATH:$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin"
fi
if command -v rustc >/dev/null; then
    rust=(rustc)
elif command -v rustup >/dev/null; then
    rust=(rustup run stable rustc)
else
    echo "error: Install Rust with rustup to build the archive path validator." >&2
    exit 1
fi

tmp=$(mktemp -d "$(dirname "$output")/archive-paths.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
objects=()
for arch in "$@"; do
    case "$platform:$arch" in
        iphoneos:arm64) target=aarch64-apple-ios ;;
        iphonesimulator:arm64) target=aarch64-apple-ios-sim ;;
        iphonesimulator:x86_64) target=x86_64-apple-ios ;;
        maccatalyst:arm64) target=aarch64-apple-ios-macabi ;;
        maccatalyst:x86_64) target=x86_64-apple-ios-macabi ;;
        *) echo "error: Unsupported archive validator platform: $platform/$arch" >&2; exit 1 ;;
    esac
    object="$tmp/$arch.o"
    "${rust[@]}" --target "$target" --edition 2021 --crate-type lib \
        --emit=obj -C opt-level=2 -C panic=abort "$source_file" -o "$object" || {
        echo "error: The archive path validator requires rustup target add $target" >&2
        exit 1
    }
    objects+=("$object")
done
if [[ ${#objects[@]} == 1 ]]; then
    mv "${objects[0]}" "$output"
else
    lipo -create "${objects[@]}" -output "$output"
fi
