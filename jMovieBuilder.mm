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
#include <climits>

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

static OSStatus MovieWriterError(NSError *error)
{
    if (error != nil)
    {
        NSLog(@"Movie writer error: %@", error);
        return (OSStatus)error.code;
    }
    return ioErr;
}

CVPixelBufferRef FastImageFromNSImage(const NSImage *image, const NSRect cropRect)
{
    CVPixelBufferRef buffer = NULL;
	
    // config
	NSRect actualCropRect = NSIntersectionRect(cropRect, NSMakeRect(0, 0, image.size.width, image.size.height));
    size_t width = (size_t)actualCropRect.size.width;
    size_t height = (size_t)actualCropRect.size.height;
    size_t bitsPerComponent = 8; // *not* CGImageGetBitsPerComponent(image);
    CGBitmapInfo bi = kCGImageAlphaNoneSkipFirst; // *not* CGImageGetBitmapInfo(image);
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
					   [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
	
	
    // create pixel buffer
    if (CVPixelBufferCreate(kCFAllocatorDefault, width, height, k32ARGBPixelFormat, (CFDictionaryRef)d, &buffer) != kCVReturnSuccess)
        return NULL;
    if (CVPixelBufferLockBaseAddress(buffer, 0) != kCVReturnSuccess)
    {
        CVPixelBufferRelease(buffer);
        return NULL;
    }
    void *rasterData = CVPixelBufferGetBaseAddress(buffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
	
    // context to draw in, set to pixel buffer's address
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGContextRef ctxt = CGBitmapContextCreate(rasterData, width, height, bitsPerComponent, bytesPerRow, cs, bi);
	CGColorSpaceRelease(cs);
    if(ctxt == NULL){
        NSLog(@"could not create context");
        CVPixelBufferUnlockBaseAddress(buffer, 0);
        CVPixelBufferRelease(buffer);
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
    const OSStatus status = destPath.length == 0 ? paramErr :
        DoInit(PathToURL(destPath), inBounds, inFrameRate, compressionFactor, channelCount);
    if (outErr != nullptr)
        *outErr = status;
    else
        ALWAYS_ASSERT_NOERR(status);
}

JMovieBuilder::JMovieBuilder(const char *destPath, const BoundsRect &inBounds, double inFrameRate, OSStatus *outErr, double compressionFactor, int channelCount)
    : JMovieBuilder([SWF:@"%s", destPath], inBounds, inFrameRate, outErr, compressionFactor, channelCount)
{
}

OSStatus JMovieBuilder::DoInit(NSURL *destURL, const BoundsRect &bounds, double frameRate, double compressionFactor, int channelCount)
{
    width = bounds.w;
    height = bounds.h;
    desiredFramesPerSecond = frameRate;
    frameCounter = 0;
    const double bitrate = double(width) * height * channelCount * 8/*bits/byte*/ * frameRate / compressionFactor;
    if (width <= 0 || height <= 0 || channelCount <= 0 || compressionFactor <= 0 ||
        !((frameRate * 1000 >= 1) && (frameRate * 1000 <= INT_MAX)) ||
        !((bitrate >= 1) && (bitrate <= INT_MAX)))
    {
        return paramErr;
    }
    
    /*  Create a new movie file.
        Somewhat to my surprise, AVAssetWriter refuses to overwrite existing files (error comes when we write first frame to file),
        so we have to delete any existing file manually.    */
    if ([[NSFileManager defaultManager] fileExistsAtPath:destURL.path])
    {
        NSError *err = nil;
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:destURL.path error:&err];
        if (!CHECK(success))
            return MovieWriterError(err);
    }
    NSError *error = nil;
    videoWriter = [[AVAssetWriter alloc] initWithURL:destURL
                                            fileType:AVFileTypeQuickTimeMovie
                                               error:&error];
    if (videoWriter == nil)
        return MovieWriterError(error);
    
    int desiredBitrate = int(bitrate);
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
    if (![videoWriter canApplyOutputSettings:videoSettings forMediaType:AVMediaTypeVideo])
        return paramErr;
    writerInput = [[AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                      outputSettings:videoSettings] retain];
    
    if (writerInput == nil || ![videoWriter canAddInput:writerInput])
        return MovieWriterError(videoWriter.error);
    // I don't know what the realtime flag actually does, but it seems to make it less likely not to be ready
    // to accept more data (especially when I am streaming brightfield live). Maybe the compressor runs at higher priority,
    // or does less demanding compression...?
    // Somebody asked on the internet, and didn't get a helpful answer!
    writerInput.expectsMediaDataInRealTime = YES;
    
    NSDictionary* bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    avAdaptor = [[AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                                                  sourcePixelBufferAttributes:bufferAttributes] retain];
    [videoWriter addInput:writerInput];
    
    if (![videoWriter startWriting])
        return MovieWriterError(videoWriter.error);
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    return noErr;
}

JMovieBuilder::~JMovieBuilder()
{
    if (videoWriter.status == AVAssetWriterStatusWriting)
        Finish();
    [avAdaptor release];
    [writerInput release];
    [videoWriter release];
}

OSStatus JMovieBuilder::Finish()
{
    if (videoWriter.status == AVAssetWriterStatusCompleted)
        return noErr;
    if (videoWriter.status != AVAssetWriterStatusWriting)
        return MovieWriterError(videoWriter.error);
    if (frameCounter == 0)
    {
        // Cancel an empty export instead of asking the writer to finalize it.
        [videoWriter cancelWriting];
        return noErr;
    }
    [writerInput markAsFinished];

    // TODO: This next call is deprecated - "may take a long time", and should be replaced with a completion handler if we care about when the file is finished.
    // However, in practice it doesn't seem to be causing my any problems (at present...) to call this.
    if ([videoWriter finishWriting])
        return noErr;
    const OSStatus error = MovieWriterError(videoWriter.error);
    if (videoWriter.status == AVAssetWriterStatusWriting)
        [videoWriter cancelWriting];
    return error;
}

OSStatus JMovieBuilder::AddFrame(const NSImage *frameImage, const NSRect *cropRect)
{
    if (frameImage == nil || cropRect == nullptr)
        return paramErr;
    return AddFrame(FastImageFromNSImage(frameImage, *cropRect));
}

OSStatus JMovieBuilder::AddFrame(const CVPixelBufferRef pixelBuffer)
{
    if (pixelBuffer == NULL)
        return paramErr;

    /*  Although the header docs imply it should be possible to continue when readyForMoreMediaData==false,
        in practice it leads to an exception. So, we have to cope with it.
        (Note the header comment "When using a push-style buffer source..." - I think that's pretty much
         what I'm doing, but I still get an exception).
        TODO: the headers indicate a better solution involving block callbacks, which I could consider.
        That said, I don't think there's any harm in blocking this thread for a while until things
        have sorted themselves out. */
    while (videoWriter.status == AVAssetWriterStatusWriting && !writerInput.readyForMoreMediaData)
        [NSThread sleepForTimeInterval:0.05];

    // Note that CMTimeMake requires an integer timescale.
    // The *1000 multipliers mean we end up with a very close approximation to whatever fps we were asked to run at
    const CMTime time = CMTimeMake(int64_t(frameCounter) * 1000, int(desiredFramesPerSecond * 1000));
    const bool ok = videoWriter.status == AVAssetWriterStatusWriting &&
        [avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time];
    CVPixelBufferRelease(pixelBuffer);
    if (!ok)
        return MovieWriterError(videoWriter.error);
    frameCounter++;
    return noErr;
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
