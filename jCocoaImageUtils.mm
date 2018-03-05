/*
 *  jCocoaImageUtils.mm
 *
 *  Copyright 2011-2015 Jonathan Taylor. All rights reserved.
 *
 *	Utility functions for working with images under Cocoa
 *
 */

#import <Cocoa/Cocoa.h>
#include "jAssert.h"
#import "MetadataParser.h"
#import "jCocoaImageUtils.h"
#import "NSPointArithmetic.h"
#import "CocoaProgressWindow.h"
#include "jCommon.h"
#include "../driver-installs/tiff-4.0.9/libtiff/tiffio.h"
#include <fts.h>

void ForEveryImageFileInDirectory(NSString *dir, void (^callback)(NSString *))
{
	// Iterate over every image file in the specified directory sequentially,
	// in our best attempt at an ascending order
	// and call the callback block for it (passing in the full path to the file)
	NSArray *dirContents = ListImageFilesInDirectory(dir);
	for (NSString *theFilename in dirContents)
	{
		/*	Make the callback. Note that we wrap the call with an autorelease pool.
			I very much doubt that will ever be a performance issue
			(if we're processing a file on disk there will always be a fair amount
			of time involved!), and this will help a lot with memory management,
			which will often grow out of control when processing a large dataset	*/
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSString *thePath = [SWF:@"%@/%@", dir, theFilename];
		callback(thePath);
		[pool drain];
	}
}

void ForEveryImageFileInDirectoryConcurrent(NSString *dir, void (^callback)(NSString *))
{
	// Iterate over every image file in the specified directory,
	// and call the callback block for it (passing in the full path to the file)
	// This variant does not guarantee to process each file in any order, and indeed
	// may concurrently call the callback for multiple files on different threads.
	NSArray *dirContents = ListImageFilesInDirectory(dir);
	__block NSString *dir2 = dir;		// Work around compiler problem with referencing inside block...
	dispatch_apply(dirContents.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i){
		NSString *theFilename = [dirContents objectAtIndex:i];
		NSString *thePath = [SWF:@"%@/%@", dir2, theFilename];
		callback(thePath);
	});
}

// TODO: the next two functions are very similar - is there a way I can combine them to save code duplication?
// If I figure out how to deal with caching the image data in the metadata parser,
// then it should be much easier to combine these two functions together
void ForEveryFrameInDirectory(NSString *dir, void (^callback)(MetadataForFrame *))
{
	// Iterate over every video frame in the specified directory sequentially,
	// in our best attempt at an ascending order,
	// and call the callback block for it (passing in the image metadata only)
	
	// Note: this function is somewhat inefficient because we load the plist metadata twice
	// (in ListImageFilesInDirectory and again as we iterate over the frames).
	// Given that the caller is presumably doing something with the image data,
	// the double-loading of metadata is probably not a significant bottleneck
	
	JAlias *folderAlias = [JAlias aliasForPath:dir];
	ForEveryImageFileInDirectory(dir, ^(NSString *imagePath)
								 {
									 //	In this variant of the function, we do not actually load the images,
									 //	we just provide the metadata.
									 FrameMetadataParser *parser = [FrameMetadataParser parserForImageFilename:imagePath.lastPathComponent inFolder:folderAlias];
									 for (size_t frameIndex = 0; frameIndex < parser.frameCount; frameIndex++)
									 {
										 // Make the callback for this particular frame
										 callback([parser metadataForFrame:frameIndex]);
									 }
								 });
}

void ForEveryFrameInDirectory(NSString *dir, void (^callback)(NSBitmapImageRep *, MetadataForFrame *))
{
	// Same as above, but also providing the image data
	JAlias *folderAlias = [JAlias aliasForPath:dir];
	ForEveryImageFileInDirectory(dir, ^(NSString *imagePath)
								 {
									 /*	Process this image file, which may contain more than one frame
										
										Note: this code is a bit outdated, in that FrameMetadataParser can provide the bitmaps
										via frameBitmapForArrayIndex.
										There does not seem to be a big performance difference between the two methods
										(which is probably not too surprising since the bottleneck will be disk access	*/
									 NSImage *theImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
									 NSArray *bitmaps = AllRawBitmapsFromImage(theImage);
									 // Open the plist file. Parser will be nil if no accompanying plist exists
									 FrameMetadataParser *parser = [FrameMetadataParser parserForImageFilename:imagePath.lastPathComponent inFolder:folderAlias];
									 if (parser.frameCount == bitmaps.count)
									 {
										 for (size_t frameIndex = 0; frameIndex < bitmaps.count; frameIndex++)
										 {
											 // Make the callback for this particular frame
											 callback([bitmaps objectAtIndex:frameIndex], [parser metadataForFrame:frameIndex]);
										 }
									 }
									 else
									 {
										 // Sanity check failed - mismatch between number of frames in image and number of frames in metadata.
										 // Not sure what to do here - best just to skip this frame(s).
									 }
									 [theImage release];
								 });
}

