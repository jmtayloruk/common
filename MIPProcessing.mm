//
//  MIPProcessing.mm
//  Spim Interface
//
//  Created by Jonny Taylor on 10/09/2015.
//
//

#import "MIPProcessing.h"
#import "CocoaProgressWindow.h"
#import <dispatch/dispatch.h>
#import "jCocoaImageUtils.h"
#import "MetadataParser.h"
#ifdef __SSE4_1__
    #import <smmintrin.h>		// SSE4.1
#endif
#include <VectorFunctions.h>

dispatch_queue_t processingQueue = dispatch_queue_create("mip processing queue", NULL);

enum { kMipXY = 1, kMipXZ };
const int gMipType = kMipXY;

template<class PIX_TYPE> void CalcMipScalar(PIX_TYPE *mipPixels, const PIX_TYPE *otherPixels, size_t numPixels)
{
    // Old scalar code for reference, and useful when the source or dest data is not sufficiently aligned for vector ops
    for (size_t x = 0; x < numPixels; x++)
        mipPixels[x] = MAX(mipPixels[x], otherPixels[x]);
}

template<class VTYPE, class STYPE, int vectorElements> void TCalcMip(STYPE *mipPixels, const STYPE *otherPixels, size_t numPixels)
{
    /*  Vectorized MIP code.
     
        Basically this is not normally the bottleneck when image files need to be loaded from disk.
        I'm not sure what scenario I had previously looked at, where this was a performance bottleneck!
     
        If we don't have to load from disk, this is 3-4x as fast as the scalar code.
        For unsigned short, we use the SSE4.1 instruction set if available,
        or otherwise fallback code which seems to be only 5-10% slower in reality.  */
    size_t i;
    for (i = 0; i <= numPixels-vectorElements; i += vectorElements)
    {
        VTYPE x = *(VTYPE*)&mipPixels[i];
        VTYPE y = *(VTYPE*)&otherPixels[i];
        *((VTYPE*)&mipPixels[i]) = vMax(x, y);
    }
    for (; i < numPixels; i++)
        mipPixels[i] = MAX(mipPixels[i], otherPixels[i]);
}

void CalcMip(unsigned char *mipPixels, const unsigned char *otherPixels, size_t numPixels, bool fast)
{
    if (fast)
        TCalcMip<vUInt8, unsigned char, 16>(mipPixels, otherPixels, numPixels);
    else
        CalcMipScalar(mipPixels, otherPixels, numPixels);
}

void CalcMip(unsigned short *mipPixels, const unsigned short *otherPixels, size_t numPixels, bool fast)
{
    if (fast)
        TCalcMip<vUInt16, unsigned short, 8>(mipPixels, otherPixels, numPixels);
    else
        CalcMipScalar(mipPixels, otherPixels, numPixels);
}

void CalcMipForBPP(unsigned char *mipData, const unsigned char *otherData, size_t bytes, int bitsPerPixel, bool fast)
{
	switch (bitsPerPixel)
	{
		case 8:
		case 32:
			// In the case of 32-bit data, we can treat it just as if it's 8-bit greyscale, but with more pixels
			CalcMip(mipData, otherData, bytes, fast);
			break;
		case 16:
			CalcMip((unsigned short *)mipData, (const unsigned short*)otherData, bytes/2, fast);
			break;
		default:
			ALWAYS_ASSERT(0);
	};
}

