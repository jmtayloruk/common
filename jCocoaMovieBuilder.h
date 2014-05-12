//
//  jCocoaMovieBuilder.h
//  Simple Preview
//
//  Created by Jonathan Taylor on 06/11/2011.
//  Copyright 2011 Durham University. All rights reserved.
//

#import <Cocoa/Cocoa.h>

void GetDestinationDetailsUsingSheetOnWindow(NSWindow *sheetOnWindow, void (^handler)(NSInteger result, NSSavePanel *savePanel));
