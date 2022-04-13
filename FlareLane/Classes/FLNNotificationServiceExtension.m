//
//  FLNNotificationServiceExtension.m
//  FlareLane
//
//  Created by MinHyeok Kim on 2022/04/12.
//

#import "FLNNotificationServiceExtension.h"
#if __has_include("FlareLane-Swift.h")
#import "FlareLane-Swift.h"
#else
#import <FlareLane/FlareLane-Swift.h>
#endif

@implementation FLNNotificationServiceExtension
{
  FlareLaneExtensionHelper *_extensionHelper;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _extensionHelper = [FlareLaneExtensionHelper new];
  }
  return self;
}

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent *contentToDeliver))contentHandler
{
  [_extensionHelper didReceive:request withContentHandler:contentHandler];
}

- (void)serviceExtensionTimeWillExpire
{
    [_extensionHelper serviceExtensionTimeWillExpire];
}

@end
