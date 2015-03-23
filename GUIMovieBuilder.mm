//
//  GUIMovieBuilder.mm
//  Simple Preview
//
//  Created by Jonathan Taylor on 29/09/2010.
//  Copyright 2010 Durham University. All rights reserved.
//

#import "GUIMovieBuilder.h"
#import "JMovieBuilder.h"
#import "jCocoaImageUtils.h"
#include "CocoaProgressWindow.h"
#import "jCocoaMovieBuilder.h"

const int qualityMapping[] = { codecLowQuality, codecNormalQuality, codecHighQuality, codecLosslessQuality, codecLosslessQuality, codecLosslessQuality };
const int codecMapping[] = { kH264CodecType, kH264CodecType, kH264CodecType, kH264CodecType, kAnimationCodecType, kRawCodecType };

NSRect MultiplyRect(const NSRect a, double n)
{
	return NSMakeRect(int(a.origin.x * n), int(a.origin.y * n), int(a.size.width * n), int(a.size.height * n));
}

NSComparisonResult DiffToNSComparisonResult(int i) { return MAX(MIN(i, 1), -1); }
NSComparisonResult DiffToNSComparisonResult(double i) { return (i < 0) ? -1 : ((i > 0) ? 1 : 0); }

computerTimestampComparatorType timestampComparator = ^(TimestampedImage *objA, TimestampedImage *objB)
{
	return DiffToNSComparisonResult(objA.computerTimestamp - objB.computerTimestamp);
};

cameraTimestampComparatorType cameraTimestampComparator = ^(TimestampedImage *objA, TimestampedImage *objB)
{
	return DiffToNSComparisonResult(objA.cameraTimestamp - objB.cameraTimestamp);
};

dispatch_queue_t movieExportQueue = dispatch_queue_create("movie export queue", NULL);

// Temporary upscaling for better image quality (needs to be integrated into the GUI...)
float upscalingFactor = 1.0;

struct ImageDrawingInfo
{
	float offsetX, offsetY, imageScaling;
	bool flipH, flipV, showCrosshairs;
	NSPoint crosshairs;	
};

@implementation TimestampedImage

+(id)timestampedImageFromFile:(NSString *)path forSequence:(ImageSequenceForChannel*)inSequence
{
	return [[[TimestampedImage alloc] initFromFile:path forSequence:inSequence] autorelease];
}

+(id)dummyTimestampedImageWithCameraTime:(double)time
{
	// This is NOT a complete object, and will crash if many methods are called.
	// It is intended for use in timestamp comparisons.
	TimestampedImage *result = [[[TimestampedImage alloc] initFromFile:nil forSequence:nil] autorelease];
	result.cameraTimestamp = time;
	return result;
}

-(id)initFromFile:(NSString *)path forSequence:(ImageSequenceForChannel*)inSequence
{
	if (!(self = [super init]))
		return nil;
	
	sequence = inSequence;
	
	if (path == nil)
		return self;	// We are just allocating a dummy object without a genuine image file backing it
	
	/*	We mustn't allocate the image because we are liable to run out of memory
	 For the moment I load every time [self image] is called, and rely on OS disk cache
	 to keep things reasonably efficient. I could consider using NSCache instead,
	 but this works ok for now, for what is not really a priority feature of the program	*/
	self.link = [JAlias aliasForPath:path];

	// Identify the XML filename
	NSString *xmlPath = MetadataPathFromImagePath(path);
	if (xmlPath != nil)
	{
		/*	We need to identify a timestamp for the frame in order to be able to cross-compare with frames in a second sequence
			Unfortunately because the QI does not supply timestamps we pretty much have to go with the OS time received etc timestamps
			rather than the times reported by the camera.
			This incidentally makes it awkward to compare the movie builder view against gnuplot prediction graphs for emulated runs,
			because the OS time received for the original frames is not used in the emulation process...	*/
		
		NSMutableDictionary *metadata = [NSMutableDictionary dictionaryWithContentsOfFile:xmlPath];
		id timestampObj = [metadata objectForKey:@"timestamp"];
		if (timestampObj != nil)
			self.cameraTimestamp = [timestampObj doubleValue];
	
		self.frameNumber = [[metadata objectForKey:@"frame_number"] intValue];

		self.metadata = metadata;
		id timeReceived = [metadata objectForKey:@"time_received"];
		if (timeReceived != nil)
			self.computerTimestamp = [timeReceived doubleValue];
		
		// Probably means this is the QI camera, which doesn't give us timestamps for some reason (bug reported to QI...)
		if (self.computerTimestamp == 0.0)
			self.computerTimestamp = [[metadata objectForKey:@"time_processing_started"] doubleValue];

		// We record timebase_start_uptime to get a universally consistent timestamp
		double timebase_start = [[metadata objectForKey:@"timebase_start_uptime"] doubleValue];
		self.computerTimestamp += timebase_start;
	}

	return self;
}

-(void)dealloc
{	
	self.link = nil;
	self.metadata = nil;
	[super dealloc];
}