void TestMIPVectorSupport(void)
{
    // Test code can be called to verify that all the SSE vector code is yielding correct results
    const size_t kTestBufferWidth = 100, kTestBufferHeight = 160, kTestBufferSize = kTestBufferHeight*kTestBufferWidth;
    for (int bpp = 1; bpp <= 4; bpp *= 2)
    {
        printf("=== bpp=%d ===\n", bpp);
        unsigned char *bufferAs = new unsigned char[kTestBufferSize];
        unsigned char *bufferAv = new unsigned char[kTestBufferSize];
        unsigned char *bufferB = new unsigned char[kTestBufferSize];
        for (size_t i = 0; i < kTestBufferSize; i++)
        {
            bufferAs[i] = random() & 0xFF;
            bufferAv[i] = bufferAs[i];
            bufferB[i] = random() & 0xFF;
        }

        CalcMipForBPP(bufferAs, bufferB, kTestBufferSize, bpp*8, false);
        CalcMipForBPP(bufferAv, bufferB, kTestBufferSize, bpp*8);
        size_t i;
        for (i = 0; i < kTestBufferSize; i++)
            if (bufferAs[i] != bufferAv[i])
            {
                printf(" -> WARNING: DISAGREEMENT!\n");
                break;
            }
        if (i == kTestBufferSize)
            printf(" -> Agreement\n");

        delete[] bufferAs;
        delete[] bufferAv;
        delete[] bufferB;
    }
}

void UpdateMipWithBitmap(NSBitmapImageRep *mipBitmap, NSBitmapImageRep *frameBitmap)
{
    if ((mipBitmap.pixelsHigh == frameBitmap.pixelsHigh) &&
        (mipBitmap.bytesPerRow == frameBitmap.bytesPerRow))
    {
        CalcMipForBPP(mipBitmap.bitmapData, frameBitmap.bitmapData, size_t(mipBitmap.pixelsHigh * mipBitmap.bytesPerRow), (int)mipBitmap.bitsPerPixel);
    }
    else
    {
        // Current behaviour for the GUI-exposed MIP calculator is actually just to skip files where these dimensions do not match
        // It's probably best to have the same behaviour here.
    }
}

void CalcYZMip(NSBitmapImageRep *mipBitmap, int mipYPos, NSBitmapImageRep *frameBitmap, int yOffset/* for shear */)
{
	ALWAYS_ASSERT(mipYPos < mipBitmap.pixelsHigh);
	unsigned char *mipRow = (unsigned char *)(mipBitmap.bitmapData + mipBitmap.bytesPerRow * mipYPos);
	for (int y = 0; y < frameBitmap.pixelsHigh; y++)
	{
		int yToUse = y + yOffset;
		if ((yToUse >= 0) && (yToUse < frameBitmap.pixelsHigh))
		{
			// No obvious way to do non-scalar, due to the fact that bytesPerRow may not be sufficiently aligned
			// for the SSE instructions we would use for a vectorized implementation.
            // TODO: is that really true? Surely I could just use unaligned loads...?
			const unsigned char *otherRow = (const unsigned char *)(frameBitmap.bitmapData + frameBitmap.bytesPerRow * yToUse);
			CalcMipForBPP(mipRow, otherRow, frameBitmap.bytesPerRow, (int)mipBitmap.bitsPerPixel, false/*scalar*/);
		}
	}
}

