@import CommonCrypto;
@import MachO;

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LCAppInfo.h"
#import "LCUtils.h"
#import "../../LiveContainer/LCSharedUtils.h"


@implementation LCAppInfo

- (instancetype)initWithBundlePath:(NSString*)bundlePath {
    self = [super init];
    self.isShared = false;
	if(self) {
        _bundlePath = bundlePath;
        _infoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Info.plist", bundlePath]];
        _info = [NSMutableDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/LCAppInfo.plist", bundlePath]];
        if(!_info) {
            _info = [[NSMutableDictionary alloc] init];
        }
        if(!_infoPlist) {
            _infoPlist = [[NSMutableDictionary alloc] init];
        }
        
        // migrate old appInfo
        if(_infoPlist[@"LCPatchRevision"] && [_info count] == 0) {
            NSArray* lcAppInfoKeys = @[
                @"LCPatchRevision",
                @"LCOrignalBundleIdentifier",
                @"LCDataUUID",
                @"LCTweakFolder",
                @"LCJITLessSignID",
                @"LCSelectedLanguage",
                @"LCExpirationDate",
                @"LCTeamId",
                @"isJITNeeded",
                @"isLocked",
                @"isHidden",
                @"doUseLCBundleId",
                @"doSymlinkInbox",
                @"bypassAssertBarrierOnQueue",
                @"signer",
                @"LCOrientationLock",
                @"cachedColor",
                @"LCContainers",
                @"hideLiveContainer",
                @"jitLaunchScriptJs"
            ];
            for(NSString* key in lcAppInfoKeys) {
                _info[key] = _infoPlist[key];
                [_infoPlist removeObjectForKey:key];
            }
            [_infoPlist writeBinToFile:[NSString stringWithFormat:@"%@/Info.plist", bundlePath] atomically:YES];
            [self save];
        }
        
        // fix bundle id and execName if crash when signing
        if (_infoPlist[@"LCBundleIdentifier"]) {
            _infoPlist[@"CFBundleExecutable"] = _infoPlist[@"LCBundleExecutable"];
            _infoPlist[@"CFBundleIdentifier"] = _infoPlist[@"LCBundleIdentifier"];
            [_infoPlist removeObjectForKey:@"LCBundleExecutable"];
            [_infoPlist removeObjectForKey:@"LCBundleIdentifier"];
            [_infoPlist writeBinToFile:[NSString stringWithFormat:@"%@/Info.plist", bundlePath] atomically:YES];
        }

        _autoSaveDisabled = false;
    }
    return self;
}

- (void)setBundlePath:(NSString*)newBundlePath {
    _bundlePath = newBundlePath;
}

- (NSMutableArray<NSString *>*)urlSchemes {
    // Every URL scheme the app declares, in order. The types are checked, as
    // a value an app got wrong would otherwise crash ryC0 each time it
    // starts, before the app could be removed.
    NSMutableArray<NSString *> *urlSchemes = [[NSMutableArray alloc] init];
    NSArray *urlTypes = _infoPlist[@"CFBundleURLTypes"];
    if (![urlTypes isKindOfClass:NSArray.class]) {
        return urlSchemes;
    }
    for (NSDictionary *urlType in urlTypes) {
        if (![urlType isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSArray *schemes = urlType[@"CFBundleURLSchemes"];
        if (![schemes isKindOfClass:NSArray.class]) {
            continue;
        }
        for (NSString *scheme in schemes) {
            if ([scheme isKindOfClass:NSString.class]) {
                [urlSchemes addObject:scheme];
            }
        }
    }
    return urlSchemes;
}

- (NSString*)displayName {
    if (_infoPlist[@"CFBundleDisplayName"]) {
        return _infoPlist[@"CFBundleDisplayName"];
    } else if (_infoPlist[@"CFBundleName"]) {
        return _infoPlist[@"CFBundleName"];
    } else if (_infoPlist[@"CFBundleExecutable"]) {
        return _infoPlist[@"CFBundleExecutable"];
    } else {
        return @"App Corrupted, Please Reinstall This App";
    }
}

- (NSString*)version {
    // A version some apps write as a number is read as one.
    for (NSString *key in @[@"CFBundleShortVersionString", @"CFBundleVersion"]) {
        id version = _infoPlist[key];
        if ([version isKindOfClass:NSString.class]) {
            return version;
        }
        if ([version isKindOfClass:NSNumber.class]) {
            return [version stringValue];
        }
    }
    return @"Unknown";
}

- (NSString*)bundleIdentifier {
    NSString* ans = nil;
    if([self doUseLCBundleId]) {
        ans = _info[@"LCOrignalBundleIdentifier"];
    } else {
        ans = _infoPlist[@"CFBundleIdentifier"];
    }
    if(ans) {
        return ans;
    } else {
        return @"Unknown";
    }
}

- (NSString*)dataUUID {
    return _info[@"LCDataUUID"];
}

- (NSString*)tweakFolder {
    return _info[@"LCTweakFolder"];
}

- (void)setDataUUID:(NSString *)uuid {
    _info[@"LCDataUUID"] = uuid;
    [self save];
}

- (void)setTweakFolder:(NSString *)tweakFolder {
    _info[@"LCTweakFolder"] = tweakFolder;
    [self save];
}

- (NSString*)selectedLanguage {
    return _info[@"LCSelectedLanguage"];
}

- (void)setSelectedLanguage:(NSString *)selectedLanguage {
    if([selectedLanguage isEqualToString: @""]) {
        _info[@"LCSelectedLanguage"] = nil;
    } else {
        _info[@"LCSelectedLanguage"] = selectedLanguage;
    }
    
    [self save];
}

- (NSString*)bundlePath {
    return _bundlePath;
}

- (NSMutableDictionary*)info {
    return _info;
}

- (UIImage*)iconIsDarkIcon:(BOOL)isDarkIcon {
    // if icon is already loaded in memory, return it
    if(_cachedIcon && !isDarkIcon) {
        return _cachedIcon;
    } else if (_cachedIconDark && isDarkIcon) {
        return _cachedIconDark;
    }
    
    // check if icon is cached on disk
    UIImage* uiIcon;
    NSString* cachedIconPath;
    if(isDarkIcon) {
        cachedIconPath = [_bundlePath stringByAppendingPathComponent:@"LCAppIconDark.png"];
    } else {
        cachedIconPath = [_bundlePath stringByAppendingPathComponent:@"LCAppIconLight.png"];
    }
    NSURL* cachedIconUrl = [NSURL fileURLWithPath:cachedIconPath];
    
    if([NSFileManager.defaultManager fileExistsAtPath:cachedIconPath]) {
        CGImageRef imageRef = loadCGImageFromURL(cachedIconUrl);
        if (imageRef) {
            uiIcon = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
        }
    }
    
    // generate and save icon cache to disk
    if(!uiIcon) {
        uiIcon = [UIImage generateIconForBundleURL:[NSURL fileURLWithPath:_bundlePath] style:isDarkIcon hasBorder:YES];
        saveCGImage([uiIcon CGImage], cachedIconUrl);
    }
    
    // cache icon to memory
    if(isDarkIcon) {
        _cachedIconDark = uiIcon;
    } else {
        _cachedIcon = uiIcon;
    }

    return uiIcon;

}

// The queue every app's Home Screen icon is drawn on, one at a time, off the
// main thread.
static dispatch_queue_t LCHomeScreenIconQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("LCHomeScreenIcons", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0));
    });
    return queue;
}