-(NSImage *)image
{
	/*	At the moment I just rely on the OS disk cache to keep things resident in memory wherever possible
		Using the line below is somewhat inefficient in that doing the actual *processing* of parsing the
		TIFF file is done whenever somebody wants to access the image.
		I don't expect this accessor to be called massively often, though, so this is probably fairly reasonable.
		One thing that could potentially be improved if it turned out to be annoying would be to prospectively
		"touch" images that we think the user is about to look at (e.g. the next ones in the images sequence)	*/
//	printf("Returning image from file %s\n", [path UTF8String]);
	NSImage *imageFromDisk = [[NSImage alloc] initWithContentsOfFile:self.path];
	if (imageFromDisk == nil)
	{
		printf("File not found. Trying again\n");
		imageFromDisk = [[NSImage alloc] initWithContentsOfFile:self.path];
		if (imageFromDisk == nil)
			printf("Retry failed\n");
		else
			printf("Retry succeeded\n");
	}
	
	// Check for missing files. This could happen if the file is deleted out from underneath us.
	// If that is the case, we return nil and the caller can warn the user if the wish
	if (imageFromDisk == nil)
		return nil;
	
	int width = int(imageFromDisk.size.width);
	int height = int(imageFromDisk.size.height);
	
	/*	Having loaded the raw image we now need to convert it into an ARGB image with any scaling,
		colouring etc applied as specified by the user. We need to do this by hand, but it makes
		things a lot tidier (and probably faster) if we do that here and then stick to conventional
		drawing APIs for composing the actual movie frames	*/
	NSBitmapImageRep *argbBitmap = [[NSBitmapImageRep alloc]
										initWithBitmapDataPlanes:NULL		// Bitmap allocates and releases the necessary memory for us
										pixelsWide:width
										pixelsHigh:height
										bitsPerSample:8
										samplesPerPixel:4
										hasAlpha:YES
										isPlanar:NO
										colorSpaceName:NSCalibratedRGBColorSpace
										bytesPerRow:0
										bitsPerPixel:0];
		
	const int channelMasks[] = { kRedChannel | kGreenChannel | kBlueChannel, kRedChannel, kGreenChannel, kBlueChannel };
	ALWAYS_ASSERT((sequence.colour >= 0) && (sequence.colour < 4));
	int channelMaskToUse = channelMasks[sequence.colour];
	float exposure = sequence.exposure;
	bool flipH = sequence.flipH;
	bool flipV = sequence.flipV;

	NSBitmapImageRep *srcBitmap = RawBitmapFromImage(imageFromDisk);
	int srcBytesPerPixel = srcBitmap.bitsPerPixel / 8;
	unsigned char *srcData = srcBitmap.bitmapData;
	int srcRowBytes = srcBitmap.bytesPerRow;
	unsigned char *destData = argbBitmap.bitmapData;
	int destRowBytes = argbBitmap.bytesPerRow;
	if ((srcBytesPerPixel == 3) || (srcBytesPerPixel == 4))
		channelMaskToUse = kRedChannel | kGreenChannel | kBlueChannel;
    
	if (srcData != nil)
	{
		dispatch_apply(height, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
		^(size_t i){
			int y = flipV ? height - 1 - i : i;
			unsigned char *src = srcData + y * srcRowBytes;
			unsigned char *dst = destData + i * destRowBytes;
#if 1
			// Special-case processing to speed things up in simple cases
			// (not actually sure how much difference this makes - prob limited by speed of reading from disk)
			if ((exposure == 1.0) && (channelMaskToUse == 0x7) && (srcBytesPerPixel == 1))
			{
				for (int j = 0; j < width; j++, dst += 4)
				{
					bool ok;
					int x = flipH ? width - j : j;
					unsigned char val = src[x*srcBytesPerPixel + 0];
					dst[0] = val;
					dst[1] = val;
					dst[2] = val;
					dst[3] = 255;
				}
			}
			else
#endif
				for (int j = 0; j < width; j++, dst += 4)
				{
					float vals[3];
					int x = flipH ? width - j : j;
					if ((srcBytesPerPixel == 3) || (srcBytesPerPixel == 4))
					{
						/*	I don't expect to use colour source data for SPIM-related data, but it makes the movie builder
							more generally useful, e.g. for generating movies from PNG sequences generated by visualization software	*/
						vals[0] = src[x*srcBytesPerPixel + 0];
						vals[1] = src[x*srcBytesPerPixel + 1];
						vals[2] = src[x*srcBytesPerPixel + 2];
					}
                    else if (srcBytesPerPixel == 8)
                    {
						/*	ImageMagick sometimes generates 16 bits/channel PNGs, so we handle them too	*/
						vals[0] = src[x*srcBytesPerPixel + 0];
						vals[1] = src[x*srcBytesPerPixel + 2];
						vals[2] = src[x*srcBytesPerPixel + 4];
                    }
					else if (srcBytesPerPixel == 2)
					{
						vals[0] = vals[1] = vals[2] = src[x*srcBytesPerPixel + 0] / 256.0 + src[x*srcBytesPerPixel + 1];
					}
					else
					{
						vals[0] = vals[1] = vals[2] = src[x*srcBytesPerPixel + 0];
					}

					for (int channel = 0; channel < 3; channel++)
						if (channelMaskToUse & (1<<channel))
							dst[channel] = LIMIT(int(round(vals[channel] * exposure)), 0, 255);
					dst[3] = 255;
				}
		});
	}
	else
	{
		// We failed to load the image file for some reason. 
		memset(destData, 0, destRowBytes * height);
	}
	
	[imageFromDisk release];
	
	NSImage *result = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
	[result addRepresentation:argbBitmap];
	[argbBitmap release];
	return [result autorelease];
}

-(bool)isBrightfield
{
	// We want to know if this is a brightfield channel. For now all we can do is look at the model_string property,
	// but TODO: I would like to copy across the channel information from the configuration plist into the image metadata
	NSString *model = [self.metadata objectForKey:@"model_string"];
	return ([model hasPrefix:@"Allied Vision"]);
}

@synthesize computerTimestamp = _computerTimestamp;
@synthesize cameraTimestamp = _cameraTimestamp;
-(NSString *)path
{
	return self.link.path;
}

@synthesize link = _link;
@synthesize metadata = _metadata;
@synthesize frameNumber = _frameNumber;

-(NSString *)fileNameNoPath
{
	return [self.path lastPathComponent];
}

@end

@implementation ImageSequenceForChannel

-(id)initForParent:(GUIMovieBuilder*)inParent;
{
	if (!(self = [super init]))
		return nil;

	parent = inParent;
	_colour = 0;
	_scale = 1.0;
	_exposure = 1.0;
	_overrideFrameIndex = -1;
	_sourceFolderURL = nil;
	interestedInCrosshairsInformation = true;
	interestedInGainInformation = true;
	self.crosshairs = [JPoint2 pointWithNSPoint:NSMakePoint(-1, -1)];
	self.offset = [JPoint2 pointWithNSPoint:NSMakePoint(0, 0)];
	timestampedImages = [[NSMutableArray alloc] init];
	[self addObserver:self forKeyPath:@"syncFramesOnly" options:0 context:NULL];
	[self addObserver:self forKeyPath:@"displayImageMayNeedChanging" options:0 context:NULL];
	
	return self;
}

-(void)dealloc
{
	[self removeObserver:self forKeyPath:@"syncFramesOnly"];
	[self removeObserver:self forKeyPath:@"displayImageMayNeedChanging"];
	self.sourceFolderURL = nil;
	self.crosshairs = nil;
	self.offset = nil;
	[timestampedImages release];
	[super dealloc];
}

+(NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)inKey
{
	NSSet* set = [super keyPathsForValuesAffectingValueForKey:inKey];
	// Many of the properties affect how the current image should be displayed.
	if ([inKey isEqualTo:@"displayImageMayNeedChanging"])
	{
		// All these variables could affect the appearance of the image
		// It is not possible to directly implement a one-to-many relationship when listing key paths here
		// In other words, the parent can't explicitly watch for a property change from *any* entry in parent.sequences
		// It's also frustrating that (apparently) NSArrayController is not fully KVO compliant so the parent can't watch
		// selection.property (which would be enough for our purposes). Instead we need to have each sequence watch for its
		// own changes (here), and inform the parent
		set = [set setByAddingObjectsFromSet:[NSSet setWithObjects:
											  @"sourceFolderURL",
											  @"flipH", @"flipV",
											  @"syncFramesOnly", @"colour",
											  @"exposure", @"scale",
											  @"offset.everything",
											  @"showCrosshairs", @"crosshairs.everything",
											  nil]];
	}
	if ([inKey isEqualTo:@"filenameString"])
	{
		// We want to know if the source filename changes.
		// In some ways it would be more logical to monitor if currentFrameObject changed,
		// but at the time of writing that is not treated as a property (it's called from the parent
		// and queries the parent to know what the current frame is!), so monitoring parent.currentFrame
		// is the best we can do at present.
		set = [set setByAddingObjectsFromSet:[NSSet setWithObjects:
											  @"sourceFolderURL",
											  @"parent.currentFrame",
											  nil]];
	}
	return set;
}

