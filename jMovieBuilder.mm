//
//  jMovieBuilder.mm
//
//	Copyright 2010-2015 Jonathan Taylor. All rights reserved.
//
//	Cocoa/NSImage interface for jMovieBuilder.
//  Correct sequence of calls for AVAsset determined from:
//  https://stackoverflow.com/questions/3741323/how-do-i-export-uiimage-array-as-a-movie?rq=1
//  and http://codethink.no-ip.org/wordpress/archives/673
//

#include "jMovieBuilder.h"
#import "jCocoaImageUtils.h"
#include <AVFoundation/AVFoundation.h>

void GetMovieDestinationDetailsUsingSheetOnWindow(NSWindow *sheetOnWindow, void (^handler)(NSInteger result, NSSavePanel *savePanel))
{
	NSSavePanel *spanel = [NSSavePanel savePanel];
	// Could use the following to set the starting directory for the save panel:
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

#if HAS_OS_X_GUI

CVPixelBufferRef FastImageFromNSImage(const NSImage *image, const NSRect cropRect)
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

JMovieBuilder::JMovieBuilder(NSString *destPath, const BoundsRect &inBounds, double inFrameRate, OSStatus *outErr, double compressionFactor, int channelCount)
{
    DoInit(PathToURL(destPath), inBounds, inFrameRate, outErr, compressionFactor, channelCount);
}

void JMovieBuilder::DoInit(NSURL *destURL, const BoundsRect &bounds, double frameRate, OSStatus *outErr, double compressionFactor, int channelCount)
{
    width = bounds.w;
    height = bounds.h;
    desiredFramesPerSecond = frameRate;
    frameCounter = 0;
    
    /*  Create a new movie file.
        Somewhat to my surprise, AVAssetWriter refuses to overwrite existing files (error comes when we write first frame to file),
        so we have to delete any existing file manually.    */
    if ([[NSFileManager defaultManager] fileExistsAtPath:destURL.path])
    {
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:destURL.path error:nil];
        CHECK(success);
    }
    NSError *error = nil;
    videoWriter = [[AVAssetWriter alloc] initWithURL:destURL
                                            fileType:AVFileTypeQuickTimeMovie
                                               error:&error];
    if (error != nil)
    {
        if (outErr != nil)
        {
            *outErr = error.code;
            return;
        }
        else
            ALWAYS_ASSERT_NOERR(error.code);
    }
    else
        *outErr = noErr;
    ALWAYS_ASSERT(videoWriter != nil);
    
    int desiredBitrate = int(width * height * channelCount * 8/*bits/byte*/ * frameRate / compressionFactor);
    printf("Specifying bitrate %.3fMbps\n", desiredBitrate/1e6);
    NSDictionary *compression = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithInt:desiredBitrate], AVVideoAverageBitRateKey,
                                 nil];          // TODO: I could consider incuding the key kVTCompressionPropertyKey_AllowFrameReordering
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   compression, AVVideoCompressionPropertiesKey,
                                   [NSNumber numberWithInt:width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:height], AVVideoHeightKey,
                                   nil];
    writerInput = [[AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                      outputSettings:videoSettings] retain];
    
    ALWAYS_ASSERT(writerInput != nil);
    // I don't know what the realtime flag actually does, but it seems to make it less likely not to be ready
    // to accept more data (especially when I am streaming brightfield live). Maybe the compressor runs at higher priority,
    // or does less demanding compression...?
    // Somebody asked on the internet, and didn't get a helpful answer!
    writerInput.expectsMediaDataInRealTime = YES;
    
    NSDictionary* bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    avAdaptor = [[AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                                                  sourcePixelBufferAttributes:bufferAttributes] retain];
    ALWAYS_ASSERT([videoWriter canAddInput:writerInput]);
    [videoWriter addInput:writerInput];
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
}

JMovieBuilder::~JMovieBuilder()
{
    // TODO: test this with zero frames and see what happens
    [writerInput markAsFinished];
    
    // TODO: This next call is deprecated - "may take a long time", and should be replaced with a completion handler if we care about when the file is finished.
    // However, in practice it doesn't seem to be causing my any problems (at present...) to call this.
    [videoWriter finishWriting];

    if (videoWriter != nil)
        [videoWriter release];
    if (writerInput != nil)
        [writerInput release];
}

void JMovieBuilder::AddFrame(const NSImage *frameImage, const NSRect *cropRect)
{
    AddFrame(FastImageFromNSImage(frameImage, *cropRect));
}

void JMovieBuilder::AddFrame(const CVPixelBufferRef pixelBuffer)
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    /*  Although the header docs imply it should be possible to continue when readyForMoreMediaData==false,
        in practice it leads to an exception. So, we have to cope with it.
        (Note the header comment "When using a push-style buffer source..." - I think that's pretty much
         what I'm doing, but I still get an exception).
        TODO: the headers indicate a better solution involving block callbacks, which I could consider.
        That said, I don't think there's any harm in blocking this thread for a while until things
        have sorted themselves out. */
    while (!writerInput.readyForMoreMediaData)
        [NSThread sleepForTimeInterval:0.05];
    bool ok = [avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:CMTimeMake(frameCounter, desiredFramesPerSecond)];
    if (!ok)
        NSLog(@"Error from appendPixelBuffer: %d %d %@\n", (int)videoWriter.status, (int)videoWriter.error.code, videoWriter.error.description);
    ALWAYS_ASSERT(ok);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CVPixelBufferRelease(pixelBuffer);
    frameCounter++;
}

// TODO: do I actually use these for anything? I don't in Spim GUI, but I might in other projects...?
MoviePixelBuffer::MoviePixelBuffer(const BoundsRect &bounds)
{
    // config
    int flag = true;
    yes = CFNumberCreate(NULL, kCFNumberIntType, &flag );
    d = CFDictionaryCreateMutable(NULL, 2, NULL, NULL);
    CFDictionaryAddValue(d, kCVPixelBufferCGImageCompatibilityKey, yes);
    CFDictionaryAddValue(d, kCVPixelBufferCGBitmapContextCompatibilityKey, yes);
    
    // create pixel buffer
    buffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, bounds.w, bounds.h, k32ARGBPixelFormat, (CFDictionaryRef)d, &buffer);
    CVPixelBufferLockBaseAddress(buffer, 0);
    baseAddr = (unsigned char *)CVPixelBufferGetBaseAddress(buffer);
    rowBytes = CVPixelBufferGetBytesPerRow(buffer);
}

MoviePixelBuffer::~MoviePixelBuffer()
{
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    CVPixelBufferRelease(buffer);
    CFRelease(d);
    CFRelease(yes);
}

#endif
