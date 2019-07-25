/*
	jMovieBuilder.h
 
	Copyright 2010-2015 Jonathan Taylor. All rights reserved.

	Build up a movie file from individual frames that are supplied to this class by the caller in sequence.
    This is still a C++ class in the hope that I can keep it callable from non-objC code,
    but after updates to this code I will probably need to do some tweaks to get this header compiling again when included from pure C++.
 
*/

#ifndef __JMOVIEBUILDER_H__
#define __JMOVIEBUILDER_H__

#include "jMutex.h"
#include "BoundsRect.h"

#if (!HAS_OS_X_GUI)

class NSImage;
class NSRect;

// This first bit of code here is just dummy code to allow things to compile on other platforms, but without any functionality
// TODO: this probably needs updating
class JMovieBuilder
{
  public:
            JMovieBuilder(NSString *destPath, const BoundsRect &inBounds, double inFrameRate, OSStatus *outErr, double compressionFactor, int channelCount);
	void	AddFrame(const NSImage *frameImage, const NSRect *cropRect) { }
};

#else

#include <Quicktime/QuickTime.h>
// Note: do not include AVFoundation.h as it conflicts with win32 typedefs also defined through Ximea camera headers, if we include this here.
// Fortunately we don't need to, we can just give @class prototypes as needed.

@class AVAssetWriter;
@class AVAssetWriterInput;
@class AVAssetWriterInputPixelBufferAdaptor;

class JMovieBuilder
{
  protected:
	int							width;		// dest width
	int							height;		// dest height
	double						desiredFramesPerSecond;
	int							frameCounter;
    
    AVAssetWriter               *videoWriter;
    AVAssetWriterInput          *writerInput;
    AVAssetWriterInputPixelBufferAdaptor *avAdaptor;
    
    void	DoInit(NSURL *destURL, const BoundsRect &bounds, double frameRate, OSStatus *outErr, double compressionFactor, int channelCount);

  public:
            JMovieBuilder(NSString *destPath, const BoundsRect &inBounds, double inFrameRate, OSStatus *outErr, double compressionFactor, int channelCount);
//            JMovieBuilder(const char *destPath, const BoundsRect &bounds, double frameRate, OSStatus *outErr, double compressionFactor, int channelCount);
	virtual ~JMovieBuilder();
	
	int Width(void) { return width; }
	int Height(void) { return height; }
	
/*	I am still working out what switch to use on this next compile-time condition.
	Originally had something like "struct _NSImage" as a placeholder for non-ObjC code, but that doesn't work on Mountain Lion.
	#ifdef __COREFOUNDATION__ doesn't seem to work (defined in some of my apparently c-only files)
	Haven't yet found a specific option that identifies files where NSImage is defined
	Trying just objc switch. I don't ~think~ I've got any C++ code that uses AddFrame...	*/
#ifdef __OBJC__
	void	AddFrame(const NSImage *frameImage, const NSRect *cropRect);
#endif
	void	AddFrame(const CVPixelBufferRef pixelBuffer);
};

#endif

#ifdef __OBJC__
void GetMovieDestinationDetailsUsingSheetOnWindow(NSWindow *sheetOnWindow, void (^handler)(NSInteger result, NSSavePanel *savePanel));
#endif

#if HAS_OS_X_GUI

#include <CoreVideo/CoreVideo.h>
#include "BoundsRect.h"

// This may be obsolete, but I am leaving it in case I use it in any of my old projects!
class MoviePixelBuffer
{
protected:
	CFNumberRef yes;
	CFMutableDictionaryRef d;
public:
	CVPixelBufferRef buffer;
	unsigned char *baseAddr;
	size_t rowBytes;
	
	MoviePixelBuffer(const BoundsRect &inBounds);
	virtual ~MoviePixelBuffer();
};
#endif

#endif