-(void)observeValueForKeyPath:(NSString *)keyPath
					 ofObject:(id)object
					   change:(NSDictionary *)change
					  context:(void *)context
{
	if ([keyPath isEqualTo:@"syncFramesOnly"])
	{
		if (self.sourceFolderURL != nil)
			[self populateSequenceArrayFromURL:self.sourceFolderURL syncOnly:self.syncFramesOnly];
	}
	else if ([keyPath isEqualTo:@"displayImageMayNeedChanging"])
		parent.displayImageMayNeedChanging++;
	else
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

-(NSURL*)sourceFolderURL
{
	return [[_sourceFolderURL retain] autorelease];
}

-(void)setSourceFolderURL:(NSURL*)url
{
	if (url == nil)
	{
		if (_sourceFolderURL != nil)
			[_sourceFolderURL release];
		_sourceFolderURL = nil;
		return;
	}
	_sourceFolderURL = [url copy];
	[self populateSequenceArrayFromURL:url syncOnly:self.syncFramesOnly];
	
	// Attempt to load sync information from the prosilica camera for this image set
	// If we find it then we will use it to improve the decision of which
	// fluorescence image belongs with which brightfield image.
	FILE *inFile = fopen([url URLByAppendingPathComponent:@"sync_log.txt"].path.UTF8String, "r");
	if (inFile == NULL)
		return;
	while (1)
	{
		FrameInfo info;
		int frameNumber, integerCycle, inSync;
		double timestamp, pixelValueSum;
		int numRead = fscanf(inFile, "SYNC\t%*f\t%d\t%lf\t%lf\t%lf\t"
							 "%lf\t%lf\t%lf\t%lf\t"
							 "%lf\t%lf\t%lf\t%lf\t"
							 "%d\t%d\t%lf\t%lf\t%d\n",
							 &frameNumber, &info.referencePos, &info.phase, &info.deltaPhase,
							 &info.timestampCopy, &info.psAnticipatedTime, &info.psUsedTriggerTime, &info.psTimeTriggerWasProgrammed,
							 &info.macTimeReceived, &info.macTimeProcessingStarted, &info.macTimeProcessingEnded, &info.macTriggerSentTime,
							 &integerCycle, &info.bestScorePos, &pixelValueSum, &info.alternativePeriodCalculation, &inSync);
		
		
		if (numRead != 17)
			break;
		frameInfoMap[frameNumber] = info;
	};
	
	fclose(inFile);
}

-(void)populateSequenceArrayFromURL:(NSURL*)url syncOnly:(bool)syncOnly
{
	ALWAYS_ASSERT(IsDirectory(url));		// Control should enforce this
	// TODO: IsDirectory call can fail if we computationally request a particular URL, which doesn't exist.
	// I should think about whether I should handle that better...?
	
	NSString *theString = [url path];
	[timestampedImages removeAllObjects];
	ForEveryImageFileInDirectory(theString, ^(NSString *thePath)
	 {
		 TimestampedImage *obj = [TimestampedImage timestampedImageFromFile:thePath forSequence:self];
		 
		 if ((!syncOnly) || ([[obj.metadata objectForKey:@"in_sync"] boolValue]))
		 {
			 [timestampedImages addObject:obj];
			 // Read the crosshairs coordinates and inform the parent accordingly
			 // It's up to the parent to decide what to do with this information
			 // (the crosshairs coords may already be known)
			 NSPoint thisCrosshairs = NSPointFromString((NSString*)[obj.metadata objectForKey:@"crosshairs"]);
			 NSRect thisCropRect = NSRectFromString((NSString*)[obj.metadata objectForKey:@"crop_rect"]);
			 if ((thisCrosshairs.x != 0) || (thisCrosshairs.y != 0))
			 {
				 if (interestedInCrosshairsInformation)
				 {
					 // Note that the code used to expect a negative value for the crosshairs y coord
					 // This is now fixed, but old video datasets will have a negative value, and this
					 // will need to be altered by hand when generating videos from the data...
					 self.crosshairs = [JPoint2 pointWithNSPoint:NSMakePoint(thisCrosshairs.x - thisCropRect.origin.x, thisCrosshairs.y - thisCropRect.origin.y)];
					 interestedInCrosshairsInformation = false;
				 }
			 }
		 }

		 if (interestedInGainInformation && ([obj.metadata objectForKey:@"exposure_on_screen"] != nil))
		 {
			 self.exposure = [[obj.metadata objectForKey:@"exposure_on_screen"] floatValue];
			 interestedInGainInformation = false;
		 }
	});
	
	// Frames need sorting by timestamp - normally we are ok but
	// the ordering won't be right if there was a wrap of frame number
	[timestampedImages sortUsingComparator:timestampComparator];

	[parent sequenceChanged:self];
}

-(bool)infoForFrameNumber:(int)f into:(FrameInfo *)fi
{
	// First identify the TimestampedImage record for this frame number
	FIM::iterator it = frameInfoMap.find(f);
	if (it != frameInfoMap.end())
	{
		*fi = (*it).second;
		return true;
	}
	else
		return false;
}

-(TimestampedImage*)currentFrameObject
{
	TimestampedImage *result;
	if (timestampedImages.count == 0)
		return nil;
	
	if (self.overrideFrameIndex != -1)
	{
		CHECK((self.overrideFrameIndex >= 0) && (self.overrideFrameIndex < self.count));
		result = [timestampedImages objectAtIndex:self.overrideFrameIndex];
	}
	else if (parent.sequenceToUseForTimings == self)
	{
		if ((parent.currentFrame > (int)timestampedImages.count) || (parent.currentFrame < 1))
			return nil;
		result = [timestampedImages objectAtIndex:parent.currentFrame-1];
	}
	else
	{
		// Note that to avoid recursions it is essential that we know that we are NOT sequenceToUseForTimings
		// when we call currentFrameObjectToUseForTimings
		// I'm adding another assert right here just to be clear about that.
		ALWAYS_ASSERT(parent.sequenceToUseForTimings != self);
		TimestampedImage *timingObject = parent.currentFrameObjectToUseForTimings;
		if (timingObject == nil)
			return nil;
		int index = [timestampedImages indexOfObject:timingObject
									   inSortedRange:NSMakeRange(0, timestampedImages.count)
											 options:NSBinarySearchingInsertionIndex
									 usingComparator:timestampComparator];
        // Note range check on index == count here, BEFORE we attempt to access objectAtIndex:index !
		if ((index == (int)timestampedImages.count) || (timestampComparator(timingObject, [timestampedImages objectAtIndex:index]) != 0))
		{
			// e.g. if insertion point for obj1 would be before the first frame in current sequence, we should not be showing anything at all.
			// The "if" conditions here ensure that if the prsesent object and the one from the sequence being used for timings
			// have exactly the same timestamp then we return the precisely matching pair
			index--;
		}
		
#if 0
		/*	TODO: this code needs updating.
			It is intended to use information logged from prosilica camera during sync analysis
			in order to refine which QI frame belongs with which PS frame.
			In the new world order I need to decide how I am going to know when to make use of
			that information for lining up sequences. I need to be able to identify whether the
			current frame was a slave frame triggered from synchronization 
			(i.e. ideally tell that it is NOT cascaded...
		     [but what about frames cascaded from frames that were themselves triggered by sync!?]). 
			If it is a slave frame then I should execute the subsequent code. 
			However the code also assumes that the PS camera that generated the log is also being used
			as the one controlling the timings for the MovieBuilder. I should ideally check that too!	*/

		// We now have what may be the correct index. However we should refine this
		// based on the precise PS time we actually fire the trigger
		bool recentlyFired = false;
		for (int i = timingObject.frameNumber - 20; i <= timingObject.frameNumber; i++)
		{
			FrameInfo info;
			bool ok = [self infoForFrameNumber:i into:&info];
			if (ok)
			{
				if (info.psUsedTriggerTime != -1)
				{
					if (info.psUsedTriggerTime <= self.timepointMS * 1e-3)
					{
						//					printf("Trigger fire time %lf has recently passed (current timepoint %lf)\n", info.psUsedTriggerTime, self.timepointMS*1e-3);
						recentlyFired = true;
						break;
					}
				}
			}
		}
		
		if (recentlyFired)
		{
			printf("recently fired\n");
			// We have very recently fired a trigger.
			// Checking if frame index+1 has a timestamp very slightly into the future
			// If so, use it
			if (index < int(sequence2.count) - 1)
			{
				TimestampedImage *next = [sequence2 objectAtIndex:index+1];
				double nextTS = next.timestamp;
				if (fabs(obj1.timestamp - nextTS) < 1e-1)
					index++;
			}
		}
#endif
		
		if (index < 0)
			result = nil;
		else
        {
            ALWAYS_ASSERT(index < (int)timestampedImages.count);
			result = [timestampedImages objectAtIndex:index];
        }
	}
	return [[result retain] autorelease];
}

-(TimestampedImage*)timestampedImageAtIndex:(NSUInteger)index
{
	ALWAYS_ASSERT(index < timestampedImages.count);
	TimestampedImage *result = [timestampedImages objectAtIndex:index];
	ALWAYS_ASSERT([result isKindOfClass:[TimestampedImage class]]);
	return result;
}

-(int)frameForCameraTimestamp:(double)time
{
	return (int)MAX(int([timestampedImages indexOfObject:[TimestampedImage dummyTimestampedImageWithCameraTime:time]
										   inSortedRange:NSMakeRange(0, timestampedImages.count)
										 		 options:NSBinarySearchingInsertionIndex
										 usingComparator:cameraTimestampComparator]) - 1,
					0);
}

-(NSRect)destRectForDrawingImage:(NSImage *)srcImage
{
	// Returns the rectangle where our current settings indicate that the frame will be drawn
	// We draw the centre of it at (offsetX,offsetY)
	// Note that we shouldn't need to have srcImage passed in. However at present we don't do a good
	// job of caching the images in TimestampedImage, so better to pass it in here than to have to
	// load it afresh just to see what size it is!
	float destX = self.offset.x;
	float destY = self.offset.y;
	float sw = srcImage.size.width * self.scale;
	float sh = srcImage.size.height * self.scale;
	
	// Certain layout behaviours require special-case handling here
	__block ImageSequenceForChannel *prevSeq = nil;
	__block NSRect rectForPrev = NSMakeRect(0, 0, 0, 0);
	if (parent.layoutBehaviour == kLayoutAllAdjacent)
	{
		// Each sequence offsets itself according to the position of the one preceding it
		// (this code needs care to avoid recursion in the call to destRectForDrawingImage!)
		for (ImageSequenceForChannel *seq in parent.sequences)
		{
			if (seq == self)
				break;
			prevSeq = seq;
			rectForPrev = [seq destRectForDrawingImage:seq.currentFrameObject.image];
		}
	}
	else if ((parent.layoutBehaviour == kLayoutBrightfieldAdjacent) && (self.currentFrameObject.isBrightfield))
	{
		// If this is a brightfield sequence then offset it relative to the bounding rect of all the non-brightfield frames
		for (ImageSequenceForChannel *seq in parent.sequences)
		{
			if (!seq.currentFrameObject.isBrightfield)
			{
				prevSeq = seq;
				rectForPrev = NSUnionRect(rectForPrev, [seq destRectForDrawingImage:seq.currentFrameObject.image]);
			}
		}
	}
	if (prevSeq != nil)
		destX += rectForPrev.origin.x + rectForPrev.size.width + sw/2.0;

	NSRect result = NSMakeRect(destX - sw/2.0, destY - sh/2.0, sw, sh);
	return result;
}

-(void)drawIntoCurrentDrawingContext
{
	if (self.currentFrameObject == nil)
		return;
	NSImage *srcImage = self.currentFrameObject.image;
	if (srcImage == nil)
	{
		// We should be displaying a frame, but we do not have an actual image for it
		// That probably means the file on disk has been moved - warn the user if we haven't
		// already done so
		if (!_warnedMissingFile)
		{
			[spimApp alertWithText:[SWF:@"Image file %@ not found", self.currentFrameObject.link.filename]
					andExplanation:@"The file or a directory containing it may have been moved (will not warn again). Please choose the source data again. It could alternatively be that the file is not in a supported image format."];
			_warnedMissingFile = true;
		}
		return;
	}
	
	// Draw srcBitmap into mergedBitmap.
	NSRect destRect = [self destRectForDrawingImage:srcImage];
	[srcImage drawInRect:destRect
				fromRect:NSMakeRect(0, 0, srcImage.size.width, srcImage.size.height)
			   operation:NSCompositePlusLighter
				fraction:1.0];
	
	if (self.showCrosshairs)
	{
		[[NSColor redColor] set];
		NSBezierPath *path = [NSBezierPath bezierPath];
		// TODO: should decide how to handle image flipping wrt crosshairs. If flipped then should flip crosshairs too,
		// but also need to make sure it behaves consistently wrt crosshairs drawn on live image when image is flipped/unflipped/
		[path moveToPoint:NSMakePoint(destRect.origin.x + self.crosshairs.x * self.scale, destRect.origin.y + (self.crosshairs.y - 10) * self.scale)];
		[path lineToPoint:NSMakePoint(destRect.origin.x + self.crosshairs.x * self.scale, destRect.origin.y + (self.crosshairs.y + 10) * self.scale)];
		[path moveToPoint:NSMakePoint(destRect.origin.x + (self.crosshairs.x - 10) * self.scale, destRect.origin.y + self.crosshairs.y * self.scale)];
		[path lineToPoint:NSMakePoint(destRect.origin.x + (self.crosshairs.x + 10) * self.scale, destRect.origin.y + self.crosshairs.y * self.scale)];
		[path stroke];
	}
}

-(NSString *)filenameString
{
	if (self.currentFrameObject != nil)
		return self.currentFrameObject.fileNameNoPath;
	return nil;
}

-(NSString*)popupMenuString
{
	// This is rather unsatisfactory - we need to know our own index in the sequence array
	// in order to know what to call ourselves. Should probably either make the string
	// more descriptive or somehow redesign this code in a more elegant way...
	return [SWF:@"%d", [parent.sequences indexOfObject:self]];
}

-(int/*remaining count*/)excludeOutsideRangeFrom:(int)firstIndex to:(int)lastIndex
{
	NSRange rangeToKeep = NSMakeRange(firstIndex, MIN(lastIndex - firstIndex + 1, int(timestampedImages.count - firstIndex)));
	timestampedImages = [[NSMutableArray arrayWithArray:[timestampedImages subarrayWithRange:rangeToKeep]] retain];
	return timestampedImages.count;
}

-(int)count { return timestampedImages.count; }
@synthesize flipH = _flipH;
@synthesize flipV = _flipV;
@synthesize syncFramesOnly = _syncFramesOnly;
@synthesize colour = _colour;
@synthesize crosshairs = _crosshairs;
@synthesize showCrosshairs = _showCrosshairs;
@synthesize offset = _offset;
@synthesize scale = _scale;
@synthesize exposure = _exposure;
@synthesize sourceFolderURL = _sourceFolderURL;
@synthesize overrideFrameIndex = _overrideFrameIndex;
-(bool)displayImageMayNeedChanging { return true; }
-(void)setDisplayImageMayNeedChanging:(bool)val { /* We do not do anything, but KVO will spot that this has been set, and so our observer will be called */ }

@end

@implementation MovieFrameView

-(void)frameNeedsRedraw
{
	[self setImage:movieBuilder.currentFrameImage];
}

@end

@implementation GUIMovieBuilder

-(id)initAndRunSession:(NSString*)nibName
{
	if (!(self = [self initAndRunBackgroundSession:nibName]))
		return nil;
	
	[[self window] makeKeyAndOrderFront:self];
	return self;
}

+(id)runSession
{
	return [[[GUIMovieBuilder alloc] initAndRunSession:@"Movie Builder"] autorelease];
}

-(id)initAndRunBackgroundSession:(NSString*)nibName
{
	if (!(self = [self initWithWindowNibName:nibName]))
		return nil;
	
	_currentFrameImage = nil;
	self.currentFrame = 1;
	self.startFrame = 1;
	self.endFrame = 1;
	self.framerateToUse = 30;
	self.sequenceToUseForTimings = nil;
	self.encodingQuality = 3;
	self.mask = [JRect rectWithNSRect:NSMakeRect(0, 0, 0, 0)];
	
	self.sequences = [[NSMutableArray new] autorelease];
	
	[self addObserver:self forKeyPath:@"mask.everything" options:0 context:NULL];
	[self addObserver:self forKeyPath:@"displayImageMayNeedChanging" options:0 context:NULL];
	
	[frameView setImageScaling:NSImageScaleProportionallyUpOrDown];
	[self window];

	return self;
}

+(id)runBackgroundSession
{
	return [[[GUIMovieBuilder alloc] initAndRunBackgroundSession:@"Movie Builder"] autorelease];
}

-(void)dealloc
{
//	printf("Dealloc MovieBuilder\n");
	[self removeObserver:self forKeyPath:@"mask.everything"];
	[self removeObserver:self forKeyPath:@"displayImageMayNeedChanging"];
	[_currentFrameImage release];
	[_sequenceArrayController removeObjects:self.sequenceArrayController.arrangedObjects];
	self.sequences = nil;
	[super dealloc];
}

-(void)acceptedWithURL:(NSURL *)outputMovieURL
{	
	// If the Save As dialog was cancelled then we DON'T cancel the entire movie builder window
	// We just return to it as if the user never pressed ok
	if (outputMovieURL == nil)
		return;
	
	// Setting the current frame to the first movie frame makes it easy for us to
	// identify the rect for the output movie. When we are done we will set the current frame
	// back to what it was before we started outputting the movie
	int firstFrame = MAX(self.startFrame, 1), lastFrame = MIN(self.endFrame, self.numFrames);
	int savedCurrentFrame = self.currentFrame;
	self.currentFrame = firstFrame;

	// The rectangles we use for building the actual movie (and masking it)
	// are defined with the origin in one corner of the image.
	// This is in contrast with the origin in the centre that we use for the display on screen
	// Hence from this point onwards we need to make an adjustment.
	NSRect maskedFrameRect = self.frameRect;
	maskedFrameRect.origin = NSMakePoint(0, 0);
	if (self.maskEnabled)
		maskedFrameRect = NSIntersectionRect(maskedFrameRect, self.mask.ns);
	if ((maskedFrameRect.size.width < 1) || (maskedFrameRect.size.height < 1))
	{
		[spimApp alertWithText:@"With the current mask settings no part of the frame is visible" andExplanation:@"No movie has been generated"];
		return;
	}
	maskedFrameRect = MultiplyRect(maskedFrameRect, upscalingFactor);
	
	OSStatus err;
	BoundsRect movieBuilderRect(0, 0, (int)maskedFrameRect.size.width, (int)maskedFrameRect.size.height);
	Handle outputMovieDataRef = NULL;
	OSType outputMovieDataRefType;
	err = QTNewDataReferenceFromCFURL((CFURLRef)outputMovieURL, 0, &outputMovieDataRef, &outputMovieDataRefType);
	ALWAYS_ASSERT_NOERR(err);
	
	JBetterMovieBuilder *builder = new JBetterMovieBuilder(codecMapping[self.encodingQuality], outputMovieDataRef, outputMovieDataRefType, movieBuilderRect, self.framerateToUse, &err, qualityMapping[self.encodingQuality]);
	if (err != noErr)
	{
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:[SWF:@"Could not create the movie file (error %d)", (int)err]];
		if (err == fBsyErr)
			[alert setInformativeText:@"The file is already open in another program."];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:nil contextInfo:nil];
		// Return to the movie builder window
		self.currentFrame = savedCurrentFrame;
		return;
	}

	CocoaProgressWindow *progress;
	bool externalObject = false;
	if (self.useExternalProgressObject)
	{
		externalObject = true;
		progress = [self.useExternalProgressObject retain];
	}
	else
	{
		progress = [[CocoaProgressWindow alloc] initForItems:(lastFrame - firstFrame + 1) * (self.includeReverseFrames ? 2 : 1)
																	withTitle:@"Exporting Movie..." 
																	sheetOnWindow:[self window]];
	}
	
	// Do the movie building work on a separate thread to allow other windows to receive events etc.
	// We can run this code async without any concurrency problems within the current class because
	// we will not receive any conflicting commands while the progress sheet is visible...
	dispatch_async(movieExportQueue,
	^{
		dispatch_sync(dispatch_get_main_queue(), ^{ self.currentFrame = firstFrame; });
		__block bool keepLooping = (firstFrame <= lastFrame);
		do
		{
			/*	If the implicit updating of the displayed image due to currentFrame changing
				turns out to be a performance hit then I can disable it, 
				or reduce the frequency with which it is updated	*/
			NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
			// MISSING IMAGES: tolerate missing source images, which mean the generic crop rect in maskedFrameRect may be inappropriate
			NSRect thisCropRect = NSIntersectionRect(maskedFrameRect, NSMakeRect(0, 0, _currentFrameImage.size.width, _currentFrameImage.size.height));
			builder->AddFrame(_currentFrameImage, &thisCropRect);

			dispatch_sync(dispatch_get_main_queue(),
			^{
				NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
				[progress deltaProgress:1];
				if (progress.userCancelled)
					keepLooping = false;
				// Note that I need to increment this before we drain the pool,
				// in order for the buffer associated with the image bitmap to be released
				// If I don't do this here then currentFrameImage is still in use and so the
				// internally cached buffer is not autoreleased. Annoying but true!
				self.currentFrame++;
				if (self.currentFrame > lastFrame)
					keepLooping = false;
				[pool drain];
			});
			[pool drain];
		} while (keepLooping);
		if (self.includeReverseFrames && !progress.userCancelled)
		{
			keepLooping = (firstFrame <= lastFrame);
			dispatch_sync(dispatch_get_main_queue(), ^{ self.currentFrame = lastFrame; });
			do
			{
				NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
				// MISSING IMAGES: tolerate missing source images, which mean the generic crop rect in maskedFrameRect may be inappropriate
				NSRect thisCropRect = NSIntersectionRect(maskedFrameRect, NSMakeRect(0, 0, _currentFrameImage.size.width, _currentFrameImage.size.height));
				builder->AddFrame(_currentFrameImage, &thisCropRect);

				dispatch_sync(dispatch_get_main_queue(),
				^{
					[progress deltaProgress:1];
					if (progress.userCancelled)
						keepLooping = false;
					// Note that I need to increment this before we drain the pool,
					// in order for the buffer associated with the image bitmap to be released
					// If I don't do this here then currentFrameImage is still in use and so the
					// internally cached buffer is not autoreleased. Annoying but true!
					self.currentFrame--;
					if (self.currentFrame < firstFrame)
						keepLooping = false;
				});
				[pool drain];
			} while (keepLooping);
		}

		dispatch_async(dispatch_get_main_queue(),
		^{
			if (externalObject)
				[progress release];
			else
			{
				// TODO ****** actually closing this is a problem if other code has retained the progress bar
				// Needs fixing (see discussion on cocoa-dev...)
				[progress closeSheetAndRelease];
			}

			// I prefer not to close the moviebuilder window when export is finished,
			// it's often convenient to keep the settings for the next export
			delete builder;
			self.currentFrame = savedCurrentFrame;
		});
	});
}

