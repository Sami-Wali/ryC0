#import "LCSharedUtils.h"
#import "FoundationPrivate.h"
#import "UIKitPrivate.h"
#import "utils.h"
@import MachO;

extern NSUserDefaults *lcUserDefaults;
extern NSString *lcAppUrlScheme;
extern NSBundle *lcMainBundle;

NSString* FBSOpenApplicationOptionKeyActivateAsClassic = @"__ActivateAsClassic";
NSString* FBSOpenApplicationOptionKeyPayloadURL = @"__PayloadURL";

static NSString * const LCAppGroupBase = @"group.com.ry0.ryC0";

static NSString * const LCAppSwitcherRequestKey = @"RYC0AppSwitcherRequest";
static NSString * const LCPendingInstallLinkKey = @"RYC0PendingInstallLink";
NSString *const LCGuestHomeControlKey = @"RYC0GuestHomeControl";

@implementation LCSharedUtils

+ (LCGuestHomeControl)guestHomeControl {
    NSUserDefaults *defaults = lcUserDefaults ?: NSUserDefaults.standardUserDefaults;
    switch ([defaults integerForKey:LCGuestHomeControlKey]) {
        case LCGuestHomeControlFloatingButton: return LCGuestHomeControlFloatingButton;
        case LCGuestHomeControlClock: return LCGuestHomeControlClock;
        default: return LCGuestHomeControlBar;
    }
}

+ (void)setAppSwitcherRequested:(BOOL)requested {
    NSUserDefaults *defaults = lcUserDefaults ?: NSUserDefaults.standardUserDefaults;
    if (requested) {
        [defaults setObject:NSDate.date forKey:LCAppSwitcherRequestKey];
    } else {
        [defaults removeObjectForKey:LCAppSwitcherRequestKey];
    }
}

+ (BOOL)takeAppSwitcherRequest {
    NSUserDefaults *defaults = lcUserDefaults ?: NSUserDefaults.standardUserDefaults;
    id request = [defaults objectForKey:LCAppSwitcherRequestKey];
    [defaults removeObjectForKey:LCAppSwitcherRequestKey];
    if (![request isKindOfClass:NSDate.class]) {
        return NO;
    }
    NSTimeInterval age = [NSDate.date timeIntervalSinceDate:request];
    return age >= 0 && age < 30;
}

static NSString *LCSwitcherCacheDirectory(void) {
    const char *home = getenv("LC_HOME_PATH");
    NSString *homePath = home ? [NSString stringWithUTF8String:home] : NSHomeDirectory();
    return [homePath stringByAppendingPathComponent:@"Library/Caches/ryC0Switcher"];
}

static void LCWriteSwitcherImage(UIImage *image, NSString *path, CGFloat quality) {
    NSFileManager *files = NSFileManager.defaultManager;
    if (!image) {
        [files removeItemAtPath:path error:nil];
        return;
    }
    [files createDirectoryAtPath:path.stringByDeletingLastPathComponent
     withIntermediateDirectories:YES attributes:nil error:nil];
    [UIImageJPEGRepresentation(image, quality) writeToFile:path
        options:NSDataWritingAtomic | NSDataWritingFileProtectionComplete error:nil];
}

+ (void)setHomeReturnBackdrop:(UIImage *)image {
    LCWriteSwitcherImage(image, [LCSwitcherCacheDirectory() stringByAppendingPathComponent:@"home.jpg"], 0.84);
}

+ (UIImage *)takeHomeReturnBackdrop {
    NSString *path = [LCSwitcherCacheDirectory() stringByAppendingPathComponent:@"home.jpg"];
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    return image;
}

static NSString *LCGuestPreviewPath(NSString *bundlePath) {
    NSString *name = [@"guest-" stringByAppendingString:bundlePath.lastPathComponent];
    return [LCSwitcherCacheDirectory() stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"jpg"]];
}

+ (void)setSwitcherPreview:(UIImage *)image forBundlePath:(NSString *)bundlePath {
    if (!bundlePath.length) return;
    LCWriteSwitcherImage(image, LCGuestPreviewPath(bundlePath), 0.92);
    if (!image) return;

    // Keep a bounded cache in the launcher sandbox. It is device-protected
    // and excluded from backups by its location in Library/Caches.
    NSFileManager *files = NSFileManager.defaultManager;
    NSURL *directory = [NSURL fileURLWithPath:LCSwitcherCacheDirectory()];
    NSArray<NSURL *> *entries = [files contentsOfDirectoryAtURL:directory
        includingPropertiesForKeys:@[NSURLContentModificationDateKey] options:0 error:nil];
    NSMutableArray<NSURL *> *previews = [NSMutableArray array];
    for (NSURL *entry in entries) {
        if ([entry.lastPathComponent hasPrefix:@"guest-"]) [previews addObject:entry];
    }
    [previews sortUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        NSDate *first = nil, *second = nil;
        [a getResourceValue:&first forKey:NSURLContentModificationDateKey error:nil];
        [b getResourceValue:&second forKey:NSURLContentModificationDateKey error:nil];
        return [(second ?: NSDate.distantPast) compare:(first ?: NSDate.distantPast)];
    }];
    for (NSUInteger i = 12; i < previews.count; i++) {
        [files removeItemAtURL:previews[i] error:nil];
    }
}

+ (UIImage *)switcherPreviewForBundlePath:(NSString *)bundlePath {
    if (!bundlePath.length) return nil;
    return [UIImage imageWithContentsOfFile:LCGuestPreviewPath(bundlePath)];
}

+ (NSURL *)guestPreviewTransferURL:(NSString *)token {
    if (![[NSUUID alloc] initWithUUIDString:token]) return nil;
    NSURL *group = self.appGroupPath;
    NSURL *cache = [group URLByAppendingPathComponent:@"Library/Caches/ryC0GuestPreviews" isDirectory:YES];
    return [cache URLByAppendingPathComponent:[token stringByAppendingPathExtension:@"jpg"]];
}

