//
//  main.m
//  LiveProcess
//
//  Created by Duy Tran on 3/5/25.
//

#import <dlfcn.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <notify.h>
#import <objc/message.h>
#import "../LiveContainer/LCSharedUtils.h"
#import "../LiveContainer/utils.h"
#import "../LiveContainer/Tweaks/Tweaks.h"

@interface LiveProcessHandler : NSObject<NSExtensionRequestHandling>
@end
@implementation LiveProcessHandler
static NSExtensionContext *extensionContext;
static NSDictionary *retrievedAppInfo;
+ (NSExtensionContext *)extensionContext {
    return extensionContext;
}

+ (NSDictionary *)retrievedAppInfo {
    return retrievedAppInfo;
}

- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context {
    extensionContext = context;
    retrievedAppInfo = [context.inputItems.firstObject userInfo];
    // Return control to LiveContainerMain
    CFRunLoopStop(CFRunLoopGetMain());
}
@end

extern int LiveContainerMain(int argc, char *argv[]);
static char **_envp, **_apple = NULL;

static void NotifyHostAfterFirstGuestFrame(NSString *requestID) {
    if (!requestID) return;
    NSString *channel = [NSString stringWithFormat:@"com.ry0.ryC0.preview.%@.firstFrame", requestID];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    __block NSMutableArray *observers = [NSMutableArray array];
    __block BOOL scheduled = NO;
    void (^checkWindows)(NSNotification *) = ^(NSNotification *note) {
        if (scheduled) return;
        BOOL ready = NO;
        NSArray<UIWindow *> *windows = nil;
        if ([note.object isKindOfClass:UIWindowScene.class]) windows = ((UIWindowScene *)note.object).windows;
        else if ([note.object isKindOfClass:UIWindow.class] && ((UIWindow *)note.object).windowScene) windows = @[note.object];
        for (UIWindow *window in windows) {
            if (!window.hidden && window.rootViewController && window.windowLevel == UIWindowLevelNormal && !CGRectIsEmpty(window.bounds)) {
                ready = YES;
                break;
            }
        }
        if (!ready) return;
        scheduled = YES;
        for (id observer in observers) [center removeObserver:observer];
        observers = nil;
        // Let the guest commit its first frame before the host zooms it open.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            notify_post(channel.UTF8String);
        });
    };
    // A guest can make its window key before UIKit attaches it to a scene.
    // Check visibility and scene activation too, so it doesn't hit the fallback.
    for (NSNotificationName name in @[UIWindowDidBecomeKeyNotification, UIWindowDidBecomeVisibleNotification, UISceneDidActivateNotification]) {
        [observers addObject:[center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:checkWindows]];
    }
}

static void ListenForGuestPreviews(NSString *requestID) {
    if (!requestID) return;
    NSURL *file = [LCSharedUtils guestPreviewTransferURL:requestID];
    if (!file) return;
    NSString *channel = [@"com.ry0.ryC0.preview." stringByAppendingString:requestID];
    dispatch_queue_t writes = dispatch_queue_create("com.ry0.ryC0.guest-preview", DISPATCH_QUEUE_SERIAL);
    int token;
    notify_register_dispatch(channel.UTF8String, &token, dispatch_get_main_queue(), ^(int notification) {
        // The extension runs the guest's UIApplication entry point by now.
        UIApplication *application = ((id (*)(id, SEL))objc_msgSend)(UIApplication.class, NSSelectorFromString(@"sharedApplication"));
        UIWindow *window = nil;
        for (UIScene *scene in application.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class]) {
                for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
                    if (candidate.isKeyWindow && !candidate.hidden) { window = candidate; break; }
                }
                if (window) break;
            }
        }
        if (!window || CGRectIsEmpty(window.bounds)) return;
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
        CGFloat longestSide = MAX(CGRectGetWidth(window.bounds), CGRectGetHeight(window.bounds));
        // Render near the card's display size, with a pixel cap for large iPad windows.
        format.scale = MIN(0.69 * MAX(1, window.traitCollection.displayScale), 2048.0 / longestSide);
        format.preferredRange = UIGraphicsImageRendererFormatRangeStandard;
        format.opaque = YES;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:window.bounds format:format];
        __block BOOL drawn = NO;
        UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            drawn = [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
        }];
        if (!drawn) return;
        dispatch_async(writes, ^{
            [NSFileManager.defaultManager createDirectoryAtURL:file.URLByDeletingLastPathComponent
                withIntermediateDirectories:YES attributes:nil error:nil];
            if ([UIImageJPEGRepresentation(image, 0.94) writeToURL:file
                options:NSDataWritingAtomic | NSDataWritingFileProtectionComplete error:nil]) {
                notify_post([channel stringByAppendingString:@".ready"].UTF8String);
            }
        });
    });
}

