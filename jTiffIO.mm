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
#include "MetadataParser.h"
#include "ProgressBar.h"

int gFrameCounter = 0;

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
										  hasAlpha:(samplesPerPixel == 4)
										  isPlanar:NO
										  colorSpaceName:(samplesPerPixel > 1) ? NSCalibratedRGBColorSpace : NSCalibratedWhiteColorSpace
										  bytesPerRow:bytesPerSample*samplesPerPixel*width
										  bitsPerPixel:0];
		if (bitmap == nil)
		{
			// Convoluted code here to satisfy the static analyzer
			CHECK(bitmap != nil);
			break;
		}
		unsigned char *baseAddr = bitmap.bitmapData;
		size_t sourceRowBytes = bitmap.bytesPerRow;
		bool ok = true;
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

void SaveTiffFromSpool(NSString *spoolPath, NSString *destPath, int numImages, NSString *plistSourcePath, int firstPlistIndex, int w, int h, int stride, int bytesPerImage)
{
    // The information passed to this function can be found in the file 'acquisitionmetadata.ini' which should accompany the Solis spool files.
    // I haven't found a way to tell how many images there actually are - except for the fact that they are all-black.
    // It should be possible to parse acquisitionmetadata.ini, but for now I just inspect it manually.
    // The TIFF-writing code in this function is just ripped off from ImageSaver - hence the shoehorning of our parameters into the variables it expects.
    FILE *spoolFile = fopen(spoolPath.UTF8String, "r");
    ALWAYS_ASSERT(spoolFile != NULL);
    unsigned short *data = new unsigned short[bytesPerImage/2];
    
    TIFF *tif = TIFFOpen(destPath.UTF8String, "w");
    ALWAYS_ASSERT(tif != NULL);
    
    NSMutableDictionary *plist = [NSMutableDictionary dictionary];
    int plistIndex = firstPlistIndex;
    NSMutableArray *frameArray = [NSMutableArray array];
    
    for (int n = 0; n < numImages; n++)
    {
        fread(data, bytesPerImage, 1, spoolFile);
        
        size_t width = w, height = h;
        NSInteger samplesPerPixel = 1, bytesPerSample = 2;
        TIFFSetField(tif, TIFFTAG_IMAGEWIDTH, width);
        TIFFSetField(tif, TIFFTAG_IMAGELENGTH, height);
        TIFFSetField(tif, TIFFTAG_SAMPLESPERPIXEL, samplesPerPixel);
        TIFFSetField(tif, TIFFTAG_BITSPERSAMPLE, bytesPerSample*8);
        TIFFSetField(tif, TIFFTAG_ORIENTATION, ORIENTATION_TOPLEFT);
        TIFFSetField(tif, TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG);
        TIFFSetField(tif, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_MINISBLACK);
        size_t rowBytes = stride;
        CHECK(TIFFScanlineSize(tif) <= (tmsize_t)rowBytes);
        
        // We set the strip size of the file to be the default that libtiff suggests.
        // Note that Apple seems to do larger blocks, of about 130k for MB-scale images
        // TODO: consider making this larger - does it matter much?
        TIFFSetField(tif, TIFFTAG_ROWSPERSTRIP, TIFFDefaultStripSize(tif, (uint32)rowBytes));
        
        // Now write image to the file one strip at a time
        unsigned char *baseAddr = (unsigned char *)data;
        size_t sourceRowBytes = stride;
        for (size_t row = 0; row < height; row++)
        {
            unsigned char *sourcePtr = baseAddr + row * sourceRowBytes;
            if (TIFFWriteScanline(tif, sourcePtr, (uint32)row, 0) < 0)
                break;
        }
        TIFFWriteDirectory(tif);
        
        NSMutableDictionary *framePlist;
        if (plistSourcePath == nil)
        {
            // Create a dummy plist file to accompany the tiff file (so that MovieBuilder can parse them in a reasonable amount of time!)
            framePlist = [NSMutableDictionary dictionary];
            [framePlist setObject:[NSNumber numberWithDouble:gFrameCounter++] forKey:@"time_processing_started"];
        }
        else
        {
            // Use the counterpart plist from the zyla mirror camera
            // TODO: it might be nice to override certain properties to better match what the zyla camera settings actually were
            FrameMetadataParser *parser = [FrameMetadataParser parserForImagePath:[SWF:@"%@/%06d.tif", plistSourcePath, plistIndex++]];
            ALWAYS_ASSERT(parser.frameCount == 1);      // TODO: so far I don't support multi-page plists from zyla mirror, but it shouldn't be too hard to implement
            MetadataForFrame *metadata = [parser metadataForFrame:0];
            framePlist = metadata.frameSpecificMetadataDictionary;
        }
        [frameArray addObject:framePlist];
    }
    
    [plist setObject:frameArray forKey:@"frames"];
    if (plistSourcePath == nil)
        [plist setObject:[NSNumber numberWithInt:3] forKey:@"metadata_version"];
    else
        [plist setObject:[NSNumber numberWithInt:2] forKey:@"metadata_version"];
    NSString *destPlistPath = [destPath.stringByDeletingPathExtension stringByAppendingPathExtension:@"plist"];
    [plist writeToFile:destPlistPath atomically:NO];
    
    fclose(spoolFile);
	delete[] data;
    TIFFClose(tif);
}

