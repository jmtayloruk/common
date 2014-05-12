//
//  CocoaProgressWindow.h
//  Simple Preview
//
//  Created by Jonathan Taylor on 30/09/2010.
//  Copyright 2010 Durham University. All rights reserved.
//

#import <Cocoa/Cocoa.h>

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
