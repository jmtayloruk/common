#import <Cocoa/Cocoa.h>
#include "jAssert.h"
#import "jCocoaImageUtils.h"
#import "NSPointArithmetic.h"

#ifndef SWF
	#define SWF NSString stringWithFormat
#endif

NSBitmapImageRep *RawBitmapFromImage(const NSImage *image)
{
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
			ALWAYS_ASSERT(result == nil);	// If we fail this then there are two different bitmap representations stored
											// (need to decide what to do then...)
			result = (NSBitmapImageRep*)imageRepresentation;
		}
	}
	
	if (result == nil)
	{
		// It is possible to end up with a representation of type NSCGImageSnapshotRep under some circumstances
		// In that case I have to explicitly draw it into a bitmap
		[image lockFocus];
		result = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, [image size].width, [image size].height)] autorelease];
		[image unlockFocus];
	}
	
	ALWAYS_ASSERT(result != nil);		// If we fail this then there was no bitmap representation stored (vector image?)
	return [[result retain] autorelease];
}

NSImage *AllocNSImageFromFile(const char *path)
{
	return [[NSImage alloc] initWithContentsOfFile:[SWF:@"%s", path]];
}

#if 0
void GetNaturalBoundsForImageFile(const char *path, Rect *outBounds)
{
	NSImage *image = [[NSImage alloc] initWithContentsOfFile:[SWF:@"%s", path]];
	NSBitmapImageRep *rep = RawBitmapFromImage(image);
	SetRect(outBounds, 0, 0, rep.pixelsWide, rep.pixelsHigh);
	[image release];
}
#endif

void ReleaseNSImage(NSImage *image)
{
//	printf("Releasing - will be %d\n", image.retainCount-1);
	[image release];
}

void BrightenNSImage(NSImage *image, int factor)
{
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

#if CARBON
void CopyNSImageToGWorld(const NSImage *image, GWorldPtr gWorldPtr, const NSRect *inCropRect, double gain)
{
    PixMapHandle 	pixMapHandle;
    Ptr 		pixBaseAddr;

	NSRect noCropRect = NSMakeRect(0, 0, image.size.width, image.size.height);
	NSRect cropRect;
	if (inCropRect != nil)
		cropRect = *inCropRect;
	else
		cropRect = noCropRect;

    // Lock the pixels
    pixMapHandle = GetGWorldPixMap(gWorldPtr);
    LockPixels (pixMapHandle);
    pixBaseAddr = GetPixBaseAddr(pixMapHandle);
	Rect gWorldRect;
	GetPortBounds(gWorldPtr, &gWorldRect);
	int gWorldWidth = gWorldRect.right - gWorldRect.left;
	int gWorldHeight = gWorldRect.bottom - gWorldRect.top;

	/*	Note that the call to bitmapData allocates memory that may need a custom autorelease pool
		to ensure it is released before memory fills up. Unfortunately we can't do that here, because
		it will only be released when the *PARENT IMAGE* is released. It is therefore up to the caller
		to create a pool as and when required.		*/

	NSBitmapImageRep *bitmapRep = RawBitmapFromImage(image);
	unsigned char * bitMapDataPtr = [bitmapRep bitmapData];

	if ((bitMapDataPtr != nil) && (pixBaseAddr != nil))
	{
		int i,j;
		int pixmapRowBytes = GetPixRowBytes(pixMapHandle);
		float coordFlippedYOrigin = image.size.height - cropRect.origin.y - cropRect.size.height;
		ALWAYS_ASSERT(cropRect.origin.x >= 0);
		ALWAYS_ASSERT(coordFlippedYOrigin >= 0);
		// MISSING IMAGES: tolerate crop rects (and implicitly source images) that don't match
		// the dimensions of the target gWorld. This shouldn't normally happen, though		
		CHECK((int)cropRect.size.width == gWorldWidth);
		CHECK((int)cropRect.size.height == gWorldHeight);
		cropRect.size.width = MIN(cropRect.size.width, gWorldWidth);
		cropRect.size.height = MIN(cropRect.size.height, gWorldHeight);

		for (i = 0; i < gWorldHeight; i++)
		{
			unsigned char *dst = (unsigned char *)pixBaseAddr + i * pixmapRowBytes;
			
			unsigned char *charSrc = bitMapDataPtr 
										+ int(i + coordFlippedYOrigin) * bitmapRep.bytesPerRow
										+ int(cropRect.origin.x) * (bitmapRep.bitsPerPixel / 8);
			unsigned short *shortSrc = (unsigned short *)charSrc;
			if (bitmapRep.bitsPerPixel == 8)
			{
				ALWAYS_ASSERT(bitmapRep.samplesPerPixel == 1);
				for (j = 0; j < gWorldWidth; j++)
				{
					unsigned char val = *charSrc++;
					*dst++ = 0;		// Alpha
					*dst++ = val;	// Red component
					*dst++ = val;	// Green component
					*dst++ = val;	// Blue component           
				}
			}
			else if (bitmapRep.bitsPerPixel == 16)
			{
				ALWAYS_ASSERT(bitmapRep.samplesPerPixel == 1);
				for (j = 0; j < gWorldWidth; j++)
				{
					unsigned int val = (unsigned int)((*shortSrc++) * gain / 255);
					val = MIN(val, (unsigned int)255);
//							ALWAYS_ASSERT(val < 256);
					*dst++ = 0;		// Alpha
					*dst++ = val;	// Red component
					*dst++ = val;	// Green component
					*dst++ = val;	// Blue component           
				}
			}
			else if ((bitmapRep.bitsPerPixel == 24) || (bitmapRep.bitsPerPixel == 32))
			{
//				printf("spp %d\n", bitmapRep.samplesPerPixel);
				ALWAYS_ASSERT((bitmapRep.samplesPerPixel == 3) || (bitmapRep.samplesPerPixel == 4));
				ALWAYS_ASSERT(bitmapRep.numberOfPlanes == 1);
				int spp = bitmapRep.samplesPerPixel;

				for (j = 0; j < gWorldWidth; j++)
				{
					*dst++ = 0;	// Alpha
#if 1
					*dst++ = charSrc[0];	// Red component
					*dst++ = charSrc[1];	// Green component
					*dst++ = charSrc[2];	// Blue component      
#else
					// Convert to B&W
					unsigned char val = (unsigned char)((charSrc[0] + charSrc[1] + charSrc[2]) / 3.0);
					*dst++ = val;
					*dst++ = val;
					*dst++ = val;
#endif
					charSrc += spp;
				}
			}
			else
			{
				printf("Unknown bpp (%d) spp (%d)\n", bitmapRep.bitsPerPixel, bitmapRep.samplesPerPixel);
				ALWAYS_ASSERT(0);					
			}
		}
	}

    UnlockPixels(pixMapHandle);
}
#endif

NSPoint ImageViewCoordToImageCoord(const NSPoint &thePoint, const NSImageView *theView)
{
	// Note that we have to allow for whitespace due to aspect ratio mismatches
	float imageAspectRatio = theView.image.size.width / theView.image.size.height;
	float scaleFactor;
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
	// Note that we have to allow for whitespace due to aspect ratio mismatches
	float imageAspectRatio = theView.image.size.width / theView.image.size.height;
	float scaleFactor;
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
	printf("Fractional coord for point %f %f\n", thePoint.x, thePoint.y);
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
	printf(" %f %f\n", result.x, result.y);
	return result;
}