// The file the app at `bundlePath` keeps its Home Screen icon in.
static NSString* LCHomeScreenIconPath(NSString* bundlePath, BOOL isDarkIcon) {
    return [bundlePath stringByAppendingPathComponent:isDarkIcon ? @"LCAppHomeScreenIconDark.png" : @"LCAppHomeScreenIconLight.png"];
}

// The icon saved at `path`, or nil when there's none.
static UIImage* LCLoadSavedIcon(NSString* path) {
    if(![NSFileManager.defaultManager fileExistsAtPath:path]) {
        return nil;
    }
    CGImageRef imageRef = loadCGImageFromURL([NSURL fileURLWithPath:path]);
    if(!imageRef) {
        return nil;
    }
    UIImage* icon = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return icon;
}

// Draws the Home Screen icon of the app at `bundlePath` with IconServices and
// saves it. The file is written in one step, so it's never read half written.
// Nil when IconServices drew nothing.
static UIImage* LCDrawHomeScreenIcon(NSString* bundlePath, BOOL isDarkIcon) {
    UIImage* icon = [UIImage generateIconForBundleURL:[NSURL fileURLWithPath:bundlePath] style:isDarkIcon hasBorder:NO];
    if(!icon.CGImage) {
        return nil;
    }
    [UIImagePNGRepresentation(icon) writeToFile:LCHomeScreenIconPath(bundlePath, isDarkIcon) atomically:YES];
    return icon;
}