+ (NSString*) teamIdentifier {
    static NSString* ans = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#if !TARGET_OS_SIMULATOR
        void* taskSelf = SecTaskCreateFromSelf(NULL);
        if(taskSelf) {
            CFErrorRef error = NULL;
            CFTypeRef cfans = SecTaskCopyValueForEntitlement(taskSelf, CFSTR("com.apple.developer.team-identifier"), &error);
            if(cfans && CFGetTypeID(cfans) == CFStringGetTypeID()) {
                ans = (__bridge_transfer NSString*)cfans;
            } else if(cfans) {
                CFRelease(cfans);
            }
            if(error) {
                CFRelease(error);
            }
            CFRelease(taskSelf);
        }
#endif
        if(!ans) {
            // the above seems not to work if the device is jailbroken by Palera1n, so we use the public api one as backup
            // https://stackoverflow.com/a/11841898
            NSString *tempAccountName = @"bundleSeedID";
            NSDictionary *query = @{
                (__bridge NSString *)kSecClass : (__bridge NSString *)kSecClassGenericPassword,
                (__bridge NSString *)kSecAttrAccount : tempAccountName,
                (__bridge NSString *)kSecAttrService : @"",
                (__bridge NSString *)kSecReturnAttributes: (__bridge NSNumber *)kCFBooleanTrue,
            };
            CFDictionaryRef result = nil;
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
            if (status == errSecItemNotFound)
                status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
            if (status == errSecSuccess) {
                status = SecItemDelete((__bridge CFDictionaryRef)query); // remove temp item
                NSDictionary *dict = (__bridge_transfer NSDictionary *)result;
                NSString *accessGroup = dict[(__bridge NSString *)kSecAttrAccessGroup];
                NSArray *components = [accessGroup componentsSeparatedByString:@"."];
                NSString *bundleSeedID = [[components objectEnumerator] nextObject];
                ans = bundleSeedID;
            }
        }
    });
    return ans;
}

+ (NSString *)keychainGroupBase {
    return @"com.ry0.ryC0.shared";
}

// The app groups in our own entitlements. Entries that aren't strings are left
// out; empty when the entitlement is missing or can't be read.
+ (NSArray<NSString *> *)entitledAppGroups {
    NSMutableArray<NSString *> *groups = [NSMutableArray array];
    void* taskSelf = SecTaskCreateFromSelf(NULL);
    if(!taskSelf) {
        return groups;
    }
    CFErrorRef error = NULL;
    CFTypeRef value = SecTaskCopyValueForEntitlement(taskSelf, CFSTR("com.apple.security.application-groups"), &error);
    CFRelease(taskSelf);
    if(error) {
        CFRelease(error);
    }
    if(!value) {
        return groups;
    }
    if(CFGetTypeID(value) != CFArrayGetTypeID()) {
        CFRelease(value);
        return groups;
    }
    NSArray *entries = (__bridge_transfer NSArray *)value;
    for(id entry in entries) {
        if([entry isKindOfClass:NSString.class] && [entry length] > 0) {
            [groups addObject:entry];
        }
    }
    return groups;
}

+ (NSString *)appGroupID {
    static dispatch_once_t once;
    // Without an app group, the shared defaults are the suite of this name, kept
    // in the app's own preferences. LiveContainer has always used it, so an
    // install updated in place keeps its settings and certificate.
    static NSString *appGroupID = @"Unknown";
    dispatch_once(&once, ^{
        NSArray<NSString *> *entitled = [self entitledAppGroups];
        NSString *prefix = [LCAppGroupBase stringByAppendingString:@"."];
        NSMutableOrderedSet<NSString *> *candidates = [NSMutableOrderedSet orderedSet];
        NSString *team = self.teamIdentifier;
        if(team.length > 0) {
            [candidates addObject:[prefix stringByAppendingString:team]];
        }
        [candidates addObject:LCAppGroupBase];
        NSString *cached = [lcUserDefaults stringForKey:@"LCAppGroupID"];
        if([cached hasPrefix:prefix]) {
            [candidates addObject:cached];
        }
        // Some sideloaders append a suffix to the group's ID.
        for(NSString *group in entitled) {
            if([group hasPrefix:prefix]) {
                [candidates addObject:group];
            }
        }
        for(NSString *candidate in candidates) {
            if([entitled containsObject:candidate] &&
               [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:candidate]) {
                appGroupID = candidate;
                return;
            }
        }
    });
    return appGroupID;
}

+ (NSURL*) appGroupPath {
    static NSURL *appGroupPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appGroupPath = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:[LCSharedUtils appGroupID]];
    });
    return appGroupPath;
}

+ (BOOL)hasAppGroup {
    return self.appGroupPath != nil;
}

// One preferences domain as it is stored. Unlike NSUserDefaults, it leaves out
// the app's own and the global defaults. Empty when the domain holds nothing.
+ (NSDictionary<NSString *, id> *)preferencesInDomain:(NSString *)domain {
    CFDictionaryRef values = CFPreferencesCopyMultiple(NULL, (__bridge CFStringRef)domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if(!values) {
        return @{};
    }
    if(CFGetTypeID(values) != CFDictionaryGetTypeID()) {
        CFRelease(values);
        return @{};
    }
    return (__bridge_transfer NSDictionary *)values;
}

// Apps inside kept their app groups in Documents/Data/AppGroup while ryC0
// had none of its own; with one, NSFileManager+GuestHooks looks for them in the
// group's LiveContainer/Data/AppGroup. Each moves over once, unless the group
// already holds one of that name.
+ (void)moveGuestAppGroupsIntoAppGroup {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *documents = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].lastObject;
    NSString *from = [documents.path stringByAppendingPathComponent:@"Data/AppGroup"];
    NSString *to = [self.appGroupPath.path stringByAppendingPathComponent:@"LiveContainer/Data/AppGroup"];
    NSArray<NSString *> *names = [fm contentsOfDirectoryAtPath:from error:nil];
    if(names.count == 0 || ![fm createDirectoryAtPath:to withIntermediateDirectories:YES attributes:nil error:nil]) {
        return;
    }
    for(NSString *name in names) {
        NSString *destination = [to stringByAppendingPathComponent:name];
        if([fm fileExistsAtPath:destination]) {
            continue;
        }
        NSError *error = nil;
        if(![fm moveItemAtPath:[from stringByAppendingPathComponent:name] toPath:destination error:&error]) {
            NSLog(@"[LC] Couldn't move the app group %@ into the shared one: %@", name, error.localizedDescription);
        }
    }
}

