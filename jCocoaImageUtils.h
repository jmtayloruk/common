/*
 *  jCocoaImageUtils.h
 *  Simple Preview
 *
 *  Created by Jonathan Taylor on 21/02/2011.
 *  Copyright 2011 Durham University. All rights reserved.
 *
 */

NSBitmapImageRep *RawBitmapFromImage(const NSImage *image);
void CopyNSImageToGWorld(const NSImage *image, GWorldPtr gWorldPtr, const CGRect *cropRect, double gain);
NSPoint FractionalCoordWithinImageView(const NSPoint &thePoint, const NSImageView *theView);
NSPoint ImageViewCoordToImageCoord(const NSPoint &thePoint, const NSImageView *theView);
NSPoint ImageCoordToImageViewCoord(const NSPoint &thePoint, const NSImageView *theView);
void BrightenNSImage(NSImage *image, int factor);
