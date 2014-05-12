//
//  jNotifications.mm
//  Simple Preview
//
//  Created by Jonathan Taylor on 11/06/2010.
//  Copyright 2010 Durham University. All rights reserved.
//

#import "jNotifications.h"

NSString *CloseSheetsForTermination = @"jmt.CloseSheetsForTermination";

void SendImmediateNotificationForFrameOnThisThread(NSString *notificationName, id obj, id<FrameProtocol> frame)
{
	// This is generally a bad idea since the notification will occur on whatever the current
	// thread is, which is probably not what we want. (Remember that frames are handled on
	// several different threads at various stages in the pipeline).
	// In a few cases it is necessary, though
	[[NSNotificationCenter defaultCenter] postNotificationName:notificationName 
											object:obj
											userInfo:[NSDictionary dictionaryWithObjectsAndKeys:frame, @"frame", nil]];
}

void SendImmediateNotificationOnThisThread(NSString *notificationName, id obj)
{
	[[NSNotificationCenter defaultCenter] postNotificationName:notificationName 
											object:obj];
}

// *** There is actually a comment here: http://www.mikeash.com/pyblog/friday-qa-2010-01-08-nsnotificationqueue.html
// that suggests this code is not safe - the notification will not necessarily run on the main queue.
// Did not really manage to get any clarification from cocoa-dev about the strict letter of the specification here.
// However in practice it seems to work ok...

void QueueNotificationForFrameOnMainThread(NSString *notificationName, id obj, id<FrameProtocol> frame, bool coalesce, NSPostingStyle style)
{
	NSNotification *myNotification = [NSNotification notificationWithName:notificationName 
														object:obj 
														userInfo:[NSDictionary dictionaryWithObjectsAndKeys:frame, @"frame", nil]];
	QueueNotificationOnMainThread2(myNotification, coalesce, style);
}

void QueueNotificationOnMainThread(NSString *notificationName, id obj, bool coalesce, NSPostingStyle style)
{
	NSNotification *myNotification = [NSNotification notificationWithName:notificationName object:obj];
	QueueNotificationOnMainThread2(myNotification, coalesce, style);
}

void QueueNotificationOnMainThread2(NSNotification *myNotification, bool coalesce, NSPostingStyle style)
{
	dispatch_async(dispatch_get_main_queue(), 
	^{
		[[NSNotificationQueue defaultQueue]
				enqueueNotification:myNotification
				postingStyle:style
				coalesceMask:(coalesce ? NSNotificationCoalescingOnName|NSNotificationCoalescingOnSender : NSNotificationNoCoalescing)
				forModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];		
	});
}

void SendImmediateNotificationOnMainThread(NSNotification *myNotification)
{
	dispatch_sync(dispatch_get_main_queue(), 
	^{
		[[NSNotificationCenter defaultCenter] postNotification:myNotification];
	});
}