// Upgrade local preferences without replacing values already written by ryC0.
+ (void)migrateLegacyPreferencesInDefaults:(NSUserDefaults *)defaults {
    NSDictionary<NSString *, id> *values = defaults.dictionaryRepresentation;
    for (NSString *key in values) {
        if (![key hasPrefix:@"ZC"]) continue;
        NSString *renamed = [@"RYC0" stringByAppendingString:[key substringFromIndex:2]];
        if (![defaults objectForKey:renamed]) {
            [defaults setObject:values[key] forKey:renamed];
        }
        [defaults removeObjectForKey:key];
    }
    NSNumber *provider = [defaults objectForKey:@"LCJITEnablerType"];
    if (provider && provider.integerValue == 7) {
        [defaults setInteger:1 forKey:@"LCJITEnablerType"];
    }
}

+ (void)migrateSharedDefaultsIfNeeded {
    [self migrateLegacyPreferencesInDefaults:lcUserDefaults ?: NSUserDefaults.standardUserDefaults];
    [self migrateLegacyPreferencesInDefaults:NSUserDefaults.lcSharedDefaults];
    [self migrateLegacyPreferencesInDefaults:[[NSUserDefaults alloc] initWithSuiteName:@"Unknown"]];
    NSString *group = self.appGroupID;
    if(!self.hasAppGroup || [group isEqualToString:@"Unknown"]) {
        return;
    }
    NSUserDefaults *standard = lcUserDefaults ?: NSUserDefaults.standardUserDefaults;
    NSString *migratedTo = [standard stringForKey:@"RYC0SharedDefaultsMigratedTo"];
    if([migratedTo isEqualToString:group]) {
        return;
    }
    NSUserDefaults *shared = NSUserDefaults.lcSharedDefaults;
    if(!shared) {
        return;
    }
    NSDictionary<NSString *, id> *unknown = [self preferencesInDomain:@"Unknown"];
    NSDictionary<NSString *, id> *current = [self preferencesInDomain:group];

    // The certificate and what is known about it only make sense together, so
    // they are copied as one set, and only into a group that holds none.
    NSArray<NSString *> *certificateKeys = @[@"LCCertificateData", @"LCCertificatePassword", @"LCCertificateUpdateDate"];
    // Left behind, with the Launch App shortcut's requests (LCLaunchExtension*):
    // the page to come back to after an app, and caches that are made again.
    NSSet<NSString *> *skipped = [NSSet setWithArray:@[
        @"RYC0HomeScreenPage", @"symbolOffsetCache", @"LCLastIOSBuildVersion", @"LCGuestURLSchemes",
    ]];

    NSUInteger copied = 0;
    if(unknown[@"LCCertificateData"] && !current[@"LCCertificateData"]) {
        for(NSString *key in certificateKeys) {
            id value = unknown[key];
            if(value) {
                [shared setObject:value forKey:key];
                copied++;
            } else {
                [shared removeObjectForKey:key];
            }
        }
    }
    for(NSString *key in unknown) {
        if(![key isKindOfClass:NSString.class] || [certificateKeys containsObject:key] ||
           [skipped containsObject:key] || [key hasPrefix:@"LCLaunchExtension"] || current[key]) {
            continue;
        }
        [shared setObject:unknown[key] forKey:key];
        copied++;
    }
    // Only the first group ryC0 has takes in the app groups it kept
    // without one.
    if(!migratedTo) {
        [self moveGuestAppGroupsIntoAppGroup];
    }
    // The "Unknown" suite stays as it is, for a build that runs without the
    // group again.
    [standard setObject:group forKey:@"RYC0SharedDefaultsMigratedTo"];
    NSLog(@"[LC] Copied %lu settings from the Unknown suite into %@", (unsigned long)copied, group);
}

+ (NSString *)certificatePassword {
    NSUserDefaults* nud = NSUserDefaults.lcSharedDefaults ?: NSUserDefaults.standardUserDefaults;
    return [nud objectForKey:@"LCCertificatePassword"];
}

+ (BOOL)launchToGuestAppWithClassicMode:(NSUInteger)classicMode {
    void (^completionHandler)(BOOL) = ^(BOOL success) {
        // syscall(SYS_ptrace, PT_DENY_ATTACH, 0, 0, 0);
        __asm__ __volatile__ (
                              "mov x0, #31\n"
                              "mov x16, #26\n"
                              "svc #0x80"
                              );
        raise(SIGKILL);
    };
    
    if (!self.certificatePassword) {
        NSString *urlScheme = nil;
        NSString *tsPath = [NSString stringWithFormat:@"%@/../_TrollStore", NSBundle.mainBundle.bundlePath];
        if (!access(tsPath.UTF8String, F_OK)) {
            urlScheme = @"apple-magnifier://enable-jit?bundle-id=%@";
        }
        
        if(urlScheme) {
            NSURL *launchURL = [NSURL URLWithString:[NSString stringWithFormat:urlScheme, NSBundle.mainBundle.bundleIdentifier]];
            UIApplication *application = [NSClassFromString(@"UIApplication") sharedApplication];
            [application openURL:launchURL options:@{} completionHandler:completionHandler];
            return YES;
        }
    }

    int tries = 2;
    _LSOpenConfiguration *configuration = [[PrivClass(_LSOpenConfiguration) alloc] init];
    if(classicMode) {
        NSMutableDictionary* dict = [NSMutableDictionary new];
        dict[FBSOpenApplicationOptionKeyActivateAsClassic] = @(classicMode);
        configuration.frontBoardOptions = dict;
    }
    LSApplicationWorkspace* workspace = [PrivClass(LSApplicationWorkspace) defaultWorkspace];
    
    for (int i = 0; i < tries; i++) {
        [workspace openApplicationWithBundleIdentifier:NSUserDefaults.lcMainBundle.bundleIdentifier
                                         configuration:configuration
                                     completionHandler:^(BOOL success, NSError* error) {
            NSLog(@"success=%d error=%@", success, error);
            completionHandler(success);
        }];
    }
    return YES;
}

