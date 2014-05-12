/*	Module: JMovieBuilder.cpp

	Create a movie file based on a simulation replay. Uses QuickTime, and is currently
	OS X-only (though should be possible to port to other operating systems on which
	QuickTime is available.

	Usage:
	TODO: These usage instructions are obsolete. I should update instructions and also remove obsolete code.
	There's quite a lot of old code around that is obsolete given how OS X has moved on so much since I
	first wrote this.

	{
		JMovieBuilder movie = (movieType, codecType, moviePath, &boundsRect, frameRate);
		
		for (frameNum = 1; frameNum <= numFrames; frameNum++)
		{
			movie.BeginMovieFrame();
			// (Insert code here to draw the frame)
			movie->EndMovieFrame();
		}
		// JMovieBuilder destructor does the required cleanup automatically when it goes out of scope
	}
	
	n.b. some of the AVI code based on freely available code written by Mark Asbach, Institute of Communications Engineering, RWTH Aachen University
	n.b. JBetterMovieBuilder is very heavily based on the Apple sample code CaptureAndCompressIPBMovie.c
 
*/
	

#include "jMovieBuilder.h"
#include "jUtils.h"
#include <algorithm>

#if HAS_OS_X_GUI

BaseMovieBuilder::BaseMovieBuilder(const BoundsRect &bounds)
{
}

#if 1
// This is obsolete code, but I'm leaving it in for now
static StringPtr ConvertCToPascalString2 (const char *theString, Str255 pStr)
{
	snprintf((char *)pStr + 1, 255, "%s", theString);
	pStr[0] = (unsigned char)(MIN((size_t)255, strlen(theString)));
	return(pStr);
}

void BaseMovieBuilder::GetDestinationDetails(const char *inFileName, Handle *outputMovieDataRef, OSType *outputMovieDataRefType)
{
	// Note that there is a partner function GetDestinationDetailsUsingSheetOnWindow that implements a modern sheet-based version of this
	ALWAYS_ASSERT(0);
#if 0
	OSStatus err = noErr;
	*outputMovieDataRef = NULL;
	*outputMovieDataRefType = 0;
	
	if (inFileName == NULL)
	{
		// Prompt the user for an output file.
		NavDialogCreationOptions navOptions;
		navOptions.version = kNavDialogCreationOptionsVersion;
		navOptions.optionFlags = 0;
		NavDialogRef navDialog = NULL;
		NavReplyRecord navReply;
		navReply.version = kNavReplyRecordVersion;
		AEDesc actualDesc = { 0, 0 };
		FSRef parentFSRef;
		
		err = NavGetDefaultDialogCreationOptions( &navOptions );
		ALWAYS_ASSERT_NOERR(err);
		navOptions.windowTitle = CFSTR("Save Captured Movie As...");
		navOptions.message = CFSTR("Pick where to save the captured and compressed movie.");
		navOptions.saveFileName = CFSTR("captured.mov");
		navOptions.modality = kWindowModalityAppModal;
		
		err = NavCreatePutFileDialog( &navOptions, MovieFileType, 'TVOD', NULL, NULL, &navDialog );
		ALWAYS_ASSERT_NOERR(err);
		
		err = NavDialogRun( navDialog );
		ALWAYS_ASSERT_NOERR(err);
		
		if (NavDialogGetUserAction( navDialog ) != kNavUserActionSaveAs)
			return;	// With null dataRef
		
		err = NavDialogGetReply( navDialog, &navReply );
		ALWAYS_ASSERT_NOERR(err);
		
		err = AECoerceDesc( &navReply.selection, typeFSRef, &actualDesc );
		ALWAYS_ASSERT_NOERR(err);

		err = AEGetDescData( &actualDesc, &parentFSRef, sizeof( FSRef ) );
		ALWAYS_ASSERT_NOERR(err);
		
		err = QTNewDataReferenceFromFSRefCFString( &parentFSRef, navReply.saveFileName, 0, outputMovieDataRef, outputMovieDataRefType );
		ALWAYS_ASSERT_NOERR(err);
		
		NavDisposeReply( &navReply );
		NavDialogDispose( navDialog );
		AEDisposeDesc( &actualDesc );
	}
	else
	{
		FSSpec fileSpec;
		Str255 fileName;
		err = FSMakeFSSpec(0, 0, ConvertCToPascalString2(inFileName, fileName), &fileSpec);
		if ((err != noErr) && (err != fnfErr))
		{
			fprintf(stderr, "FSMakeFSSpec: error %d with filename %.100s\n", (int)err, inFileName);
			ALWAYS_ASSERT_NOERR(err);
		}
		err =	QTNewDataReferenceFromFSSpec(&fileSpec, 0, outputMovieDataRef, outputMovieDataRefType);
		ALWAYS_ASSERT_NOERR(err);
	}
#endif
}
#endif

