#import <XCTest/XCTest.h>
@import SQLite3;
// Compile the guest implementation into this isolated test host. The normal
// integration host loads the UI frameworks, not the guest bootstrap executable.
#import "../../../LiveContainer/Tweaks/Dead10ccFix.m"

@interface BackgroundLockProbe : Dead10ccFix
@property NSUInteger scans;
@property NSUInteger waits;
@property BOOL background;
@property BOOL scannedOnMainThread;
@end
@implementation BackgroundLockProbe
- (void)handleAppDidEnterBackgroundReal {
    self.scans++;
    self.scannedOnMainThread = NSThread.isMainThread;
}
- (void)_handleTaskCompletionAndTerminate:(id)sender { self.waits++; }
- (BOOL)isInBackground { return self.background; }
@end

@interface BackgroundLockTests : XCTestCase
@end
@implementation BackgroundLockTests
- (void)testWALDatabaseSharedMemoryLockIsProtected {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    sqlite3 *database = NULL;
    XCTAssertEqual(sqlite3_open(path.fileSystemRepresentation, &database), SQLITE_OK);
    @try {
        XCTAssertEqual(sqlite3_exec(database, "PRAGMA journal_mode=WAL; CREATE TABLE sample (value); BEGIN IMMEDIATE; INSERT INTO sample VALUES (1);", NULL, NULL, NULL), SQLITE_OK);
        [[Dead10ccFix new] handleAppDidEnterBackgroundReal];
        unsigned char allowed = 0;
        NSString *sharedMemory = [path stringByAppendingString:@"-shm"];
        XCTAssertEqual(getxattr(sharedMemory.fileSystemRepresentation, "com.apple.runningboard.can-suspend-locked", &allowed, sizeof(allowed), 0, 0), 1);
        XCTAssertEqual(allowed, 1);
    } @finally {
        sqlite3_exec(database, "ROLLBACK", NULL, NULL, NULL);
        sqlite3_close(database);
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    }
}
- (void)testOrdinaryFileLockIsProtectedRegardlessOfFilename {
    NSString *path = [[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] stringByAppendingString:@"-journal"];
    int fd = open(path.fileSystemRepresentation, O_CREAT | O_RDWR, 0600);
    XCTAssertGreaterThanOrEqual(fd, 0);
    @try {
        struct flock lock = { .l_type = F_WRLCK, .l_whence = SEEK_SET, .l_start = 0, .l_len = 0 };
        XCTAssertEqual(fcntl(fd, F_SETLK, &lock), 0);
        struct flock before = { .l_type = F_WRLCK, .l_whence = SEEK_SET, .l_start = 0, .l_len = 0, .l_pid = getpid() };
        XCTAssertEqual(fcntl(fd, F_OFD_GETLKPID, &before), 0);
        XCTAssertEqual(before.l_type, F_WRLCK);
        [[Dead10ccFix new] handleAppDidEnterBackgroundReal];
        struct flock held = { .l_type = F_WRLCK, .l_whence = SEEK_SET, .l_start = 0, .l_len = 0, .l_pid = getpid() };
        XCTAssertEqual(fcntl(fd, F_OFD_GETLKPID, &held), 0);
        XCTAssertEqual(held.l_type, F_WRLCK, @"Protection must never release the guest's lock");
        unsigned char allowed = 0;
        XCTAssertEqual(getxattr(path.fileSystemRepresentation, "com.apple.runningboard.can-suspend-locked", &allowed, sizeof(allowed), 0, 0), 1);
        XCTAssertEqual(allowed, 1);
    } @finally {
        close(fd);
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    }
}
- (void)testLockedDatabaseIsMarkedBeforeSuspension {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    sqlite3 *database = NULL;
    XCTAssertEqual(sqlite3_open(path.fileSystemRepresentation, &database), SQLITE_OK);
    @try {
        XCTAssertEqual(sqlite3_exec(database, "CREATE TABLE sample (value); BEGIN EXCLUSIVE; INSERT INTO sample VALUES (1);", NULL, NULL, NULL), SQLITE_OK);
        Dead10ccFix *fix = [Dead10ccFix new];
        [fix handleAppDidEnterBackground:nil];
        unsigned char allowed = 0;
        XCTAssertEqual(getxattr(path.fileSystemRepresentation, "com.apple.runningboard.can-suspend-locked", &allowed, sizeof(allowed), 0, 0), 1);
        XCTAssertEqual(allowed, 1);
    } @finally {
        sqlite3_exec(database, "ROLLBACK", NULL, NULL, NULL);
        sqlite3_close(database);
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    }
}
- (void)testSceneAndLegacyBackgroundBothProtectLocksWithoutDuplicateWaiters {
    BackgroundLockProbe *probe = [BackgroundLockProbe new];
    probe.methodInited = YES;
    [probe observeBackgroundForLiveProcess:YES];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    XCTAssertEqual(probe.scans, 1u);
    [NSNotificationCenter.defaultCenter postNotificationName:NSExtensionHostDidEnterBackgroundNotification object:nil];
    XCTAssertEqual(probe.scans, 2u);
    XCTAssertEqual(probe.waits, 1u);
    XCTAssertTrue(probe.scannedOnMainThread);
}
- (void)testAudioInterruptionProtectsNewLocksWithoutAnotherBackgroundEvent {
    BackgroundLockProbe *probe = [BackgroundLockProbe new];
    probe.methodInited = YES;
    probe.background = YES;
    [probe observeBackgroundForLiveProcess:YES];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    [center postNotificationName:AVAudioSessionInterruptionNotification object:nil
                       userInfo:@{AVAudioSessionInterruptionTypeKey: @(AVAudioSessionInterruptionTypeBegan)}];
    XCTAssertEqual(probe.scans, 2u);
    XCTAssertEqual(probe.waits, 1u);
    [center postNotificationName:AVAudioSessionInterruptionNotification object:nil
                       userInfo:@{AVAudioSessionInterruptionTypeKey: @(AVAudioSessionInterruptionTypeEnded)}];
    XCTAssertEqual(probe.scans, 2u);
    probe.background = NO;
    [center postNotificationName:AVAudioSessionInterruptionNotification object:nil
                       userInfo:@{AVAudioSessionInterruptionTypeKey: @(AVAudioSessionInterruptionTypeBegan)}];
    XCTAssertEqual(probe.scans, 2u);
}
@end
