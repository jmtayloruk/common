//
//  jUtils.mm
//
// Copyright 2011-2015 Jonathan Taylor. All rights reserved.
//
//	A random assortment of utility functions!
//

#import <Cocoa/Cocoa.h>
#import "CocoaProgressWindow.h"

// Determine whether this selector is available - it's useful, but not available in old OS versions
static bool selectorAvailable = [NSURL respondsToSelector:@selector(fileURLWithFileSystemRepresentation:isDirectory:relativeToURL:)];

NSURL *PathToURL(NSString *path, NSURL *relativeTo)
{
	/*  Convert a path into an NSURL object, relative to another specified URL
        Note that there is no need to worry about specifying a scheme in my string, since this is a relative URL
    
        Note: care is needed when processing a filename containing certain characters (such as a "smart quote")
		with NSASCIIStringEncoding this would fail (and return nil) - presumably because that's a non-ASCII character.
		I think that NSUTF8StringEncoding seems to work.
		NSUnicodeStringEncoding does not work because even for regular filenames it makes URL.path nil, and I rely on that in quite a few places in my code
	 
		I have also encountered warnings on the Edinburgh system:
			CFURLSetTemporaryResourcePropertyForKey failed because it was passed this URL which has no scheme: ///Users/spim/Victoria/AMA/4dpf/4dpf%20flkgfprenkr%20fISH%206%20for%20tunnel/2017-11-20%20flk%20fish%206%20ablation/
		I wonder if this is the fault of this function, because I am not creating a file URL explicitly.
		-> But actually it seems that it *is* being recognised as a file URL, so I think I need to investigate further to understand
			where exactly the original warning is appearing from
		However, I am not sure exactly where in the code the lack of URL scheme is causing issues...
		I tried to reproduce the problem on the Edinburgh system but did not succeed - I don't know if it was an old version that was
		running to produce those log errors, perhaps?
		When the error appeared, there did not seem to be anything controversial about the URL path, it just had some spaces in it.
     */
    CHECK(relativeTo != nil);       // Otherwise should call PathToURL(path)
    if ((false))//selectorAvailable)
    {
        // I was experimenting with this code branch, but I am doubtful about whether I am
        // handling the path in an appropriate way for all encodings.
        // It's also rather disappointing that I need to specify whether the object is a directory or not.
        bool isDirectory = IsDirectory(PathToURL([relativeTo.path stringByAppendingPathComponent:path]));
        return [NSURL fileURLWithFileSystemRepresentation:path.UTF8String//[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding].UTF8String
                                              isDirectory:isDirectory
                                            relativeToURL:relativeTo];
    }
    else
        return [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] relativeToURL:relativeTo];
}

NSURL *PathToURL(NSString *path)
{
	// Convert a path into an NSURL object, as an absolute path
	return [NSURL fileURLWithPath:path];
}

bool IsDirectory(NSURL *fileURL)
{
	// Returns true if the supplied URL is a valid URL for a filesystem directory
    CFURLRef cfURLRef = (CFURLRef)fileURL;
    
    LSItemInfoRecord info;
    LSCopyItemInfoForURL(cfURLRef, kLSRequestAllFlags, &info);
    if (info.flags & kLSItemInfoIsContainer)
        return true;
	return false;
} 

bool DirectoryPathExists(NSString *folderPath)
{
    // Note: this might well be pretty much duplicating the functionality of IsDirectory,
    // but if nothing else it seems helpful to have both functions as their different titles can be more informative in different contexts...
    BOOL isDir;
    return [[NSFileManager defaultManager] fileExistsAtPath:folderPath isDirectory:&isDir] && isDir;
}

NSString *GetUserDocumentDirectory(void)
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	if (!CHECK(paths.count >= 1))
		return nil;		// Surely should never happen...?
	return [paths objectAtIndex:0];
}

bool/*success*/ CreateDirectoryIfNeeded(NSString *path)
{
	// Returns true unless we fail to create the directory for some reason
	NSError *err;
	bool ok = [[NSFileManager defaultManager] createDirectoryAtPath:path
										withIntermediateDirectories:YES
														 attributes:nil
															  error:&err];
	if (!CHECK(ok))
	{
        // Note that createDirectoryAtPath does not seem to be fully threadsafe:
        // if we call createDirectoryAtPath from two different threads then the second attempt may return error 516 (already exists).
        // If we encounter this, it's really up to the calling code to figure out where the race condition is coming in, and eliminate it.
        // This seems to be a harmless failure - retry seems typically to succeed.
		NSLog(@"Failed to create directory %@ (%ld, %s)\n", path, (long)err.code, err.localizedFailureReason.UTF8String);
		ok = [[NSFileManager defaultManager] createDirectoryAtPath:path
											withIntermediateDirectories:YES
															 attributes:nil
																  error:&err];
		if (ok)
			NSLog(@"Retry succeeded\n");
	}
	return ok;
}