-(void)blockWhileBusy
{
	// This will wait for any previously-queued work, but of course additional work
	// could in principle be added at any time after this function is entered
	dispatch_sync(movieExportQueue, ^{});
}

-(void)createFileAtPath:(NSString*)path
{
	[self acceptedWithURL:[NSURL fileURLWithPath:path]];
}

-(IBAction)accept:(id)sender
{
	// Actually build the movie frame by frame
	GetDestinationDetailsUsingSheetOnWindow(
				self.window,
				^(NSInteger returnCode, NSSavePanel *savePanel)
				{
					dispatch_async(dispatch_get_main_queue(),
					^{
						if (returnCode != NSOKButton)
							return;	// with data ref NULL
						[self acceptedWithURL:savePanel.URL];
					});
				});
}

-(IBAction)cancel:(id)sender
{
	[self close];
}

-(void)close
{
	// Disappointingly I have to release retained properties manually
	self.useExternalProgressObject = nil;
	[super close];
}

#if 0
// TODO: temporary code (see comment in addSequence)
-(void)pathControl:(NSPathControl*)pathControl willPopUpMenu:(NSMenu*)menu
{
	if (simulatingPathControlClick)
	{
//		[menu performActionForItemAtIndex:0];
		SEL action = [menu itemAtIndex:0].action;
		id target = [menu itemAtIndex:0].target;
//		dispatch_async(dispatch_get_main_queue(), ^{ [menu performActionForItemAtIndex:0]; });NSMenuItem
		[JDispatchTimer newOneShotTimerOnQueue:dispatch_get_main_queue()
								 afterInterval:0.3
								   withHandler:^{
									   [menu cancelTracking];
								   }];
		[JDispatchTimer newOneShotTimerOnQueue:dispatch_get_main_queue()
										 afterInterval:0.5
										   withHandler:^{
											   [target performSelector:action withObject:nil];
										   }];
	}
}
#endif