NSString *FirstImageFileNameInDirectory(NSString *dir)
{
	// Returns the path ot the first image file found in the specified directory
	NSArray *dirContents = ListImageFilesInDirectory(dir);
	if (dirContents.count > 0)
		return [SWF:@"%@/%@", dir, [dirContents objectAtIndex:0]];
	else
		return nil;
}

NSBitmapImageRep *FirstBitmapInDirectory(NSString *dirPath)
{
	FrameMetadataParser *parser = [FrameMetadataParser parserForImagePath:FirstImageFileNameInDirectory(dirPath)];
	return [parser metadataForFrame:0].frameBitmap;
}

NSInteger alphabeticalOrder(id string1, id string2, void *)
{
	return [(NSString *)string1 caseInsensitiveCompare:(NSString *)string2];
}

NSInteger frameSortOrder(id string1, id string2, void *)
{
	// Comparison function used to work out the ordering of a list of image filenames
	// The complication comes in dealing with files numbered file1.tif, file2.tif... file10.tif... file100.tif
	const char *str1 = [((NSString *)string1).lastPathComponent UTF8String];
	const char *str2 = [((NSString *)string2).lastPathComponent UTF8String];
	// Identify the first dot in each filename
	const char *pos1 = strchr(str1, '.');
	const char *pos2 = strchr(str2, '.');
	if ((pos1 != NULL) && (pos2 != NULL))
	{
		// If both filenames have dots, and one is shorter than the other, order that one first.
		// e.g. file1.tif comes before file10.tif.
		if ((pos1 - str1) < (pos2 - str2))
			return NSOrderedAscending;
		if ((pos1 - str1) > (pos2 - str2))
			return NSOrderedDescending;
	}
	if ((pos1 == NULL) && (pos2 == NULL))
	{
		// If neither has a dot, and one is shorter than the other, order that one first.
		// e.g. folder1 comes before folder10
		size_t len1 = strlen(str1);
		size_t len2 = strlen(str2);
		if (len1 < len2)
			return NSOrderedAscending;
		if (len1 > len2)
			return NSOrderedDescending;
	}
	// Normal case: just do a standard string comparison.
	return [(NSString *)string1 caseInsensitiveCompare:(NSString *)string2];
}

NSInteger frameSortOrderUsingTimestamps(id string1, id string2, void *pathStem)
{
	// This is slower than sorting on the name alone,
	// but is the best way of handling some strangely-named old datasets
	// However, better than this is the code in FasterSortFramesByTimestamp that caches the timestamps rather than reading them repeatedly
	NSString *stem = @"";
	if (pathStem != nil)
	{
		ALWAYS_ASSERT([(id)pathStem isKindOfClass:[NSString class]]);
		stem = [SWF:@"%@/", pathStem];
	}
	MetadataForFrame *metadata1 = [MetadataForFrame metadataForFirstFrameAtImagePath:[SWF:@"%@%@", stem, string1]];
	MetadataForFrame *metadata2 = [MetadataForFrame metadataForFirstFrameAtImagePath:[SWF:@"%@%@", stem, string2]];
	NSNumber *timestamp1 = [metadata1 valueForKeyPath:@"frame.timestamp"];
	NSNumber *timestamp2 = [metadata2 valueForKeyPath:@"frame.timestamp"];
	if ((timestamp1 != nil) && (timestamp2 != nil))
	{
		double t1 = timestamp1.doubleValue;
		double t2 = timestamp2.doubleValue;
		if (t1 < t2)
			return NSOrderedAscending;
		else if (t1 > t2)
			return NSOrderedDescending;
		else
			return NSOrderedSame;
	}
	// If we get here then there is presumably not metadata available
	return frameSortOrder(string1, string2, nil);
}

