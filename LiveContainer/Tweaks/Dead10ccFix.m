//
//  Dead10ccFix.m
//  LiveContainer
//
//  Created by s s on 2025/5/21.
//
#include <sys/xattr.h>
#include "utils.h"
#include <unistd.h>
#include "./libproc.h"
#include <sys/stat.h>
#include <sys/xattr.h>
#include "./proc_info.h"
#include <fcntl.h>
#include <spawn.h>
@import Foundation;
@import UIKit;
@import AVFoundation;

// Darwin's descriptor-owner query complements the process-owner query.
// https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/fcntl.h
#ifndef F_OFD_GETLKPID
#define F_OFD_GETLKPID 94
#endif

@interface Dead10ccFix : NSObject
@property(nonatomic) BOOL methodInited;
@property(nonatomic) int deboundeToken;
@property(nonatomic) BOOL waitingForTasks;
- (void)observeBackgroundForLiveProcess:(BOOL)liveProcess;
- (void)handleAudioInterruption:(NSNotification *)notification;
- (BOOL)isInBackground;
- (void)handleAppDidEnterBackground:(NSNotification *)notification;
- (void)_handleTaskCompletionAndTerminate:(id)arg1;
@end
Dead10ccFix* fix = nil;

void initDead10ccFix(void) {
    if (!NSUserDefaults.isLiveProcess && !NSUserDefaults.isSharedApp) return;
    fix = [[Dead10ccFix alloc] init];
    [fix observeBackgroundForLiveProcess:NSUserDefaults.isLiveProcess];
}

@implementation Dead10ccFix

- (void)observeBackgroundForLiveProcess:(BOOL)liveProcess {
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    // Scene-hosted guests receive UIKit lifecycle events. The modern host
    // deliberately removes NSExtension's host-background forwarding.
    [center addObserver:self selector:@selector(handleAppDidEnterBackground:)
                   name:UIApplicationDidEnterBackgroundNotification object:nil];
    if (liveProcess) {
        [center addObserver:self selector:@selector(handleAppDidEnterBackground:)
                       name:NSExtensionHostDidEnterBackgroundNotification object:nil];
    }
    [center addObserver:self selector:@selector(handleAudioInterruption:)
                   name:AVAudioSessionInterruptionNotification object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL)isInBackground {
    return UIApplication.sharedApplication.applicationState == UIApplicationStateBackground;
}

- (void)handleAudioInterruption:(NSNotification *)notification {
    if ([notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue] != AVAudioSessionInterruptionTypeBegan) return;
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self handleAudioInterruption:notification]; });
        return;
    }
    // Losing the audio assertion can suspend an already-backgrounded guest
    // without a second didEnterBackground notification. Protect its current
    // locks now; never reactivate audio or override the guest's pause handler.
    if ([self isInBackground]) {
        [self handleAppDidEnterBackground:notification];
    }
}

- (void)handleAppDidEnterBackgroundReal {
    NSSet* locks = [self _lock_lockedFilePathsIgnoring:[NSMutableSet set]];
    for(NSString* path in locks) {
        unsigned char value = 0x01;

        setxattr([path UTF8String], "com.apple.runningboard.can-suspend-locked", &value, sizeof(value),0,0);
    }
}