+ (NSURL *)installSourceURLFromLink:(NSURL *)link {
    if (link.isFileURL || ![link.host.lowercaseString isEqualToString:@"install"]) {
        return nil;
    }
    NSURLComponents *components = [NSURLComponents componentsWithURL:link resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in components.queryItems.reverseObjectEnumerator) {
        if (![item.name isEqualToString:@"url"] || !item.value) {
            continue;
        }
        NSURL *source = [NSURL URLWithString:item.value];
        NSString *scheme = source.scheme.lowercaseString;
        if (source.isFileURL || (source.host.length > 0 &&
            ([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]))) {
            return source;
        }
        return nil;
    }
    return nil;
}

+ (NSURL *)takePendingInstallLink {
    NSDictionary *request = [lcUserDefaults dictionaryForKey:LCPendingInstallLinkKey];
    [lcUserDefaults removeObjectForKey:LCPendingInstallLinkKey];
    NSDate *date = request[@"date"];
    NSString *address = request[@"url"];
    if (![date isKindOfClass:NSDate.class] || ![address isKindOfClass:NSString.class]) {
        return nil;
    }
    NSTimeInterval age = -date.timeIntervalSinceNow;
    if (age < 0 || age >= 60) {
        return nil;
    }
    NSURL *link = [NSURL URLWithString:address];
    NSURL *source = [self installSourceURLFromLink:link];
    return source && !source.isFileURL ? link : nil;
}

+ (BOOL)launchToGuestAppWithURL:(NSURL *)url {
    NSURL *installSource = [self installSourceURLFromLink:url];
    if (installSource && !installSource.isFileURL && !NSUserDefaults.isLiveProcess) {
        // A classic guest occupies the host process. Keep the request in the
        // host's preferences so its Home Screen can take it after relaunch.
        [lcUserDefaults setObject:@{ @"date": NSDate.date, @"url": url.absoluteString }
                            forKey:LCPendingInstallLinkKey];
        [lcUserDefaults setObject:@"ui" forKey:@"selected"];
        [lcUserDefaults removeObjectForKey:@"selectedContainer"];
        [lcUserDefaults removeObjectForKey:@"launchAppUrlScheme"];
        [lcUserDefaults synchronize];
        return [self launchToGuestAppWithClassicMode:0];
    }

    NSURLComponents* components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    if(![components.host isEqualToString:@"livecontainer-launch"]) return NO;

    NSString* launchBundleId = nil;
    NSString* openUrl = nil;
    NSString* containerFolderName = nil;
    for (NSURLQueryItem* queryItem in components.queryItems) {
        if ([queryItem.name isEqualToString:@"bundle-name"]) {
            launchBundleId = queryItem.value;
        } else if ([queryItem.name isEqualToString:@"open-url"]){
            NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:queryItem.value options:0];
            openUrl = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
        } else if ([queryItem.name isEqualToString:@"container-folder-name"]) {
            containerFolderName = queryItem.value;
        }
    }
    if(launchBundleId) {
        if (openUrl) {
            [lcUserDefaults setObject:openUrl forKey:@"launchAppUrlScheme"];
        }
        
        // Attempt to restart LiveContainer with the selected guest app
        [lcUserDefaults setObject:launchBundleId forKey:@"selected"];
        [lcUserDefaults setObject:containerFolderName forKey:@"selectedContainer"];
        bool isSharedApp = false;
        NSBundle *appBundle = [self findBundleWithBundleId:launchBundleId isSharedAppOut:&isSharedApp];
        NSDictionary *appInfo = [NSDictionary dictionaryWithContentsOfFile:
            [appBundle.bundlePath stringByAppendingPathComponent:@"LCAppInfo.plist"]];
        NSUInteger classicMode = [appInfo[@"classicMode"] boolValue]
            ? [appInfo[@"LCClassicModeCache"][@"defaultClassicMode"] unsignedIntegerValue]
            : 0;
        return [self launchToGuestAppWithClassicMode:classicMode];
    }
    
    return NO;
}

+ (void)setWebPageUrlForNextLaunch:(NSString*) urlString {
    [lcUserDefaults setObject:urlString forKey:@"webPageToOpen"];
}

+ (NSURL*)containerLockPath {
    static dispatch_once_t once;
    static NSURL *infoPath;
    
    dispatch_once(&once, ^{
        infoPath = [[LCSharedUtils appGroupPath] URLByAppendingPathComponent:@"LiveContainer/containerLock.plist"];
    });
    return infoPath;
}

+ (BOOL)isLCSchemeInUse:(NSString*)lc {
    NSURL* infoPath = [self containerLockPath];
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath.path];
    if (!info) {
        return NO;
    }
    
    NSNumber* num57 = info[lc];
    if(![num57 isKindOfClass:NSNumber.class]) {
        return NO;
    }
    
    uint64_t val57 = [num57 longLongValue];
    audit_token_t token;
    token.val[5] = val57 >> 32;
    token.val[7] = val57 & 0xffffffff;
    
    errno = 0;
    csops_audittoken(token.val[5], 0, NULL, 0, &token);
    return errno != ESRCH;
}

+ (NSString*)getContainerUsingLCSchemeWithFolderName:(NSString*)folderName {
    NSURL* infoPath = [self containerLockPath];
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath.path];
    if (!info) {
        return nil;
    }
    
    NSDictionary* appUsageInfo = info[folderName];
    if (!appUsageInfo) {
        return nil;
    }
    uint64_t val57 = [appUsageInfo[@"auditToken57"] longLongValue];
    audit_token_t token;
    token.val[5] = val57 >> 32;
    token.val[7] = val57 & 0xffffffff;
    
    errno = 0;
    csops_audittoken(token.val[5], 0, NULL, 0, &token);
    return errno==ESRCH ? nil : appUsageInfo[@"runningLC"];
}

// lc can be something like livecontainer or livecontainer2.liveprocess, such that one LC can jump to another LC hosting the multitask app when user presses run while it's running
+ (void)setContainerUsingByLC:(NSString*)lc folderName:(NSString*)folderName auditToken:(uint64_t)val57 {
    NSURL* infoPath = [self containerLockPath];
    
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath.path];
    if (!info) {
        info = [NSMutableDictionary new];
    }
    
    if(val57 == 0) {
        audit_token_t token;
        mach_msg_type_number_t size = TASK_AUDIT_TOKEN_COUNT;
        
        kern_return_t kr = task_info(mach_task_self(), TASK_AUDIT_TOKEN, (task_info_t)&token, &size);
        if (kr != KERN_SUCCESS) {
            NSLog(@"Error getting task audit_token");
        }
        val57 = token.val[7] | ((uint64_t)token.val[5] << 32);
    }
    info[folderName] = @{
        @"runningLC": lc,
        @"auditToken57": @(val57)
    };
    
    info[lc] = @(val57);

    [info writeBinToFile:infoPath.path atomically:YES];
}

