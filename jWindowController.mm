//
//  JWindowController.m
//  Simple Preview
//
//  Created by Jonathan Taylor on 14/09/2013.
//
//

#import "JWindowController.h"
#import "JNotifications.h"

NSMutableSet *activeWindowControllers = [[NSMutableSet alloc] init];
NSString *WindowControllerListChanged = @"jonny.jWindowController.listChanged";

@implementation JWindowController

-(void)windowDidLoad
{
	ALWAYS_ASSERT(![activeWindowControllers containsObject:self]);
	[activeWindowControllers addObject:self];
	QueueNotificationOnMainThread(WindowControllerListChanged, self, false, NSPostASAP);
}

-(void)windowWillClose:(NSNotification *)notification
{
	if (!CHECK([activeWindowControllers containsObject:self]))
		return;
	// Remove self from list of active window controllers.
	// Since this is probably the last retain of the object, we do a retain/autorelease
	// to make sure we live until the stack has been unwound.
	[[self retain] autorelease];
	[activeWindowControllers removeObject:self];
	/*	I can't help feeling there's a better way of handling this, but some code
		wants to know when windows come and go. This is the best means I can find
		of implementing that. I suspect though that the logic that requires us to
		monitor the window list might be better done a different way.	*/
	QueueNotificationOnMainThread(WindowControllerListChanged, self, false, NSPostASAP);
}

@end