NSInteger frameSortOrderForURLs(id url1, id url2, void *)
{
	return frameSortOrder(((NSURL *)url1).path, ((NSURL *)url2).path, nil);
}

struct TimestampedFrame
{
	NSString *filename;
	double timestamp;
	
	static bool Compare(const TimestampedFrame &a, const TimestampedFrame &b)
	{
		if (a.timestamp != b.timestamp)
			return (a.timestamp < b.timestamp);
		return (frameSortOrder(a.filename, b.filename, nil) == NSOrderedAscending);
	}
};

NSArray *FasterSortFramesByTimestamp(NSArray *filenames, NSString *pathStem, CocoaProgressWindow *progress = nil)
{
	/*  This function sorts files generated by Spim GUI, sorting by their timestamp.
		
		We get terrible performance if we just use frameSortOrderUsingTimestamps naively,
	 because of the number of times it reads the entire metadata dictionary just to get one value!
	 Although it makes the code longer, it's worth reading the timestamps once and caching them.
	 At this point, the shortest code is going to be using C++, not ObjC I think...
	 
	 Note that of course the strings are not retained by the C++ code, so we are careful to
	 insert the strings into a new array rather than messing with the old one, just in case
	 that leads to string objects being released prematurely or anything like that.
	 */
	NSString *stem = @"";
	if (pathStem != nil)
	{
		ALWAYS_ASSERT([(id)pathStem isKindOfClass:[NSString class]]);
		stem = [SWF:@"%@/", pathStem];
	}
	std::vector<TimestampedFrame> ts(filenames.count);
	size_t i = 0;
	if (progress != nil)
	{
		// Caller has provided a progress window for us to take over
		progress.progressCaption = @"Sorting frames...";
		[progress upgradeToDeterminateLength:filenames.count];
	}
	JAlias *folderAlias = [JAlias aliasForPath:stem];
	for (NSString *s in filenames)
	{
		// Attempt to get a timestamp for this file, from the metadata.
		// If metadata exists, this code will correctly handle both old-style metadata for a single frame,
		// and new-style metadata that might be for multiple frames (in which case it will get the timestamp of the first frame in the file)
		FrameMetadataParser *parser = [FrameMetadataParser parserForImageFilename:s inFolder:folderAlias];
		NSNumber *timestamp = [parser valueForKeyPath:@"frame.timestamp" arrayIndex:0];
		// Note down the timestamp (if we found one)
		if (timestamp != nil)
			ts[i++] = (TimestampedFrame){s, timestamp.doubleValue};
		else
			ts[i++] = (TimestampedFrame){s, -1.0};
		// Crude flow control on the progress updates, since our unit of work is very small
		if ((i % 100) == 0)
			[progress deltaProgress:100];
	}
	std::sort(ts.begin(), ts.end(), TimestampedFrame::Compare);
	
	NSMutableArray *result = [NSMutableArray array];
	for (i = 0; i < ts.size(); i++)
		[result addObject:ts[i].filename];
	return result;
}

bool IsImageFile(NSString *theFilename)
{
	// Returns true if the filename looks like an image file
	return ([theFilename hasSuffix:@".tif"] ||
			[theFilename hasSuffix:@".tiff"] ||
			[theFilename hasSuffix:@".bmp"] ||
			[theFilename hasSuffix:@".png"] ||
			[theFilename hasSuffix:@".jpg"] ||
			[theFilename hasSuffix:@".jpeg"] ||
			[theFilename hasSuffix:@".eps"]);
}

