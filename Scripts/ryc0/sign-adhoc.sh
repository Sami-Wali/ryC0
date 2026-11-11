#!/usr/bin/env bash
# Re-signs a copy of a built IPA, ad-hoc, with zsign compiled for this machine
# and then checks every signature with verify_sig.py. It shows
# that zsign replaces the build's own signatures cleanly. zsign signs without
# entitlements here, so this copy can't be installed and must never be shipped.
#
#   RYC0_ZSIGN_SRC=/path/to/zsign/src Scripts/ryc0/sign-adhoc.sh build/ryc0/LiveContainer.ipa
#
# RYC0_ZSIGN_SRC: zsign's src/ folder (https://github.com/zhlynn/zsign, commit
#   614caa8d or compatible). Needs a host C++ compiler, OpenSSL and zlib headers.
# RYC0_ZSIGN_BUILD: where the host zsign-adhoc command is built (default
#   build/ryc0/tools). It is rebuilt when missing or older than its sources.
# The signed copy goes to build/ryc0/adhoc/<ipa name>/Payload.
set -euo pipefail
RYC0_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RYC0_REPO="$(cd "$RYC0_SCRIPTS/../.." && pwd)"
: "${RYC0_BUILD_DIR:=$RYC0_REPO/build/ryc0}"
: "${RYC0_ZSIGN_BUILD:=$RYC0_BUILD_DIR/tools}"
: "${HOST_CC:=cc}"
: "${HOST_CXX:=c++}"
die() { echo "error: $*" >&2; exit 1; }

[[ $# == 1 && -f "$1" ]] || die "usage: $0 <path to .ipa>"
IPA="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
TOOL="$RYC0_ZSIGN_BUILD/zsign-adhoc"

if [[ -n "${RYC0_ZSIGN_SRC:-}" ]]; then
    [[ -f "$RYC0_ZSIGN_SRC/bundle.cpp" && -d "$RYC0_ZSIGN_SRC/common" ]] ||
        die "RYC0_ZSIGN_SRC=$RYC0_ZSIGN_SRC is not zsign's src/ folder"
    if [[ ! -x "$TOOL" ]] || [[ -n "$(find "$RYC0_ZSIGN_SRC" "$RYC0_SCRIPTS/tools/zsign-adhoc.cpp" -newer "$TOOL" -type f | head -n 1)" ]]; then
        echo "Building $TOOL from $RYC0_ZSIGN_SRC"
        mkdir -p "$RYC0_ZSIGN_BUILD/obj"
        objects=()
        for src in "$RYC0_ZSIGN_SRC"/third-party/minizip/*.c; do
            obj="$RYC0_ZSIGN_BUILD/obj/$(basename "$src").o"
            "$HOST_CC" -O1 -w -c "$src" -o "$obj"
            objects+=("$obj")
        done
        "$HOST_CXX" -std=c++17 -O1 -w -I "$RYC0_ZSIGN_SRC" -I "$RYC0_ZSIGN_SRC/common" \
            "$RYC0_ZSIGN_SRC"/*.cpp "$RYC0_ZSIGN_SRC"/common/*.cpp "$RYC0_SCRIPTS/tools/zsign-adhoc.cpp" \
            "${objects[@]}" -lcrypto -lz -o "$TOOL"
    fi
fi
[[ -x "$TOOL" ]] || die "no $TOOL yet; set RYC0_ZSIGN_SRC to zsign's src/ folder to build it"

OUT="$RYC0_BUILD_DIR/adhoc/$(basename "$IPA" .ipa)"
rm -rf "$OUT"
mkdir -p "$OUT"
(cd "$OUT" && unzip -q "$IPA")
"$TOOL" "$OUT" > "$OUT.log" 2>&1 || { cat "$OUT.log" >&2; die "zsign failed (log: $OUT.log)"; }
echo "Ad-hoc signed a copy in $OUT/Payload"
python3 "$RYC0_SCRIPTS/verify_sig.py" "$OUT/Payload"
