//
//  FLNNotificationServiceExtension.m
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

#import "FLNNotificationServiceExtension.h"
#if __has_include("FlareLane-Swift.h")
#import "FlareLane-Swift.h"
#else
#import <FlareLane/FlareLane-Swift.h>
#endif

@implementation FLNNotificationServiceExtension

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent *contentToDeliver))contentHandler
{
  [[FlareLaneNotificationServiceExtensionHelper shared] didReceive:request withContentHandler:contentHandler];
}

- (void)serviceExtensionTimeWillExpire
{
  [[FlareLaneNotificationServiceExtensionHelper shared] serviceExtensionTimeWillExpire];
}

@end
