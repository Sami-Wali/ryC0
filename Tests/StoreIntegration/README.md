# ryC0 Home Screen integration tests

The tests use the actual Debug ryC0 framework and a dedicated arm64 iPhone simulator. They cover saved dock layout migration, Tendies motion and path validation, bundled ryP0 provisioning, the Home Screen notification inbox, and switcher navigation.

`BrandingIntegrationTests` also checks preference migration, supported JIT providers, and pending installs across source identity changes.

Requires Xcode, XcodeGen, Python 3 and the arm64 iOS Simulator Rust target. Set `RYC0_TEST_SIMULATOR` to the UUID of a dedicated booted iPhone simulator. Seeding replaces that test app's local fixtures.

```sh
xcodebuild -project LiveContainer.xcodeproj -scheme LiveContainer -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/ryc0-store-validation-build CODE_SIGNING_ALLOWED=NO \
  LIVECONTAINER_BUNDLE_IDENTIFIER=com.ry0.ryC0.storetest ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build

export RYC0_REPO="$PWD"
export RYC0_TEST_PRODUCTS=/tmp/ryc0-store-validation-build/Build/Products/Debug-iphonesimulator
test_project=$(mktemp -d)
xcodegen generate --spec Tests/StoreIntegration/project.yml --project "$test_project"
xcodebuild -project "$test_project/RYStoreIntegration.xcodeproj" \
  -scheme RYStoreIntegration -destination "id=$RYC0_TEST_SIMULATOR" \
  -derivedDataPath /tmp/ryc0-store-test-build -parallel-testing-enabled NO test

fixtures=$(python3 Tests/StoreIntegration/fixture_server.py --prepare-only)
xcrun simctl uninstall "$RYC0_TEST_SIMULATOR" com.ry0.ryC0.storetest || true
xcrun simctl install "$RYC0_TEST_SIMULATOR" "$RYC0_TEST_PRODUCTS/LiveContainer.app"
python3 Tests/StoreIntegration/seed_simulator.py "$RYC0_TEST_SIMULATOR" "$fixtures"
xcodebuild -project "$test_project/RYStoreIntegration.xcodeproj" \
  -scheme RYStoreUI -destination "id=$RYC0_TEST_SIMULATOR" \
  -derivedDataPath /tmp/ryc0-store-test-build -parallel-testing-enabled NO test
```

The simulator verifies that ryP0 is unpacked and registered as a guest. Execution of the device IPA, the guest Home swipe, and Lock Screen or Dynamic Island rendering require a signed device build.

## Background playback and empty switcher regression

`testZZCloseAllAndRejectEmptySwitcher` closes every seeded card, repeatedly taps
Apps with an empty list, and checks that the empty state survives relaunch.
The simulator cannot verify the physical rejection haptic or guest audio.

On a signed device, play audio in YouTube Music, leave ryC0 for another app,
lock/unlock, then return. Check uninterrupted playback and the same guest session,
including Now Playing/Live Activity updates. Repeat after returning to ryC0 Home,
and verify that explicitly closing the guest still terminates it. Exercise both
the legacy scene presenter and the hosting-controller API where available.
Background playback remains unresolved. The experimental fullscreen scene-lifecycle
forwarding was reverted after a device report of crashes when opening any guest.
The presenter and extension notification behavior match the pre-change implementation;
do not reintroduce this forwarding without a signed-device launch and playback test.

## ryP0 launch investigation

There is no bundle-identifier exception for ryP0 in `LCAppModel.runApp`,
`FullScreenGuestSession`, or the native switcher. Its special handling provisions
the bundled IPA, places it in the initial layout, and supports a notification test.
The bundled installer formerly disabled `spoofSDKVersion` specifically for ryP0.
It now enables it like other apps; a one-time migration also updates existing
visible and hidden ryP0 installations without overriding later manual changes.
All ordinary hosted guests use the same opening zoom, first-frame handshake,
cover dismissal, and switcher transitions. Classic mode, window mode, 32-bit/JIT
requirements, cold versus resumed launches, and the guest's first-frame timing
can select different behavior. Compare these settings and cold/resumed launches
on the affected device before attributing its motion difference to the bundle ID.