void MakeMipFromImagesInFolder(NSString *sourceFolderPath, NSString *destFilename, CocoaProgressWindow *progress, double totalWork)
{
	// TODO: this could be improved on - currently it just bails out if the files aren't in the format it expects
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

    /*  We first need to know how many frames there are in this folder, which is not trivial given the presence of multi-page TIFFs
        We could get away without that for the xy MIP (it's only used for progress updates), but it's pretty essential for the xz MIP.
        However, we can get it by parsing the metadata (trusting that all frames also have accompanying metadata).
        This is not trivial from a performance point of view (parsing the xml takes a while), but it's not too bad. */
    __block size_t numFrames = 0;
    ForEveryFrameInDirectory(sourceFolderPath, ^(MetadataForFrame *frameMetadata) { numFrames++; });
    
    NSBitmapImageRep *firstBitmap = FirstBitmapInDirectory(sourceFolderPath);
	printf(" First file: %s %p\n", FirstImageFileNameInDirectory(sourceFolderPath).UTF8String, firstBitmap);
    if ([sourceFolderPath rangeOfString:@"Brightfield"].length > 0)
    {
        printf("Skipping brightfield\n");
        return;
    }

	__block int counter = 0;
	double shear = 0.0;//2.0;
	int shearStart = 0;//-100 * shear;
    __block NSBitmapImageRep *mipBitmap;
    if (gMipType == kMipXY)
    {
        mipBitmap = [firstBitmap retain];
        unsigned char *mipData = mipBitmap.bitmapData;
        memset(mipData, 0, mipBitmap.bytesPerRow * mipBitmap.pixelsHigh);
        ForEveryFrameInDirectory(sourceFolderPath,
            ^(NSBitmapImageRep *frameBitmap, MetadataForFrame *frameMetadata) {
                 if (!progress.userCancelled)		// Not sure we can break out of a block-based loop, but we can bail fairly quickly like this
                 {
                     if (!(CHECK(frameBitmap != nil)))
                         return;
                     ALWAYS_ASSERT(frameBitmap != nil);     // Redundant, but useful to silence spurious static analysis warning
                     if (!(CHECK(frameBitmap.bytesPerRow == mipBitmap.bytesPerRow)))
                         return;
                     if (!(CHECK(frameBitmap.pixelsHigh == mipBitmap.pixelsHigh)))
                         return;
#if 0
                     // Optional compile-time feature:
                     // check plist to see if a triggered frame is reasonably close to the target phase
                     NSMutableDictionary *metadata = [NSMutableDictionary dictionaryWithContentsOfFile:MetadataPathFromImagePath(filename)];
                     NSNumber *err = [metadata objectForKey:@"estimated_ref_frame_error"];
                     if ((err != nil) &&
                         (fabs(err.doubleValue) > 5.0))
                     {
                         return;
                     }
#endif
                     if (shear == 0.0)
                         CalcMipForBPP(mipData, frameBitmap.bitmapData, size_t(mipBitmap.pixelsHigh * mipBitmap.bytesPerRow), (int)mipBitmap.bitsPerPixel);
                     else
                     {
                         if (!(CHECK(frameBitmap.bitsPerPixel == 16)))
                         {
                             // Other bit depths (with shear) are not supported here yet.
                             // To be honest, this shear code is probably obsolete now I am supporting rotation in StackViewer
                             return;
                         }
                         for (int y = 0; y < frameBitmap.pixelsHigh; y++)
                         {
                             unsigned short *mipRow = (unsigned short *)(mipBitmap.bitmapData + mipBitmap.bytesPerRow * y);
                             int yToUse = y + shearStart + int(shear * counter);
                             if ((yToUse >= 0) && (yToUse < frameBitmap.pixelsHigh))
                             {
                                 const unsigned short *otherRow = (const unsigned short *)(frameBitmap.bitmapData + frameBitmap.bytesPerRow * yToUse);
                                 // No obvious way to do non-scalar, due to the fact that bytesPerRow may not be sufficiently aligned
                                 // for the SSE instructions we would use for a vectorized implementation.
                                 // TODO: if I cared, I could presumably implement unaligned loads/stores in my MIP-calculating code
                                 CalcMipScalar(mipRow, otherRow, frameBitmap.pixelsWide);
                             }
                         }
                     }
                     counter++;
                     dispatch_async(dispatch_get_main_queue(), ^{ [progress deltaProgress:(totalWork / double(numFrames))]; });
                 }
             });
    }
    else
    {
        ALWAYS_ASSERT(gMipType == kMipXZ);
		mipBitmap = [[NSBitmapImageRep bitmapLike:firstBitmap width:firstBitmap.pixelsWide height:numFrames] retain];
        ForEveryFrameInDirectory(sourceFolderPath,
            ^(NSBitmapImageRep *frameBitmap, MetadataForFrame *frameMetadata) {
                 if (!progress.userCancelled)		// Not sure we can break out of a block-based loop, but we can bail fairly quickly like this
                 {
                     if (!(CHECK(frameBitmap != nil)))
                         return;
                     if (!(CHECK(frameBitmap.bytesPerRow == mipBitmap.bytesPerRow)))
                         return;
					 CalcYZMip(mipBitmap, counter, frameBitmap, shearStart + int(shear * counter));
                     counter++;
                     dispatch_async(dispatch_get_main_queue(), ^{ [progress deltaProgress:(totalWork / double(numFrames))]; });
                 }
             });
    }
	
    /*  For now I save the MIPs as individual files, despite everything else being in multi-page TIFFs.
        This shouldn't be a huge issue in terms of bloated number of files, but TODO: I could change it in future.  */
    printf(" Saving as %s\n", destFilename.UTF8String);
    [[mipBitmap TIFFRepresentation] writeToFile:destFilename atomically:NO];
	[mipBitmap release];
	[pool drain];
}