-(void)pathControl:(NSPathControl *)pathControl willDisplayOpenPanel:(NSOpenPanel *)panel
{
	panel.title = @"Choose image folder...";
	panel.message = @"Choose folder containing images for this channel.";
	panel.prompt = @"Choose";
}

-(IBAction)addSequence:(id)sender
{
	
#if 0
	ImageSequenceForChannel *seq = [self addSequenceUsingURL:nil];

	// TODO: Work in progress. This does not currently work, I'm hoping for an answer from cocoa-dev...
	// Although I can bring up the Open window, it does not get populated with anything, for some reason
	
	// When adding a new sequence we immediately prompt the user to select a folder to use for image files
	// I am pretty confident this is always the first step the user should take, and this saves clicks and
	// saves confusion over why nothing (much) has apparently happened!
	simulatingPathControlClick = true;
	[folderSelectPopup performClick:self];
	simulatingPathControlClick = false;
#elif 1
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.allowsMultipleSelection = FALSE;
	panel.canChooseDirectories = TRUE;
	panel.canChooseFiles = FALSE;
	panel.title = @"Choose image folder...";
	panel.message = @"Choose folder containing images for this channel.";
	panel.prompt = @"Choose";
	
	[panel beginWithCompletionHandler:^(NSInteger result)
	 {
		 NSURL *url = nil;
		 if ((result == NSFileHandlingPanelOKButton) && (panel.filenames.count == 1))
		 {
			 url = [NSURL fileURLWithPath:[panel.filenames objectAtIndex:0]];
			 [self addSequenceUsingURL:url];
		 }
	 }];

#else
	ImageSequenceForChannel *seq = [self addSequenceUsingURL:nil];
#endif
}