// https://gist.github.com/JJTech0130/07e2458df592faad1d2ba72283a0ca50
- (NSMutableSet *)_lock_lockedFilePathsIgnoring: (NSMutableSet *)ignoring {
    int pid = getpid();
    int pidinfo_size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
    if (pidinfo_size <= 0) {
        // _rbs_process_log with strerr
        return nil;
    }

    void *pidinfo = malloc(pidinfo_size);
    if (!pidinfo) {
        return nil;
    }
    pidinfo_size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, pidinfo, pidinfo_size);
    if (pidinfo_size <= 0) {
        free(pidinfo);
        return nil;
    }

    NSMutableDictionary<NSString *, NSNumber *> *openFileDescriptors = [NSMutableDictionary dictionary];

    if (pidinfo_size >= 8) {
        uint64_t count = pidinfo_size / sizeof(struct proc_fdinfo);
        struct proc_fdinfo *fdinfo = (struct proc_fdinfo *)pidinfo;
        
        while (count--) {
            if (fdinfo->proc_fdtype == PROX_FDTYPE_VNODE) {
                struct vnode_fdinfowithpath vnodeinfo;
                //memset(&vnodeinfo, 0, 0x200); // TODO: Why not sizeof(vnodeinfo)?
                int vnodeinfo_size = proc_pidfdinfo(pid, fdinfo->proc_fd, PROC_PIDFDVNODEPATHINFO, &vnodeinfo, sizeof(vnodeinfo));
                if (vnodeinfo_size == 0) {
                    // _rbs_process_log with %{public}@ proc_pidfdinfo failed for fd %d with errno %d
                    continue;
                } else if (vnodeinfo_size < sizeof(vnodeinfo)) {
                    // _rbs_process_log with %{public}@ Weird size (%d != %lu) for fd %d
                    continue;
                }

                int64_t pathlen = strlen(vnodeinfo.pvip.vip_path);
                if (pathlen == 0) {
                    // _rbs_process_log with%{public}@ nodeFDInfo.pvip.vip_path is empty for one fd
                    continue;
                }

                NSString *path = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:vnodeinfo.pvip.vip_path length:pathlen];
                if (path == nil) {
                    continue;
                }

                path = [path stringByStandardizingPath];
                openFileDescriptors[path] = @(fdinfo->proc_fd);
            }
            fdinfo++;
        }
    }
    free(pidinfo);

    NSMutableSet *lockedFilePaths = [NSMutableSet set];

    for (NSString *path in openFileDescriptors) {
        char *path_c = (char *)[path UTF8String];
        struct stat statbuf;
        if (stat(path_c, &statbuf) != 0) {
            // _rbs_process_log with %{public}@ Could not stat %{public}@: %{public}s
            NSLog(@"Could not stat %@: %s", path, strerror(errno));
            continue;
        }

        if ((statbuf.st_mode & S_IFMT) != S_IFREG) {
            // _rbs_process_log with %{public}@ Not checking lock on special file: %{public}@
//            NSLog(@"Not checking lock on special file: %@", path);
            continue;
        }

        BOOL ignored = NO;
        for (NSString *ignoringPath in ignoring) {
            if ([path isEqualToString:ignoringPath] ||
                [path hasPrefix:[ignoringPath stringByAppendingString:@"/"]]) {
                ignored = YES;
                break;
            }
        }
        if (ignored) continue;

        // SQLite WAL takes locks on its -shm file. Names cannot tell us whether
        // a regular file is safe to suspend; inspect the actual lock instead.
        unsigned char allowed = 0;
        if (getxattr(path_c, "com.apple.runningboard.can-suspend-locked", &allowed, sizeof(allowed), 0, 0) == 1 && allowed != 0) continue;
        // Query an existing descriptor. Opening and then closing another
        // descriptor for the same inode releases this process's POSIX
        // locks, even when those locks were acquired on a different fd.
        int fd = openFileDescriptors[path].intValue;
        struct stat current;
        if (fstat(fd, &current) != 0 || current.st_dev != statbuf.st_dev ||
            current.st_ino != statbuf.st_ino) continue;

        // F_GETLKPID ignores POSIX locks owned by the caller. The OFD
        // query uses the descriptor as owner and can see those locks; the
        // process query in turn sees OFD locks (including SQLite's locks).
        const int commands[] = { F_GETLKPID, F_OFD_GETLKPID };
        for (NSUInteger index = 0; index < sizeof(commands) / sizeof(commands[0]); index++) {
            struct flock fl = { .l_type = F_WRLCK, .l_whence = SEEK_SET, .l_pid = pid };
            if (fcntl(fd, commands[index], &fl) == 0 &&
                (fl.l_type == F_RDLCK || fl.l_type == F_WRLCK)) {
                [lockedFilePaths addObject:path];
                break;
            }
        }
    }

    return lockedFilePaths;
}

- (void)handleAppDidEnterBackground:(NSNotification *)notification {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self handleAppDidEnterBackground:notification]; });
        return;
    }
    // Do not wait for a pending background task to finish before protecting
    // locks: an audio interruption may be the last execution opportunity.
    [self handleAppDidEnterBackgroundReal];
    if (self.waitingForTasks) return;
    if(!_methodInited) {
        // hack: steal -[UIApplication _handleTaskCompletionAndTerminate:]
        Class class = NSClassFromString(@"UIApplication");
        SEL sel = @selector(_handleTaskCompletionAndTerminate:);
        Method method = class_getInstanceMethod(class, sel);
        if (!method) return;
        class_addMethod(Dead10ccFix.class, sel, method_getImplementation(method), method_getTypeEncoding(method));
        _methodInited = YES;
    }
    self.waitingForTasks = YES;
    // this will call _UIApplicationCallWhenBackgroundTaskCountReachesZero which calls _terminateWithStatus: when no background tasks are left
    [self _handleTaskCompletionAndTerminate:self];
}

- (void)_terminateWithStatus:(int)status {
    self.waitingForTasks = NO;
    // Fake implementation from UIApplication
//    NSLog(@"[LC] _handleTaskCompletionAndTerminate");
    [self handleAppDidEnterBackgroundReal];
    //    NSLog(@"Backtrace: %@", [NSThread performSelector:@selector(ams_symbolicatedCallStackSymbols)]);
    if([[NSClassFromString(@"UIApplication") sharedApplication] applicationState] != 0) {
        self.deboundeToken += 1;
        int curToken = self.deboundeToken;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if(self.deboundeToken != curToken) {
                return;
            }
            [self handleAppDidEnterBackground:nil];
        });
    }
}

- (BOOL)waitForBackgroundTaskCompletion {
    // Fake implementation from UIApplicationSceneTransitionContext for _handleTaskCompletionAndTerminate:
    return YES;
}

@end