JBetterMovieBuilder::JBetterMovieBuilder(OSType inCodec, const char *inFileName, const BoundsRect &inBounds, float inFrameRate, OSStatus *outErr, int inQuality) : BaseMovieBuilder(inBounds)
{
	Handle outputMovieDataRef;
	OSType outputMovieDataRefType;

	// I have commented out the definition of this function because I want to upgrade to more modern Cocoa APIs
	// See GetDestinationDetailsUsingSheetOnWindow for a modern sheet-based implementation, though I may
	// want an equivalent dialog version too...
	GetDestinationDetails(inFileName, &outputMovieDataRef, &outputMovieDataRefType);
//	ALWAYS_ASSERT(0);
//	assert(0);

	DoInit(inCodec, inBounds, inFrameRate, outputMovieDataRef, outputMovieDataRefType, outErr, inQuality);
	DisposeHandle(outputMovieDataRef);
}

JBetterMovieBuilder::JBetterMovieBuilder(OSType inCodec, Handle outputMovieDataRef, OSType outputMovieDataRefType, const BoundsRect &inBounds, float inFrameRate, OSStatus *outErr, int inQuality) : BaseMovieBuilder(inBounds)
{
	DoInit(inCodec, inBounds, inFrameRate, outputMovieDataRef, outputMovieDataRefType, outErr, inQuality);
}

void JBetterMovieBuilder::DoInit(OSType inCodec, const BoundsRect &bounds, float frameRate, Handle outputMovieDataRef, OSType outputMovieDataRefType, OSStatus *outErr, int inQuality)
{
	width = bounds.w;
	height = bounds.h;
	codecType = inCodec;
	desiredFramesPerSecond = frameRate;
	timeScale = (TimeScale)(desiredFramesPerSecond * 100);
	frameDuration = (TimeScale)(timeScale / desiredFramesPerSecond);
	verbose = false;
	outputVideoMedia = NULL;
	quality = inQuality;
	frameCounter = 0;
	
	// Create a new movie file. 
	OSStatus err = CreateMovieStorage(outputMovieDataRef, outputMovieDataRefType, 'TVOD', 0, 
										createMovieFileDeleteCurFile, &outputMovieDataHandler, &outputMovie);
	if (outErr == NULL)
		ALWAYS_ASSERT_NOERR(err);
	else 
	{
		*outErr = err;
		if (err != noErr)
			return;		// Most likely is that file is open, which should be reported to the user
	}
	
	CreateCompressionSession(&compressionSession);
								
	// Make a CFDictionary that describes the pixel buffers we will use for the compression session
	// We want them to be the right dimensions and pixel format; we want them to be compatible with 
	// CGBitmapContext and CGImage.  
	pixelFormat = k32ARGBPixelFormat;
	pixelBufferAttributes = CFDictionaryCreateMutable( NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks );
	ALWAYS_ASSERT(pixelBufferAttributes != NULL);
	CFNumberRef number = CFNumberCreate( NULL, kCFNumberIntType, &width );
	CFDictionaryAddValue( pixelBufferAttributes, kCVPixelBufferWidthKey, number );
	CFRelease( number );
	number = CFNumberCreate( NULL, kCFNumberIntType, &height );
	CFDictionaryAddValue( pixelBufferAttributes, kCVPixelBufferHeightKey, number );
	CFRelease( number );
	number = CFNumberCreate( NULL, kCFNumberSInt32Type, &pixelFormat );
	CFDictionaryAddValue( pixelBufferAttributes, kCVPixelBufferPixelFormatTypeKey, number );
	CFRelease( number );
	CFDictionaryAddValue( pixelBufferAttributes, kCVPixelBufferCGBitmapContextCompatibilityKey, kCFBooleanTrue );
	CFDictionaryAddValue( pixelBufferAttributes, kCVPixelBufferCGImageCompatibilityKey, kCFBooleanTrue );								
}

JBetterMovieBuilder::~JBetterMovieBuilder()
{
	if (frameCounter)
	{
		OSStatus result = ICMCompressionSessionCompleteFrames(compressionSession, true, 0, 0);
		ALWAYS_ASSERT_NOERR(result);
		ICMCompressionSessionRelease(compressionSession);
	}
	CFRelease(pixelBufferAttributes);
	
	if (outputMovie)
		FinishOutputMovie();
}