NSArray *ListImageFilesInDirectory(NSString *dir, bool sorted, bool useTimestamps, bool fullPath, CocoaProgressWindow *progress)
{
	// Returns an array containing NSStrings for each image file in a directory
#if 0
	// (Old version that I think is probably slower)
	NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
	// Filter to keep only the image files
	NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
	for (size_t i = 0; i < dirContents.count; i++)
	{
		if (IsImageFile([dirContents objectAtIndex:i]))
			[set addIndex:i];
	}
	dirContents = [dirContents objectsAtIndexes:set];
	dirContents = [dirContents sortedArrayUsingFunction:frameSortOrder context:nil];
	return dirContents;
#else
	// It will hopefully be faster to use lower-level APIs as follows.
	// Get a pointer to the first in a tree of structures representing the contents of the directory
	ALWAYS_ASSERT(dir != nil);
	size_t len = strlen(dir.UTF8String) + 1;
	char pathBuffer[len];
	snprintf(pathBuffer, len, "%s", dir.UTF8String);
	char * const pathArray[2] = { pathBuffer, NULL };
	FTS *ftsHandle = fts_open(pathArray, FTS_LOGICAL | FTS_NOSTAT, NULL);
	// We do not actually use this next result, just need to do this before call to fts_children.
	// May possibly be better just to repeatedly do fts_read?
	fts_read(ftsHandle);
	
	// Now we can get the linked list of child files
	FTSENT *child = fts_children(ftsHandle, FTS_NAMEONLY);
	
	// Transfer the linked list into a mutable array
	NSMutableArray *dirContents2 = [NSMutableArray array];
	while (child != NULL)
	{
		// Add any image filenames to our array.
		/*	Note that this actual traversal and filtering doesn't seem to take
			a significant amount of time compared with the fts calls above	*/
		NSString *thisFile = [SWF:@"%s", child->fts_name];
		if (IsImageFile(thisFile))
			[dirContents2 addObject:thisFile];
		child = child->fts_link;
	}
	fts_close(ftsHandle);
	
	// Sort after filtering (let's make the array as small as possible before we sort it!)
	NSArray *dirContents3;
	if (sorted)
	{
		if (useTimestamps)
		{
			dirContents3 = FasterSortFramesByTimestamp(dirContents2, dir, progress);
		}
		else
			dirContents3 = [dirContents2 sortedArrayUsingFunction:frameSortOrder context:nil];
	}
	else
		dirContents3 = dirContents2;
	
	if (fullPath)
	{
		NSMutableArray *dirContents4 = [NSMutableArray array];
		for (int i = 0; i < (int)dirContents2.count; i++)
		{
			NSString *theFullPath = [dir stringByAppendingPathComponent:[dirContents3 objectAtIndex:i]];
			[dirContents4 addObject:theFullPath];
		}
		return dirContents4;
	}
	else
		return dirContents3;
#endif
}

#pragma mark -

bool /*sizes matched*/ PopulateArrayFromBitmap(const NSBitmapImageRep *bitmap, double *destArray, int destWidth, int destHeight, int downsampleFactor, bool assertOnSizeMismatch)
{
    // Handle potential difference in bitmap and array dimensions
    bool sizeMismatch = false;
    if (bitmap.pixelsWide != destWidth * downsampleFactor)
        sizeMismatch = true;
    if (bitmap.pixelsHigh != destHeight * downsampleFactor)
        sizeMismatch = true;
    if (assertOnSizeMismatch)
        ALWAYS_ASSERT(!sizeMismatch);
    int width = MIN(destWidth, (int)bitmap.pixelsWide/downsampleFactor);
    int height = MIN(destHeight, (int)bitmap.pixelsHigh/downsampleFactor);
    int x0 = 0, y0 = 0;
    if (sizeMismatch)
    {
        if (bitmap.pixelsWide / downsampleFactor < destWidth)
            x0 = (destWidth - (int)bitmap.pixelsWide / downsampleFactor) / 2;
        if (bitmap.pixelsHigh / downsampleFactor < destHeight)
            y0 = (destHeight - (int)bitmap.pixelsHigh / downsampleFactor) / 2;
    }
    
    // For now we expect an 8- or 16-bit greyscale image
    if (bitmap.bitsPerPixel == 16)
    {
        for (int y = 0; y < height; y++)
        {
            const unsigned short *rowSource = (const unsigned short*)(bitmap.bitmapData + (y * downsampleFactor) * bitmap.bytesPerRow);
            ALWAYS_ASSERT((y+y0)*destWidth+(width+x0) <= destWidth * destHeight);
            double scaleFactor = 1.0 / 65536.0;
            for (int x = 0; x < width; x++)
            {
                destArray[(y+y0)*destWidth+(x+x0)] = rowSource[x*downsampleFactor] * scaleFactor;
            }
        }
    }
    else
    {
        ALWAYS_ASSERT(bitmap.bitsPerPixel == 8);
    //    ALWAYS_ASSERT(!(bitmap.bitmapFormat & NSAlphaFirstBitmapFormat));

        for (int y = 0; y < height; y++)
        {
            const unsigned char *rowSource = bitmap.bitmapData + (y * downsampleFactor) * bitmap.bytesPerRow;
            if (!CHECK((y+y0)*destWidth+(width+x0) <= destWidth * destHeight))
            {
                printf("%d %d %d %d %d %d\n", y, y0, x0, width, destWidth, destHeight);
            }
            ALWAYS_ASSERT((y+y0)*destWidth+(width+x0) <= destWidth * destHeight);
            double scaleFactor = 1.0 / 256.0;
            for (int x = 0; x < width; x++)
            {
                destArray[(y+y0)*destWidth+(x+x0)] = rowSource[x*downsampleFactor] * scaleFactor;
            }
        }
    }
    
    return sizeMismatch;
}

