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

timestampComparatorType timestampComparator = ^(TimestampedImage *objA, TimestampedImage *objB)
{
	return DiffToNSComparisonResult(objA.timestamp - objB.timestamp);
};

psTimestampComparatorType psTimestampComparator = ^(TimestampedImage *objA, TimestampedImage *objB)
{
	return DiffToNSComparisonResult(objA.psTimestamp - objB.psTimestamp);
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

+(id)timestampedImageFromFile:(NSString *)path forSequence:(int)inSequence parent:(GUIMovieBuilder*)inParent
{
	return [[[TimestampedImage alloc] initFromFile:path forSequence:inSequence parent:inParent] autorelease];
}

+(id)dummyTimestampedImageWithPSTime:(double)time
{
	TimestampedImage *result = [[[TimestampedImage alloc] initFromFile:nil  forSequence:1 parent:nil] autorelease];
	result.psTimestamp = time;
	return result;
}

-(id)initFromFile:(NSString *)path forSequence:(int)inSequence parent:(GUIMovieBuilder*)inParent
{
	if (!(self = [super init]))
		return nil;
	
	/*	We mustn't allocate the image because we are liable to run out of memory
		For the moment I load every time [self image] is called, and rely on OS disk cache
		to keep things reasonably efficient. I could consider using NSCache instead,
		but this works ok for now, for what is not really a priority feature of the program	*/
	NSError *err;
	self.link = [JAlias aliasForPath:path];
	sequence = inSequence;
	image = nil;
	parent = inParent;
	
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
			self.psTimestamp = [timestampObj doubleValue];
	
		self.frameNumber = [[metadata objectForKey:@"frame_number"] intValue];

		self.metadata = metadata;
		id timeReceived = [metadata objectForKey:@"time_received"];
		if (timeReceived != nil)
			self.timestamp = [timeReceived doubleValue];
		
		// Probably means this is the QI camera, which doesn't give us timestamps for some reason (bug reported to QI...)
		if (self.timestamp == 0.0)
			self.timestamp = [[metadata objectForKey:@"time_processing_started"] doubleValue];

		// We record timebase_start_uptime to get a universally consistent timestamp
		double timebase_start = [[metadata objectForKey:@"timebase_start_uptime"] doubleValue];
		self.timestamp += timebase_start;
	}

	return self;
}

