//
//  CocoaProgressWindow.h
//
//  Copyright 2011-2015 Jonathan Taylor. All rights reserved.
//
//	A cocoa wrapper for my BaseProgressBar class, to display a progress window as a proper OS X window
//
//

#import <Cocoa/Cocoa.h>
#import "jWindowController.h"

@interface CocoaProgressWindow : JWindowController
{
	IBOutlet NSProgressIndicator	*indicator;
	IBOutlet NSTextField			*fraction, *elapsed, *remaining;
	class CocoaProgressWindowHelper	*_base;
	NSString						*_progressCaption;
	IBOutlet NSTextField			*progressTextField;		// This is duplicate (used when overlaying controls on an existing window). Should consolidate things here...
	bool							sheetBegun, _userCancelled;
}

-(id)initForItems:(double)inLength withTitle:(NSString *)title;
-(id)initForItems:(double)inLength withTitle:(NSString *)title sheetOnWindow:(NSWindow *)win;
-(id)initInitiallyIndeterminateWithTitle:(NSString *)title sheetOnWindow:(NSWindow *)win;
-(id)initIndeterminateWithTitle:(NSString *)title sheetOnWindow:(NSWindow *)win;
-(id)initIndeterminateOverlayWithTitle:(NSString *)title withControl:(NSProgressIndicator *)inProgressIndicator andTextField:(NSTextField *)inTextField;
-(void)dealloc;
-(void)upgradeToDeterminateLength:(double)inLength;
-(void)setUpSheetOnWindow:(NSWindow *)win;
-(void)closeSheetAndRelease;
-(void)closeWindowAndRelease;
-(void)resetTimeEstimate;
-(void)updateProgress:(int)val;
-(void)deltaProgress:(int)delta;
-(void)internalUpdateProgress:(double)newProgress;
-(IBAction)cancel:(id)sender;

@property (readwrite, nonatomic, retain) NSString *progressCaption;
@property (readwrite) bool userCancelled;
@end
