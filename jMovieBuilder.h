#ifndef __JMOVIEBUILDER_H__
#define __JMOVIEBUILDER_H__

#include "jMutex.h"
#include "BoundsRect.h"

#if !HAS_OS_X_GUI

// Code not implemented except on OS X

class BaseMovieBuilder
{
  public:
					BaseMovieBuilder(const BoundsRect &bounds) { ALWAYS_ASSERT(0); }
	virtual			~BaseMovieBuilder() { }
//	static void		GetDestinationDetails(const char *inFileName, void *outputMovieDataRef, OSType *outputMovieDataRefType) { ALWAYS_ASSERT(0); }
};

class JMovieBuilder : public BaseMovieBuilder
{
  public:
			JMovieBuilder(OSType type, OSType inCodec, const char *fileName, const BoundsRect &bounds, float frameRate = 60) : BaseMovieBuilder(bounds) { }
};

class JBetterMovieBuilder : public BaseMovieBuilder
{
  public:
			JBetterMovieBuilder(OSType inCodec, const char *inFileName, const BoundsRect &bounds, float frameRate, int32_t *outErr, int inQuality = 0) : BaseMovieBuilder(bounds) { }
			JBetterMovieBuilder(OSType inCodec, char** outputMovieDataRef, OSType outputMovieDataRefType, const BoundsRect &bounds, float frameRate, int32_t *outErr, int inQuality = 0) : BaseMovieBuilder(bounds) { }
};

#else

#include <Quicktime/QuickTime.h>

class BaseMovieBuilder
{
  protected:
	GWorldPtr theGWorld;
	CGrafPtr oldPort;
	GDHandle oldGDeviceH;
	OSType	compressionTypeToUse;
  public:
					BaseMovieBuilder(const BoundsRect &bounds);
	virtual			~BaseMovieBuilder() { }
	static void		GetDestinationDetails(const char *inFileName, Handle *outputMovieDataRef, OSType *outputMovieDataRefType);
//	virtual Rect	BeginMovieFrame(GWorldPtr *destPort = NULL) = 0;
//	virtual void	EndMovieFrame(void) = 0;
};

#if 0
class JMovieBuilder : public BaseMovieBuilder
{
  protected:
	ImageDescriptionHandle  imageDescription; 
	MovieExportComponent	ci, compressionComponent; 
	long                    trackID; 
	Handle					myDataRef;
	char					cFilename[1024];
	OSType					movieType;

	pthread_t				workerThread;
	JMutex					commsMutex;
	pthread_cond_t			dataReadySignal;
	long					lastTrackWritten, currentTrackReady, frameToGenerate;
	
  public:
			JMovieBuilder(OSType type, OSType inCodec, const char *inFileName, const Rect *bounds, float frameRate);
	virtual ~JMovieBuilder();
	
	OSErr	GetVideoProperty(long trackID, OSType propertyType, void * propertyValue);
	OSErr	GetVideoData(MovieExportGetDataParams * params);
	void	WorkThread(void);
	virtual void	EndMovieFrame(void);

	static pascal OSErr getVideoPropertyProc(void *, long, OSType, void *);
	static pascal OSErr getVideoDataProc(void *, MovieExportGetDataParams *);
	static void *WorkThreadCallback(void *ref);
};
#endif

class JBetterMovieBuilder : public BaseMovieBuilder
{
  protected:
	int							width;		// dest width
	int							height;		// dest height
	CodecType					codecType;	// codec
	int							quality;
	ICMCompressionSessionRef	compressionSession; // compresses frames
	Movie						outputMovie; // movie file for storing compressed frames
	Media						outputVideoMedia; // media for our video track in the movie
	DataHandler					outputMovieDataHandler; // storage for movie header
	Boolean						didBeginVideoMediaEdits;
	Boolean						verbose;
    TimeScale					timeScale;
	float						desiredFramesPerSecond;
	TimeValue					frameDuration;
	CFMutableDictionaryRef		pixelBufferAttributes;
	OSType						pixelFormat;
	int							frameCounter;
	
	void	DoInit(OSType inCodec, const BoundsRect &bounds, float frameRate, Handle outputMovieDataRef, OSType outputMovieDataRefType, OSStatus *outErr, int inQuality);
	void	SetUpOutputMovie(const char *inFileName);
	void	CreateCompressionSession(ICMCompressionSessionRef *compressionSessionOut);
	void	CreateVideoMedia(ImageDescriptionHandle imageDesc, TimeScale timescale );
	static OSStatus WriteEncodedFrameToMovie(void *encodedFrameOutputRefCon, 
											   ICMCompressionSessionRef session, 
											   OSStatus err,
											   ICMEncodedFrameRef encodedFrame,
											   void *reserved );
	OSStatus WriteEncodedFrameToMovie2(ICMCompressionSessionRef session, ICMEncodedFrameRef encodedFrame);
	static void ReleaseBackingStorage(void *releaseRefCon, const void *baseAddress);
	void	FinishOutputMovie(void);
	
  public:
			JBetterMovieBuilder(OSType inCodec, const char *inFileName, const BoundsRect &bounds, float frameRate, OSStatus *outErr, int inQuality = codecLosslessQuality);
			JBetterMovieBuilder(OSType inCodec, Handle outputMovieDataRef, OSType outputMovieDataRefType, const BoundsRect &bounds, float frameRate, OSStatus *outErr, int inQuality = codecLosslessQuality);
	virtual ~JBetterMovieBuilder();
	
	int Width(void) { return width; }
	int Height(void) { return height; }
	
#if 0//def __CARBON__
	Rect	BeginMovieFrame(GWorldPtr *destPort = NULL);
	void	EndMovieFrame(void);
#endif
/*	I am still working out what switch to use on this next one. 
	Originally had something like "struct _NSImage" as a placeholder for non-ObjC code, but that doesn't work on Mountain Lion.
	#ifdef __COREFOUNDATION__ doesn't seem to work (defined in some of my apparently c-only files)
	Haven't yet found a specific option that identifies files where NSImage define
	Trying just objc switch. I don't ~think~ I've got any C++ code that uses AddFrame...	*/
#ifdef __OBJC__
	void	AddFrame(const NSImage *frameImage, const NSRect *cropRect, double gain = 1.0);
#endif
	void	AddFrame(const CVPixelBufferRef pixelBuffer);
};

#endif


#if OS_X

#include <CoreVideo/CoreVideo.h>
#include "BoundsRect.h"

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