- (UIImage*)cachedHomeScreenIconIsDarkIcon:(BOOL)isDarkIcon {
    UIImage* uiIcon = isDarkIcon ? _cachedHomeScreenIconDark : _cachedHomeScreenIcon;
    if(uiIcon) {
        return uiIcon;
    }

    uiIcon = LCLoadSavedIcon(LCHomeScreenIconPath(_bundlePath, isDarkIcon));
    if(isDarkIcon) {
        _cachedHomeScreenIconDark = uiIcon;
    } else {
        _cachedHomeScreenIcon = uiIcon;
    }
    return uiIcon;
}

- (UIImage*)homeScreenIconIsDarkIcon:(BOOL)isDarkIcon {
    UIImage* uiIcon = [self cachedHomeScreenIconIsDarkIcon:isDarkIcon];
    if(uiIcon) {
        return uiIcon;
    }

    uiIcon = LCDrawHomeScreenIcon(_bundlePath, isDarkIcon);
    if(isDarkIcon) {
        _cachedHomeScreenIconDark = uiIcon;
    } else {
        _cachedHomeScreenIcon = uiIcon;
    }
    return uiIcon;
}

- (void)drawHomeScreenIconIsDarkIcon:(BOOL)isDarkIcon completion:(void (^)(void))completion {
    // Only the path goes to the queue: the icons in memory are only read and
    // changed on the main thread.
    NSString* bundlePath = _bundlePath;
    dispatch_async(LCHomeScreenIconQueue(), ^{
        // An icon asked for again while it waited has been saved by now.
        UIImage* icon = LCLoadSavedIcon(LCHomeScreenIconPath(bundlePath, isDarkIcon));
        if(!icon) {
            icon = LCDrawHomeScreenIcon(bundlePath, isDarkIcon);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if(icon) {
                if(isDarkIcon) {
                    self->_cachedHomeScreenIconDark = icon;
                } else {
                    self->_cachedHomeScreenIcon = icon;
                }
            }
            completion();
        });
    });
}

- (void)clearIconCache {
    NSString* lightModeIconPath = [_bundlePath stringByAppendingPathComponent:@"LCAppIconLight.png"];
    NSString* darkModeIconPath = [_bundlePath stringByAppendingPathComponent:@"LCAppIconDark.png"];
    [NSFileManager.defaultManager removeItemAtPath:lightModeIconPath error:nil];
    [NSFileManager.defaultManager removeItemAtPath:darkModeIconPath error:nil];
    [NSFileManager.defaultManager removeItemAtPath:[_bundlePath stringByAppendingPathComponent:@"LCAppHomeScreenIconLight.png"] error:nil];
    [NSFileManager.defaultManager removeItemAtPath:[_bundlePath stringByAppendingPathComponent:@"LCAppHomeScreenIconDark.png"] error:nil];
    [self setCachedColor:nil];
    [self setCachedColorDark:nil];
    _cachedIcon = nil;
    _cachedIconDark = nil;
    _cachedHomeScreenIcon = nil;
    _cachedHomeScreenIconDark = nil;
}

- (UIImage *)generateLiveContainerWrappedIconWithStyle:(GeneratedIconStyle)style {
    UIImage* icon = [UIImage generateIconForBundleURL:[NSURL fileURLWithPath:_bundlePath] style:style hasBorder:NO];
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"LCFrameShortcutIcons"]) {
        return icon;
    }

    UIImage *lcIcon = [UIImage imageNamed:@"AppIcon60x60@2x"];
    CGFloat iconXY = (lcIcon.size.width - 40) / 2;
    UIGraphicsBeginImageContextWithOptions(lcIcon.size, NO, 0.0);
    [lcIcon drawInRect:CGRectMake(0, 0, lcIcon.size.width, lcIcon.size.height)];
    CGRect rect = CGRectMake(iconXY, iconXY, 40, 40);
    [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:7] addClip];
    [icon drawInRect:rect];
    UIImage *newIcon = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newIcon;
}