// move app data to private folder to prevent 0xdead10cc https://forums.developer.apple.com/forums/thread/126438
// This method is here for backward compatability, 0xdead10cc is already resolved.
+ (void)moveSharedAppFolderBack {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *libraryPathUrl = [fm URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask]
        .lastObject;
    NSURL *docPathUrl = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask]
        .lastObject;
    NSURL *appGroupFolder = [[LCSharedUtils appGroupPath] URLByAppendingPathComponent:@"LiveContainer"];
    
    NSError *error;
    NSString *sharedAppDataFolderPath = [libraryPathUrl.path stringByAppendingPathComponent:@"SharedDocuments"];
    if(![fm fileExistsAtPath:sharedAppDataFolderPath]){
        return;
    }
    // move all apps in shared folder back
    NSArray<NSString *> * sharedDataFoldersToMove = [fm contentsOfDirectoryAtPath:sharedAppDataFolderPath error:&error];
    
    // something went wrong with app group
    if(!appGroupFolder && sharedDataFoldersToMove.count > 0) {
        [lcUserDefaults setObject:@"ryC0 was unable to move the data of shared app back because ryC0 cannot access app group. Please check JITLess diagnose page in ryC0 settings for more information." forKey:@"error"];
        return;
    }
    
    for(int i = 0; i < [sharedDataFoldersToMove count]; ++i) {
        NSString* destPath = [appGroupFolder.path stringByAppendingPathComponent:[NSString stringWithFormat:@"Data/Application/%@", sharedDataFoldersToMove[i]]];
        if([fm fileExistsAtPath:destPath]) {
            [fm
             moveItemAtPath:[sharedAppDataFolderPath stringByAppendingPathComponent:sharedDataFoldersToMove[i]]
             toPath:[docPathUrl.path stringByAppendingPathComponent:[NSString stringWithFormat:@"FOLDER_EXISTS_AT_APP_GROUP_%@", sharedDataFoldersToMove[i]]]
             error:&error
            ];
            
        } else {
            [fm
             moveItemAtPath:[sharedAppDataFolderPath stringByAppendingPathComponent:sharedDataFoldersToMove[i]]
             toPath:destPath
             error:&error
            ];
        }
    }
    
}

+ (NSBundle*)findBundleWithBundleId:(NSString*)bundleId isSharedAppOut:(bool*)isSharedAppOut {
    NSString *docPath = [NSString stringWithFormat:@"%s/Documents", getenv("LC_HOME_PATH")];
    
    NSURL *appGroupFolder = nil;
    
    NSString *bundlePath = [NSString stringWithFormat:@"%@/Applications/%@", docPath, bundleId];
    NSBundle *appBundle;
    if([NSFileManager.defaultManager fileExistsAtPath:bundlePath]) {
        appBundle = [[NSBundle alloc] initWithPath:bundlePath];
    }

    // not found locally, let's look for the app in shared folder
    if (!appBundle) {
        appGroupFolder = [[LCSharedUtils appGroupPath] URLByAppendingPathComponent:@"LiveContainer"];
        
        bundlePath = [NSString stringWithFormat:@"%@/Applications/%@", appGroupFolder.path, bundleId];
        if([NSFileManager.defaultManager fileExistsAtPath:bundlePath]) {
            appBundle = [[NSBundle alloc] initWithPath:bundlePath];
        }
        if(appBundle) {
            *isSharedAppOut = true;
        }
    } else {
        *isSharedAppOut = false;
    }
    return appBundle;
}

// This method is here for backward compatability, preferences is direcrly saved to app's preference folder.
+ (void)dumpPreferenceToPath:(NSString*)plistLocationTo dataUUID:(NSString*)dataUUID {
    NSFileManager* fm = [[NSFileManager alloc] init];
    NSError* error1;
    
    NSDictionary* preferences = [lcUserDefaults objectForKey:dataUUID];
    if(!preferences) {
        return;
    }
    
    [fm createDirectoryAtPath:plistLocationTo withIntermediateDirectories:YES attributes:@{} error:&error1];
    for(NSString* identifier in preferences) {
        NSDictionary* preference = preferences[identifier];
        NSString *itemPath = [plistLocationTo stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", identifier]];
        if([preference count] == 0) {
            // Attempt to delete the file
            [fm removeItemAtPath:itemPath error:&error1];
            continue;
        }
        [preference writeToFile:itemPath atomically:YES];
    }
    [lcUserDefaults removeObjectForKey:dataUUID];
}

+ (NSString*)findDefaultContainerWithBundleId:(NSString*)bundleId {
    // find app's default container
    NSURL* appGroupFolder = [[LCSharedUtils appGroupPath] URLByAppendingPathComponent:@"LiveContainer"];
    
    NSString* bundleInfoPath = [NSString stringWithFormat:@"%@/Applications/%@/LCAppInfo.plist", appGroupFolder.path, bundleId];
    NSDictionary* infoDict = [NSDictionary dictionaryWithContentsOfFile:bundleInfoPath];
    return infoDict[@"LCDataUUID"];
}

// The first URL scheme in the app's own Info.plist, read from the host app when
// this runs in one of its extensions (LiveProcess, the share and launch
// extensions), which sit two folders down in PlugIns. ryC0 reads the scheme
// here so its links also work when a build overrides RYC0_URL_SCHEME.
+ (NSString *)hostAppUrlScheme {
    static NSString *scheme = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // lcMainBundle keeps the app's bundle after a guest app takes over
        // NSBundle.mainBundle; extensions that don't run LiveContainerMain leave it nil.
        NSBundle *bundle = lcMainBundle ?: NSBundle.mainBundle;
        if([bundle.bundlePath.pathExtension isEqualToString:@"appex"]) {
            NSURL *appURL = bundle.bundleURL.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent;
            bundle = [NSBundle bundleWithURL:appURL] ?: bundle;
        }
        id urlTypes = bundle.infoDictionary[@"CFBundleURLTypes"];
        if([urlTypes isKindOfClass:NSArray.class] && [urlTypes count] > 0 && [urlTypes[0] isKindOfClass:NSDictionary.class]) {
            id schemes = urlTypes[0][@"CFBundleURLSchemes"];
            if([schemes isKindOfClass:NSArray.class] && [schemes count] > 0 && [schemes[0] isKindOfClass:NSString.class]) {
                scheme = schemes[0];
            }
        }
        if(scheme.length == 0) {
            scheme = @"ryc0";
        }
    });
    return scheme;
}

