//
//  JWindowController.h
//  Simple Preview
//
//  Created by Jonathan Taylor on 14/09/2013.
//
//

#import <Cocoa/Cocoa.h>

extern NSMutableSet *activeWindowControllers;
extern NSString *WindowControllerListChanged;

@interface JWindowController : NSWindowController <NSWindowDelegate>

@end
