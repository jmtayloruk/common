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
		bool present = TIFFGetField(tif, TIFFTAG_IMAGEWIDTH, &width);
        CHECK(present);
		present = TIFFGetField(tif, TIFFTAG_IMAGELENGTH, &height);
        CHECK(present);
		present = TIFFGetField(tif, TIFFTAG_SAMPLESPERPIXEL, &samplesPerPixel);
        if (!present)
        {
            // Some tiffs generated from python don't seem to have this field filled out,
            // even though I would have imagined it might be compulsory
            samplesPerPixel = 1;
        }
		present = TIFFGetField(tif, TIFFTAG_BITSPERSAMPLE, &bitsPerSample);
        CHECK(present);
		bytesPerSample = (bitsPerSample + 7) / 8;
		// Expecting an orientation of ORIENTATION_TOPLEFT, but if it's something else then
		// I will just ignore that and read it as-is!
		TIFFGetField(tif, TIFFTAG_ORIENTATION, &orientation);
		// Expecting PLANARCONFIG_CONTIG. Not a lot I can do if it is different - if it is, then we will load garbage.
		present = TIFFGetField(tif, TIFFTAG_PLANARCONFIG, &planarConfig);
        CHECK(present);
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

bool SaveTiffFromSpool(NSString *spoolPath, NSString *destPath, int numImages, NSDictionary *metadataMapping, int firstPlistIndex, int w, int h, int stride, int bytesPerImage)
{
    // The information passed to this function can be found in the file 'acquisitionmetadata.ini' which should accompany the Solis spool files.
    // I haven't found a way to tell how many images there actually are - except for the fact that any excess "slots" are all-black.
    // It should be possible to parse acquisitionmetadata.ini, but for now I just inspect it manually.
    // The TIFF-writing code in this function is just ripped off from TIFFFileSaver - hence the shoehorning of our parameters into the variables it expects.
    // This code could probably be updated to just call that code directly, but since it works I'm not going to modify it just for the sake of tidiness - let's wait until (if) I am editing this function anyway.
    FILE *spoolFile = fopen(spoolPath.UTF8String, "r");
    ALWAYS_ASSERT(spoolFile != NULL);
    unsigned short *data = new unsigned short[bytesPerImage/2];
    
    TIFF *tif = TIFFOpen(destPath.UTF8String, "w");
    ALWAYS_ASSERT(tif != NULL);
    
    NSMutableDictionary *plist = [NSMutableDictionary dictionary];
    int plistIndex = firstPlistIndex;
    NSMutableArray *frameArray = [NSMutableArray array];
    
    bool outOfPlists = false;
    for (int n = 0; n < numImages; n++, plistIndex++)
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
        if (metadataMapping == nil)
        {
            // Create a dummy plist file to accompany the tiff file (so that MovieBuilder can parse them in a reasonable amount of time!)
            framePlist = [NSMutableDictionary dictionary];
            [framePlist setObject:[NSNumber numberWithDouble:gFrameCounter++] forKey:@"time_processing_started"];
        }
        else
        {
            // Use the counterpart plist from the zyla mirror camera
            // TODO: it might be nice to override certain properties to better match what the zyla camera settings actually were
            MetadataForFrame *metadata = [metadataMapping objectForKey:[SWF:@"%d", plistIndex]];
            framePlist = metadata.frameSpecificMetadataDictionary;
            if (framePlist == nil)
            {
                printf("Frame %d not found in plist\n", plistIndex);
                outOfPlists = true;
                break;
            }
        }
        [frameArray addObject:framePlist];
    }
    
    [plist setObject:frameArray forKey:@"frames"];
    if (metadataMapping == nil)
        [plist setObject:[NSNumber numberWithInt:3] forKey:@"metadata_version"];
    else
        [plist setObject:[NSNumber numberWithInt:2] forKey:@"metadata_version"];
    NSString *destPlistPath = [destPath.stringByDeletingPathExtension stringByAppendingPathExtension:@"plist"];
    [plist writeToFile:destPlistPath atomically:NO];
    
    fclose(spoolFile);
	delete[] data;
    TIFFClose(tif);
    return outOfPlists;
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

void ProcessSpoolFilesFromDirectory(NSString *spoolDir, NSString *iniPath, NSString *plistSourceDir, int firstPlistIndex, NSString *destTiffDir)
{
    /*  Parse and process Andor spool files, exporting them to plists.
        This code is useful for when a long Andor acquisition crashes - we can recover the data even though it hasn't been exported to TIFFs by the Andor code.
        If plistSourceDir is not nil, this code also deals with transferring metadata across from my zyla mirror files (acquired using a Prosilica camera)
        which contain timestamp information etc that matches up with each Zyla frame.
             spoolDir: directory containing the Andor spool files
             iniPath: path to the .ini file describing the spool files
             plistSourceDir: the directory containing zyla mirror plist files [and there must be accompanying tiffs, due to how ForEveryFrameInDirectory is written]
             firstPlistIndex: the number appearing in the first plist filename you want to match up with the Andor files.
             destTiffDir: directory where the tiffs (and plists) will be saved. Directory must exist already
     */
    
    // Load all the plist information into a dictionary mapping frame index to metadata.
    // That seems the easiest way to code it...
    // Note that, because of the way ForEveryFrameInDirectory is currently coded, the tiffs must also exist.
    NSMutableDictionary *metadataMapping = nil;
    if (plistSourceDir != nil)
    {
        metadataMapping = [NSMutableDictionary dictionary];
        NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:plistSourceDir error:nil];
        TextualProgressBar progress("Reading metadata files", dirContents.count/2);
        /*  This next line is a workaround to avoid a subtle issue that is now highlighted by the compiler.
            I cannot copy TextualProgressBar objects, because JMutex objects cannot be copied
            (for good reasons - unclear if that implies the same mutex object or a new one).
            If I apply the __block attribute to 'progress' that implicitly calls the copy constructor.
            The workaround is to access a pointer, rather than an object, within the block. */
        TextualProgressBar *_progress = &progress;
        ForEveryFrameInDirectory(plistSourceDir, ^(MetadataForFrame *metadata)
                                 {
                                     [metadataMapping setObject:metadata forKey:[SWF:@"%d", metadata.frameNumber]];
                                     _progress->DeltaProgress(1);
                                 });
    }
    
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
    int plistIndex = firstPlistIndex;
    TextualProgressBar progress("Processing %d spool files", dirContents.count, (int)dirContents.count);
    for (NSString *theFilename in dirContents)
    {
        //        printf("%s\n", theFilename.UTF8String);
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSString *spoolPath = [SWF:@"%@/%@", spoolDir, theFilename];
        bool outOfPlists = SaveTiffFromSpool(spoolPath, [SWF:@"%@/%06d.tif", destTiffDir, plistIndex], imagesPerFile,
                                             metadataMapping, plistIndex,
                                             w, h, stride, bytesPerImage);
        plistIndex += imagesPerFile;
        progress.DeltaProgress(1);
        [pool drain];
        if (outOfPlists)
        {
            // We might well run out of plists due to the "filler" frames in the final spool file,
            // but it should only be the final file.
            CHECK([theFilename isEqualToString:[dirContents lastObject]]);
            break;
        }
    }
}
