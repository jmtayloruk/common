//
//  jAlias.mm
//  Simple Preview
//
//  Created by Jonathan Taylor on 07/04/2014.
//  Copyright 2014 Durham University. All rights reserved.
//

#import "jAlias.h"

@interface JAlias()
	@property (readwrite, copy) NSData *bookmark;
@end

@implementation JAlias

+(id)aliasForPath:(NSString *)path
{
	return [[[JAlias alloc] initForPath:path] autorelease];
}

-(id)initForPath:(NSString *)path
{
	return [self initForURL:[NSURL fileURLWithPath:path]];
}

+(id)aliasForURL:(NSURL *)url
{
	return [[[JAlias alloc] initForURL:url] autorelease];
}

-(id)initForURL:(NSURL *)url
{
	if (!(self = [super init]))
		return nil;
	NSError *err;
	self.bookmark = [url bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:&err];
	return self;
}

-(void)dealloc
{
	self.bookmark = nil;
	[super dealloc];
}

-(id)copyWithZone:(NSZone *)zone;
{
	JAlias *copy = [[[self class] alloc] init];
	copy.bookmark = self.bookmark;
    return copy;
}

-(NSString *)path
{
	BOOL stale;
	NSError *error;
	NSURL *url = [NSURL URLByResolvingBookmarkData:self.bookmark options:NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:&stale error:&error];
	return [url path];
}

-(NSString *)filename
{
	// Works even if bookmark is unresolvable
	NSDictionary *dict = [NSURL resourceValuesForKeys:[NSArray arrayWithObject:NSURLNameKey] fromBookmarkData:self.bookmark];
	return [dict objectForKey:NSURLNameKey];
}

-(BOOL)resolvesSameAs:(JAlias *)other
{
	return ([self.path compare:other.path] == NSOrderedSame);
}

@synthesize bookmark = _bookmark;

@end