void JBetterMovieBuilder::CreateCompressionSession(ICMCompressionSessionRef *compressionSessionOut)
{
	OSStatus err = noErr;
	ICMEncodedFrameOutputRecord encodedFrameOutputRecord;
	encodedFrameOutputRecord.encodedFrameOutputCallback = NULL;
	ICMCompressionSessionOptionsRef sessionOptions = NULL;
	
	err = ICMCompressionSessionOptionsCreate( NULL, &sessionOptions );
	ALWAYS_ASSERT_NOERR(err);
	
	// We must set these flags to enable P and B frames.
	err = ICMCompressionSessionOptionsSetAllowTemporalCompression( sessionOptions, true );
	ALWAYS_ASSERT_NOERR(err);
	err = ICMCompressionSessionOptionsSetAllowFrameReordering( sessionOptions, true );
	ALWAYS_ASSERT_NOERR(err);
	
	// Set the maximum key frame interval, also known as the key frame rate.
	err = ICMCompressionSessionOptionsSetMaxKeyFrameInterval( sessionOptions, 30 );
	ALWAYS_ASSERT_NOERR(err);

	// We need durations when we store frames.
	err = ICMCompressionSessionOptionsSetDurationsNeeded( sessionOptions, true );
	ALWAYS_ASSERT_NOERR(err);

#if 0
	// Set the average data rate.
	err = ICMCompressionSessionOptionsSetProperty( sessionOptions, 
				kQTPropertyClass_ICMCompressionSessionOptions,
				kICMCompressionSessionOptionsPropertyID_AverageDataRate,
				sizeof( averageDataRate ),
				&averageDataRate );
	ALWAYS_ASSERT_NOERR(err);
#else
	// Set the compression quality.
	err = ICMCompressionSessionOptionsSetProperty( sessionOptions, 
				kQTPropertyClass_ICMCompressionSessionOptions,
				kICMCompressionSessionOptionsPropertyID_Quality,
				sizeof( quality ),
				&quality );
	ALWAYS_ASSERT_NOERR(err);
#endif
	
	encodedFrameOutputRecord.encodedFrameOutputCallback = WriteEncodedFrameToMovie;
	encodedFrameOutputRecord.encodedFrameOutputRefCon = this;
	encodedFrameOutputRecord.frameDataAllocator = NULL;

	err = ICMCompressionSessionCreate( NULL, width, height, codecType, timeScale,
			sessionOptions, NULL, &encodedFrameOutputRecord, compressionSessionOut );
	ALWAYS_ASSERT_NOERR(err);
	
	ICMCompressionSessionOptionsRelease( sessionOptions );
}

// Create a video track and media to hold encoded frames.
// This is called the first time we get an encoded frame back from the compression session.
void JBetterMovieBuilder::CreateVideoMedia( 
							ImageDescriptionHandle imageDesc,
							TimeScale timescale )
{
	OSStatus err = noErr;
	Fixed trackWidth, trackHeight;
	Track outputTrack = NULL;
	
	err = ICMImageDescriptionGetProperty( 
			imageDesc,
			kQTPropertyClass_ImageDescription, 
			kICMImageDescriptionPropertyID_ClassicTrackWidth,
			sizeof( trackWidth ),
			&trackWidth,
			NULL );
	ALWAYS_ASSERT_NOERR(err);
	
	err = ICMImageDescriptionGetProperty( 
			imageDesc,
			kQTPropertyClass_ImageDescription, 
			kICMImageDescriptionPropertyID_ClassicTrackHeight,
			sizeof( trackHeight ),
			&trackHeight,
			NULL );
	ALWAYS_ASSERT_NOERR(err);
	
	if( verbose ) {
		printf( "creating %g x %g track\n", Fix2X(trackWidth), Fix2X(trackHeight) );
	}
	
	outputTrack = NewMovieTrack( outputMovie, trackWidth, trackHeight, 0 );
	ALWAYS_ASSERT_NOERR(GetMoviesError());
	
	outputVideoMedia = NewTrackMedia( outputTrack, VideoMediaType, timescale, 0, 0 );
	ALWAYS_ASSERT_NOERR(GetMoviesError());
	
	err = BeginMediaEdits( outputVideoMedia );
	ALWAYS_ASSERT_NOERR(err);
	didBeginVideoMediaEdits = true;
}

void JBetterMovieBuilder::ReleaseBackingStorage(void *releaseRefCon, const void *baseAddress)
{
	delete[] (char *)baseAddress;
}