void ProcessStacksIntoMIPsSavingAt(NSArray *inURLs, NSURL *destinationURL, void (^completionBlock)(int mipCounter, NSURL *destinationURL))
{
	// Sort filenames in chronological order
	NSArray *urls = [inURLs sortedArrayUsingFunction:frameSortOrderForURLs context:nil];
	CocoaProgressWindow *progress = [[CocoaProgressWindow alloc] initForItems:urls.count
																	withTitle:@"Generating MIPs..."
																sheetOnWindow:nil];
	[progress.window makeKeyAndOrderFront:nil];
	// We need to run this on a separate queue or we will encounter deadlocks
	// MovieBuilder expects to be able to dispatch_sync to the main queue
	dispatch_async(processingQueue,
				   ^{
					   int stackCounter = 0;
					   int mipCounter = 0;
					   for (NSURL *url in urls)
					   {
						   printf("File %s\n", url.path.UTF8String);
						   NSAutoreleasePool *pool = [NSAutoreleasePool new];
						   
						   // Process each of the image folders contained within the stack folder
						   NSString *mipFilename = [SWF:@"mip_%04d.tif", stackCounter++];
						   NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:url.path error:nil];
						   
						   // First do a rough estimate of number of camera folders present (for the progress bar)
						   int numCamFolders = 0;
						   for (NSString *cameraFolderPath in dirContents)
						   {
							   NSURL *contentsURL = PathToURL(cameraFolderPath, url);
							   if ((IsDirectory(contentsURL)) &&
								   (FirstImageFileNameInDirectory(contentsURL.path) != nil))
							   {
								   numCamFolders++;
							   }
						   }
						   if (FirstImageFileNameInDirectory(url.path) != nil)
						   {
							   // We also (or, more likely, instead...) have image files in the base directory itself
							   numCamFolders++;
							   // Add the base directory in, in order to pick up those image files too
							   dirContents = [dirContents arrayByAddingObject:@"."];
						   }
						   
						   // Now iterate properly, processing the files
						   for (NSString *cameraFolderPath in dirContents)
						   {
							   NSString *cameraFolderName = cameraFolderPath.lastPathComponent;
							   NSURL *contentsURL = PathToURL(cameraFolderPath, url);
							   if ((IsDirectory(contentsURL)) &&
								   (FirstImageFileNameInDirectory(contentsURL.path) != nil))
							   {
								   // This is a genuine camera folder containing images.
								   // Process a MIP for them, saving it into the appropriate folder
								   NSString *destDirPath = [SWF:@"%@/%@", destinationURL.path, cameraFolderName];
								   CHECK(CreateDirectoryIfNeeded(destDirPath));								   
								   NSString *destFilename = [SWF:@"%@/%@", destDirPath, mipFilename];
								   NSString *destMetadataPath = [SWF:@"%@/%@.plist", destDirPath, destFilename.lastPathComponent.stringByDeletingPathExtension];
								   MakeMipFromImagesInFolder(contentsURL.path, destFilename, progress, 1.0 / numCamFolders);
                                   MetadataForFrame *temp = [MetadataForFrame metadataForFirstFrameAtImagePath:FirstImageFileNameInDirectory(contentsURL.path)];
                                   [temp saveStandaloneMetadataFileAtPath:destMetadataPath];
								   mipCounter++;
								   if (progress.userCancelled)
									   break;
							   }
						   }
						   
#if 0
						   // Alternative code to generate a single sequence of frames that can be imported into ImageJ and turned into a hyperstack
						   // So far there isn't a GUI for this (need to make sure there is a fixed number of frames in each stack, discarding excess
						   // if necessary, offer a means of tweaking gain/offsets etc that is applied to all stacks that are processed, etc)
						   GUIMovieBuilder *builder = [[GUIMovieBuilder alloc] initAndRunBackgroundSession:@"Movie Builder"];
						   [builder addSequencesUsingDirectoryURL:url];
						   builder.tiffStem = [SWF:@"stack_%04d_", counter++];
						   
						   builder.maskEnabled = true;
						   builder.mask = [JRect rectWithNSRect:NSMakeRect(0, 0, 1000, 1000)];
						   builder.endFrame = 50;		// TODO: temp hack to deal with inconsistent frame counts in each stack
						   if (builder.sequences.count == 2)
							   [[builder.sequences objectAtIndex:1] setExposure:60];
						   
						   [builder saveMovie:nil andTiffs:destURL andMIP:nil];
						   [builder blockWhileBusy];
						   [builder release];
#endif
						   // We updateProgress rather than deltaProgress because we don't know
						   // what the individual stack-processing code may do in terms of delta progress
						   dispatch_async(dispatch_get_main_queue(), ^{ progress.progressValue = stackCounter; });
						   [pool drain];
						   if (progress.userCancelled)
							   break;
					   }
					   
					   
					   dispatch_async(dispatch_get_main_queue(), ^{
							   if (!progress.userCancelled)
								   completionBlock(mipCounter, destinationURL);
							   [progress closeWindowAndRelease];
					   });
				   });
}

