//
//  jUtils.mm
//
// Copyright 2011-2015 Jonathan Taylor. All rights reserved.
//
//	A random assortment of utility functions!
//

#import <Cocoa/Cocoa.h>
#include <fts.h>

NSURL *PathToURL(NSString *path, NSURL *relativeTo)
{
	// Convert a path into an NSURL object, relative to another specified URL
	return [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding] relativeToURL:relativeTo];
}

NSURL *PathToURL(NSString *path)
{
	// Convert a path into an NSURL object, as an absolute path
	return [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
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

NSInteger alphabeticalOrder(id string1, id string2, void *)
{
    return [(NSString *)string1 caseInsensitiveCompare:(NSString *)string2];
}

NSInteger frameSortOrder(id string1, id string2, void *)
{
	// Comparison function used to work out the ordering of a list of image filenames
	// The complication comes in dealing with files numbered file1.tif, file2.tif... file10.tif... file100.tif
	const char *str1 = [((NSString *)string1).lastPathComponent UTF8String];
	const char *str2 = [((NSString *)string2).lastPathComponent UTF8String];
	// Identify the first dot in each filename
	const char *pos1 = strchr(str1, '.');
	const char *pos2 = strchr(str2, '.');
	if ((pos1 != NULL) && (pos2 != NULL))
	{
		// If both filenames have dots, and one is shorter than the other, order that one first.
		// e.g. file1.tif comes before file10.tif.
		if ((pos1 - str1) < (pos2 - str2))
			return NSOrderedAscending;
		if ((pos1 - str1) > (pos2 - str2))
			return NSOrderedDescending;
	}
	if ((pos1 == NULL) && (pos2 == NULL))
	{
		// If neither has a dot, and one is shorter than the other, order that one first.
		// e.g. folder1 comes before folder10
		size_t len1 = strlen(str1);
		size_t len2 = strlen(str2);
		if (len1 < len2)
			return NSOrderedAscending;
		if (len1 > len2)
			return NSOrderedDescending;
	}
	// Normal case: just do a standard string comparison.
	return [(NSString *)string1 caseInsensitiveCompare:(NSString *)string2];
}

NSInteger frameSortOrderForURLs(id url1, id url2, void *)
{
	return frameSortOrder(((NSURL *)url1).path, ((NSURL *)url2).path, nil);
}

bool IsImageFile(NSString *theFilename)
{
	// Returns true if the filename looks like an image file
	return ([theFilename hasSuffix:@".tif"] ||
			[theFilename hasSuffix:@".tiff"] ||
			[theFilename hasSuffix:@".bmp"] ||
			[theFilename hasSuffix:@".png"] ||
			[theFilename hasSuffix:@".jpg"] ||
			[theFilename hasSuffix:@".jpeg"] ||
			[theFilename hasSuffix:@".eps"]);
}

NSArray *ListImageFilesInDirectory(NSString *dir, bool sorted)
{
	// Returns an array containing NSStrings for each image file in a directory
#if 0
	NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
	// Filter to keep only the image files
	NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
	for (size_t i = 0; i < dirContents.count; i++)
	{
		if (IsImageFile([dirContents objectAtIndex:i]))
			[set addIndex:i];
	}
	dirContents = [dirContents objectsAtIndexes:set];
	dirContents = [dirContents sortedArrayUsingFunction:frameSortOrder context:nil];
	return dirContents;
#else
	// It will hopefully be faster to use lower-level APIs as follows.
	// Get a pointer to the first in a tree of structures representing the contents of the directory
	int len = strlen(dir.UTF8String) + 1;
	char pathBuffer[len];
	snprintf(pathBuffer, len, "%s", dir.UTF8String);
	char * const pathArray[2] = { pathBuffer, NULL };
	FTS *ftsHandle = fts_open(pathArray, FTS_LOGICAL | FTS_NOSTAT, NULL);
	// We do not actually use this next result, just need to do this before call to fts_children.
	// May possibly be better just to repeatedly do fts_read?
	fts_read(ftsHandle);

	// Now we can get the linked list of child files
	FTSENT *child = fts_children(ftsHandle, FTS_NAMEONLY);

	// Transfer the linked list into a mutable array
	NSMutableArray *dirContents2 = [NSMutableArray new];
	while (child != NULL)
	{
		// Add any image filenames to our array.
		/*	Note that this actual traversal and filtering doesn't seem to take
			a significant amount of time compared with the fts calls above	*/
		NSString *thisFile = [SWF:@"%s", child->fts_name];
		if (IsImageFile(thisFile))
			[dirContents2 addObject:thisFile];
		child = child->fts_link;
	}
	fts_close(ftsHandle);

	// Sort after filtering (let's make the array as small as possible before we sort it!)
	if (sorted)
		return [dirContents2 sortedArrayUsingFunction:frameSortOrder context:nil];
	return dirContents2;
#endif
}

void ForEveryImageFileInDirectory(NSString *dir, void (^callback)(NSString *))
{
	// Iterate over every image file in the specified directory sequentially,
	// in our best attempt at an ascending order
	// and call the callback block for it (passing in the full path to the file)
	NSArray *dirContents = ListImageFilesInDirectory(dir);
	for (NSString *theFilename in dirContents)
	{
		NSString *thePath = [SWF:@"%@/%@", dir, theFilename];
		/*	Make the callback. Note that we wrap the call with an autorelease pool.
			I very much doubt that will ever be a performance issue
			(if we're processing a file on disk there will always be a fair amount
			of time involved!), and this will help a lot with memory management,
			which will often grow out of control when processing a large dataset	*/
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		callback(thePath);
		[pool drain];
	}
}

void ForEveryImageFileInDirectoryConcurrent(NSString *dir, void (^callback)(NSString *))
{
	// Iterate over every image file in the specified directory,
	// and call the callback block for it (passing in the full path to the file)
	// This variant does not guarantee to process each file in any order, and indeed
	// may concurrently call the callback for multiple files on different threads.
	NSArray *dirContents = ListImageFilesInDirectory(dir);
	__block NSString *dir2 = dir;		// Work around compiler problem with referencing inside block...
	dispatch_apply(dirContents.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i){
		NSString *theFilename = [dirContents objectAtIndex:i];
		NSString *thePath = [SWF:@"%@/%@", dir2, theFilename];
		callback(thePath);
	});
}

NSString *FirstImageFileNameInDirectory(NSString *dir)
{
	// Returns the path ot the first image file found in the specified directory
	NSArray *dirContents = ListImageFilesInDirectory(dir);
	if (dirContents.count > 0)
		return [SWF:@"%@/%@", dir, [dirContents objectAtIndex:0]];
	else
		return nil;
}

// These next three functions are really designed for the Spim GUI codebase, but I am including them
// in this common codebase because they can be useful in other utility code as well

NSString *MetadataPathFromImagePath(NSString *fileName)
{
	return [[fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"plist"];
}

id MetadataKeyValueForFramePath(NSString *path, NSString *key)
{
    NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:MetadataPathFromImagePath(path)];
    return [metadata valueForKeyPath:key];      // Using valueForKeyPath instead of objectForKey allows for recursive addressing e.g. of toplevel.sublevel.key
}

void CopyMetadataForImageFile(NSString *sourceFilePath, NSString *destDirPath, NSString *destFileName)
{
	NSString *metadataPath = MetadataPathFromImagePath(sourceFilePath);
	if (destFileName == nil)
		destFileName = @"";	// Copy without specifying a dest filename (i.e. retain existing filename)
	NSString *cmdString = [SWF:@"cp \"%@\" \"%@/%@\"", metadataPath, destDirPath, destFileName];
	system([cmdString UTF8String]);
}

double dirCheckTime = 0, contentsTime = 0;
void PrintCompleteFolderPath(NSString *basePath, int indentationLevel, int leadingCharsToSkip)
{
    // Utility function to print out the complete folder path (useful for comparing/merging backup directory contents)
    double t1 = GetTime();
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:nil];
    dirContents = [dirContents sortedArrayUsingFunction:alphabeticalOrder context:nil];
    double t2 = GetTime();
    contentsTime += t2 - t1;
    double recursionTime = 0;
    
    if (indentationLevel == 0)
        leadingCharsToSkip = strlen(basePath.UTF8String)+1;     // +1 for the '/' character...
    
    for (NSString *theFilename in dirContents)
    {
        NSString *thePath = [SWF:@"%@/%@", basePath, theFilename];
        // Quick rejection of things we know are not directories
        if (IsImageFile(theFilename) ||
            [theFilename hasSuffix:@".plist"])
        {
            continue;
        }
        
        // Print out text files to make sure we are replicating any notes files
        if ([theFilename hasSuffix:@".txt"] || [theFilename hasSuffix:@".rtf"])
        {
            for (int i = 0; i < indentationLevel; i++)
                printf(" ");
            printf("%s\n", [thePath substringFromIndex:leadingCharsToSkip].UTF8String);
        }
        

        // Now do a proper check for directories
        if (IsDirectory([NSURL fileURLWithPath:thePath]))
        {
            double t3 = GetTime();
            for (int i = 0; i < indentationLevel; i++)
                printf(" ");
            printf("%s\n", [thePath substringFromIndex:leadingCharsToSkip].UTF8String);
//            printf("%s   %lf %lf\n", thePath.UTF8String, contentsTime, dirCheckTime);
            PrintCompleteFolderPath(thePath, indentationLevel+1, leadingCharsToSkip);
            double t4 = GetTime();
            recursionTime += t4 - t3;
        }
    }
    dirCheckTime += GetTime() - t2 - recursionTime;
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
