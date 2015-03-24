/*
 *  GeometryObjects.h
 *  Simple Preview
 *
 *  Created by Jonathan Taylor on 26/03/2012.
 *  Copyright 2012 Durham University. All rights reserved.
 *
 */

@interface JRect : NSObject
{
	NSRect rect;
}

+(JRect*)rectWithNSRect:(const NSRect)r;
-(id)initWithRect:(const NSRect)r;
-(JRect*)roundedToIntegers;

@property (readwrite) float x;
@property (readwrite) float y;
@property (readwrite) float w;
@property (readwrite) float h;
@property (readwrite) const NSRect ns;
@property (readonly) int everything;

@end

@interface JPoint2 : NSObject
{
	NSPoint point;
}

+(JPoint2*)pointWithNSPoint:(const NSPoint)r;
-(id)initWithPoint:(const NSPoint)r;

@property (readwrite) float x;
@property (readwrite) float y;
@property (readwrite) const NSPoint ns;
@property (readonly) int everything;

@end

struct IntegerPoint
{
	int x, y;
};

// Sadly I can't seem to get pass-by-reference to work with this - some of my ObjC property-based
// code doesn't compile if I pass a and b by reference. Not sure if this would be fix-able, but
// I'm just going to leave it as-is for now.
inline bool operator!=(IntegerPoint a, IntegerPoint b) { return ((a.x != b.x) || (a.y != b.y)); }