void ProcessTheseStacksIntoMIPs(NSArray *stackURLs, void (^completionBlock)(int mipCounter, NSURL *destinationURL))
{
	NSOpenPanel *destinationPanel = [NSOpenPanel openPanel];
	// Could use the following to set the starting directory for the save panel:
	//	[spanel setDirectory:[path stringByExpandingTildeInPath]];
	destinationPanel.title = @"Save Generated MIPs In Folder...";
	destinationPanel.message = @"Choose the folder in which your MIP data will be saved";
	destinationPanel.prompt = @"Choose";
	destinationPanel.allowsMultipleSelection = FALSE;
	destinationPanel.canChooseDirectories = TRUE;
	destinationPanel.canChooseFiles = FALSE;
	destinationPanel.canCreateDirectories = TRUE;
	
	[destinationPanel beginWithCompletionHandler:^(NSInteger result)
	 {
		 dispatch_async(dispatch_get_main_queue(),
						^{
							if (result != NSOKButton)
								return;
							ProcessStacksIntoMIPsSavingAt(stackURLs, destinationPanel.URL, completionBlock);
						});
	 }];
}

void ProcessStacksIntoMIPs(void (^completionBlock)(int mipCounter, NSURL *destinationURL))
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.allowsMultipleSelection = TRUE;
	panel.canChooseDirectories = TRUE;
	panel.title = @"Choose a batch of stacks to process...";
	panel.message = @"Select stack folders - a MIP will be generated for each one.";
	
	[panel beginWithCompletionHandler:^(NSInteger result)
	 {
		 if (result == NSFileHandlingPanelOKButton)
			 ProcessTheseStacksIntoMIPs(panel.URLs, completionBlock);
	 }];
}
