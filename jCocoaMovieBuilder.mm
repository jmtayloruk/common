//
//  jCocoaMovieBuilder.mm
//  Simple Preview
//
//  Created by Jonathan Taylor on 06/11/2011.
//  Copyright 2011 Durham University. All rights reserved.
//

#import "jCocoaMovieBuilder.h"

void GetDestinationDetailsUsingSheetOnWindow(NSWindow *sheetOnWindow, void (^handler)(NSInteger result, NSSavePanel *savePanel))
{
	NSSavePanel *spanel = [NSSavePanel savePanel];
//	[spanel setDirectory:[path stringByExpandingTildeInPath]];
	spanel.title = @"Save Captured Movie As...";
	spanel.nameFieldLabel = @"Save Captured Movie As...";
	spanel.message = @"Pick where to save the captured and compressed movie.";
	spanel.nameFieldStringValue = @"captured.mov";

	[spanel beginSheetModalForWindow:sheetOnWindow
				completionHandler:^(NSInteger result)
				{
					handler(result, spanel);
				}];
}