-(IBAction)removeCurrentSequence:(id)sender
{
	// TODO: should probably warn user before deleting?
	if (self.sequenceArrayController.selectedObjects.count > 0)
		[_sequenceArrayController removeObjects:self.sequenceArrayController.selectedObjects];
}

-(ImageSequenceForChannel *)addSequenceUsingURL:(NSURL*)url
{
	CHECK(url != nil);
	ImageSequenceForChannel *seq = [[[ImageSequenceForChannel alloc] initForParent:self] autorelease];
	[self.sequenceArrayController addObject:seq];
	seq.sourceFolderURL = url;
	return seq;
}

-(void)sequenceChanged:(ImageSequenceForChannel*)sequence
{
	// The contents of a sequence have changed (probably a new URL was set)

	// If we don't currently have any sequences, use this one for timings
	if (self.sequenceToUseForTimings == nil)
		self.sequenceToUseForTimings = sequence;
}

-(IBAction)setStartFrameToCurrentFrame:(id)sender
{
	self.startFrame = self.currentFrame;
}

-(IBAction)setEndFrameToCurrentFrame:(id)sender
{
	self.endFrame = self.currentFrame;
}

-(IBAction)deleteExcludedFrames:(id)sender
{
	/*	This action will delete all image files (and associated plists) that fall outside the range
		that the user has selected. This is a big step to take, so we move to the Trash rather
		than deleting outright	*/
		
	// Work out which files we may be going to trash
	NSString *parentDir = nil;
	NSMutableArray *filesToDelete = [[[NSMutableArray alloc] init] autorelease];
	NSString *rangeString = nil;
	
	// TODO: currently we only trash for sequence 1. Need to update this to trash for all sequences
	// This pointer is a temporary workaround to make the existing code work with variable numbers of image sequences,
	// but the implementation needs more thought and updating (bug #75)
	if (self.sequences.count == 0)
		return;
	ImageSequenceForChannel *sequence1 = [self.sequences objectAtIndex:0];
	if (self.startFrame > 1)
	{
		rangeString = [SWF:@"%d-%d", 1, self.startFrame-1];
		for (int frameNumber = 1; frameNumber < self.startFrame; frameNumber++)
		{
			TimestampedImage *tsi = [sequence1 timestampedImageAtIndex:frameNumber - 1];
			NSString *thisParentDir = [tsi.link.path stringByDeletingLastPathComponent];
			if (parentDir == nil)
				parentDir = thisParentDir;
			else
				ALWAYS_ASSERT([parentDir isEqualToString:thisParentDir]);
			[filesToDelete addObject:tsi.link.path];
		}
	}
	if (self.endFrame < self.numFrames)
	{
		if (rangeString != nil)
			rangeString = [rangeString stringByAppendingString:@" and "];
		else
			rangeString = @"";
		rangeString = [rangeString stringByAppendingString:[SWF:@"%d-%d", self.endFrame+1, self.numFrames]];
		for (int frameNumber = self.endFrame + 1; frameNumber <= self.numFrames; frameNumber++)
		{
			TimestampedImage *tsi = [sequence1 timestampedImageAtIndex:frameNumber - 1];
			NSString *thisParentDir = [tsi.link.path stringByDeletingLastPathComponent];
			if (parentDir == nil)
				parentDir = thisParentDir;
			else
				ALWAYS_ASSERT([parentDir isEqualToString:thisParentDir]);
			[filesToDelete addObject:tsi.link.path];
		}
	}
	if (parentDir == nil)
	{
		[spimApp alertWithText:@"No frames are currently outside the start/end range. Nothing will be deleted."
				andExplanation:@"This button will delete any files outside the range \"Start\" to \"End\". Since that range currently covers all the files in the directory, nothing will be deleted."];
		return;
	}
		
	// Warn the user before continuing	
	NSAlert *alert = [NSAlert alertWithMessageText:[SWF:@"Are you sure you want to delete frames %@?", rangeString]
								defaultButton:@"Cancel"
								alternateButton:@"Delete"
								otherButton:nil
								informativeTextWithFormat:@"Frames %@ are outside the range \"Start\" to \"End\" and will be moved to the Trash. "
														       @"This will lead to them being permanently deleted if you go ahead with this.", rangeString];
	NSInteger result = [alert runModal];
	if (result == NSAlertDefaultReturn)	// Cancel
		return;

	// Remove the files from our working list
	CHECK(self.startFrame >= 1);
	CHECK(self.endFrame >= 1);
	int remainingCount = [sequence1 excludeOutsideRangeFrom:self.startFrame-1 to:self.endFrame-1];		// -1 because startFrame and endFrame are 1-based indexes
	// Update the current, start and end frame numbers now we have removed some frames from the sequence
	self.currentFrame -= self.startFrame - 1;
	self.startFrame = 1;
	self.endFrame = remainingCount;
	// Although we should now have updated the frame positions, for safety we call this function too
	[self limitCurStartEndFrames];
	
	// Create a temporary directory to move the unwanted files into
	NSString *intermediateDir = [parentDir stringByAppendingPathExtension:@"deleted"];
	NSError *err = nil;
	bool ok = [[NSFileManager defaultManager] createDirectoryAtPath:intermediateDir
								withIntermediateDirectories:FALSE
								attributes:nil
								error:&err];
	if (!ok)
		goto fail;
	
	// Move the unwanted files into that directory
	for (int i = 0; i < (int)filesToDelete.count; i++)
	{
		NSString *filePath = [filesToDelete objectAtIndex:i];
		NSString *plistPath = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"plist"];
		ok = [[NSFileManager defaultManager] moveItemAtPath:filePath
												toPath:[intermediateDir stringByAppendingPathComponent:[filePath lastPathComponent]]
												error:&err];
		if (!ok)
			goto fail;
		// Also want to delete the accompanying plist, but if that fails then never mind - maybe it doesn't exist
		[[NSFileManager defaultManager] moveItemAtPath:plistPath toPath:[intermediateDir stringByAppendingPathComponent:[plistPath lastPathComponent]] error:&err];
	}
	
	// Now move directory to trash
	[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation 
								   source:[intermediateDir stringByDeletingLastPathComponent]
								   destination:@"" 
								   files:[NSArray arrayWithObject:[intermediateDir lastPathComponent]]
								   tag:nil];
	return;
	
  fail:
	// If we get here then an error has occurred
	[spimApp alertWithText:@"An error occurred while deleting the files. They have probably not been moved to the trash."
				andExplanation:[SWF:@"Error: %@", err.localizedDescription]];
}

