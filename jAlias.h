//
//  JAlias.h
//  Simple Preview
//
//  Created by Jonathan Taylor on 07/04/2014.
//  Copyright 2014 Durham University. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface JAlias : NSObject {
	NSData *_bookmark;
}
@property (readonly) NSString *path;
@property (readonly) NSString *filename; // Works even if bookmark is unresolvable

+(id)aliasForPath:(NSString *)path;
-(id)initForPath:(NSString *)path;
-(BOOL)resolvesSameAs:(JAlias *)other;

@end
