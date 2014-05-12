//
//  jNotifications.h
//  Simple Preview
//
//  Created by Jonathan Taylor on 11/06/2010.
//  Copyright 2010 Durham University. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol FrameProtocol;

void SendImmediateNotificationForFrameOnThisThread(NSString *notificationName, id obj, id<FrameProtocol> frame);
void SendImmediateNotificationOnThisThread(NSString *notificationName, id obj);
void QueueNotificationForFrameOnMainThread(NSString *notificationName, id obj, id<FrameProtocol> frame, bool coalesce = false, NSPostingStyle style = NSPostASAP);
void QueueNotificationOnMainThread(NSString *notificationName, id obj, bool coalesce = false, NSPostingStyle style = NSPostASAP);
void QueueNotificationOnMainThread2(NSNotification *myNotification, bool coalesce = false, NSPostingStyle style = NSPostASAP);
void SendImmediateNotificationOnMainThread(NSNotification *myNotification);

extern NSString *CloseSheetsForTermination;