-(void)setCurrentFrameToCameraTimestamp:(double)time
{
	// This function sets the current frame to the specified time.
	// It looks for the specified time in whichever sequence is currently designated as the one to use for timings
	ImageSequenceForChannel *sourceSequence = self.sequenceToUseForTimings;
	self.currentFrame = [sourceSequence frameForCameraTimestamp:time];
}

-(double)timepointMS
{
	// Will be overridden by TimelineAnimationBuilder
	TimestampedImage *frame = self.currentFrameObjectToUseForTimings;
	if (frame == nil)
		return 0;
	return frame.cameraTimestamp * 1e3;
}

-(void)setTimepointMS:(double)val
{
	// Shouldn't be called for this class.
	// TimelineAnimationBuilder overrides it.
	CHECK(0);
}

-(NSRect)frameRect
{
	// Return the rectangle that bounds the complete image we are going to draw for this frame
	// This is just the union of all the individual image rectangles
	// TODO: this is an example of an inefficiency, where we read the 'image' property of the
	// timestamped image (in this case just because we need to know where it will be drawn)
	// Since image is not cached, that is very inefficient. Needs improvement.
	if (self.sequences.count == 0)
		return NSMakeRect(0, 0, 1, 1);
	NSRect result = NSMakeRect(0, 0, 0, 0);
	for (ImageSequenceForChannel *seq in self.sequences)
	{
		if (seq.count == 0)
			continue;
		NSImage *firstImageInSequence = [seq timestampedImageAtIndex:0].image;
		NSRect destRect = [seq destRectForDrawingImage:firstImageInSequence];
		result = NSUnionRect(result, destRect);
	}
	return NSMakeRect(floor(result.origin.x), floor(result.origin.y), ceil(result.size.width), ceil(result.size.height));
}

float PoissonNoise(float initialVal, float quantVal)
{
	if (quantVal < 0.1)
		return initialVal;
	double lambda = initialVal / quantVal;
	double L = exp(-lambda);
	if (L < 1e-80)
		return initialVal;
	int k = 0;
	double p = 1;
	do
	{
		k++;
		double u = random_01();
		p *= u;
	} while (p > L);
    return (k - 1) * quantVal;
}

-(NSImage *)currentFrameImage
{
	return _currentFrameImage;
}

-(void)setScaledBitmapContext:(NSBitmapImageRep *)theBitmap withOrigin:(NSPoint)origin
{
	[NSGraphicsContext saveGraphicsState];
	NSGraphicsContext *newContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:theBitmap];
	[NSGraphicsContext setCurrentContext:newContext];

	NSAffineTransform *transform1 = [NSAffineTransform transform];
	NSAffineTransform *transform2 = [NSAffineTransform transform];
	[transform1 translateXBy:-origin.x yBy:-origin.y];
	[transform1 concat];
	[transform2 scaleBy:upscalingFactor];
	[transform2 concat];
}

-(NSBitmapImageRep *)newRenderedFrameBitmap
{
	bool foundAtLeastOneFrame = false;
	for (ImageSequenceForChannel *thisChannel in self.sequences)
	{
		ALWAYS_ASSERT([thisChannel isKindOfClass:[ImageSequenceForChannel class]]);
		if (thisChannel.currentFrameObject != nil)
			foundAtLeastOneFrame = true;
	}
	if (!foundAtLeastOneFrame)
		return nil;

	// thisRect gives the bounds of the rectangle into which stuff will be drawn
	// That may have a negative origin. Our bitmap needs to have the same dimensions as this rectangle,
	// but we need to handle the origin appropriately
	NSRect thisRect = self.frameRect;
	// Determine the width and height of the overall image
	// MISSING IMAGES: more code to cope with corrupt/missing image files, because I'd rather not actually hit assertions and crash the program if the image would have zero size
	int width = (int)MAX(thisRect.size.width, 1.0f);
	int height = (int)MAX(thisRect.size.height, 1.0f);

	NSBitmapImageRep *combinedBitmap = [[NSBitmapImageRep alloc]
											initWithBitmapDataPlanes:NULL		// Bitmap allocates and releases the necessary memory for us
											pixelsWide:int(width*upscalingFactor)
											pixelsHigh:int(height*upscalingFactor)
											bitsPerSample:8
											samplesPerPixel:4
											hasAlpha:YES
											isPlanar:NO
											colorSpaceName:NSCalibratedRGBColorSpace
											bytesPerRow:0
											bitsPerPixel:0];

	[self setScaledBitmapContext:combinedBitmap withOrigin:thisRect.origin];

	// Iterate over each sequence, rendering it according to the offsets, scale etc specified for that channel
	for (ImageSequenceForChannel *thisChannel in self.sequences)
		[thisChannel drawIntoCurrentDrawingContext];

	[NSGraphicsContext restoreGraphicsState];
	
	return combinedBitmap;
}