+ (NSArray<NSString*>*)lcUnorderedUrlSchemes {
    NSArray<NSString *> *defaultSchemes = @[self.hostAppUrlScheme];
    return defaultSchemes;
}

+ (NSArray<NSString*>*)lcUrlSchemes {
    NSArray<NSString *> *defaultSchemes = [self lcUnorderedUrlSchemes];
    NSSet<NSString *> *allowedSchemes = [NSSet setWithArray:defaultSchemes];
    NSMutableArray<NSString *> *result = [NSMutableArray array];

    id savedValue = [NSUserDefaults.lcSharedDefaults objectForKey:@"LCMultiLaunchPriority"];
    if([savedValue isKindOfClass:NSArray.class]) {
        for(id value in (NSArray *)savedValue) {
            if(![value isKindOfClass:NSString.class]) {
                continue;
            }

            NSString *scheme = [(NSString *)value lowercaseString];
            if(![allowedSchemes containsObject:scheme] || [result containsObject:scheme]) {
                continue;
            }

            [result addObject:scheme];
        }
    }

    for(NSString *scheme in defaultSchemes) {
        if(![result containsObject:scheme]) {
            [result addObject:scheme];
        }
    }

    return result;
}
@end

#pragma mark - Guest notification history

#import <UserNotifications/UserNotifications.h>
#include <sys/file.h>
#include <fcntl.h>
#include <notify.h>

static const NSUInteger LCNotificationLimit = 128;
static const char *const LCGuestNotificationsChanged = "com.ry0.ryC0.guestNotifications";
static NSString *const LCNotificationDirectoriesKey = @"RYC0GuestSystemNotificationDirectories";
static NSURL *LCGuestSystemNotificationDirectory;

static NSString *LCNotificationApp(void) {
    return NSBundle.mainBundle.bundlePath.lastPathComponent;
}

static NSString *LCNotificationContainer(void) {
    return NSHomeDirectory().lastPathComponent;
}

// The host and its classic or hosted guest processes share this file. Keep
// the lock separate so the plist can be replaced atomically while it's held.
static BOOL LCEventTransactionInDirectory(NSURL *directory, NSString *filename, BOOL (^change)(NSMutableArray<NSDictionary *> *)) {
    if (!directory) return NO;
    NSString *path = [directory.path stringByAppendingPathComponent:filename];
    NSString *lockPath = [path stringByAppendingPathExtension:@"lock"];
    int lock = open(lockPath.fileSystemRepresentation, O_CREAT | O_CLOEXEC | O_NOFOLLOW | O_RDWR, 0600);
    if (lock < 0) return NO;
    @try {
        if (flock(lock, LOCK_EX) != 0) return NO;
        NSMutableArray *records = [NSMutableArray new];
        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
        if ([attributes.fileType isEqualToString:NSFileTypeRegular] && attributes.fileSize < 4 * 1024 * 1024) {
            for (id entry in [NSArray arrayWithContentsOfFile:path]) {
                if (![entry isKindOfClass:NSDictionary.class]) continue;
                if ([entry[@"date"] isKindOfClass:NSDate.class] &&
                    [entry[@"app"] isKindOfClass:NSString.class] &&
                    [entry[@"id"] isKindOfClass:NSString.class]) {
                    [records addObject:entry];
                    if (records.count >= LCNotificationLimit) break;
                }
            }
        }
        if (change(records)) {
            NSData *data = [NSPropertyListSerialization dataWithPropertyList:records
                format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
            return [data writeToFile:path options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:nil];
        }
    } @finally {
        close(lock);
    }
    return NO;
}

static BOOL LCGuestEventTransaction(NSString *filename, BOOL (^change)(NSMutableArray<NSDictionary *> *)) {
    return LCEventTransactionInDirectory([LCSharedUtils guestEventsDirectory], filename, change);
}

static NSURL *LCSystemNotificationDirectory(NSString *identifier) {
    if (![identifier isKindOfClass:NSString.class] || ![[NSUUID alloc] initWithUUIDString:identifier]) return nil;
    return [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:
        [@"Library/Application Support/GuestSystemNotifications/" stringByAppendingString:identifier]] isDirectory:YES];
}

static void LCEnumerateSystemNotificationDirectories(NSString *onlyApp, void (^visit)(NSString *, NSString *, NSURL *)) {
    NSDictionary *apps = [NSUserDefaults.standardUserDefaults dictionaryForKey:LCNotificationDirectoriesKey];
    for (NSString *app in apps) {
        if (onlyApp && ![app isEqualToString:onlyApp]) continue;
        NSDictionary *containers = apps[app];
        if (![containers isKindOfClass:NSDictionary.class]) continue;
        for (NSString *container in containers) {
            NSURL *directory = LCSystemNotificationDirectory(containers[container]);
            if (directory) visit(app, container, directory);
        }
    }
}

static NSString *LCLimitEventText(NSString *text, NSUInteger maximum) {
    if (text.length <= maximum) return text ?: @"";
    return [text substringToIndex:[text rangeOfComposedCharacterSequenceAtIndex:maximum].location];
}

static NSDictionary *LCNextNotification(NSDictionary *record) {
    NSData *data = record[@"repeatTrigger"];
    if (![data isKindOfClass:NSData.class] || data.length > 64 * 1024) return nil;
    NSSet *classes = [NSSet setWithArray:@[UNTimeIntervalNotificationTrigger.class, UNCalendarNotificationTrigger.class]];
    UNNotificationTrigger *trigger = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:nil];
    NSDate *next = [trigger isKindOfClass:UNTimeIntervalNotificationTrigger.class]
        ? [(UNTimeIntervalNotificationTrigger *)trigger nextTriggerDate]
        : [(UNCalendarNotificationTrigger *)trigger nextTriggerDate];
    if (!next || [next timeIntervalSinceNow] <= 0) return nil;
    NSMutableDictionary *updated = [record mutableCopy];
    updated[@"date"] = next;
    return updated;
}