-(void)dealloc
{	
	[image release];
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
	
//	printf("Loading file %s\n", self.path.UTF8String);
	int width = 1, height = 1;
	if ((imageFromDisk == nil) && (!parent.warnedMissingFile))
	{
		[spimApp alertWithText:[SWF:@"Image file %@ not found", self.link.filename]
					andExplanation:@"The file or a directory containing it may have been moved (will not warn again). Please choose the source data again. It could alternatively be that the file is not in a supported image format."];
		parent.warnedMissingFile = true;
	}
	
	if (imageFromDisk != nil)
	{
		width = int(imageFromDisk.size.width);
		height = int(imageFromDisk.size.height);
	}
	
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
	int channelMaskToUse = channelMasks[(sequence == 1) ? parent.sequence1Colour : parent.sequence2Colour];
	float exposure = (sequence == 1) ? parent.sequence1Exposure : parent.sequence2Exposure;
	bool flipH = (sequence == 1) ? parent.flipSequence1H : parent.flipSequence2H;
	bool flipV = (sequence == 1) ? parent.flipSequence1V : parent.flipSequence2V;

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

@synthesize timestamp = _timestamp;
@synthesize psTimestamp = _psTimestamp;
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
	printf("Using nib %s\n", nibName.UTF8String);
	if (!(self = [self initWithWindowNibName:nibName]))
		return nil;
	
	currentFrameImage = nil;	
	self.currentFrame = 1;
	self.hasSecondSequence = false;
	self.startFrame = 1;
	self.endFrame = 1;
	self.framerateToUse = 30;
	self.sequence1Colour = 0;
	self.sequence2Colour = 0;
	self.sequence1Exposure = 1.;
	self.sequence2Exposure = 1.;
	self.timingsFromSequence = 0;
	self.offsetForSequence = 0;
	self.encodingQuality = 3;
	
	offset = NSMakePoint(0, 0);
	self.offsetImageScale = 1.0;
	sequence1URL = nil;
	sequence2URL = nil;
	sequence1 = [[NSMutableArray alloc] init];
	sequence2 = [[NSMutableArray alloc] init];
	
	[self addObserver:self forKeyPath:@"syncFramesOnly1" options:0 context:NULL];	
	[self addObserver:self forKeyPath:@"syncFramesOnly2" options:0 context:NULL];	
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
	[self removeObserver:self forKeyPath:@"syncFramesOnly1"];
	[self removeObserver:self forKeyPath:@"syncFramesOnly2"];
	[self removeObserver:self forKeyPath:@"displayImageMayNeedChanging"];
	[currentFrameImage release];
	[sequence1 release];
	[sequence2 release];
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

	NSRect maskedFrameRect = NSMakeRect(0, 0, self.frameSize.width, self.frameSize.height);
	if (maskEnabled)
		maskedFrameRect = NSIntersectionRect(maskedFrameRect, mask);
	if ((maskedFrameRect.size.width < 1) || (maskedFrameRect.size.height < 1))
	{
		[spimApp alertWithText:@"With the current mask settings no part of the frame is visible" andExplanation:@"No movie has been generated"];
		return;
	}
	maskedFrameRect = MultiplyRect(maskedFrameRect, upscalingFactor);
	
	OSStatus err;
#if 1
	BoundsRect movieBuilderRect(0, 0, (int)maskedFrameRect.size.width, (int)maskedFrameRect.size.height);
	Handle outputMovieDataRef = NULL;
	OSType outputMovieDataRefType;
	err = QTNewDataReferenceFromCFURL((CFURLRef)outputMovieURL, 0, &outputMovieDataRef, &outputMovieDataRefType);
	ALWAYS_ASSERT_NOERR(err);
	
	const int qualityMapping[] = { codecLowQuality, codecNormalQuality, codecHighQuality, codecLosslessQuality, codecLosslessQuality, codecLosslessQuality };
	const int codecMapping[] = { kH264CodecType, kH264CodecType, kH264CodecType, kH264CodecType, kAnimationCodecType, kRawCodecType };
	JBetterMovieBuilder *builder = new JBetterMovieBuilder(codecMapping[self.encodingQuality], outputMovieDataRef, outputMovieDataRefType, movieBuilderRect, framerateToUse, &err, qualityMapping[self.encodingQuality]);
#else
	const int qualityMapping[] = { 0.2, 0.5, 0.7, 0.9, 1.0, 1.0, 1.0 };
	//**** need to use outputMovieURL...
	JModernMovieBuilder *builder = new JModernMovieBuilder("temp_file.mov", maskedFrameRect.size, framerateToUse, &err, qualityMapping[self.encodingQuality]);
	
#endif
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
	if (self.useExternalProgressObject)
		progress = [self.useExternalProgressObject retain];
	else
		progress = [[CocoaProgressWindow alloc] initForItems:(lastFrame - firstFrame + 1) * (includeReverseFrames ? 2 : 1)
																	withTitle:@"Exporting Movie..." 
																	sheetOnWindow:[self window]];
	
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
			NSRect thisCropRect = NSIntersectionRect(maskedFrameRect, NSMakeRect(0, 0, currentFrameImage.size.width, currentFrameImage.size.height));
			builder->AddFrame(currentFrameImage, &thisCropRect);

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
				NSRect thisCropRect = NSIntersectionRect(maskedFrameRect, NSMakeRect(0, 0, currentFrameImage.size.width, currentFrameImage.size.height));
				builder->AddFrame(currentFrameImage, &thisCropRect);

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
			// TODO ****** actually closing this is a problem if other code has retained the progress bar
			// Needs fixing (see discussion on cocoa-dev...)
			[progress closeSheetAndRelease];

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
	NSMutableArray *filesToDelete = [[NSMutableArray alloc] init];
	NSString *rangeString = nil;
	if (self.startFrame > 1)
	{
		rangeString = [SWF:@"%d-%d", 1, self.startFrame-1];
		for (int frameNumber = 1; frameNumber < self.startFrame; frameNumber++)
		{
			TimestampedImage *tsi = [sequence1 objectAtIndex:frameNumber - 1];
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
			TimestampedImage *tsi = [sequence1 objectAtIndex:frameNumber - 1];
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
								informativeTextWithFormat:[SWF:@"Frames %@ are outside the range \"Start\" to \"End\" and will be moved to the Trash. "
														       @"This will lead to them being permanently deleted if you go ahead with this.", rangeString]];
	NSInteger result = [alert runModal];
	if (result == NSAlertDefaultReturn)	// Cancel
		return;

	// Remove the files from our working list
	sequence1 = [[NSMutableArray arrayWithArray:[sequence1 subarrayWithRange:NSMakeRange(self.startFrame-1, MIN(self.endFrame - self.startFrame + 1, int(sequence1.count - self.startFrame+1)))]] retain];
	self.startFrame = 1;
	self.endFrame = sequence1.count;
	[self numFramesChangedImplicitly];
	
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

-(void)setCurrentFrameToPSTime:(double)time
{
	NSArray *sourceSequence = (timingsFromSequence == 0) ? sequence1 : sequence2;
	self.currentFrame = (int)MAX(int([sourceSequence indexOfObject:[TimestampedImage dummyTimestampedImageWithPSTime:time]
												inSortedRange:NSMakeRange(0, sourceSequence.count)
												options:NSBinarySearchingInsertionIndex
												usingComparator:psTimestampComparator]) - 1,
							     0);
}

-(TimestampedImage*)currentFrameObject1
{
	TimestampedImage *result;
	if ((sequence1 == nil) || ([sequence1 count] == 0))
		return nil;
		
	if (timingsFromSequence == 0)
	{
		if ((self.currentFrame > (int)[sequence1 count]) || (self.currentFrame < 1))
			return nil;
		result = [sequence1 objectAtIndex:self.currentFrame-1];
	}
	else
	{
		TimestampedImage *obj2 = [self currentFrameObject2];
		if (obj2 == nil)
			return nil;
		int index = [sequence1 indexOfObject:obj2
								inSortedRange:NSMakeRange(0, [sequence1 count])
								options:NSBinarySearchingInsertionIndex
								usingComparator:timestampComparator];
		index--;		// e.g. if insertion point for obj2 would be before the first frame in current sequence, we should not be showing anything at all.
		if (index < 0)
			result = nil;
		else
			result = [sequence1 objectAtIndex:index];
	}
	return [[result retain] autorelease];
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

-(double)timepointMS
{
	// Will be overridden by TimelineAnimationBuilder
	TimestampedImage *obj1 = [self currentFrameObject1];
	if (obj1 == nil)
		return 0;
	return obj1.psTimestamp * 1e3;
}

-(void)setTimepointMS:(double)val
{
	// Shouldn't be called for this class.
	// TimelineAnimationBuilder overrides it.
	CHECK(0);
}

-(TimestampedImage*)currentFrameObject2
{
	TimestampedImage *result;
	if ((!hasSecondSequence) || (sequence2 == nil) || ([sequence2 count] == 0))
		return nil;

	if (timingsFromSequence == 1)
	{
		if ((self.currentFrame > (int)[sequence2 count]) || (self.currentFrame < 1))
			return nil;
		result = [sequence2 objectAtIndex:self.currentFrame-1];
	}
	else
	{
		TimestampedImage *obj1 = [self currentFrameObject1];
		if (obj1 == nil)
			return nil;
		int index = [sequence2 indexOfObject:obj1 
								inSortedRange:NSMakeRange(0, [sequence2 count])
								options:NSBinarySearchingInsertionIndex
								usingComparator:timestampComparator];
		printf("Looking for match with timestamp %lf\n", obj1.timestamp);
		printf("Got index %d as insertion point, timestamp %lf\n", index, [[sequence2 objectAtIndex:index] timestamp]);
		// [n.b. this next code branch was merged in from a different version. I think it is ok, but
		//  if any problems encountered, that may explain it!]
		if ((index == (int)sequence2.count) || (timestampComparator(obj1, [sequence2 objectAtIndex:index]) != 0))
		{
			// e.g. if insertion point for obj1 would be before the first frame in current sequence, we should not be showing anything at all.
			// The "if" conditions here ensure that if obj1 and obj2 have exactly the same timestamp then
			// we return the precisely matching pair
			index--;		
			printf("Special case: decrement\n");
		}
		printf("Decrement\n");
		//index--;
		
		// We now have what may be the correct index. However we should refine this
		// based on the precise PS time we actually fire the trigger
		bool recentlyFired = false;
		for (int i = obj1.frameNumber - 20; i <= obj1.frameNumber; i++)
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
		
		if (index < 0)
			result = nil;
		else
			result = [sequence2 objectAtIndex:index];
	}
	return [[result retain] autorelease];
}

-(NSSize)frameSize
{
	// TODO: this next code is very inefficient. We explicitly access currentFrameObject.image and query its dimensions.
	// However to avoid keeping masses of data around unnecessarily, currentFrameObject does NOT cache its image!
	// Thus just querying the frame size results in an additional read-from-disk of the entire image!
	// If this situation is improved on somehow, this could potentially double the rate of frame processing here.
	if (self.currentFrameObject1 == nil)
		return NSMakeSize(0, 0);
		
	NSSize s;
	if (sequence2IsAdjacent)
	{
		float image1Scale = (self.offsetForSequence == 0) ? self.offsetImageScale : 1;
		float image2Scale = (self.offsetForSequence == 1) ? self.offsetImageScale : 1;
		NSImage *image1 = self.currentFrameObject1.image;
		NSImage *image2 = self.currentFrameObject2.image;
		int width = (int)(image1.size.width * image1Scale + image2.size.width * image2Scale);
		int height = (int)MAX(image1.size.height * image1Scale, image2.size.height * image2Scale);
		s = NSMakeSize(width, height);
	}
	else if ((!hasSecondSequence) || (offsetForSequence == 1) || (self.currentFrameObject2 == nil))
	{
		NSImage *temp = self.currentFrameObject1.image;
		s = temp.size;
	}
	else
		s = [self.currentFrameObject2.image size];
		
	return NSMakeSize(ceil(s.width), ceil(s.height));
}

// Temporary hack used for fading movie in and out
static double gMultiplier = 1.0;

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

void MergeBitmaps(NSImage *srcImage, ImageDrawingInfo *offsets)
{
	// Draw srcBitmap into mergedBitmap.
	// We draw the centre of it at (offsetX,offsetY) relative to the centre of the destination bitmap
	float destX = offsets->offsetX;
	float destY = offsets->offsetY;
	float sw = srcImage.size.width;
	float sh = srcImage.size.height;
	NSRect destRect = NSMakeRect(destX - sw / 2.0 * offsets->imageScaling, destY - sh / 2.0 * offsets->imageScaling, sw * offsets->imageScaling, sh * offsets->imageScaling);
	
	[srcImage drawInRect:destRect
					fromRect:NSMakeRect(0, 0, sw, sh)
					operation:NSCompositeCopy
					fraction:1.0];
	
	// Temporary code still needs testing and making to work for different scalings etc.
	if (offsets->showCrosshairs)
	{
		[[NSColor redColor] set];
		NSBezierPath *path = [NSBezierPath bezierPath];
		[path moveToPoint:NSMakePoint(destRect.origin.x + offsets->crosshairs.x * offsets->imageScaling, destRect.origin.y + (offsets->crosshairs.y - 10) * offsets->imageScaling)];
		[path lineToPoint:NSMakePoint(destRect.origin.x + offsets->crosshairs.x * offsets->imageScaling, destRect.origin.y + (offsets->crosshairs.y + 10) * offsets->imageScaling)];
		[path moveToPoint:NSMakePoint(destRect.origin.x + (offsets->crosshairs.x - 10) * offsets->imageScaling, destRect.origin.y + offsets->crosshairs.y * offsets->imageScaling)];
		[path lineToPoint:NSMakePoint(destRect.origin.x + (offsets->crosshairs.x + 10) * offsets->imageScaling, destRect.origin.y + offsets->crosshairs.y * offsets->imageScaling)];
		[path stroke];
	}
}


-(NSImage *)currentFrameImage
{
	return currentFrameImage;
}

-(void)setScaledBitmapContext:(NSBitmapImageRep *)theBitmap
{
	[NSGraphicsContext saveGraphicsState];
	NSGraphicsContext *newContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:theBitmap];
	[NSGraphicsContext setCurrentContext:newContext];

	NSAffineTransform *transform1 = [NSAffineTransform transform];
	NSAffineTransform *transform2 = [NSAffineTransform transform];
	[transform1 translateXBy:theBitmap.size.width/2 yBy:theBitmap.size.height/2];
	[transform1 concat];
	[transform2 scaleBy:upscalingFactor];
	[transform2 concat];
}

-(NSBitmapImageRep *)newRenderedFrameBitmap
{
	TimestampedImage *obj1 = [self currentFrameObject1];
	TimestampedImage *obj2 = [self currentFrameObject2];
//	printf("obj1 timestamp %lf\n", obj1.timestamp);
//	printf("obj2 timestamp %lf\n", obj2.timestamp);
	if (obj1 == nil)
		return nil;

	bool showCrosshairsOverride = showCrosshairs;
	bool suppressSequence2 = false;
	if (0)
	{
		// Temporary code to fade specific frames in and out
		int distance;
		if (obj1.frameNumber <= 6824)
			distance = abs(6824 - obj1.frameNumber);
		else if (obj1.frameNumber <= 19500)
			distance = 0;
		else
		{
			distance = abs(obj1.frameNumber - 19500);
			showCrosshairsOverride = false;
			suppressSequence2 = true;
		}
		if (obj1.frameNumber >= 6820)
			showCrosshairsOverride = false;
		gMultiplier = LIMIT(double(distance) / 20.0, 0.0, 1.0);
	}
	bool showCrosshairsOverride2 = showCrosshairsOverride;
	if (0)
	{
		if (obj1.frameNumber > 6705)
			showCrosshairsOverride = false;
	}
	NSBitmapImageRep *bitmap1 = RawBitmapFromImage(obj1.image);
	NSBitmapImageRep *bitmap2 = (obj2 == nil) ? nil : RawBitmapFromImage(obj2.image);
	NSSize thisSize = self.frameSize;
	int width = (int)thisSize.width;
	int height = (int)thisSize.height;

	if ((bitmap1 == nil) && (bitmap2 == nil))
	{
		// MISSING IMAGES: more code to cope with corrupt/missing image files, because I'd rather not actually hit assertions and crash the program
		width = height = 1;
	}

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

	[self setScaledBitmapContext:combinedBitmap];

	if (sequence2IsAdjacent)
	{
		float image1Scale = (self.offsetForSequence == 0) ? self.offsetImageScale : 1;
		float image2Scale = (self.offsetForSequence == 1) ? self.offsetImageScale : 1;

		// I am not really merging anything here, but I'd rather reuse the same code
		ImageDrawingInfo offsets1 = { -width/2 + obj1.image.size.width*image1Scale/2.0, 0, image1Scale, flipSequence1H, flipSequence1V, showCrosshairsOverride, crosshairs };
		if (self.offsetForSequence == 0)
		{
			offsets1.offsetX += self.offsetX;
			offsets1.offsetY += self.offsetY;
		}
		// Special code (not exposed in GUI) used to perform additional tweaks for
		// programmatic generation of very specific videos for publication
		offsets1.offsetX += additionalProgrammaticOffset1.x;
		offsets1.offsetY += additionalProgrammaticOffset1.y;
			
		MergeBitmaps(obj1.image, &offsets1);
		if ((bitmap2 != nil) && (!suppressSequence2))
		{
			ImageDrawingInfo offsets2 = { width/2 - obj2.image.size.width*image2Scale/2.0, 0, image2Scale, flipSequence2H, flipSequence2V, showCrosshairsOverride2, crosshairs };
			if (self.offsetForSequence == 1)
			{
				offsets2.offsetX += self.offsetX;
				offsets2.offsetY += self.offsetY;
			}
			MergeBitmaps(obj2.image, &offsets2);
		}
	}
	else
	{
		// Merge the two bitmaps together to create my image.
		bool useOffsets = ((self.offsetForSequence == 0) && (self.hasSecondSequence));
		ImageDrawingInfo offsets1 = { useOffsets ? self.offsetX : 0, useOffsets ? self.offsetY : 0, useOffsets ? offsetImageScale : 1, flipSequence1H, flipSequence1V, showCrosshairsOverride, crosshairs };
		MergeBitmaps(obj1.image, &offsets1);
		if (bitmap2 != nil)
		{
			useOffsets = ((self.offsetForSequence == 0) && (self.hasSecondSequence));
			ImageDrawingInfo offsets2 = { useOffsets ? self.offsetX : 0, useOffsets ? self.offsetY : 0, useOffsets ? offsetImageScale : 1, flipSequence2H, flipSequence2V, showCrosshairsOverride2, crosshairs };
			MergeBitmaps(obj2.image, &offsets2);
		}
	}
	
	[NSGraphicsContext restoreGraphicsState];
	
	return combinedBitmap;
}

-(void)updateCurrentFrameImage
{
	// We first release the current image and set the variable to nil
	// I do actually want to do this even if we later hit some problem -
	// currentFrameImage is actually *stale*, so we don't want just to 
	// keep displaying it in the event of a problem.
	[currentFrameImage release];
	currentFrameImage = nil;

	/*	Also, we have to create an autorelease pool here because depending on implementation
		we may be passed an autoreleased image. We may run out of memory if we don't keep
		draining the autorelease pool!	*/
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
	
	currentFrameImage = image;
	
	[pool drain];
}

-(void)setSequenceArray:(int)whichSequence toURL:(NSURL*)url syncOnly:(bool)syncOnly
{
	ALWAYS_ASSERT(IsDirectory(url));		// Control should enforce this
	NSString *theString = [url path];

	NSMutableArray *sequence = (whichSequence == 1) ? sequence1 : sequence2;
	[sequence removeAllObjects];

	ForEveryImageFileInDirectory(theString, ^(NSString *thePath)
	{
		TimestampedImage *obj = [TimestampedImage timestampedImageFromFile:thePath forSequence:whichSequence parent:self];
		
		if ((!syncOnly) || ([[obj.metadata objectForKey:@"in_sync"] boolValue]))
			[sequence addObject:obj];
		if (!haveSetCrosshairs)
		{
			NSPoint thisCrosshairs = NSPointFromString((NSString*)[obj.metadata objectForKey:@"crosshairs"]);
			NSRect thisCropRect = NSRectFromString((NSString*)[obj.metadata objectForKey:@"crop_rect"]);
			if ((thisCrosshairs.x != 0) || (thisCrosshairs.y != 0))
			{
				[self willChangeValueForKey:@"crosshairsX"];
				[self willChangeValueForKey:@"crosshairsY"];
				// Note that the code used to expect a negative value for the crosshairs y coord
				// This is now fixed, but old video datasets will have a negative value, and this
				// will need to be altered by hand when generating videos from the data...
				crosshairs = NSMakePoint(thisCrosshairs.x - thisCropRect.origin.x, thisCrosshairs.y - thisCropRect.origin.y); 
				haveSetCrosshairs = true;
				[self didChangeValueForKey:@"crosshairsX"];
				[self didChangeValueForKey:@"crosshairsY"];
			}			
		}
	});

	// Frames need sorting by timestamp - normally we are ok but
	// the ordering won't be right if there was a wrap of frame number
	[sequence sortUsingComparator:timestampComparator];
	
	// If the frame number and limits are set to zero, update them now we have some real frames
	// Don't do that if the user has already set them though (that would be annoying!)
	if (self.currentFrame == 0)
		self.currentFrame = 1;
	if (self.startFrame == 0)
		self.startFrame = 1;
	if (self.endFrame == 0)
		self.endFrame = self.numFrames;
	self.warnedMissingFile = false;		// Reset warnings
	
	// The following may not have any effect if this sequence isn't the one the timings are taken from
	[self numFramesChangedImplicitly];
}

-(void)setSequence1URL:(NSURL *)url
{
	[sequence1URL release];
	sequence1URL = [url copy];
	[self setSequenceArray:1 toURL:sequence1URL syncOnly:self.syncFramesOnly1];

	// Attempt to load sync information for this image set
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

-(void)setSequence2URL:(NSURL *)url
{
	[sequence2URL release];
	sequence2URL = [url copy];
	[self setSequenceArray:2 toURL:sequence2URL syncOnly:self.syncFramesOnly2];
}

-(int)numFrames
{
	if (timingsFromSequence == 0)
		return [sequence1 count];
	else
		return [sequence2 count];
}


+(NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)inKey
{
	NSSet* set = [super keyPathsForValuesAffectingValueForKey:inKey];
	// Many of the properties affect how the current image should be displayed.
	// There are various properties that depend directly on which image is displayed,
	// and we also have a special property which can be monitored for changes whenever the
	// current image may need altering.
	if (StringIsInList(inKey, @"imageTooltip", @"timestampString", @"filename1String", @"filename2String",
								@"revealFile1InFinderEnabled", @"revealFile1InFinderEnabled", @"displayImageMayNeedChanging", nil))
	{
		set = [set setByAddingObjectsFromSet:[NSSet setWithObjects:
												@"currentFrame", @"hasSecondSequence", @"sequence2IsAdjacent",
												@"flipSequence1H", @"flipSequence1V", @"flipSequence2H", @"flipSequence2V",
												@"syncFramesOnly1", @"syncFramesOnly2", @"sequence1Colour", @"sequence2Colour",
												@"sequence1Exposure", @"sequence2Exposure", @"timingsFromSequence", @"offsetForSequence",
												@"offsetX", @"offsetY", @"showCrosshairs", @"crosshairsX", @"crosshairsY",
												@"maskX", @"maskY", @"maskW", @"maskH", @"maskEnabled",
												@"offsetImageScale", @"sequence1URL", @"sequence2URL",
												nil]];
	}
	return set;
}

-(void)observeValueForKeyPath:(NSString *)keyPath
				ofObject:(id)object
				change:(NSDictionary *)change
				context:(void *)context
{
	if ([keyPath isEqualTo:@"syncFramesOnly1"])
	{
		if (sequence1URL != nil)
			[self setSequence1URL:self.sequence1URL];		// Force reload
	}
	else if ([keyPath isEqualTo:@"syncFramesOnly2"])
	{
		if (sequence2URL != nil)
			[self setSequence2URL:self.sequence2URL];		// Force reload
	}
	else if ([keyPath isEqualTo:@"displayImageMayNeedChanging"])
	{
		[self updateCurrentFrameImage];
		[frameView frameNeedsRedraw];
	}
	else
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

-(float)offsetX { return offset.x; }
-(void)setOffsetX:(float)x { offset.x = x; }
-(float)offsetY { return offset.y; }
-(void)setOffsetY:(float)y { offset.y = y; }
-(float)crosshairsX { return crosshairs.x; }
-(void)setCrosshairsX:(float)x { crosshairs.x = x; }
-(float)crosshairsY { return crosshairs.y; }
-(void)setCrosshairsY:(float)y { crosshairs.y = y; }

-(float)maskX { return mask.origin.x; }
-(void)setMaskX:(float)x { mask.origin.x = x; frameView.boxRectInImageUnits = MultiplyRect(mask, upscalingFactor); }
-(float)maskY { return mask.origin.y; }
-(void)setMaskY:(float)y { mask.origin.y = y; frameView.boxRectInImageUnits = MultiplyRect(mask, upscalingFactor); }
-(float)maskW { return mask.size.width; }
-(void)setMaskW:(float)w { mask.size.width = w; frameView.boxRectInImageUnits = MultiplyRect(mask, upscalingFactor); }
-(float)maskH { return mask.size.height; }
-(void)setMaskH:(float)h { mask.size.height = h; frameView.boxRectInImageUnits = MultiplyRect(mask, upscalingFactor); }

-(IBAction)setMaskFromMarkedRect:(id)sender
{
	mask = MultiplyRect(frameView.boxRectInImageUnits, 1.0 / upscalingFactor);
	if ((mask.size.width == 0) &&
		(mask.size.height == 0))
	{
		// Empty mask. Set mask rect to entire image
		NSSize imageSize = frameView.image.size;
		mask = NSMakeRect(0, 0, imageSize.width, imageSize.height);
	}
	UpdateKeys(self, @"maskX", @"maskY", @"maskW", @"maskH", nil);
}

-(void)setTimingsFromSequence:(int)seq
{
	timingsFromSequence = seq;
	[self numFramesChangedImplicitly];
}

-(void)numFramesChangedImplicitly
{
	[self willChangeValueForKey:@"numFrames"];
	self.currentFrame = (int)MIN(self.currentFrame, self.numFrames);
	self.startFrame = (int)MIN(self.startFrame, self.numFrames);
	self.endFrame = (int)MIN(self.endFrame, self.numFrames);
	[self didChangeValueForKey:@"numFrames"];
}

-(NSString *)filename1String
{
	if (self.currentFrameObject1 != nil)
		return self.currentFrameObject1.fileNameNoPath;
	return nil;
}

-(NSString *)filename2String
{
	if (self.currentFrameObject2 != nil)
		return self.currentFrameObject2.fileNameNoPath;
	return nil;
}

-(NSString *)timestampString
{
	if (timingsFromSequence == 0)
	{
		if (self.currentFrameObject1 != nil)
			return [SWF:@"%.3lf s", self.currentFrameObject1.timestamp];
	}
	else
	{
		if (self.currentFrameObject2 != nil)
			return [SWF:@"%.3lf s", self.currentFrameObject2.timestamp];
	}
	return @"";
}

-(NSString *)imageTooltip
{
	NSString *firstString = @"", *secondString = @"";
	if (self.currentFrameObject1 != nil)
		firstString = [SWF:@"File %@  timestamp %.3lf", self.currentFrameObject1.fileNameNoPath, self.currentFrameObject1.timestamp];
	if (self.currentFrameObject2 != nil)
		secondString = [SWF:@"\nFile %@  timestamp %.3lf", self.currentFrameObject2.fileNameNoPath, self.currentFrameObject2.timestamp];
	return [SWF:@"%@%@", firstString, secondString];
}

-(BOOL)revealFile1InFinderEnabled { return self.currentFrameObject1 != nil; }
-(BOOL)revealFile2InFinderEnabled { return self.currentFrameObject2 != nil; }

-(IBAction)revealFile1InFinder:(id)sender
{
	[[NSWorkspace sharedWorkspace] selectFile:self.currentFrameObject1.path inFileViewerRootedAtPath:nil];
}

-(IBAction)revealFile2InFinder:(id)sender
{
	[[NSWorkspace sharedWorkspace] selectFile:self.currentFrameObject2.path inFileViewerRootedAtPath:nil];
}

@synthesize currentFrame = _currentFrame;
@synthesize startFrame;
@synthesize includeReverseFrames;
@synthesize endFrame;
@synthesize framerateToUse;
@synthesize hasSecondSequence;
@synthesize sequence2IsAdjacent;
@synthesize flipSequence1H;
@synthesize flipSequence1V;
@synthesize flipSequence2H;
@synthesize flipSequence2V;
@synthesize syncFramesOnly1;
@synthesize syncFramesOnly2;
@synthesize sequence1Colour;
@synthesize sequence2Colour;
@synthesize sequence1Exposure;
@synthesize sequence2Exposure;
@synthesize timingsFromSequence;
@synthesize encodingQuality;
@synthesize offsetForSequence;
@synthesize offsetImageScale;
@synthesize sequence1URL;
@synthesize sequence2URL;
@synthesize warnedMissingFile = _warnedMissingFile;
@synthesize useExternalProgressObject = _useExternalProgressObject;
@synthesize showCrosshairs;
@synthesize maskEnabled;
-(bool)displayImageMayNeedChanging { return true; }

@end
