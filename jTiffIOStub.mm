/*
 *  jTiffIOStub.mm
 *
 *  Copyright 2011-2015 Jonathan Taylor. All rights reserved.
 *
 *	Utility functions for working with tiff files under Cocoa
 *	This is a stub that just calls standard Cocoa APIs, for code that does not
 *	want the faff of linking against libtiff.
 *
 */

#import <Cocoa/Cocoa.h>
#import "jCocoaImageUtils.h"

NSImage *NSImageFromTiffFile(NSString *tiffPath)
{
	return [[[NSImage alloc] initWithContentsOfFile:self.imagePath] autorelease];
}
