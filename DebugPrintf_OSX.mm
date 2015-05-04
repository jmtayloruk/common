//
//  DebugPrintf_OSX.mm
//
//  Copyright 2015 Jonathan Taylor. All rights reserved.
//
//	Implementation of DebugPrintf suitable for running on OS X
//	Only one platform-specific implementation file like this one should be included in a project,
//	or else there will be linker errors due to multiple function definitions.
//

#include "DebugPrintf.h"
#include "jCommon.h"
#include <Cocoa/Cocoa.h>

void DebugPrintf(const char *format, ...)
{
	va_list args;

	// Print to stderr
	va_start(args, format);
	vfprintf(stderr, format, args);
	va_end(args);
	
	// Also print to Apple's console log facility, to ensure it shows up when running standalone (not under debugger)
	va_start(args, format);
	NSLogv([SWF:@"%s", format], args);
	va_end(args);
}
