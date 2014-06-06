//
//  GUIMovieBuilder.h
//  Simple Preview
//
//  Created by Jonathan Taylor on 29/09/2010.
//  Copyright 2010 Durham University. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FrameProtocol.h"
#import "CameraFrameView.h"

@class GUIMovieBuilder;
@class CocoaProgressWindow;
@class JAlias;

enum
{
	kRedChannel = 1,
	kGreenChannel = 2,
	kBlueChannel = 4
};

@interface TimestampedImage : NSObject
{
	NSImage *image;
	JAlias *_link;
	double _timestamp, _psTimestamp;
	int sequence, _frameNumber;
	NSDictionary *_metadata;
	GUIMovieBuilder *parent;
}
+(id)timestampedImageFromFile:(NSString *)path forSequence:(int)inSequence parent:(GUIMovieBuilder*)inParent;
-(id)initFromFile:(NSString *)path forSequence:(int)inSequence parent:(GUIMovieBuilder*)inParent;
-(NSImage *)image;

@property (nonatomic, readwrite) double timestamp;
@property (nonatomic, readwrite) double psTimestamp;
@property (nonatomic, readonly, retain) NSString *path;
@property (nonatomic, readwrite, retain) JAlias *link;
@property (nonatomic, readonly) NSString *fileNameNoPath;
@property (nonatomic, readwrite, retain) NSDictionary *metadata;
@property (nonatomic, readwrite) int frameNumber;

@end
	
typedef NSComparisonResult (^timestampComparatorType)(TimestampedImage *, TimestampedImage *);
typedef NSComparisonResult (^psTimestampComparatorType)(TimestampedImage *, TimestampedImage *);

#include <map>
typedef std::map<int, FrameInfo> FIM;

@interface GUIMovieBuilder : JWindowController
{
	int _currentFrame, startFrame, endFrame;
	int framerateToUse;
	bool hasSecondSequence, includeReverseFrames, maskEnabled, sequence2IsAdjacent, showCrosshairs;
	bool flipSequence1H, flipSequence1V, flipSequence2H, flipSequence2V, syncFramesOnly1, syncFramesOnly2;
	int sequence1Colour, sequence2Colour;
	int timingsFromSequence, offsetForSequence;
	int encodingQuality;
	NSPoint offset, crosshairs, additionalProgrammaticOffset1;
	bool haveSetCrosshairs;
	NSRect mask;
	float offsetImageScale, sequence1Exposure, sequence2Exposure;
	NSURL *sequence1URL, *sequence2URL;
	NSMutableArray *sequence1, *sequence2;
	NSImage *currentFrameImage;
	IBOutlet NSPathControl *sequence1Popup;
	IBOutlet NSPathControl *sequence2Popup;
	IBOutlet MovieFrameView *frameView;
	bool _warnedMissingFile;
	CocoaProgressWindow *_useExternalProgressObject;
	FIM frameInfoMap;
}

+(id)runSession;
+(id)runBackgroundSession;
-(id)initAndRunBackgroundSession:(NSString*)nibName;
-(id)initAndRunSession:(NSString*)nibName;
-(TimestampedImage*)currentFrameObject1;
-(TimestampedImage*)currentFrameObject2;
-(IBAction)setStartFrameToCurrentFrame:(id)sender;
-(IBAction)setEndFrameToCurrentFrame:(id)sender;
-(void)setCurrentFrameToPSTime:(double)time;
-(IBAction)setMaskFromMarkedRect:(id)sender;
-(IBAction)accept:(id)sender;
-(IBAction)cancel:(id)sender;
-(IBAction)deleteExcludedFrames:(id)sender;
-(void)createFileAtPath:(NSString*)path;
-(NSImage *)currentFrameImage;
-(void)setScaledBitmapContext:(NSBitmapImageRep *)theBitmap;
-(NSBitmapImageRep *)newRenderedFrameBitmap;
-(void)updateCurrentFrameImage;
-(void)numFramesChangedImplicitly;
-(IBAction)revealFile1InFinder:(id)sender;
-(IBAction)revealFile2InFinder:(id)sender;
-(void)blockWhileBusy;
-(bool)infoForFrameNumber:(int)f into:(FrameInfo *)fi;

@property (nonatomic, readwrite) int currentFrame;
@property (nonatomic, readwrite) int startFrame;
@property (nonatomic, readwrite) int endFrame;
@property (nonatomic, readwrite) int framerateToUse;
@property (nonatomic, readonly) int numFrames;
@property (nonatomic, readonly) NSSize frameSize;
@property (nonatomic, readwrite) bool hasSecondSequence;
@property (nonatomic, readwrite) bool sequence2IsAdjacent;
@property (nonatomic, readwrite) bool flipSequence1H;
@property (nonatomic, readwrite) bool flipSequence1V;
@property (nonatomic, readwrite) bool flipSequence2H;
@property (nonatomic, readwrite) bool flipSequence2V;
@property (nonatomic, readwrite) bool syncFramesOnly1;
@property (nonatomic, readwrite) bool syncFramesOnly2;
@property (nonatomic, readwrite) bool includeReverseFrames;
@property (nonatomic, readwrite) int sequence1Colour;
@property (nonatomic, readwrite) int sequence2Colour;
@property (nonatomic, readwrite) float sequence1Exposure;
@property (nonatomic, readwrite) float sequence2Exposure;
@property (nonatomic, readwrite) int timingsFromSequence;
@property (nonatomic, readwrite) int encodingQuality;
@property (nonatomic, readwrite) int offsetForSequence;
@property (nonatomic, readwrite) float offsetX;
@property (nonatomic, readwrite) float offsetY;
@property (nonatomic, readwrite) bool showCrosshairs;
@property (nonatomic, readwrite) float crosshairsX;
@property (nonatomic, readwrite) float crosshairsY;
@property (nonatomic, readwrite) float maskX;
@property (nonatomic, readwrite) float maskY;
@property (nonatomic, readwrite) float maskW;
@property (nonatomic, readwrite) float maskH;
@property (nonatomic, readwrite) bool maskEnabled;
@property (nonatomic, readwrite) float offsetImageScale;
@property (nonatomic, readwrite, copy) NSURL* sequence1URL;
@property (nonatomic, readwrite, copy) NSURL* sequence2URL;
@property (readwrite) bool warnedMissingFile;
@property (nonatomic, readonly) NSString *imageTooltip;
@property (nonatomic, readonly) NSString *timestampString;
@property (nonatomic, readonly) NSString *filename1String;
@property (nonatomic, readonly) NSString *filename2String;
@property (nonatomic, readonly) BOOL revealFile1InFinderEnabled;
@property (nonatomic, readonly) BOOL revealFile2InFinderEnabled;
@property (nonatomic, readwrite, retain) CocoaProgressWindow *useExternalProgressObject;
@property (readwrite) double timepointMS;
@property (readonly) bool displayImageMayNeedChanging;


@end
