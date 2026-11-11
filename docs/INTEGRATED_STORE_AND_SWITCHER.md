# Bundled ryP0 and App Switcher

ryP0 ships as a standalone guest IPA. The first launch imports it through the regular installer and puts it on the first Home Screen page. An existing ryP0 installation is kept. After provisioning succeeds, manually removing ryP0 is respected. Use the **Install in ryC0** destination in ryP0 to hand packages off to the host installer.

The bundled IPA is built from the public ryP0 target. Rebuild it from the ryP0 checkout using the unsigned Release `iphoneos` build, then run `python3 Scripts/ryp0/package_guest.py /path/to/ryP0.app` from ryC0. The bundle can be built independently once the IPA is present.

## Dock and Home gesture

Swipe along the dock to change pages. In edit mode, tap its page indicator to cycle pages. A new blank page becomes available when the last page fills. From a full-screen guest, swipe up from the small bar above the system Home indicator to return to ryC0.

## Notifications and Live Activities

On the Home Screen, pull down from just below the clock to open the notification center. Enable **Fix Local Notifications** in an app’s settings and reopen the app to capture its local alerts. The center can display immediate, time-interval and calendar notifications. Remote push still uses Apple Push Notification service and its signing entitlement.

A supported hosted guest can publish a Live Activity through the `LCSharedUtils` class method `publishGuestActivity:`. Pass a dictionary with a UUID string `id`, a short `title`, optional `detail` and optional numeric `progress` between zero and one. Pass the same ID without a title to end it. ryP0 sends download progress through this interface. ryC0 presents the activity through its WidgetKit extension when iOS Live Activities are enabled. Updates from classic guests can reach the host after it returns to the foreground. Third-party apps need this bridge to supply their activity state.

## Tendies wallpapers

In **Settings → Wallpaper**, choose **Import Tendies Wallpaper**. ryC0 plays embedded movies, frame sequences and supported declarative CAML layers on its Home Screen. The CAML player handles image layers, keyframe motion and particle emitters. System wallpaper providers and JavaScript effects require PosterBoard. The poster is used for Reduce Motion and in wallpaper previews.

## App Switcher reference and measurements

Apple documents the interactions in [Switch between open apps on iPhone](https://support.apple.com/guide/iphone/switch-between-open-apps-iph1a1f981ad/ios). The guide's [published App Switcher illustration](https://ipcdn-web.apple.com/assets/v2/web/e618f83c-acf5-4516-9710-ee6e890890b0) is a 490 × 1008 raster including a device bezel. Approximate image coordinates:

- Display interior: x = 22…467, y = 20…986 (445 × 966).
- Center Calendar card: top y ≈ 157, bottom y ≈ 828; preview/display height ≈ 0.695.
- Center card leading edge x ≈ 123; older Mail leading edge x ≈ 44. Their separation/display width ≈ 0.178.
- Newer Photos card leading edge x ≈ 362; separation from Calendar/display width ≈ 0.537.
- Preview center y/display height ≈ 0.49; center-card center x/display width ≈ 0.575.
- Preview corner radius ≈ 16% of preview width; header icon inset ≈ 8% of card width.

These are measurements from Apple's illustration, **not published SpringBoard layout constants**. The custom switcher uses 0.70 uniform preview scaling, 0.18 display-width leading exposure for the immediate older neighbor (including the first page), and 0.53 display-width forward stride. Deeper cards compress consistently and scale uniformly, preserving the display aspect ratio. Header icon/title separation is 10 points, and each header clips to its exposed strip to prevent label/icon collisions. Snapshots fit inside the preview rather than cropping differently sized guest windows.

The existing recent/running session model, horizontal gesture direction, velocity projection, edge resistance, focus retention, swipe-up closing, launch origins, and Reduce Motion handling remain. This follows Apple's [motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion). The deck remains a custom component; a public SpringBoard App Switcher API does not exist.
