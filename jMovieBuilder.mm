#include "jMovieBuilder.cpp"

CVPixelBufferRef FastImageFromNSImage(const NSImage *image, const _NSRect cropRect)
{
    CVPixelBufferRef buffer = NULL;
	
    // config
	NSRect actualCropRect = NSIntersectionRect(cropRect, NSMakeRect(0, 0, image.size.width, image.size.height));
    size_t width = (size_t)actualCropRect.size.width;
    size_t height = (size_t)actualCropRect.size.height;
    size_t bitsPerComponent = 8; // *not* CGImageGetBitsPerComponent(image);
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGBitmapInfo bi = kCGImageAlphaNoneSkipFirst; // *not* CGImageGetBitmapInfo(image);
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
					   [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
	
	
    // create pixel buffer
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, k32ARGBPixelFormat, (CFDictionaryRef)d, &buffer);
    CVPixelBufferLockBaseAddress(buffer, 0);
    void *rasterData = CVPixelBufferGetBaseAddress(buffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
	
    // context to draw in, set to pixel buffer's address
    CGContextRef ctxt = CGBitmapContextCreate(rasterData, width, height, bitsPerComponent, bytesPerRow, cs, bi);
	CGColorSpaceRelease(cs);
    if(ctxt == NULL){
        NSLog(@"could not create context");
        return NULL;
    }
	
    // draw
    NSGraphicsContext *nsctxt = [NSGraphicsContext graphicsContextWithGraphicsPort:ctxt flipped:NO];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsctxt];
    [image drawAtPoint:NSZeroPoint fromRect:cropRect operation:NSCompositeCopy fraction:1.0];
    
	[NSGraphicsContext restoreGraphicsState];
	
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    CFRelease(ctxt);
	
    return buffer;
}

void JBetterMovieBuilder::AddFrame(const NSImage *frameImage, const _NSRect *cropRect, double gain)
{
	CVPixelBufferRef pixelBuffer = FastImageFromNSImage(frameImage, *cropRect);
	
	// Feed the frame to the compression session and then release the CVBuffer
	OSStatus err = ICMCompressionSessionEncodeFrame(compressionSession, pixelBuffer,
										   frameCounter * frameDuration, frameDuration, kICMValidTime_DisplayTimeStampIsValid | kICMValidTime_DisplayDurationIsValid,
										   NULL, NULL, NULL);
	ALWAYS_ASSERT_NOERR(err);
	CVPixelBufferRelease(pixelBuffer);
	frameCounter++;
}