int LiveProcessMain(int argc, char *argv[]) {
    // Let NSExtensionContext initialize, once it's done it will call CFRunLoopStop
    CFRunLoopRun();
    // Ensure app info is delivered
    NSDictionary *appInfo = LiveProcessHandler.retrievedAppInfo;
    NSCAssert(appInfo, @"Failed to retrieve app info");
    
    // Check if we received a request to execute a custom payload
    NSString *customPayloadDylib = appInfo[@"customPayloadDylib"];
    if(customPayloadDylib) {
        void *handle = dlopen(customPayloadDylib.fileSystemRepresentation, RTLD_LAZY);
        NSCAssert(appInfo, @"Failed to load custom payload dylib at path: %@", customPayloadDylib);
        
        NSString *customPayloadEntry = appInfo[@"customPayloadEntry"];
        NSCAssert(customPayloadEntry, @"Missing customPayloadEntry");
        int (*payloadEntry)(int, char **, char **, char **) = dlsym(handle, customPayloadEntry.UTF8String);
        return payloadEntry(argc, argv, _envp, _apple);
    }
    
    NSLog(@"Retrieved app info for %@", appInfo[@"selected"]);
    // Set LiveContainer's home path
    setenv("LP_HOME_PATH", getenv("HOME"), 1);
    const char *overrideHomePath = [appInfo[@"lcHomePath"] fileSystemRepresentation];
    if(overrideHomePath) setenv("LC_HOME_PATH", overrideHomePath, 1);
    // Pass selected app info to user defaults
    NSUserDefaults *lcUserDefaults = NSUserDefaults.standardUserDefaults;
    [lcUserDefaults setObject:appInfo[@"hostUrlScheme"] forKey:@"hostUrlScheme"];
    [lcUserDefaults setObject:appInfo[@"launchAppUrlScheme"] forKey:@"launchAppUrlScheme"];
    [lcUserDefaults setObject:appInfo[@"selected"] forKey:@"selected"];
    [lcUserDefaults setObject:appInfo[@"selectedContainer"] forKey:@"selectedContainer"];
    
    NSArray* bookmarks = appInfo[@"bookmarks"];
    NSMutableArray<NSURL *>* bookmarkedUrls = [NSMutableArray array];
    for(int i = 0; i < bookmarks.count; i++) {
        bool isStale = false;
        NSError* error = nil;
        bookmarkedUrls[i] = [NSURL URLByResolvingBookmarkData:bookmarks[i] options:0 relativeToURL:nil bookmarkDataIsStale:&isStale error:&error];
        [bookmarkedUrls[i] startAccessingSecurityScopedResource];
    }
    NSData *systemNotificationsBookmark = appInfo[@"systemNotificationsBookmark"];
    if (systemNotificationsBookmark) {
        NSURL *directory = [NSURL URLByResolvingBookmarkData:systemNotificationsBookmark options:0 relativeToURL:nil
                                       bookmarkDataIsStale:nil error:nil];
        if ([directory startAccessingSecurityScopedResource]) {
            [LCSharedUtils setGuestSystemNotificationDirectory:directory];
        }
    }

    NSString *homeSwipeToken = appInfo[@"ryGuestHomeSwipeToken"];
    if ([homeSwipeToken isKindOfClass:NSString.class] && [[NSUUID alloc] initWithUUIDString:homeSwipeToken]) {
        setenv(LC_HOME_SWIPE_TOKEN_ENV, homeSwipeToken.UTF8String, 1);
    }
    ListenForGuestPreviews(appInfo[@"ryGuestPreviewToken"]);
    if (@available(iOS 18.0, *)) {
        NotifyHostAfterFirstGuestFrame(appInfo[@"ryGuestPreviewToken"]);
    }
    return LiveContainerMain(argc, argv);
}

// this is our fake UIApplicationMain called from _xpc_objc_uimain (xpc_main)
__attribute__((visibility("default")))
int UIApplicationMain(int argc, char * argv[], NSString * principalClassName, NSString * delegateClassName) {
    return LiveProcessMain(argc, argv);
}

// NSExtensionMain will load UIKit and call UIApplicationMain, so we need to redirect it to our fake one
static void* (*orig_dlopen)(void* dyldApiInstancePtr, const char* path, int mode);
static void* hook_dlopen(void* dyldApiInstancePtr, const char* path, int mode) {
    const char *UIKitFrameworkPath = "/System/Library/Frameworks/UIKit.framework/UIKit";
    if(path && !strncmp(path, UIKitFrameworkPath, strlen(UIKitFrameworkPath))) {
        // switch back to original dlopen
        performHookDyldApi("dlopen", 2, (void**)&orig_dlopen, orig_dlopen);
        // FIXME: may be incompatible with jailbreak tweaks?
        return RTLD_MAIN_ONLY;
    } else {
        __attribute__((musttail)) return orig_dlopen(dyldApiInstancePtr, path, mode);
    }
}

// Extension entry point
int NSExtensionMain(int argc, char *argv[], char *envp[], char *apple[]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    method_setImplementation(class_getInstanceMethod(NSClassFromString(@"NSXPCDecoder"), @selector(_validateAllowedClass:forKey:allowingInvocations:)), (IMP)hook_do_nothing);
#pragma clang diagnostic pop
    // hook dlopen UIKit
    performHookDyldApi("dlopen", 2, (void**)&orig_dlopen, hook_dlopen);
    // call the real one
    _envp = envp;
    _apple = apple;
    int (*orig_NSExtensionMain)(int argc, char * argv[]) = dlsym(RTLD_NEXT, "NSExtensionMain");
    return orig_NSExtensionMain(argc, argv);
}