- (NSDictionary *)generateWebClipConfigWithContainerId:(NSString*)containerId iconStyle:(GeneratedIconStyle)style{
    NSString* appClipUrl;
    if(containerId) {
        appClipUrl = [NSString stringWithFormat:@"%@://livecontainer-launch?bundle-name=%@&container-folder-name=%@", LCSharedUtils.hostAppUrlScheme, self.bundlePath.lastPathComponent, containerId];
    } else {
        appClipUrl = [NSString stringWithFormat:@"%@://livecontainer-launch?bundle-name=%@", LCSharedUtils.hostAppUrlScheme, self.bundlePath.lastPathComponent];
    }
    
    UIImage* icon = [self generateLiveContainerWrappedIconWithStyle:style];
    
    NSString *profileIdentifier = [NSString stringWithFormat:@"%@.%@", NSBundle.mainBundle.bundleIdentifier, self.bundleIdentifier];
    NSDictionary *payload = @{
        @"FullScreen": @YES,
        @"Icon": UIImagePNGRepresentation(icon),
        @"IgnoreManifestScope": @YES,
        @"IsRemovable": @YES,
        @"Label": self.displayName,
        @"PayloadDescription": [NSString stringWithFormat:@"Web Clip for launching %@ (%@) in ryC0", self.displayName, self.bundlePath.lastPathComponent],
        @"PayloadDisplayName": self.displayName,
        @"PayloadIdentifier": [profileIdentifier stringByAppendingString:@".webclip"],
        @"PayloadType": @"com.apple.webClip.managed",
        @"PayloadUUID": NSUUID.UUID.UUIDString,
        @"PayloadVersion": @(1),
        @"Precomposed": @NO,
        @"toPayloadOrganization": @"ryC0",
        @"URL": appClipUrl
    };
    return @{
        @"ConsentText": @{
            @"default": [NSString stringWithFormat:@"This profile installs a web clip which opens %@ (%@) in ryC0", self.displayName, self.bundlePath.lastPathComponent]
        },
        @"PayloadContent": @[payload],
        @"PayloadDescription": payload[@"PayloadDescription"],
        @"PayloadDisplayName": self.displayName,
        @"PayloadIdentifier": profileIdentifier,
        @"PayloadOrganization": @"ryC0",
        @"PayloadRemovalDisallowed": @(NO),
        @"PayloadType": @"Configuration",
        @"PayloadUUID": NSUUID.UUID.UUIDString,
        @"PayloadVersion": @(1),
    };
}

- (void)save {
    if(!_autoSaveDisabled) {
        [_info writeBinToFile:[NSString stringWithFormat:@"%@/LCAppInfo.plist", _bundlePath] atomically:YES];
    }

}

- (NSString *)executableProblem {
    NSString *execPath = [NSString stringWithFormat:@"%@/%@", self.bundlePath, _infoPlist[@"CFBundleExecutable"]];
    __block bool isEncrypted = false;
    NSString *error = LCParseMachO(execPath.UTF8String, true, ^(const char *path, struct mach_header_64 *header, int fd, void *filePtr) {
        isEncrypted |= LCIsMachOEncrypted(header);
    });
    if (error) {
        return error;
    }
    if (isEncrypted) {
        return @"The app you tried to install is encrypted. Please provide decrypted app.";
    }
    return nil;
}

