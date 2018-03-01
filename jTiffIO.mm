/*
 *  jTiffIO.mm
 *
 *  Copyright 2011-2015 Jonathan Taylor. All rights reserved.
 *
 *	Utility functions for working with tiff files under Cocoa
 *	This gets a file of its own to prevent other code from being forced
 *	to link against libtiff unnecessarily
 *
 */

#import <Cocoa/Cocoa.h>
#include "jAssert.h"
#import "jCocoaImageUtils.h"
#include "../driver-installs/tiff-4.0.9/libtiff/tiffio.h"

NSImage *NSImageFromTiffFile(NSString *tiffPath)
{
	NSImage *result = [[NSImage new] autorelease];

	uint32 width, height, bytesPerSample;
	uint16 samplesPerPixel, bitsPerSample, orientation, planarConfig;
	TIFF *tif = TIFFOpen(tiffPath.UTF8String, "r");
	if (!CHECK(tif != nil))
		return nil;
	
	do
	{
		TIFFGetField(tif, TIFFTAG_IMAGEWIDTH, &width);
		TIFFGetField(tif, TIFFTAG_IMAGELENGTH, &height);
		TIFFGetField(tif, TIFFTAG_SAMPLESPERPIXEL, &samplesPerPixel);
		TIFFGetField(tif, TIFFTAG_BITSPERSAMPLE, &bitsPerSample);
		bytesPerSample = (bitsPerSample + 7) / 8;
		// Expecting an orientation of ORIENTATION_TOPLEFT, but if it's something else then
		// I will just ignore that and read it as-is!
		TIFFGetField(tif, TIFFTAG_ORIENTATION, &orientation);
		// Expecting PLANARCONFIG_CONTIG. Not a lot I can do if it is different - if it is, then we will load garbage.
		TIFFGetField(tif, TIFFTAG_PLANARCONFIG, &planarConfig);
		CHECK(planarConfig == PLANARCONFIG_CONTIG);
		NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
										  initWithBitmapDataPlanes:NULL
										  pixelsWide:width
										  pixelsHigh:height
										  bitsPerSample:bitsPerSample
										  samplesPerPixel:samplesPerPixel
										  hasAlpha:(bitsPerSample == 32)
										  isPlanar:NO
										  colorSpaceName:(samplesPerPixel > 1) ? NSCalibratedRGBColorSpace : NSCalibratedWhiteColorSpace
										  bytesPerRow:bytesPerSample*samplesPerPixel*width
										  bitsPerPixel:0];
		if (!CHECK(bitmap != nil))
			break;
		unsigned char *baseAddr = bitmap.bitmapData;
		size_t sourceRowBytes = bitmap.bytesPerRow;
		bool ok;
		for (size_t row = 0; row < height; row++)
		{
			unsigned char *destPtr = baseAddr + row * sourceRowBytes;
			ok = (TIFFReadScanline(tif, destPtr, (uint32)row, 0) == 1);
			if (!ok)
				break;
		}
		CHECK(ok);
		[result addRepresentation:bitmap];
		[bitmap release];
	} while (TIFFReadDirectory(tif));
	
	TIFFClose(tif);
	return result;
}