bool /*sizes matched*/ PopulateArrayFromBitmap(const char *bitmapPath, double *destArray, int destWidth, int destHeight, int downsampleFactor, bool assertOnSizeMismatch)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    bool result = PopulateArrayFromBitmap(RawBitmapFromImagePath([SWF:@"%s", bitmapPath]), destArray, destWidth, destHeight, downsampleFactor, assertOnSizeMismatch);
    [pool drain];
    return result;
}

NSArray *AllRawBitmapsFromImage(const NSImage *image)
{
    // Returns an array of NSBitmapImageReps from the NSImage that is passed in.
    // It is expected that the NSImage represents a multi-page TIFF
    if (!CHECK(image != nil))
        return nil;
    
    NSMutableArray      *result = [NSMutableArray new];
    for (NSObject *imageRepresentation in image.representations)
    {
        if ([imageRepresentation isKindOfClass:[NSBitmapImageRep class]])
            [result addObject:(NSBitmapImageRep*)imageRepresentation];
    }
    return [result autorelease];
}

NSBitmapImageRep *RawBitmapFromImage(const NSImage *image)
{
	// Returns an NSBitmapImageRep from the NSImage that is passed in.
	// This isn't intended to handle all possible scenarios, but will do the best it can,
	// and assert if things don't make sense.
	// In practice most images I work with seem to contain one and only one bitmap image.
	if (!CHECK(image != nil))
		return nil;
		
	NSBitmapImageRep	*result = nil;
    NSArray				*repArray = [image representations];
	
	/*	n.b. a better way of implementing all this under 10.6 would actually be based on:
		 [[NSBitmapImageRep alloc] initWithCGImage:[image CGImageForProposedRect?:context:hints:]]
		 See http://cocoadev.com/index.pl?NSBitmapImageRep	*/
		 
    for (size_t imgRepresentationIndex = 0; imgRepresentationIndex < repArray.count; ++imgRepresentationIndex)
    {
        NSObject *imageRepresentation = [repArray objectAtIndex:imgRepresentationIndex];
     
//		printf("Got rep %p (%zd of %d, class %s)\n", imageRepresentation, imgRepresentationIndex, repArray.count, object_getClassName(imageRepresentation));
        if ([imageRepresentation isKindOfClass:[NSBitmapImageRep class]])
		{
			CHECK(result == nil);	// If we fail this then there are two different bitmap representations stored
											// (need to decide what to do then...)
			result = (NSBitmapImageRep*)imageRepresentation;
		}
	}
	
	if (result == nil)
	{
		// It is possible to end up with a representation of type NSCGImageSnapshotRep under some circumstances
		// In that case I have to explicitly draw it into a bitmap as follows
		[image lockFocus];
		result = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, [image size].width, [image size].height)] autorelease];
		[image unlockFocus];
	}
	
	ALWAYS_ASSERT(result != nil);		// If we fail this then there was no bitmap representation stored (vector image?)
	return [[result retain] autorelease];
}