- (void)patchExecAndSignIfNeedWithCompletionHandler:(void(^)(bool success, NSString* errorInfo))completetionHandler progressHandler:(void(^)(NSProgress* progress))progressHandler forceSign:(BOOL)forceSign {
    [NSUserDefaults.standardUserDefaults setObject:@(YES) forKey:@"SigningInProgress"];
    NSString *appPath = self.bundlePath;

    NSMutableDictionary *info = _info;
    NSMutableDictionary *infoPlist = _infoPlist;
    if (!info) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"SigningInProgress"];
        completetionHandler(NO, @"Info.plist not found");
        return;
    }
    NSFileManager* fm = NSFileManager.defaultManager;
    NSString *execPath = [NSString stringWithFormat:@"%@/%@", appPath, _infoPlist[@"CFBundleExecutable"]];
    
    // Update patch
    int currentPatchRev = 7;
    bool needPatch = [info[@"LCPatchRevision"] intValue] < currentPatchRev;
    if (needPatch || forceSign) {
        // Use a fresh inode before patching to avoid a cached code signature.
        NSString *backupPath = [NSString stringWithFormat:@"%@/%@_LiveContainerPatchBackUp", appPath, _infoPlist[@"CFBundleExecutable"]];
        NSError *err = nil;
        if ([fm fileExistsAtPath:execPath]) {
            // a backup left by an interrupted run is stale while the executable still exists
            [fm removeItemAtPath:backupPath error:nil];
            if (![fm copyItemAtPath:execPath toPath:backupPath error:&err]) {
                [fm removeItemAtPath:backupPath error:nil];
                [NSUserDefaults.standardUserDefaults removeObjectForKey:@"SigningInProgress"];
                completetionHandler(NO, err.localizedDescription);
                return;
            }
        }
        // Replaces the executable atomically, or restores the backup from an
        // older interrupted install if the executable is missing.
        if (rename(backupPath.fileSystemRepresentation, execPath.fileSystemRepresentation) != 0) {
            err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
            [NSUserDefaults.standardUserDefaults removeObjectForKey:@"SigningInProgress"];
            completetionHandler(NO, err.localizedDescription);
            return;
        }
    }
    
    bool is32bit = false;
    if (needPatch) {
        __block bool has64bitSlice = NO;
        __block bool isEncrypted = false;
        NSString *error = LCParseMachO(execPath.UTF8String, false, ^(const char *path, struct mach_header_64 *header, int fd, void* filePtr) {
            if(header->cputype == CPU_TYPE_ARM64) {
                has64bitSlice |= YES;
                int patchResult = LCPatchExecSlice(path, header, ![self dontInjectTweakLoader]);
                if(patchResult & PATCH_EXEC_RESULT_NO_SPACE_FOR_TWEAKLOADER) {
                    info[@"LCTweakLoaderCantInject"] = @YES;
                    info[@"dontInjectTweakLoader"] = @YES;
                }
                if(patchResult & PATCH_EXEC_RESULT_SEG_COUNT_MISMATCH) {
                    info[@"segCountMismatch"] = @YES;
                }
            }
            isEncrypted |= LCIsMachOEncrypted(header);
        });
        is32bit = !has64bitSlice;
        if (isEncrypted) {
            error = @"The app you tried to install is encrypted. Please provide decrypted app.";
        }
        if (error) {
            [NSUserDefaults.standardUserDefaults removeObjectForKey:@"SigningInProgress"];
            completetionHandler(NO, error);
            return;
        }
        self.is32bit = is32bit;
        if (!is32bit) {
            LCPatchAppBundleFixupARM64eSlice([NSURL fileURLWithPath:appPath]);
        } else {
            self.isJITNeeded = YES;
            self.classicMode = YES;
            self.spoofSDKVersion = YES;
        }
        info[@"LCPatchRevision"] = @(currentPatchRev);
        forceSign = true;
        
        [self save];
    }

    if (!LCSharedUtils.certificatePassword || self.is32bit || self.dontSign) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"SigningInProgress"];
        completetionHandler(YES, nil);
        return;
    }

    // check if iOS think this app's signature is valid, if so, we can skip any further signature check
    NSString* executablePath = [appPath stringByAppendingPathComponent:infoPlist[@"CFBundleExecutable"]];
    if(!forceSign) {
        bool signatureValid = checkCodeSignature(executablePath.UTF8String);
        
        if(signatureValid) {
            [NSUserDefaults.standardUserDefaults removeObjectForKey:@"SigningInProgress"];
            completetionHandler(YES, nil);
            return;
        }
    }
    
    if (!LCUtils.certificateData) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"SigningInProgress"];
        completetionHandler(NO, @"lc.signer.noCertificateFoundErr");
        return;
    }
    
    // Sign app if JIT-less is set up
        NSURL *appPathURL = [NSURL fileURLWithPath:appPath];
            void (^signCompletionHandler)(BOOL success, NSError *error)  = ^(BOOL success, NSError *_Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"SigningInProgress"];
                    if(!success) {
                        completetionHandler(NO, error.localizedDescription);
                    } else {
                        bool signatureValid = checkCodeSignature(executablePath.UTF8String);
                        if(signatureValid) {
                            completetionHandler(YES, [error localizedDescription]);
                        } else {
                            completetionHandler(NO, @"lc.signer.latestCertificateInvalidErr");
                        }
                    }
                    
                });
            };
            
            __block NSProgress *progress = [LCUtils signAppBundleWithZSign:appPathURL completionHandler:signCompletionHandler];

            if (progress) {
                progressHandler(progress);
            }
}

