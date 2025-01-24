/*
 *  jCocoaImageUtils.h
 *
 *  Copyright 2011-2015 Jonathan Taylor. All rights reserved.
 *
 *	Utility functions for working with images under Cocoa
 *
 */

#ifndef __J_COCOA_IMAGE_UTILS_H__
#define __J_COCOA_IMAGE_UTILS_H__ 1

#import "BoundsRect.h"

class Tinter
{
protected:
    int _maxVal;
    NSColor *_tint;
    NSColor *_saturation;
    double _exposureOnScreen;
public:
    std::vector<uint32_t> valLookup;
    
    Tinter(NSBitmapImageRep *scratchBitmap, int maxVal, NSColor *tint, NSColor *saturation, double exposureOnScreen);
    bool MatchesSettings(int maxVal, NSColor *tint, NSColor *saturation, double exposureOnScreen);
};

NSArray *AllRawBitmapsFromImage(const NSImage *image);
NSBitmapImageRep *RawBitmapFromImage(const NSImage *image);
NSBitmapImageRep *RawBitmapFromImagePath(NSString *imagePath);
NSBitmapImageRep *CropBitmap(NSBitmapImageRep *originalBitmap, BoundsRect cropRect);
NSImage *NSImageFromTiffFile(NSString *tiffPath);
bool /*sizes matched*/ PopulateArrayFromBitmap(const NSBitmapImageRep *bitmap, double *destArray, int destWidth, int destHeight, int downsampleFactor, bool assertOnSizeMismatch);
void CopyNSImageToGWorld(const NSImage *image, GWorldPtr gWorldPtr, const CGRect *cropRect, double gain);
NSPoint FractionalCoordWithinImageView(const NSPoint &thePoint, const NSImageView *theView);
NSPoint ImageViewCoordToImageCoord(const NSPoint &thePoint, const NSImageView *theView);
NSPoint ImageCoordToImageViewCoord(const NSPoint &thePoint, const NSImageView *theView);
void BrightenNSImage(NSImage *image, int factor);
NSBitmapImageRep *TintBitmap(NSBitmapImageRep *destBitmap, NSBitmapImageRep *srcBitmap, Tinter *tinter);
void AddNoiseToImage(NSImage *image, double level);

@interface NSBitmapImageRep (JBitmapExtensions)
	+(NSBitmapImageRep *)rgbaBitmap_width:(NSInteger)width height:(NSInteger)height;
	+(NSBitmapImageRep *)bitmapLike:(NSBitmapImageRep *)rep width:(NSInteger)width height:(NSInteger)height;
@end

#endif