NSBitmapImageRep *RawBitmapFromImagePath(NSString *imagePath)
{
	NSImage *theImage = [[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease];
	return RawBitmapFromImage(theImage);
}

NSImage *AllocNSImageFromFile(const char *path)
{
	// Not sure if I use this for anything any more, but it was intended to allow C code
	// to load an image file into an NSImage (which the C code could treat as an opaque pointer)
	return [[NSImage alloc] initWithContentsOfFile:[SWF:@"%s", path]];
}

void ReleaseNSImage(NSImage *image)
{
	// Allows C code to release an NSImage
	[image release];
}

void BrightenNSImage(NSImage *image, int factor)
{
	// Almost certainly obsolete code, doing a quick-and-dirty brightening operation on an NSImage
	if (factor == 1)
		return;
		
	// Very dodgy way of brightening an NSImage - should come up with a proper way of doing it!
	NSRect theRect = NSMakeRect(0, 0, image.size.width, image.size.height);
	NSImage *imageCopy = [image copy];
	[image lockFocus];
	for (int i = 1; i < factor; i++)
		[imageCopy drawInRect:theRect fromRect:theRect operation:NSCompositePlusLighter fraction:1.0];
	[imageCopy release];
	[image unlockFocus];
}

NSBitmapImageRep *TintBitmap(NSBitmapImageRep *srcBitmap, NSColor *tint, NSColor *saturation, double exposureOnScreen)
{
	// Takes a greyscale input image and returns a colour result image
	// that has been tinted according to the input colours
	ALWAYS_ASSERT(srcBitmap.samplesPerPixel == 1);
	int width = (int)srcBitmap.pixelsWide, height = (int)srcBitmap.pixelsHigh;
	NSBitmapImageRep *destBitmap = [NSBitmapImageRep rgbaBitmap_width:width height:height];

	// We are going to fill in the bitmap data by hand, but first we need to know what the colours are.
	// There's no simple way of querying the RGB components of an arbitrary NSColor, so we do it the
	// empirical way by seeing how they come out when drawn into the bitmap!
	[NSGraphicsContext saveGraphicsState];
	NSGraphicsContext *newContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:destBitmap];
	[NSGraphicsContext setCurrentContext:newContext];
	[tint setFill];
	NSBezierPath* drawingPath = [NSBezierPath bezierPath];
	[drawingPath appendBezierPathWithRect:NSMakeRect(0, height-1, 1, 1)];
	[drawingPath fill];
	[saturation setFill];
	drawingPath = [NSBezierPath bezierPath];
	[drawingPath appendBezierPathWithRect:NSMakeRect(1, height-1, 1, 1)];
	[drawingPath fill];
	[NSGraphicsContext restoreGraphicsState];
	void *srcData = srcBitmap.bitmapData;
	unsigned char *destData = destBitmap.bitmapData;
	double tintRGB[3] = { (double)destData[0], (double)destData[1], (double)destData[2] };
	unsigned char saturatedRGB[3] = { destData[4], destData[5], destData[6] };
	
	// Fill in the bitmap data
	int sizeInBytes = width * height * 4;
	double invMaxVal = 1.0 / ((1 << srcBitmap.bitsPerPixel) - 1);
	bool sixteenBit = (srcBitmap.bitsPerPixel == 16) ? true : false;
	ALWAYS_ASSERT(destBitmap.bytesPerPlane == sizeInBytes);
	for (int pos = 0; pos < width * height; pos++)
	{
		double val;
		if (sixteenBit)
			val = ((unsigned short*)srcData)[pos] * invMaxVal;
		else
			val = ((unsigned char*)srcData)[pos] * invMaxVal;
		if (val == 1.0)
		{
			destData[pos*4] = saturatedRGB[0];
			destData[pos*4+1] = saturatedRGB[1];
			destData[pos*4+2] = saturatedRGB[2];
			destData[pos*4+3] = 255;
		}
		else
		{
			val *= exposureOnScreen;
			val = MAX(val, 0.0);
			val = MIN(val, 1.0);
			destData[pos*4] = (unsigned char)(val * tintRGB[0]);
			destData[pos*4+1] = (unsigned char)(val * tintRGB[1]);
			destData[pos*4+2] = (unsigned char)(val * tintRGB[2]);
			destData[pos*4+3] = 255;
		}
	}
	
	return destBitmap;
}

NSImage *TintImage(NSImage *srcImage, NSColor *tint, NSColor *saturation, double exposureOnScreen)
{
	NSBitmapImageRep *destBitmap = TintBitmap(RawBitmapFromImage(srcImage), tint, saturation, exposureOnScreen);
	NSImage *result = [[NSImage alloc] initWithSize:NSMakeSize(destBitmap.pixelsWide, destBitmap.pixelsHigh)];
	[result addRepresentation:destBitmap];
	return [result autorelease];
}