static void LCRemoveNotifications(NSMutableArray<NSDictionary *> *records, BOOL pending, BOOL (^matches)(NSDictionary *)) {
    NSDate *now = NSDate.date;
    for (NSUInteger i = records.count; i > 0; i--) {
        NSDictionary *record = records[i - 1];
        if (!matches(record)) continue;
        BOOL isPending = [record[@"date"] compare:now] == NSOrderedDescending;
        if (pending) {
            if (isPending) [records removeObjectAtIndex:i - 1];
            else if (record[@"repeatTrigger"]) {
                NSMutableDictionary *updated = [record mutableCopy];
                [updated removeObjectForKey:@"repeatTrigger"];
                records[i - 1] = updated;
            }
        } else if (!isPending) {
            NSDictionary *next = LCNextNotification(record);
            if (next) records[i - 1] = next;
            else [records removeObjectAtIndex:i - 1];
        }
    }
}

@implementation LCSharedUtils (GuestNotifications)

+ (NSURL *)systemNotificationDirectoryForApp:(NSString *)app container:(NSString *)container {
    if (!app.length || !container.length) return nil;
    @synchronized (self) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSMutableDictionary *apps = [[defaults dictionaryForKey:LCNotificationDirectoriesKey] mutableCopy] ?: [NSMutableDictionary new];
        NSMutableDictionary *containers = [apps[app] mutableCopy] ?: [NSMutableDictionary new];
        NSString *identifier = containers[container] ?: NSUUID.UUID.UUIDString;
        NSURL *directory = LCSystemNotificationDirectory(identifier);
        if (!directory || ![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES
                                                                    attributes:nil error:nil]) return nil;
        if (!containers[container]) {
            containers[container] = identifier;
            apps[app] = containers;
            [defaults setObject:apps forKey:LCNotificationDirectoriesKey];
        }
        return directory;
    }
}

+ (void)setGuestSystemNotificationDirectory:(NSURL *)directory {
    LCGuestSystemNotificationDirectory = directory;
}

+ (NSURL *)guestEventsDirectory {
    const char *home = getenv("LC_HOME_PATH");
    if (!home) return nil;
    NSString *path = [[NSString stringWithUTF8String:home] stringByAppendingPathComponent:@"Documents/.ryC0Events"];
    NSURL *directory = [NSURL fileURLWithPath:path isDirectory:YES];
    if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES
         attributes:nil error:nil]) return nil;
    [directory setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    return directory;
}

+ (void)recordGuestNotification:(UNNotificationRequest *)request forApp:(NSString *)app container:(NSString *)container
               forSystemDelivery:(BOOL)forSystemDelivery {
    UNNotificationTrigger *trigger = request.trigger;
    NSDate *date = nil;
    if (!trigger) date = NSDate.date;
    else if ([trigger isKindOfClass:UNTimeIntervalNotificationTrigger.class]) {
        date = [(UNTimeIntervalNotificationTrigger *)trigger nextTriggerDate];
    } else if ([trigger isKindOfClass:UNCalendarNotificationTrigger.class]) {
        date = [(UNCalendarNotificationTrigger *)trigger nextTriggerDate];
    }
    if (!date || !app.length || !container.length || request.identifier.length > 512) return;

    UNNotificationContent *content = request.content;
    if (!(content.title.length || content.subtitle.length || content.body.length)) return;
    NSMutableDictionary *record = [@{
        @"id": NSUUID.UUID.UUIDString, @"request": request.identifier, @"app": app, @"container": container,
        @"date": date, @"title": LCLimitEventText(content.title, 256), @"subtitle": LCLimitEventText(content.subtitle, 256),
        @"body": LCLimitEventText(content.body, 2048)
    } mutableCopy];
    if (trigger.repeats) {
        record[@"repeatTrigger"] = [NSKeyedArchiver archivedDataWithRootObject:trigger requiringSecureCoding:YES error:nil];
    }
    BOOL (^store)(NSMutableArray<NSDictionary *> *) = ^BOOL(NSMutableArray<NSDictionary *> *records) {
        NSIndexSet *previous = [records indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry, NSUInteger index, BOOL *stop) {
            return [entry[@"app"] isEqual:app] && [entry[@"container"] isEqual:container] &&
                [entry[@"request"] isEqual:request.identifier];
        }];
        [records removeObjectsAtIndexes:previous];
        [records addObject:record];
        if (records.count > LCNotificationLimit) [records removeObjectAtIndex:0];
        return YES;
    };
    LCGuestEventTransaction(@"GuestNotifications.plist", store);
    if (forSystemDelivery && !trigger.repeats && LCGuestSystemNotificationDirectory) {
        record[@"systemDeliveryRequestedAt"] = NSDate.date;
        record[@"sound"] = @(content.sound != nil);
        if (LCEventTransactionInDirectory(LCGuestSystemNotificationDirectory, @"Notifications.plist", store)) {
            notify_post(LCGuestNotificationsChanged);
        }
    }
}

+ (void)recordGuestNotification:(UNNotificationRequest *)request {
    [self recordGuestNotification:request forApp:LCNotificationApp() container:LCNotificationContainer()
                forSystemDelivery:NSUserDefaults.isLiveProcess];
}

+ (void)recordGuestNotification:(UNNotificationRequest *)request forApp:(NSString *)app container:(NSString *)container {
    [self recordGuestNotification:request forApp:app container:container forSystemDelivery:NO];
}

+ (void)removeGuestNotificationsWithIdentifiers:(NSArray<NSString *> *)identifiers pending:(BOOL)pending {
    NSString *app = LCNotificationApp();
    NSString *container = LCNotificationContainer();
    NSSet *selection = identifiers ? [NSSet setWithArray:identifiers] : nil;
    BOOL (^remove)(NSMutableArray<NSDictionary *> *) = ^BOOL(NSMutableArray<NSDictionary *> *records) {
        LCRemoveNotifications(records, pending, ^BOOL(NSDictionary *record) {
            return [record[@"app"] isEqual:app] && [record[@"container"] isEqual:container] &&
                (!selection || [selection containsObject:record[@"request"]]);
        });
        return YES;
    };
    LCGuestEventTransaction(@"GuestNotifications.plist", remove);
    if (LCEventTransactionInDirectory(LCGuestSystemNotificationDirectory, @"Notifications.plist", remove)) {
        notify_post(LCGuestNotificationsChanged);
    }
}