-(void)updateCurrentFrameImage
{
	// We first release the current image and set the variable to nil
	// I do actually want to do this even if we later hit some problem -
	// currentFrameImage is actually *stale*, so we don't want just to 
	// keep displaying it in the event of a problem.
	[_currentFrameImage release];
	_currentFrameImage = nil;

	/*	Also, we have to create an autorelease pool here because depending on implementation
		we may be passed an autoreleased image. We may run out of memory if we don't keep
		draining the autorelease pool as we go!	*/
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	NSBitmapImageRep *currentFrameBitmap = [self newRenderedFrameBitmap];
	NSImage *image = [[NSImage alloc] initWithSize:[currentFrameBitmap size]];
	[image addRepresentation:currentFrameBitmap];

#if 0
		// Temp: annotate the video
		if ((obj1.frameNumber >= 6705) && (obj1.frameNumber <= 6730))
		{
			[image lockFocus];
			[@"Laser fired" drawAtPoint:NSMakePoint(175, 190) withAttributes:nil];
			[image unlockFocus];
		}
		if ((obj1.frameNumber >= 19461) && (obj1.frameNumber < 19500))
		{
			[image lockFocus];
			NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
			ps.alignment = NSCenterTextAlignment;
			NSMutableDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
																[NSFont fontWithName:@"Helvetica" size:20], NSFontAttributeName,
																[NSColor whiteColor], NSForegroundColorAttributeName,
																ps, NSParagraphStyleAttributeName,
																nil];
			[@"4 minutes later" drawInRect:NSMakeRect(0, image.size.height/2-10, image.size.width, 20) withAttributes:attributes];
			[image unlockFocus];
		}
#endif

	[currentFrameBitmap release];
	_currentFrameImage = image;
	
	[pool drain];
}

-(int)numFrames
{
	return self.sequenceToUseForTimings.count;
}

+(NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)inKey
{
	NSSet* set = [super keyPathsForValuesAffectingValueForKey:inKey];
	// Many of the properties affect how the current image should be displayed.
	// There are various properties that depend directly on which image is displayed,
	// and we also have a special property which can be monitored for changes whenever the
	// current image may need altering.
	if (StringIsInList(inKey, @"imageTooltip", @"timestampString", @"displayImageMayNeedChanging", nil))
	{
		// All these variables could affect the appearance of the image
		// Note that the individual channel sequences also watch for changes to themselves, which will be
		// communicated to us by them changing "displayImageMayNeedChanging".
		set = [set setByAddingObjectsFromSet:[NSSet setWithObjects:
												@"currentFrame", @"sequences", @"sequenceToUseForTimings",
												@"maskEnabled", @"mask.everything", @"layoutBehaviour",
												nil]];
	}
	if ([inKey isEqualTo:@"numFrames"])
	{
		set = [set setByAddingObject:@"sequenceToUseForTimings"];
	}
	return set;
}

-(void)observeValueForKeyPath:(NSString *)keyPath
				ofObject:(id)object
				change:(NSDictionary *)change
				context:(void *)context
{
	if ([keyPath isEqualTo:@"displayImageMayNeedChanging"])
	{
		[self updateCurrentFrameImage];
		[frameView frameNeedsRedraw];
	}
	else if ([keyPath isEqualTo:@"mask.everything"])
	{
		// If our mask changes, then the box shown in the frame view should also be updated to reflect this
		frameView.boxRectInImageCoords = MultiplyRect(self.mask.ns, upscalingFactor);
	}
	else
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

-(IBAction)setMaskFromMarkedRect:(id)sender
{
	self.mask = [JRect rectWithNSRect:MultiplyRect(frameView.boxRectInImageCoords, 1.0 / upscalingFactor)];
	if ((self.mask.w == 0) &&
		(self.mask.h == 0))
	{
		// Empty mask. Set mask rect to entire image
		NSSize imageSize = frameView.image.size;
		self.mask = [JRect rectWithNSRect:NSMakeRect(0, 0, imageSize.width, imageSize.height)];
	}
	UpdateKeys(self, @"maskX", @"maskY", @"maskW", @"maskH", nil);
}

-(void)limitCurStartEndFrames
{
	self.currentFrame = (int)MIN(self.currentFrame, self.numFrames);
	self.startFrame = (int)MIN(self.startFrame, self.numFrames);
	self.endFrame = (int)MIN(self.endFrame, self.numFrames);
}

-(NSString *)timestampString
{
	if (self.sequenceToUseForTimings.currentFrameObject != nil)
		return [SWF:@"%.3lf s", self.sequenceToUseForTimings.currentFrameObject.computerTimestamp];
	return @"";
}

-(NSString *)imageTooltip
{
	NSString *theString = @"";
	for (ImageSequenceForChannel *thisChannel in self.sequences)
	{
		if (thisChannel.currentFrameObject != nil)
		{
			if (theString.length > 0)
				theString = [theString stringByAppendingString:@"\n"];
			theString = [theString stringByAppendingString:[SWF:@"File %@  timestamp %.3lf",
															thisChannel.currentFrameObject.fileNameNoPath,
															thisChannel.currentFrameObject.computerTimestamp]];
		}
	}
	return theString;
}

-(IBAction)revealFilesInFinder:(id)sender
{
	for (ImageSequenceForChannel *thisChannel in self.sequences)
		[[NSWorkspace sharedWorkspace] selectFile:thisChannel.currentFrameObject.path inFileViewerRootedAtPath:nil];
}

@synthesize sequences = _sequences;
-(ImageSequenceForChannel *)sequence:(NSUInteger)i
{
	if (i >= self.sequences.count) return nil;
	ImageSequenceForChannel *result = [self.sequences objectAtIndex:i];
	ALWAYS_ASSERT([result isKindOfClass:[ImageSequenceForChannel class]]);
	return result;
}
@synthesize currentFrame = _currentFrame;
@synthesize startFrame = _startFrame;
@synthesize includeReverseFrames = _includeReverseFrames;
@synthesize endFrame = _endFrame;
@synthesize framerateToUse = _framerateToUse;
@synthesize layoutBehaviour = _layoutBehaviour;
@synthesize encodingQuality = _encodingQuality;
@synthesize useExternalProgressObject = _useExternalProgressObject;
@synthesize maskEnabled = _maskEnabled;
@synthesize mask = _mask;
@synthesize sequenceArrayController = _sequenceArrayController;
-(bool)displayImageMayNeedChanging { return true; }
-(void)setDisplayImageMayNeedChanging:(bool)val { /* We do not do anything, but KVO will spot that this has been set, and so our observer will be called */ }

-(void)setSequenceToUseForTimings:(ImageSequenceForChannel *)seq
{
	[_sequenceToUseForTimings release];
	_sequenceToUseForTimings = [[MAZeroingWeakRef alloc] initWithTarget:seq];
	
	// If the frame number and limits are set to zero, update them now we have some real frames
	// Don't do that if the user has already set them though (that would be annoying!)
	if (self.currentFrame == 0)
		self.currentFrame = 1;
	if (self.startFrame == 0)
		self.startFrame = 1;
	if (self.endFrame == 0)
		self.endFrame = self.numFrames;

	[self limitCurStartEndFrames];
}
-(ImageSequenceForChannel *)sequenceToUseForTimings { return _sequenceToUseForTimings.target; }

-(TimestampedImage *)currentFrameObjectToUseForTimings { return self.sequenceToUseForTimings.currentFrameObject; }

@end