NSPoint ImageViewCoordToImageCoord(const NSPoint &thePoint, const NSImageView *theView)
{
	/*	Converts from a point in an NSImageView (e.g. a mouse click) to the equivalent pixel coord
		in the image that is being shown in the view.
		This makes (hopefully reasonable!) assumptions about how the NSImageView draws the NSImage.
		Note that we have to allow for whitespace due to aspect ratio mismatches	*/
	double imageAspectRatio = theView.image.size.width / theView.image.size.height;
	double scaleFactor;
	NSPoint viewOrigin;

	if (theView.bounds.size.width / theView.bounds.size.height > imageAspectRatio)
	{
		// Whitespace on left and right
		viewOrigin = NSMakePoint(([theView bounds].size.width - theView.bounds.size.height * imageAspectRatio) / 2.0,
								 0);
		scaleFactor = theView.image.size.height / theView.bounds.size.height;
	}
	else
	{
		// Whitespace above and below
		viewOrigin = NSMakePoint(0,
								 ([theView bounds].size.height - theView.bounds.size.width / imageAspectRatio) / 2.0);
		scaleFactor = theView.image.size.width / theView.bounds.size.width;
	}

	return (thePoint - viewOrigin) * scaleFactor;
}

NSPoint ImageCoordToImageViewCoord(const NSPoint &thePoint, const NSImageView *theView)
{
	/*	Converts from a pixel coord in an image to a screen coordinate in an NSImageView
		that is displaying the image.
		This makes (hopefully reasonable!) assumptions about how the NSImageView draws the NSImage.
		Note that we have to allow for whitespace due to aspect ratio mismatches	*/
	double imageAspectRatio = theView.image.size.width / theView.image.size.height;
	double scaleFactor;
	NSPoint viewOrigin;

	if (theView.bounds.size.width / theView.bounds.size.height > imageAspectRatio)
	{
		// Whitespace on left and right
		viewOrigin = NSMakePoint(([theView bounds].size.width - theView.bounds.size.height * imageAspectRatio) / 2.0,
								 0);
		scaleFactor = theView.image.size.height / theView.bounds.size.height;
	}
	else
	{
		// Whitespace above and below
		viewOrigin = NSMakePoint(0,
								 ([theView bounds].size.height - theView.bounds.size.width / imageAspectRatio) / 2.0);
		scaleFactor = theView.image.size.width / theView.bounds.size.width;
	}

	return viewOrigin + thePoint / scaleFactor;
}

NSPoint FractionalCoordWithinImageView(const NSPoint &thePoint, const NSImageView *theView)
{
	// Note that we have to allow for whitespace due to aspect ratio mismatches
	float imageAspectRatio = theView.image.size.width / theView.image.size.height, imageWidthInView;
	NSPoint viewCentre = { [theView bounds].size.width / 2,
						   [theView bounds].size.height / 2 };
	if (theView.bounds.size.width / theView.bounds.size.height > imageAspectRatio)
	{
		// Whitespace on left and right
		imageWidthInView = imageAspectRatio * theView.bounds.size.height;
	}
	else
	{
		// Whitespace above and below
		imageWidthInView = theView.bounds.size.width;
	}

	NSPoint result = (thePoint - viewCentre) / imageWidthInView;
	return result;
}

double GaussianRandom(void)
{
	static int counter = 2;
	static double randomNumbers[2];
	
	if (counter == 2)
	{
		double x1, x2, w;
		
		do {
			x1 = 2.0 * random_01() - 1.0;
			x2 = 2.0 * random_01() - 1.0;
			w = x1 * x1 + x2 * x2;
		} while ( w >= 1.0 || w == 0.0 );
		
		w = sqrt( (-2.0 * log( w ) ) / w );
		randomNumbers[0] = x1 * w;
		randomNumbers[1] = x2 * w;
		counter = 0;
	}
	counter++;
	return randomNumbers[counter - 1];
}