+ (NSArray<NSDictionary<NSString *, id> *> *)deliveredGuestNotifications {
    __block NSArray *delivered = @[];
    NSDate *now = NSDate.date;
    LCGuestEventTransaction(@"GuestNotifications.plist", ^BOOL(NSMutableArray *records) {
        delivered = [records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *record, NSDictionary *bindings) {
            return [record[@"date"] compare:now] != NSOrderedDescending;
        }]];
        return NO;
    });
    return delivered;
}

+ (NSArray<NSDictionary<NSString *, id> *> *)guestNotificationsForSystemDelivery {
    NSMutableArray *pending = [NSMutableArray new];
    LCEnumerateSystemNotificationDirectories(nil, ^(NSString *app, NSString *container, NSURL *directory) {
        LCEventTransactionInDirectory(directory, @"Notifications.plist", ^BOOL(NSMutableArray *records) {
            for (NSDictionary *record in records) {
                NSMutableDictionary *trusted = [record mutableCopy];
                trusted[@"app"] = app;
                trusted[@"container"] = container;
                [pending addObject:trusted];
            }
            return NO;
        });
    });
    return pending;
}

+ (void)clearDeliveredGuestNotifications {
    BOOL (^clear)(NSMutableArray<NSDictionary *> *) = ^BOOL(NSMutableArray<NSDictionary *> *records) {
        LCRemoveNotifications(records, NO, ^BOOL(NSDictionary *record) { return YES; });
        return YES;
    };
    LCGuestEventTransaction(@"GuestNotifications.plist", clear);
    LCEnumerateSystemNotificationDirectories(nil, ^(NSString *app, NSString *container, NSURL *directory) {
        LCEventTransactionInDirectory(directory, @"Notifications.plist", clear);
    });
    notify_post(LCGuestNotificationsChanged);
}

+ (void)resetGuestNotifications {
    BOOL (^clear)(NSMutableArray<NSDictionary *> *) = ^BOOL(NSMutableArray<NSDictionary *> *records) {
        [records removeAllObjects];
        return YES;
    };
    LCGuestEventTransaction(@"GuestNotifications.plist", clear);
    LCEnumerateSystemNotificationDirectories(nil, ^(NSString *app, NSString *container, NSURL *directory) {
        LCEventTransactionInDirectory(directory, @"Notifications.plist", clear);
    });
    notify_post(LCGuestNotificationsChanged);
}

+ (void)removeGuestNotificationsForApp:(NSString *)bundlePath {
    BOOL changed = LCGuestEventTransaction(@"GuestNotifications.plist", ^BOOL(NSMutableArray *records) {
        NSIndexSet *matching = [records indexesOfObjectsPassingTest:^BOOL(NSDictionary *record, NSUInteger index, BOOL *stop) {
            return [record[@"app"] isEqual:bundlePath.lastPathComponent];
        }];
        [records removeObjectsAtIndexes:matching];
        return matching.count > 0;
    });
    @synchronized (self) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSMutableDictionary *apps = [[defaults dictionaryForKey:LCNotificationDirectoriesKey] mutableCopy];
        NSString *app = bundlePath.lastPathComponent;
        if (apps[app]) {
            LCEnumerateSystemNotificationDirectories(app, ^(NSString *app, NSString *container, NSURL *directory) {
                [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
            });
            [apps removeObjectForKey:app];
            [defaults setObject:apps forKey:LCNotificationDirectoriesKey];
            changed = YES;
        }
    }
    if (changed) notify_post(LCGuestNotificationsChanged);
}

@end

@implementation LCSharedUtils (GuestActivities)

+ (BOOL)publishGuestActivity:(NSDictionary<NSString *, id> *)event {
    NSDictionary *info = NSUserDefaults.guestAppInfo;
    if (!NSUserDefaults.lcGuestAppId || [info[@"isHidden"] boolValue] || [info[@"isLocked"] boolValue]) return NO;
    NSString *app = LCNotificationApp();
    NSString *identifier = [event[@"id"] isKindOfClass:NSString.class] ? event[@"id"] : nil;
    if (!identifier || ![[NSUUID alloc] initWithUUIDString:identifier] || !app.length) return NO;
    NSString *title = [event[@"title"] isKindOfClass:NSString.class] ? event[@"title"] : nil;
    NSString *detail = [event[@"detail"] isKindOfClass:NSString.class] ? event[@"detail"] : @"";
    NSNumber *progress = [event[@"progress"] isKindOfClass:NSNumber.class] ? event[@"progress"] : nil;
    BOOL changed = LCGuestEventTransaction(@"GuestActivities.plist", ^BOOL(NSMutableArray *records) {
        NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-120];
        NSIndexSet *expired = [records indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry, NSUInteger index, BOOL *stop) {
            return [entry[@"date"] compare:cutoff] == NSOrderedAscending ||
                ([entry[@"app"] isEqual:app] && [entry[@"id"] isEqual:identifier]);
        }];
        [records removeObjectsAtIndexes:expired];
        if (title.length) {
            NSMutableDictionary *record = [@{
                @"id": identifier, @"app": app, @"date": NSDate.date,
                @"title": LCLimitEventText(title, 120),
                @"detail": LCLimitEventText(detail, 160)
            } mutableCopy];
            if (progress && isfinite(progress.doubleValue)) {
                record[@"progress"] = @(MAX(0, MIN(1, progress.doubleValue)));
            }
            [records addObject:record];
            if (records.count > 16) [records removeObjectAtIndex:0];
        }
        return title.length || expired.count;
    });
    if (changed) notify_post("com.ry0.ryC0.guestActivities");
    return changed;
}

+ (NSArray<NSDictionary<NSString *, id> *> *)guestActivities {
    __block NSArray *result = @[];
    LCGuestEventTransaction(@"GuestActivities.plist", ^BOOL(NSMutableArray *records) {
        result = [records copy];
        return NO;
    });
    return result;
}

@end