- (bool)isJITNeeded {
    if(_info[@"isJITNeeded"] != nil) {
        return [_info[@"isJITNeeded"] boolValue];
    } else {
        return NO;
    }
}
- (void)setIsJITNeeded:(bool)isJITNeeded {
    _info[@"isJITNeeded"] = [NSNumber numberWithBool:isJITNeeded];
    [self save];
    
}

- (bool)classicMode {
    return [_info[@"classicMode"] boolValue];
}

- (void)setClassicMode:(bool)classicMode {
    _info[@"classicMode"] = @(classicMode);

    if(classicMode) {
        [self defaultClassicMode];
    } else {
        _info[@"LCClassicModeCache"] = nil;
        [self save];
    }
}

- (NSUInteger)defaultClassicMode {
    if(!self.classicMode) {
        return 0;
    }

    NSInteger systemMajorVersion = NSProcessInfo.processInfo.operatingSystemVersion.majorVersion;
    NSDictionary *cache = _info[@"LCClassicModeCache"];
    NSNumber *cachedMode = cache[@"defaultClassicMode"];
    NSNumber *cachedSystemMajorVersion = cache[@"systemMajorVersion"];
    if([cachedMode isKindOfClass:NSNumber.class] &&
       [cachedSystemMajorVersion isKindOfClass:NSNumber.class] &&
       cachedSystemMajorVersion.integerValue == systemMajorVersion) {
        return cachedMode.unsignedIntegerValue;
    }

    NSError *error = nil;
    NSNumber *mode = LCGetDefaultClassicMode([NSURL fileURLWithPath:self.bundlePath]);

    _info[@"LCClassicModeCache"] = @{
        @"defaultClassicMode": mode,
        @"systemMajorVersion": @(systemMajorVersion),
    };
    [self save];
    return mode.unsignedIntegerValue;
}

- (bool)isLocked {
    if(_info[@"isLocked"] != nil) {
        return [_info[@"isLocked"] boolValue];
    } else {
        return NO;
    }
}
- (void)setIsLocked:(bool)isLocked {
    _info[@"isLocked"] = [NSNumber numberWithBool:isLocked];
    [self save];
    
}

- (bool)isHidden {
    if(_info[@"isHidden"] != nil) {
        return [_info[@"isHidden"] boolValue];
    } else {
        return NO;
    }
}
- (void)setIsHidden:(bool)isHidden {
    _info[@"isHidden"] = [NSNumber numberWithBool:isHidden];
    [self save];
    
}

- (bool)doSymlinkInbox {
    if(_info[@"doSymlinkInbox"] != nil) {
        return [_info[@"doSymlinkInbox"] boolValue];
    } else {
        return NO;
    }
}
- (void)setDoSymlinkInbox:(bool)doSymlinkInbox {
    _info[@"doSymlinkInbox"] = [NSNumber numberWithBool:doSymlinkInbox];
    [self save];
    
}

- (bool)hideLiveContainer {
    if(_info[@"hideLiveContainer"] != nil) {
        return [_info[@"hideLiveContainer"] boolValue];
    } else {
        return NO;
    }
}
- (void)setHideLiveContainer:(bool)hideLiveContainer {
    _info[@"hideLiveContainer"] = [NSNumber numberWithBool:hideLiveContainer];
    [self save];
}

- (bool)hideHomeButton {
    return [_info[@"hideHomeButton"] boolValue];
}
- (void)setHideHomeButton:(bool)hideHomeButton {
    _info[@"hideHomeButton"] = [NSNumber numberWithBool:hideHomeButton];
    [self save];
}

- (bool)dontInjectTweakLoader {
    if(_info[@"dontInjectTweakLoader"] != nil) {
        return [_info[@"dontInjectTweakLoader"] boolValue];
    } else {
        return NO;
    }
}
- (void)setDontInjectTweakLoader:(bool)dontInjectTweakLoader {
    if([_info[@"dontInjectTweakLoader"] boolValue] == dontInjectTweakLoader) {
        return;
    }
    
    _info[@"dontInjectTweakLoader"] = [NSNumber numberWithBool:dontInjectTweakLoader];
    // we have to update patch to achieve this
    _info[@"LCPatchRevision"] = @(-1);
    [self save];
}

- (bool)dontLoadTweakLoader {
    if(_info[@"dontLoadTweakLoader"] != nil) {
        return [_info[@"dontLoadTweakLoader"] boolValue];
    } else {
        return NO;
    }
}
- (void)setDontLoadTweakLoader:(bool)dontLoadTweakLoader {
    _info[@"dontLoadTweakLoader"] = [NSNumber numberWithBool:dontLoadTweakLoader];
    [self save];
}