template<class DataType> void AddNoiseToData(DataType *data, size_t numElements, double level)
{
	int maxVal = (DataType)-1;
	for (size_t i = 0; i < numElements; i++)
	{
		double noise = GaussianRandom() * level;
		int val = int(data[i] + noise);
		data[i] = (DataType)round(LIMIT(val, 0, maxVal));
	}
}

void AddNoiseToImage(NSImage *image, double level)
{
	NSBitmapImageRep *bitmap = RawBitmapFromImage(image);
	if (bitmap.bitsPerPixel == 8)
		AddNoiseToData((unsigned char*)bitmap.bitmapData, bitmap.bytesPerPlane, level);
	else
	{
		ALWAYS_ASSERT(bitmap.bitsPerPixel == 16);
		AddNoiseToData((unsigned short*)bitmap.bitmapData, bitmap.bytesPerPlane / 2, level);
	}
}

double dirCheckTime = 0, contentsTime = 0;
void PrintCompleteFolderPath(NSString *basePath, int indentationLevel, int leadingCharsToSkip)
{
	// Utility function to print out the complete folder path (useful for comparing/merging backup directory contents)
	double t1 = GetTime();
	NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:nil];
	dirContents = [dirContents sortedArrayUsingFunction:alphabeticalOrder context:nil];
	double t2 = GetTime();
	contentsTime += t2 - t1;
	double recursionTime = 0;
	
	if (indentationLevel == 0)
		leadingCharsToSkip = (int)strlen(basePath.UTF8String)+1;     // +1 for the '/' character...
	
	for (NSString *theFilename in dirContents)
	{
		NSString *thePath = [SWF:@"%@/%@", basePath, theFilename];
		// Quick rejection of things we know are not directories
		if (IsImageFile(theFilename) ||
			[theFilename hasSuffix:@".plist"])
		{
			continue;
		}
		
		// Print out text files to make sure we are replicating any notes files
		if ([theFilename hasSuffix:@".txt"] || [theFilename hasSuffix:@".rtf"])
		{
			for (int i = 0; i < indentationLevel; i++)
				printf(" ");
			printf("%s\n", [thePath substringFromIndex:leadingCharsToSkip].UTF8String);
		}
		
		
		// Now do a proper check for directories
		if (IsDirectory([NSURL fileURLWithPath:thePath]))
		{
			double t3 = GetTime();
			for (int i = 0; i < indentationLevel; i++)
				printf(" ");
			printf("%s\n", [thePath substringFromIndex:leadingCharsToSkip].UTF8String);
			//            printf("%s   %lf %lf\n", thePath.UTF8String, contentsTime, dirCheckTime);
			PrintCompleteFolderPath(thePath, indentationLevel+1, leadingCharsToSkip);
			double t4 = GetTime();
			recursionTime += t4 - t3;
		}
	}
	dirCheckTime += GetTime() - t2 - recursionTime;
}

@implementation NSBitmapImageRep (JBitmapExtensions)

+(NSBitmapImageRep *)rgbaBitmap_width:(NSInteger)width height:(NSInteger)height
{
	// Return an rgba bitmap
	// Note that we could let the function choose a value for bytesPerRow,
	// but some of my existing code relies on there being no extra slop at the end of each row,
	// so I specify bytesPerRow explicitly.
	return [[[NSBitmapImageRep alloc]
				initWithBitmapDataPlanes:NULL
							  pixelsWide:width
							  pixelsHigh:height
						   bitsPerSample:8
				         samplesPerPixel:4
				                hasAlpha:YES
				                isPlanar:NO
						  colorSpaceName:NSCalibratedRGBColorSpace
				             bytesPerRow:4*width
							bitsPerPixel:0] autorelease];
}

+(NSBitmapImageRep *)bitmapLike:(NSBitmapImageRep *)rep width:(NSInteger)width height:(NSInteger)height
{
	return [[[NSBitmapImageRep alloc]
				initWithBitmapDataPlanes:NULL
				pixelsWide:width
				pixelsHigh:height
				bitsPerSample:rep.bitsPerSample
				samplesPerPixel:rep.samplesPerPixel
				hasAlpha:rep.hasAlpha
				isPlanar:NO
				colorSpaceName:rep.colorSpaceName
				bytesPerRow:width*((rep.bitsPerSample+7)/8)*rep.samplesPerPixel
				bitsPerPixel:0] autorelease];
}

@end
