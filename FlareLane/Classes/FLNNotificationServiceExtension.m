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

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent *contentToDeliver))contentHandler
{
  [[FlareLaneNotificationServiceExtensionHelper shared] didReceive:request withContentHandler:contentHandler];
}

- (void)serviceExtensionTimeWillExpire
{
  [[FlareLaneNotificationServiceExtensionHelper shared] serviceExtensionTimeWillExpire];
}

@end
