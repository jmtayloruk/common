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
@class ImageSequenceForChannel;
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
	JAlias *_link;
	double _computerTimestamp, _cameraTimestamp;
	int _frameNumber;
	NSDictionary *_metadata;
	ImageSequenceForChannel *sequence;
}
+(id)timestampedImageFromFile:(NSString *)path forSequence:(ImageSequenceForChannel*)inSequence;
-(id)initFromFile:(NSString *)path forSequence:(ImageSequenceForChannel*)inSequence;
-(NSImage *)image;

@property (nonatomic, readwrite) double computerTimestamp;
@property (nonatomic, readwrite) double cameraTimestamp;
@property (nonatomic, readonly, retain) NSString *path;
@property (nonatomic, readwrite, retain) JAlias *link;
@property (nonatomic, readonly) NSString *fileNameNoPath;
@property (nonatomic, readwrite, retain) NSDictionary *metadata;
@property (nonatomic, readwrite) int frameNumber;
@property (nonatomic, readonly) bool isBrightfield;

@end

#include <map>
typedef std::map<int, FrameInfo> FIM;

@interface ImageSequenceForChannel : NSObject
{
	NSURL *_sourceFolderURL;
	bool _flipH, _flipV, _syncFramesOnly;
	int _colour, _overrideFrameIndex;
	JPoint2 *_offset, *_crosshairs;
	float _scale, _exposure;
	bool _showCrosshairs;
	bool interestedInCrosshairsInformation;
	
	NSMutableArray *timestampedImages;
	FIM frameInfoMap;
	GUIMovieBuilder *parent;
	bool _warnedMissingFile;
}

-(id)initForParent:(GUIMovieBuilder*)inParent;
-(int)count;
-(TimestampedImage *)timestampedImageAtIndex:(NSUInteger)index;
-(TimestampedImage*)currentFrameObject;
-(bool)infoForFrameNumber:(int)f into:(FrameInfo *)fi;
-(int/*remaining count*/)excludeOutsideRangeFrom:(int)firstIndex to:(int)lastIndex;
-(NSRect)destRectForDrawingImage:(NSImage *)srcImage;

@property (nonatomic, readwrite) bool flipH;
@property (nonatomic, readwrite) bool flipV;
@property (nonatomic, readwrite) bool syncFramesOnly;
@property (nonatomic, readwrite) int colour;
@property (nonatomic, readwrite, retain) JPoint2 *offset;
@property (nonatomic, readwrite) float scale;
@property (nonatomic, readwrite) float exposure;
@property (nonatomic, readwrite, copy) NSURL *sourceFolderURL;
@property (nonatomic, readonly) NSString *filenameString;
@property (nonatomic, readonly) NSString *popupMenuString;
@property (nonatomic, readwrite) bool showCrosshairs;
@property (nonatomic, readwrite, retain) JPoint2 *crosshairs;
@property (readwrite) bool displayImageMayNeedChanging;
@property (readwrite) int overrideFrameIndex;

@end


typedef NSComparisonResult (^computerTimestampComparatorType)(TimestampedImage *, TimestampedImage *);
typedef NSComparisonResult (^cameraTimestampComparatorType)(TimestampedImage *, TimestampedImage *);

enum
{
	kLayoutAllOverlaid = 0,
	kLayoutBrightfieldAdjacent,
	kLayoutAllAdjacent
};

@interface GUIMovieBuilder : JWindowController
{
	int _currentFrame, _startFrame, _endFrame;
	int _framerateToUse, _layoutBehaviour;
	bool _includeReverseFrames, _maskEnabled;
	int _encodingQuality;
	JRect *_mask;
	
	// Array holding the various image sequences to use in the movie
	NSMutableArray *_sequences;
	// TODO: This is a pointer to one of the sequences, but I suspect we must manually update it if the relevant sequence is deleted from the GUI
	MAZeroingWeakRef *_sequenceToUseForTimings;
	
	NSImage *_currentFrameImage;
	IBOutlet MovieFrameView *frameView;
	IBOutlet NSArrayController *_sequenceArrayController;
	CocoaProgressWindow *_useExternalProgressObject;
	
	bool simulatingPathControlClick;
	IBOutlet NSPathControl *folderSelectPopup;
}

+(id)runSession;
+(id)runBackgroundSession;
-(id)initAndRunBackgroundSession:(NSString*)nibName;
-(id)initAndRunSession:(NSString*)nibName;
-(ImageSequenceForChannel *)addSequenceUsingURL:(NSURL*)url;
-(ImageSequenceForChannel *)sequence:(NSUInteger)i;
-(void)sequenceChanged:(ImageSequenceForChannel*)sequence;
-(IBAction)addSequence:(id)sender;
-(IBAction)removeCurrentSequence:(id)sender;
-(IBAction)setStartFrameToCurrentFrame:(id)sender;
-(IBAction)setEndFrameToCurrentFrame:(id)sender;
-(void)setCurrentFrameToCameraTimestamp:(double)time;
-(IBAction)setMaskFromMarkedRect:(id)sender;
-(IBAction)accept:(id)sender;
-(IBAction)cancel:(id)sender;
-(IBAction)deleteExcludedFrames:(id)sender;
-(void)createFileAtPath:(NSString*)path;
-(NSImage *)currentFrameImage;
-(void)setScaledBitmapContext:(NSBitmapImageRep *)theBitmap withOrigin:(NSPoint)origin;
-(NSBitmapImageRep *)newRenderedFrameBitmap;
-(void)updateCurrentFrameImage;
-(IBAction)revealFilesInFinder:(id)sender;
-(void)blockWhileBusy;

@property (nonatomic, readwrite) int currentFrame;
@property (nonatomic, readwrite) int startFrame;
@property (nonatomic, readwrite) int endFrame;
@property (nonatomic, readwrite) int framerateToUse;
@property (nonatomic, readonly) int numFrames;
@property (nonatomic, readonly) NSRect frameRect;
@property (nonatomic, readwrite) bool includeReverseFrames;
@property (nonatomic, readwrite) int encodingQuality;
@property (nonatomic, readwrite) int layoutBehaviour;
@property (nonatomic, readwrite, retain) JRect *mask;
@property (nonatomic, readwrite) bool maskEnabled;
@property (nonatomic, readonly) NSString *imageTooltip;
@property (nonatomic, readonly) NSString *timestampString;
@property (nonatomic, readwrite, retain) CocoaProgressWindow *useExternalProgressObject;
@property (readwrite) double timepointMS;
@property (readwrite) bool displayImageMayNeedChanging;
@property (nonatomic, readwrite, retain) NSMutableArray *sequences;
@property (readwrite, retain) ImageSequenceForChannel *sequenceToUseForTimings;
@property (readonly) TimestampedImage *currentFrameObjectToUseForTimings;
@property (readonly, retain) NSArrayController *sequenceArrayController;

@end
