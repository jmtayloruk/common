//
//  jUtils.mm
//  Simple Preview
//
//  Created by Jonathan Taylor on 30/09/2010.
//  Copyright 2010 Durham University. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NSURL *PathToURL(NSString *path, NSURL *relativeTo)
{
	return [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding] relativeToURL:relativeTo];
}

NSURL *PathToURL(NSString *path)
{
	return [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
}

bool IsDirectory(NSURL *fileURL)
{
    FSRef               ref;
    CFURLRef cfURLRef = (CFURLRef)fileURL;
    
    // Get the FSRef for the URL
    if (CFURLGetFSRef(cfURLRef, &ref) == TRUE)
    {
		LSItemInfoRecord info;
		LSCopyItemInfoForRef(&ref, kLSRequestAllFlags, &info);
		if (info.flags & kLSItemInfoIsContainer)
			return true;
	}
	return false;
} 

NSInteger frameSortOrder(id string1, id string2, void *)
{
	const char *str1 = [(NSString *)string1 UTF8String];
	const char *str2 = [(NSString *)string2 UTF8String];
	const char *pos1 = strchr(str1, '.');
	const char *pos2 = strchr(str2, '.');
	if ((pos1 != NULL) && (pos2 != NULL))
	{
		if ((pos1 - str1) < (pos2 - str2))
			return NSOrderedAscending;
		if ((pos1 - str1) > (pos2 - str2))
			return NSOrderedDescending;
	}
	return [(NSString *)string1 caseInsensitiveCompare:(NSString *)string2];
}

bool IsImageFile(NSString *theFilename)
{
	return ([theFilename hasSuffix:@".tif"] || [theFilename hasSuffix:@".tiff"] || [theFilename hasSuffix:@".bmp"] || [theFilename hasSuffix:@".png"] || [theFilename hasSuffix:@".jpg"] || [theFilename hasSuffix:@".jpeg"] || [theFilename hasSuffix:@".eps"]);
}

NSArray *ListImageFilesInDirectory(NSString *dir)
{
	NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
	dirContents = [dirContents sortedArrayUsingFunction:frameSortOrder context:nil];	// ?? is this leaking the array? possibly...
	NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
	for (size_t i = 0; i < dirContents.count; i++)
	{
		if (IsImageFile([dirContents objectAtIndex:i]))
			[set addIndex:i];
	}
	return [dirContents objectsAtIndexes:set];
}

void ForEveryImageFileInDirectory(NSString *dir, void (^callback)(NSString *))
{
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
	NSArray *dirContents = ListImageFilesInDirectory(dir);
	if (dirContents.count > 0)
		return [SWF:@"%@/%@", dir, [dirContents objectAtIndex:0]];
	else
		return nil;
}

void UpdateKeys(id owner, ...)
{
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
	if (ref.target == nil)
	{
		[ref release];
		ref = [[MAZeroingWeakRef alloc] initWithTarget:resurrectionBlock()];
	}
	return ref.target;
}

id ResurrectAndShowWeakWindowRef(MAZeroingWeakRef *&ref, BlockReturningObject resurrectionBlock)
{
	ResurrectWeakRef(ref, resurrectionBlock);
	NSWindow *win = [ref.target window];
	[win makeKeyAndOrderFront:nil];
	return ref.target;
}