NSInteger crazySpoolSortOrder(id string1, id string2, void *)
{
    /*  Andor order starts with 100000, 200000... 900000 then 010000 110000 210000
     i.e. it all makes sense if you read the digits back-to-front!    */
    const char *str1 = [((NSString *)string1).lastPathComponent UTF8String];
    const char *str2 = [((NSString *)string2).lastPathComponent UTF8String];
    ALWAYS_ASSERT((strlen(str1) > 6) && (strlen(str2) > 6));
    
    int num1 = 0;
    for (int i = 0, mul = 1; isdigit(str1[i]); i++, mul*=10)
        num1 = num1 + (str1[i]-'0') * mul;
    int num2 = 0;
    for (int i = 0, mul = 1; isdigit(str2[i]); i++, mul*=10)
        num2 = num2 + (str2[i]-'0') * mul;
    return DiffToNSComparisonResult(num1 - num2);
}

void ProcessSpoolFilesFromDirectory(NSString *spoolDir, NSString *iniPath, NSString *plistSourcePath, int firstPlistIndex, NSString *destTiffDir)
{
    // Parse and process Andor spool files, exporting them to plists.
    
    // Get a complete list of the files in the directory
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:spoolDir error:nil];
    // Filter to keep only the spool files
    NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
    for (size_t i = 0; i < dirContents.count; i++)
    {
        if ([[dirContents objectAtIndex:i] hasSuffix:@"spool.dat"])
            [set addIndex:i];
    }
    dirContents = [dirContents objectsAtIndexes:set];
    dirContents = [dirContents sortedArrayUsingFunction:crazySpoolSortOrder context:nil];
    
    // Crudely parse the .ini file
    int imagesPerFile, w, h, stride, bytesPerImage;
    FILE *iniFile = fopen(iniPath.UTF8String, "r");
    ALWAYS_ASSERT(iniFile != nil);
    int numRead = fscanf(iniFile, "%*c%*c%*c[data] AOIHeight = %d AOIWidth = %d AOIStride = %d PixelEncoding = Mono16 ImageSizeBytes = %d [multiimage] ImagesPerFile = %d", &h, &w, &stride, &bytesPerImage, &imagesPerFile);
    ALWAYS_ASSERT(numRead == 5);
    printf("Parsed .ini file: %d images/file %dx%d stride=%d bytes=%d\n", imagesPerFile, h, w, stride, bytesPerImage);
    fclose(iniFile);
    
    // Iterate over them, turning each one into a multipage tiff file
    int counter = 0;
    TextualProgressBar progress("Processing spool files", dirContents.count);
    for (NSString *theFilename in dirContents)
    {
        //        printf("%s\n", theFilename.UTF8String);
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSString *spoolPath = [SWF:@"%@/%@", spoolDir, theFilename];
        SaveTiffFromSpool(spoolPath, [SWF:@"%@/%06d.tif", destTiffDir, counter++], imagesPerFile,
                          plistSourcePath, firstPlistIndex,
                          w, h, stride, bytesPerImage);
        progress.DeltaProgress(1);
        [pool drain];
    }
}