bool/*success*/ CreateDirectoryIfNeeded(NSURL *url)
{
	return CreateDirectoryIfNeeded(url.path);
}

NSString *CreateTemporaryDirectory(void)
{
    NSString *guid = [[NSProcessInfo processInfo] globallyUniqueString];
    NSString *destPath = [SWF:@"%@/%@", NSTemporaryDirectory(), guid];
	ALWAYS_ASSERT(CreateDirectoryIfNeeded(destPath));
    return destPath;
}

void ForEverySubdirectoryInDirectory(NSURL *dir, void (^callback)(NSURL *))
{
	NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir.path error:nil];
	for (NSString *filename in dirContents)
	{
		NSURL *subdirectoryURL = PathToURL(filename, dir);
        /*  I have had PathToURL fail before on unusual filenames.
            I think I have fixed that, but am putting in this check out of paranoia in case of future issues    */
        if (CHECK(subdirectoryURL != nil))
        {
            if (IsDirectory(subdirectoryURL))
                callback(subdirectoryURL);
        }
	}
}

// These next three functions are really designed for the Spim GUI codebase, but I am including them
// in this common codebase because they can be useful in other utility code as well

NSString *MetadataPathFromImagePath(NSString *fileName)
{
	return [fileName.stringByDeletingPathExtension stringByAppendingPathExtension:@"plist"];
}

void CopyMetadataForImageFile(NSString *sourceFilePath, NSString *destDirPath, NSString *destFileName)
{
	NSString *metadataPath = MetadataPathFromImagePath(sourceFilePath);
	if (destFileName == nil)
		destFileName = @"";	// Copy without specifying a dest filename (i.e. retain existing filename)
	NSString *cmdString = [SWF:@"cp \"%@\" \"%@/%@\"", metadataPath, destDirPath, destFileName];
	system([cmdString UTF8String]);
}

void UpdateKeys(id owner, ...)
{
	// Call will/didChangeValueForKey for each of the NSString keys that are passed in.
	va_list		argList;
	va_start(argList, owner);
	id obj;
	while ((obj = va_arg(argList, id)) != nil)
	{
		ALWAYS_ASSERT([obj isKindOfClass:[NSString class]]);
		[owner willChangeValueForKey:obj];
		[owner didChangeValueForKey:obj];
	}
	va_end(argList);
}

bool StringIsInList(NSString *s, ...)
{
	// Returns true if s matches one of the subsequent NSStrings passed in to this function
	va_list		argList;
	va_start(argList, s);
	id obj;
	while ((obj = va_arg(argList, id)) != nil)
	{
		ALWAYS_ASSERT([obj isKindOfClass:[NSString class]]);
		if ([s isEqualToString:obj])
			return true;
	}
	va_end(argList);
	return false;
}

NSString *SizeStringInGBOrMB(double sizeInBytes)
{
    double size = sizeInBytes / 1e6;
    if (size > 100.0)
        return [SWF:@"%.1lf GB", size/1e3];
    return [SWF:@"%.1lf MB", size];
}

id ResurrectWeakRef(MAZeroingWeakRef *&ref, BlockReturningObject resurrectionBlock)
{
	// Ensure that the weak reference exists. If it does not, then call the supplied block
	// in order to re-create the object.
	if (ref.target == nil)
	{
		[ref release];
		ref = [[MAZeroingWeakRef alloc] initWithTarget:resurrectionBlock()];
	}
	return ref.target;
}

id ResurrectAndShowWeakWindowRef(MAZeroingWeakRef *&ref, BlockReturningObject resurrectionBlock)
{
	// Ensure that the weak reference (to an NSWindow) exists. If it does not,
	// then call the supplied block in order to re-create the window.
	// Then show the window.
	ResurrectWeakRef(ref, resurrectionBlock);
	NSWindow *win = [ref.target window];
	[win makeKeyAndOrderFront:nil];
	return ref.target;
}

void dispatch_groups_async(dispatch_group_t group1, dispatch_group_t group2, dispatch_queue_t queue, dispatch_block_t block)
{
    if (group2 != nil)
        dispatch_group_enter(group2);
    dispatch_group_async(group1, queue, ^{
        block();
        if (group2 != nil)
            dispatch_group_leave(group2);
    });
}
