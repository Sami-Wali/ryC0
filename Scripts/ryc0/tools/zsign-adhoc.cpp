// Host (Linux) command that ad-hoc signs an unpacked app with zsign's library,
// for sign-adhoc.sh. Written against zsign commit 614caa8d (src/ of
// https://github.com/zhlynn/zsign); newer zsign may change these signatures.
//
//   zsign-adhoc <folder holding Payload/> [entitlements.plist]
#include "bundle.h"
#include "common.h"
#include "openssl.h"

#include <cstdio>
#include <string>
#include <vector>

int main(int argc, char **argv) {
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "usage: %s <folder holding Payload/> [entitlements.plist]\n", argv[0]);
        return 2;
    }
    ZLog::SetLogLever(ZLog::E_INFO);
    ZSignAsset asset;
    // Ad-hoc: no certificate, key or profile; SHA-1 and SHA-256 code directories.
    if (!asset.Init("", "", "", argc > 2 ? argv[2] : "", "", true, false, false)) {
        return 1;
    }
    ZBundle bundle;
    const std::vector<std::string> none;
    bool ok = bundle.SignFolder(&asset, argv[1], "", "", "", none, none, true, false, false);
    printf("%s\n", ok ? "signed" : "signing failed");
    return ok ? 0 : 1;
}
