#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LCUtils.h"

typedef NS_ENUM(NSInteger, LCOrientationLock){
    Disabled = 0,
    Landscape = 1,
    Portrait = 2
};

typedef NS_ENUM(NSInteger, MultitaskSpecified){
    MultitaskSpecifiedDefault = 0,
    MultitaskSpecifiedNo = 1,
    MultitaskSpecifiedYes = 2
};


@interface LCAppInfo : NSObject {
    NSMutableDictionary* _info;
    NSMutableDictionary* _infoPlist;
    NSString* _bundlePath;
}
@property NSString* relativeBundlePath;
@property bool isShared;
@property bool isJITNeeded;
@property bool classicMode;
@property (nonatomic, readonly) NSUInteger defaultClassicMode;
@property bool isLocked;
@property bool isHidden;
@property bool doSymlinkInbox;
@property bool hideLiveContainer;
// Whether the Home button that floats over the app while it runs is hidden
// (TweakLoader's LCHomeButtonController reads it as "hideHomeButton").
@property bool hideHomeButton;
@property bool dontLoadTweakLoader;
@property bool dontInjectTweakLoader;
@property LCOrientationLock orientationLock;
@property MultitaskSpecified multitaskSpecified;
@property bool fixFilePickerNew;
@property bool fixLocalNotification;
@property bool doUseLCBundleId;
@property NSString* selectedLanguage;
@property NSString* dataUUID;
@property NSString* tweakFolder;
@property NSArray<NSDictionary*>* containerInfo;
@property bool autoSaveDisabled;
@property bool dontSign;
@property bool spoofSDKVersion;
@property (nonatomic, strong) NSString* jitLaunchScriptJs;
@property (nonatomic, strong) NSString* selected32BitEmulator;
@property NSDate* lastLaunched;
@property NSDate* installationDate;
@property NSString* remark;
@property bool is32bit;
@property(readonly) bool is32bitEmulator;
@property UIColor* cachedColor;
@property UIColor* cachedColorDark;
@property UIImage* cachedIcon;
@property UIImage* cachedIconDark;
@property UIImage* cachedHomeScreenIcon;
@property UIImage* cachedHomeScreenIconDark;

- (void)setBundlePath:(NSString*)newBundlePath;
- (NSMutableDictionary*)info;
- (UIImage*)iconIsDarkIcon:(BOOL)isDarkIcon;
// The icon without IconServices' mask and border, for views that clip it to
// the Home Screen's icon shape themselves, so no light rim shows at its edges.
// One that hasn't been drawn yet is drawn here, on the calling thread.
- (UIImage*)homeScreenIconIsDarkIcon:(BOOL)isDarkIcon;
// The same icon once it has been drawn, from memory or from the file it was
// saved in, or nil before that. It never draws, so views can ask for it as
// they draw. Call it on the main thread.
- (UIImage*)cachedHomeScreenIconIsDarkIcon:(BOOL)isDarkIcon;
// Draws the same icon off the main thread, on the one queue every app's icon
// is drawn on, one at a time, and saves it. `completion` runs on the main
// queue once it's in memory, or once IconServices failed to draw it. Call it
// on the main thread.
- (void)drawHomeScreenIconIsDarkIcon:(BOOL)isDarkIcon completion:(void (^)(void))completion NS_SWIFT_DISABLE_ASYNC;
- (void)clearIconCache;
- (NSString*)displayName;
- (NSString*)bundlePath;
// Why the app's executable can't run in ryC0, read without changing it:
// it's missing, isn't a Mach-O, or is encrypted. Nil when it can run.
- (nullable NSString *)executableProblem;
- (NSString*)bundleIdentifier;
- (NSString*)version;
- (NSMutableArray<NSString *>*)urlSchemes;
- (instancetype)initWithBundlePath:(NSString*)bundlePath;
- (UIImage *)generateLiveContainerWrappedIconWithStyle:(GeneratedIconStyle)style;
- (NSDictionary *)generateWebClipConfigWithContainerId:(NSString*)containerId iconStyle:(GeneratedIconStyle)style;
- (void)save;
- (void)patchExecAndSignIfNeedWithCompletionHandler:(void(^)(bool success, NSString* errorInfo))completetionHandler progressHandler:(void(^)(NSProgress* progress))progressHandler  forceSign:(BOOL)forceSign;
@end