- (bool)doUseLCBundleId {
    if(_info[@"doUseLCBundleId"] != nil) {
        return [_info[@"doUseLCBundleId"] boolValue];
    } else {
        return NO;
    }
}
- (void)setDoUseLCBundleId:(bool)doUseLCBundleId {
    _info[@"doUseLCBundleId"] = [NSNumber numberWithBool:doUseLCBundleId];
    NSString *infoPath = [NSString stringWithFormat:@"%@/Info.plist", self.bundlePath];
    if(doUseLCBundleId) {
        _info[@"LCOrignalBundleIdentifier"] = _infoPlist[@"CFBundleIdentifier"];
        _infoPlist[@"CFBundleIdentifier"] = NSBundle.mainBundle.bundleIdentifier;
    } else if (_info[@"LCOrignalBundleIdentifier"]) {
        _infoPlist[@"CFBundleIdentifier"] = _info[@"LCOrignalBundleIdentifier"];
        [_info removeObjectForKey:@"LCOrignalBundleIdentifier"];
    }
    [_infoPlist writeBinToFile:infoPath atomically:YES];
    [self save];
}

- (bool)fixFilePickerNew {
    if(_info[@"fixFilePickerNew"] != nil) {
        return [_info[@"fixFilePickerNew"] boolValue];
    } else {
        return NO;
    }
}

- (void)setFixFilePickerNew:(bool)fixFilePickerNew {
    _info[@"fixFilePickerNew"] = @(fixFilePickerNew);
    [self save];
}

- (bool)fixLocalNotification {
    if(_info[@"fixLocalNotification"] != nil) {
        return [_info[@"fixLocalNotification"] boolValue];
    } else {
        return NO;
    }
}

- (void)setFixLocalNotification:(bool)fixLocalNotification {
    _info[@"fixLocalNotification"] = @(fixLocalNotification);
    [self save];
}

- (LCOrientationLock)orientationLock {
    return (LCOrientationLock) [((NSNumber*) _info[@"LCOrientationLock"]) intValue];
}
- (void)setOrientationLock:(LCOrientationLock)orientationLock {
    _info[@"LCOrientationLock"] = [NSNumber numberWithInt:(int) orientationLock];
    [self save];
}

- (MultitaskSpecified)multitaskSpecified {
    return (LCOrientationLock) [((NSNumber*) _info[@"MultitaskSpecified"]) intValue];
}
- (void)setMultitaskSpecified:(MultitaskSpecified)multitaskSpecified {
    _info[@"MultitaskSpecified"] = [NSNumber numberWithInt:(int) multitaskSpecified];
    [self save];
}

- (UIColor*)cachedColor {
    if(_info[@"cachedColor"] != nil) {
        NSData *colorData = _info[@"cachedColor"];
        NSError* error;
        UIColor *color = [NSKeyedUnarchiver unarchivedObjectOfClass:UIColor.class fromData:colorData error:&error];
        if (!error) {
            return color;
        } else {
            NSLog(@"[LC] failed to get color %@", error);
            return nil;
        }
    } else {
        return nil;
    }
}

- (void)setCachedColor:(UIColor*) color {
    if(color == nil) {
        _info[@"cachedColor"] = nil;
    } else {
        NSError* error;
        NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color requiringSecureCoding:YES error:&error];
        [_info setObject:colorData forKey:@"cachedColor"];
        if(error) {
            NSLog(@"[LC] failed to set color %@", error);
        }

    }
    [self save];
}

- (UIColor*)cachedColorDark {
    if(_info[@"cachedColorDark"] != nil) {
        NSData *colorData = _info[@"cachedColorDark"];
        NSError* error;
        UIColor *color = [NSKeyedUnarchiver unarchivedObjectOfClass:UIColor.class fromData:colorData error:&error];
        if (!error) {
            return color;
        } else {
            NSLog(@"[LC] failed to get color %@", error);
            return nil;
        }
    } else {
        return nil;
    }
}

- (void)setCachedColorDark:(UIColor*)color {
    if(color == nil) {
        _info[@"cachedColorDark"] = nil;
    } else {
        NSError* error;
        NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color requiringSecureCoding:YES error:&error];
        [_info setObject:colorData forKey:@"cachedColorDark"];
        if(error) {
            NSLog(@"[LC] failed to set color %@", error);
        }

    }
    [self save];
}