#if 0//def __CARBON__
Rect JBetterMovieBuilder::BeginMovieFrame(GWorldPtr *destPort)
{
	// Change the current graphics port to the GWorld
	GetGWorld(&oldPort, &oldGDeviceH);
	SetGWorld(theGWorld, nil);
	Rect bounds;
	GetPortBounds(theGWorld, &bounds);
	if (destPort != NULL)
		*destPort = theGWorld;
		
	return bounds;
}

void JBetterMovieBuilder::EndMovieFrame(void)
{
	// Unfortunately the ICM code wants to passed a CVPixelBuffer.
	// I suppose we'll have to copy our data into that...
	// On the plus side this would make it very easy to also support CGContext drawing for movie frame drawing
	// (see CaptureAndCompressIPBMovie sample code for how to shoehorn the CVPixelBuffer into a CGContext...)
	// We need to provide backing storage because the PixMap will soon have the next frame rendered into it.
	CVPixelBufferRef pixelBuffer;
	PixMapHandle thePixMap = GetPortPixMap(theGWorld);
	size_t pixMapSizeInBytes = height * GetPixRowBytes(thePixMap);
	char *backingStorage = new char[pixMapSizeInBytes];
	memcpy(backingStorage, GetPixBaseAddr(thePixMap), pixMapSizeInBytes);
	OSStatus err = CVPixelBufferCreateWithBytes(CFAllocatorGetDefault(),
												width, height,
												pixelFormat,
												backingStorage,
												GetPixRowBytes(thePixMap),
												ReleaseBackingStorage,
												NULL,
												pixelBufferAttributes,
												&pixelBuffer);
	ALWAYS_ASSERT_NOERR(err);
						
	// Feed the frame to the compression session and then release the CVBuffer
	err = ICMCompressionSessionEncodeFrame(compressionSession, pixelBuffer,
					frameCounter * frameDuration, frameDuration, kICMValidTime_DisplayTimeStampIsValid | kICMValidTime_DisplayDurationIsValid,
					NULL, NULL, NULL);
	ALWAYS_ASSERT_NOERR(err);
	CVPixelBufferRelease(pixelBuffer);
	frameCounter++;

	SetGWorld (oldPort, oldGDeviceH);
}
#elif 0
void JBetterMovieBuilder::AddFrame(const NSImage *frameImage, const _NSRect *cropRect, double gain)
{
	CVPixelBufferRef pixelBuffer = FastImageFromNSImage(frameImage);
	
	// Feed the frame to the compression session and then release the CVBuffer
	OSStatus err = ICMCompressionSessionEncodeFrame(compressionSession, pixelBuffer,
										   frameCounter * frameDuration, frameDuration, kICMValidTime_DisplayTimeStampIsValid | kICMValidTime_DisplayDurationIsValid,
										   NULL, NULL, NULL);
	ALWAYS_ASSERT_NOERR(err);
	CVPixelBufferRelease(pixelBuffer);
	frameCounter++;
}
#endif

