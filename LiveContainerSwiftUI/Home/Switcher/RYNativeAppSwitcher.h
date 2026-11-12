#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RYNativeSwitcherItem : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong, nullable) UIImage *icon;
@property (nonatomic, strong, nullable) UIImage *snapshot;
@end

/// Hosts the system deck. SpringBoard owns card layout, scrolling and transitions.
@interface RYNativeAppSwitcher : UIViewController
@property (nonatomic, copy) NSArray<RYNativeSwitcherItem *> *items;
@property (nonatomic, copy, nullable) NSString *entryIdentifier;
@property (nonatomic, copy, nullable) void (^openHandler)(NSString *identifier, CGRect frame);
@property (nonatomic, copy, nullable) void (^closeHandler)(NSString *identifier);
@property (nonatomic, copy, nullable) void (^homeHandler)(void);
@property (nonatomic, readonly) BOOL usesNativeDeck;
@property (nonatomic, readonly, nullable) NSString *focusedIdentifier;
@property (nonatomic, readonly) NSDictionary<NSString *, NSValue *> *cardFrames;
- (void)refreshItems;
@end

NS_ASSUME_NONNULL_END
