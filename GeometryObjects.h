/*
 *  GeometryObjects.h
 *
 *	Copyright 2010-2015 Jonathan Taylor. All rights reserved.
 *
 *	Obj-C objects to wrap an NSRect and an NSPoint.
 *	The main purpose is to allow GUI code to bind to individual variables within the structure
 *
 */

#import "GeometryObjectsC.h"

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
@property (readonly) int everything;	// Can be monitored using KVO to see if any variable changes

@end

@interface JPoint2 : NSObject
{
	NSPoint point;
}

+(JPoint2*)pointWithNSPoint:(const NSPoint)r;
+(JPoint2*)pointWithCoord2:(const coord2)r;
-(id)initWithPoint:(const NSPoint)r;

@property (readwrite) float x;
@property (readwrite) float y;
@property (readwrite) const NSPoint ns;
@property (readonly) int everything;	// Can be monitored using KVO to see if any variable changes

@end

@interface JPoint3 : NSObject
{
    float _x, _y, _z;        // Variable type chosen to be consistent with JPoint2
}

+(JPoint3*)pointWithCoord3:(const coord3)r;

@property (readwrite) float x;
@property (readwrite) float y;
@property (readwrite) float z;
@property (readwrite) const NSPoint nsXY;
@property (readonly) int everything;	// Can be monitored using KVO to see if any variable changes

@end

// This class is named to be consistent with the others above, but it's a bit of a misnomer
// since IntegerPoint is also one of my own classes.
@interface JIntegerPoint : NSObject
{
    IntegerPoint point;
}

+(JIntegerPoint*)pointWithIntegerPoint:(const IntegerPoint&)r;
-(id)initWithPoint:(const IntegerPoint&)r;

@property (readwrite) float x;
@property (readwrite) float y;
@property (readwrite) IntegerPoint ip;
@property (readonly) int everything;	// Can be monitored using KVO to see if any variable changes

@end