#if CARBON
CVPixelBufferRef FastImageFromNSImage(const NSImage *image)
{
    CVPixelBufferRef buffer = NULL;
	
    // config
    size_t width = (size_t)[image size].width;
    size_t height = (size_t)[image size].height;
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
    [image drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
    
	[NSGraphicsContext restoreGraphicsState];
	
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    CFRelease(ctxt);
	
    return buffer;
}

#endif

void JBetterMovieBuilder::AddFrame(const CVPixelBufferRef pixelBuffer)
{
	// Feed the frame to the compression session
	OSStatus err = ICMCompressionSessionEncodeFrame(compressionSession, pixelBuffer,
										   frameCounter * frameDuration, frameDuration, kICMValidTime_DisplayTimeStampIsValid | kICMValidTime_DisplayDurationIsValid,
										   NULL, NULL, NULL);
	ALWAYS_ASSERT_NOERR(err);
	frameCounter++;
}

// This is the tracking callback function for the compression session.
// Write the encoded frame to the movie file.
// Note that this function adds each sample separately; better chunking can be achieved
// by flattening the movie after it is finished, or by grouping samples, writing them in 
// groups to the data reference manually, and using AddSampleTableToMedia.
OSStatus JBetterMovieBuilder::WriteEncodedFrameToMovie(void *encodedFrameOutputRefCon, 
															   ICMCompressionSessionRef session, 
															   OSStatus err,
															   ICMEncodedFrameRef encodedFrame,
															   void *reserved )
{
	ALWAYS_ASSERT(err == noErr);
	JBetterMovieBuilder *us = (JBetterMovieBuilder *)encodedFrameOutputRefCon;
	return us->WriteEncodedFrameToMovie2(session, encodedFrame);
}

OSStatus JBetterMovieBuilder::WriteEncodedFrameToMovie2(ICMCompressionSessionRef session, 
														ICMEncodedFrameRef encodedFrame)
{
	ImageDescriptionHandle imageDesc = NULL;
	TimeValue64 decodeDuration;
	
	OSStatus err = ICMEncodedFrameGetImageDescription( encodedFrame, &imageDesc );
	ALWAYS_ASSERT_NOERR(err);
	
	if(!outputVideoMedia)
		CreateVideoMedia( imageDesc, ICMEncodedFrameGetTimeScale( encodedFrame ));
	
	decodeDuration = ICMEncodedFrameGetDecodeDuration( encodedFrame );
	if( decodeDuration == 0 ) 
	{
		// You can't add zero-duration samples to a media.  If you try you'll just get invalidDuration back.
		// Because we don't tell the ICM what the source frame durations are,
		// the ICM calculates frame durations using the gaps between timestamps.
		// It can't do that for the final frame because it doesn't know the "next timestamp"
		// (because in this example we don't pass a "final timestamp" to ICMCompressionSessionCompleteFrames).
		// So we'll give the final frame our minimum frame duration.
		decodeDuration = frameDuration * ICMEncodedFrameGetTimeScale( encodedFrame ) / timeScale;
	}
	
	if (verbose)
	{
		printf( "adding %ld byte sample: decode duration %ld, display offset %ld, flags %#lx", 
				(long)ICMEncodedFrameGetDataSize( encodedFrame ),
				(long)decodeDuration, 
				(long)ICMEncodedFrameGetDisplayOffset( encodedFrame ),
				(long)ICMEncodedFrameGetMediaSampleFlags( encodedFrame ) );
		if( true )
		{
			ICMValidTimeFlags validTimeFlags = ICMEncodedFrameGetValidTimeFlags( encodedFrame );
			if( kICMValidTime_DecodeTimeStampIsValid & validTimeFlags )
				printf( ", decode time stamp %ld", (long)ICMEncodedFrameGetDecodeTimeStamp( encodedFrame ) );
			if( kICMValidTime_DisplayTimeStampIsValid & validTimeFlags )
				printf( ", display time stamp %ld", (long)ICMEncodedFrameGetDisplayTimeStamp( encodedFrame ) );
		}
		printf( "\n" );
	}
	
	err = AddMediaSample2(
		outputVideoMedia,
		ICMEncodedFrameGetDataPtr( encodedFrame ),
		ICMEncodedFrameGetDataSize( encodedFrame ),
		decodeDuration,
		ICMEncodedFrameGetDisplayOffset( encodedFrame ),
		(SampleDescriptionHandle)imageDesc,
		1,
		ICMEncodedFrameGetMediaSampleFlags( encodedFrame ),
		NULL );
	ALWAYS_ASSERT_NOERR(err);
	
	// Note: if you don't need to intercept any values, you could equivalently call:
	// err = AddMediaSampleFromEncodedFrame( outputVideoMedia, encodedFrame, NULL );
	// if( err ) {
	//     fprintf( stderr, "AddMediaSampleFromEncodedFrame() failed (%d)\n", (int)err );
	//     goto bail;
	// }

	return noErr;
}


void JBetterMovieBuilder::FinishOutputMovie(void)
{
	OSStatus err = noErr;
	Track videoTrack = NULL;
	
	if (didBeginVideoMediaEdits)
	{
		// End the media sample-adding session.
		err = EndMediaEdits(outputVideoMedia);
		ALWAYS_ASSERT_NOERR(err);
	}	
	
	// Make sure things are extra neat.
	ExtendMediaDecodeDurationToDisplayEndTime(outputVideoMedia, NULL );
	
	// Insert the stuff we added into the track, at the end.
	videoTrack = GetMediaTrack(outputVideoMedia);
	err = InsertMediaIntoTrack(videoTrack, 
			GetTrackDuration(videoTrack), 
			0, GetMediaDisplayDuration(outputVideoMedia), // NOTE: use this instead of GetMediaDuration
			fixed1);
	ALWAYS_ASSERT_NOERR(err);
	
	// Write the movie header to the file.
	err = AddMovieToStorage(outputMovie, outputMovieDataHandler);
	ALWAYS_ASSERT_NOERR(err);
	
	CloseMovieStorage(outputMovieDataHandler);
	outputMovieDataHandler = 0;
	
	DisposeMovie(outputMovie);
}

#endif

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