- (NSArray<NSDictionary*>* )containerInfo {
    return _info[@"LCContainers"];
}

- (void)setContainerInfo:(NSArray<NSDictionary *> *)containerInfo {
    _info[@"LCContainers"] = containerInfo;
    [self save];
}

- (bool)is32bit {
    if(_info[@"is32bit"] != nil) {
        return [_info[@"is32bit"] boolValue];
    } else {
        return NO;
    }
}
- (void)setIs32bit:(bool)is32bit {
    _info[@"is32bit"] = [NSNumber numberWithBool:is32bit];
    [self save];
    
}
- (bool)is32bitEmulator {
    return [_infoPlist[@"LC32BitTranslationLayer"] boolValue];
}

- (bool)dontSign {
    if(_info[@"dontSign"] != nil) {
        return [_info[@"dontSign"] boolValue];
    } else {
        return NO;
    }
}
- (void)setDontSign:(bool)dontSign {
    _info[@"dontSign"] = [NSNumber numberWithBool:dontSign];
    [self save];
    
}

- (NSString *)jitLaunchScriptJs {
    if (self.is32bit && LCUtils.isTXMScriptRequired) {
        return LCUtils.base64EncodedUniversalJITScript;
    }
    return _info[@"jitLaunchScriptJs"];
}

- (void)setJitLaunchScriptJs:(NSString *)jitLaunchScriptJs {
    if (jitLaunchScriptJs.length > 0) {
        _info[@"jitLaunchScriptJs"] = jitLaunchScriptJs;
    } else {
        [_info removeObjectForKey:@"jitLaunchScriptJs"];
    }
    if (!_autoSaveDisabled) [self save];
}

- (NSString *)selected32BitEmulator {
    return _info[@"selected32BitEmulator"];
}

- (void)setSelected32BitEmulator:(NSString *)selected32BitEmulator {
    if (selected32BitEmulator.length > 0) {
        _info[@"selected32BitEmulator"] = selected32BitEmulator;
    } else {
        [_info removeObjectForKey:@"selected32BitEmulator"];
    }
    if (!_autoSaveDisabled) [self save];
}

- (bool)spoofSDKVersion {
    if(!_info[@"spoofSDKVersion"]) {
        return false;
    } else {
        return [_info[@"spoofSDKVersion"] unsignedIntValue] != 0;
    }
}

- (void)setSpoofSDKVersion:(bool)doSpoof {
    if(!doSpoof) {
        _info[@"spoofSDKVersion"] = 0;
    } else {
        NSString *execPath = [NSString stringWithFormat:@"%@/%@", _bundlePath, _infoPlist[@"CFBundleExecutable"]];
        __block uint32_t sdkVersion = 0;
        LCParseMachO(execPath.UTF8String, true, ^(const char *path, struct mach_header_64 *header, int fd, void *filePtr) {
            sdkVersion = dyld_get_sdk_version((const struct mach_header *)header);
        });
        // Hardcode spoofed SDK to iOS 11 if lower, as lower causes `Error in compatibility flow` crashes
        // for 32-bit apps, eg LiveExec32 has special hooks to fix issues, might cherry pick here later if needed
        uint32_t minSDK = self.is32bit ? 0x20000 : 0xb0000;
        if ((self.is32bit || sdkVersion) && sdkVersion < minSDK) {
            sdkVersion = minSDK;
        }
        NSLog(@"[LC] sdkversion = %8x", sdkVersion);
        _info[@"spoofSDKVersion"] = [NSNumber numberWithUnsignedInt:sdkVersion];
    }
    [self save];
}

- (NSDate*)lastLaunched {
    return _info[@"lastLaunched"];
}

- (void)setLastLaunched:(NSDate*)lastLaunched {
    _info[@"lastLaunched"] = lastLaunched;
    [self save];
}

- (NSDate*)installationDate {
    return _info[@"installationDate"];
}

- (void)setInstallationDate:(NSDate*)installationDate {
    _info[@"installationDate"] = installationDate;
    [self save];
}

- (NSString*)remark {
    return _info[@"remark"];
}

- (void)setRemark:(NSString *)remark {
    if([remark isEqualToString: @""]) {
        _info[@"remark"] = nil;
    } else {
        _info[@"remark"] = remark;
    }
    [self save];
}

@end
