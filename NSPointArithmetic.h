/*
 *  NSPointArithmetic.h
 *  Simple Preview
 *
 *  Created by Jonathan Taylor on 02/03/2011.
 *  Copyright 2011 Durham University. All rights reserved.
 *
 */

inline NSPoint operator+(NSPoint a, NSPoint b)
{
	NSPoint result = { a.x + b.x, a.y + b.y };
	return result;
}

inline NSPoint operator-(NSPoint a, NSPoint b)
{
	NSPoint result = { a.x - b.x, a.y - b.y };
	return result;
}

inline NSPoint operator/(NSPoint a, float b)
{
	NSPoint result = { a.x / b, a.y / b };
	return result;
}

inline NSPoint operator*(NSPoint a, float b)
{
	NSPoint result = { a.x * b, a.y * b };
	return result;
}

inline NSPoint operator+(NSPoint a, NSSize b)
{
	NSPoint result = { a.x + b.width, a.y + b.height };
	return result;
}
