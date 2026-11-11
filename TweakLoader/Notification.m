#import <UserNotifications/UserNotifications.h>
#import "LCSharedUtils.h"
#import "../LiveContainer/utils.h"

@interface UNUserNotificationCenter (LCGuestNotifications)
@property (nonatomic, copy) NSString *bundleIdentifier;
@end

@implementation UNUserNotificationCenter (LCGuestNotifications)

- (void)lc_addNotificationRequest:(UNNotificationRequest *)request withCompletionHandler:(void (^)(NSError *))completion {
    [NSClassFromString(@"LCSharedUtils") recordGuestNotification:request];
    [self lc_addNotificationRequest:request withCompletionHandler:completion];
}

- (void)lc_removePendingNotificationRequestsWithIdentifiers:(NSArray<NSString *> *)identifiers {
    [NSClassFromString(@"LCSharedUtils") removeGuestNotificationsWithIdentifiers:identifiers pending:YES];
    [self lc_removePendingNotificationRequestsWithIdentifiers:identifiers];
}

- (void)lc_removeDeliveredNotificationsWithIdentifiers:(NSArray<NSString *> *)identifiers {
    [NSClassFromString(@"LCSharedUtils") removeGuestNotificationsWithIdentifiers:identifiers pending:NO];
    [self lc_removeDeliveredNotificationsWithIdentifiers:identifiers];
}

- (void)lc_removeAllPendingNotificationRequests {
    [NSClassFromString(@"LCSharedUtils") removeGuestNotificationsWithIdentifiers:nil pending:YES];
    [self lc_removeAllPendingNotificationRequests];
}

- (void)lc_removeAllDeliveredNotifications {
    [NSClassFromString(@"LCSharedUtils") removeGuestNotificationsWithIdentifiers:nil pending:NO];
    [self lc_removeAllDeliveredNotifications];
}

@end

__attribute__((constructor))
static void UNHooksInit(void) {
    if (!NSUserDefaults.lcGuestAppId || ![NSUserDefaults.guestAppInfo[@"fixLocalNotification"] boolValue]) return;
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    if ([center respondsToSelector:@selector(setBundleIdentifier:)]) {
        center.bundleIdentifier = NSUserDefaults.lcMainBundle.bundleIdentifier;
    }
    Class centerClass = UNUserNotificationCenter.class;
    swizzle(centerClass, @selector(addNotificationRequest:withCompletionHandler:), @selector(lc_addNotificationRequest:withCompletionHandler:));
    swizzle(centerClass, @selector(removePendingNotificationRequestsWithIdentifiers:), @selector(lc_removePendingNotificationRequestsWithIdentifiers:));
    swizzle(centerClass, @selector(removeDeliveredNotificationsWithIdentifiers:), @selector(lc_removeDeliveredNotificationsWithIdentifiers:));
    swizzle(centerClass, @selector(removeAllPendingNotificationRequests), @selector(lc_removeAllPendingNotificationRequests));
    swizzle(centerClass, @selector(removeAllDeliveredNotifications), @selector(lc_removeAllDeliveredNotifications));
}
