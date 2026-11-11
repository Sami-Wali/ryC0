@import Foundation;

@class UIImage, UNNotificationRequest;

typedef NS_ENUM(NSInteger, LCGuestHomeControl) {
    LCGuestHomeControlBar,
    LCGuestHomeControlFloatingButton,
    LCGuestHomeControlClock,
};

FOUNDATION_EXPORT NSString *const LCGuestHomeControlKey;

@interface LCSharedUtils : NSObject
+ (NSString*) teamIdentifier;
+ (NSString *)appGroupID;
+ (NSString *)keychainGroupBase;
+ (NSURL*) appGroupPath;
+ (BOOL)hasAppGroup;
// Copies the settings saved while ryC0 had no app group (the "Unknown"
// suite in its own preferences) into the group's, once per group. Settings the
// group holds already are kept, and the certificate is only copied into a group
// without one. The first time ryC0 has a group, it also moves the app
// groups of apps inside into it, except names the group holds already. The main
// app calls it at launch, before anything reads them.
+ (void)migrateSharedDefaultsIfNeeded;
+ (NSString *)certificatePassword;
+ (LCGuestHomeControl)guestHomeControl;
+ (void)setAppSwitcherRequested:(BOOL)requested;
+ (BOOL)takeAppSwitcherRequest;
+ (void)setHomeReturnBackdrop:(nullable UIImage *)image;
+ (nullable UIImage *)takeHomeReturnBackdrop;
+ (void)setSwitcherPreview:(nullable UIImage *)image forBundlePath:(nonnull NSString *)bundlePath;
+ (nullable UIImage *)switcherPreviewForBundlePath:(nonnull NSString *)bundlePath NS_SWIFT_NAME(switcherPreview(forBundlePath:));
+ (nullable NSURL *)guestPreviewTransferURL:(nonnull NSString *)token;
+ (BOOL)launchToGuestAppWithClassicMode:(NSUInteger)classicMode;
+ (BOOL)launchToGuestAppWithURL:(NSURL *)url;
+ (NSURL *)installSourceURLFromLink:(NSURL *)link NS_SWIFT_NAME(installSourceURL(from:));
+ (NSURL *)takePendingInstallLink;
+ (void)setWebPageUrlForNextLaunch:(NSString*)urlString;
+ (BOOL)isLCSchemeInUse:(NSString*)lc;
+ (NSString*)getContainerUsingLCSchemeWithFolderName:(NSString*)folderName;
+ (void)setContainerUsingByLC:(NSString*)lc folderName:(NSString*)folderName auditToken:(uint64_t)val57;
+ (void)moveSharedAppFolderBack;
+ (NSBundle*)findBundleWithBundleId:(NSString*)bundleId isSharedAppOut:(bool*)isSharedAppOut;
+ (void)dumpPreferenceToPath:(NSString*)plistLocationTo dataUUID:(NSString*)dataUUID;
+ (NSString*)findDefaultContainerWithBundleId:(NSString*)bundleId;
// The URL scheme of the host application.
+ (NSString *)hostAppUrlScheme;
+ (NSArray<NSString*>*)lcUnorderedUrlSchemes;
+ (NSArray<NSString*>*)lcUrlSchemes;
@end

@interface LCSharedUtils (GuestNotifications)
+ (nullable NSURL *)guestEventsDirectory;
+ (nullable NSURL *)systemNotificationDirectoryForApp:(nonnull NSString *)app container:(nonnull NSString *)container;
+ (void)setGuestSystemNotificationDirectory:(nonnull NSURL *)directory;
+ (void)recordGuestNotification:(nonnull UNNotificationRequest *)request;
+ (void)recordGuestNotification:(nonnull UNNotificationRequest *)request
                         forApp:(nonnull NSString *)app
                      container:(nonnull NSString *)container;
+ (void)removeGuestNotificationsWithIdentifiers:(nullable NSArray<NSString *> *)identifiers
                                        pending:(BOOL)pending;
+ (nonnull NSArray<NSDictionary<NSString *, id> *> *)deliveredGuestNotifications;
+ (nonnull NSArray<NSDictionary<NSString *, id> *> *)guestNotificationsForSystemDelivery;
+ (void)clearDeliveredGuestNotifications;
+ (void)resetGuestNotifications;
+ (void)removeGuestNotificationsForApp:(nonnull NSString *)bundlePath;
@end


@interface LCSharedUtils (GuestActivities)
+ (BOOL)publishGuestActivity:(nonnull NSDictionary<NSString *, id> *)event;
+ (nonnull NSArray<NSDictionary<NSString *, id> *> *)guestActivities;
@end
