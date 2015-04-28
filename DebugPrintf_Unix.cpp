//
//  DebugPrintf_Unix.cpp
//
//  Copyright 2015 Jonathan Taylor. All rights reserved.
//
//	Implementation of DebugPrintf suitable for running on OS X
//	Only one platform-specific implementation file like this one should be included in a project,
//	or else there will be linker errors due to multiple function definitions.
//

#include "DebugPrintf.h"

void DebugPrintf(const char *format, ...)
{
	// Just call through to stderr
	va_list args;
	va_start(args, format);
	vfprintf(stderr, format, args);
	va_end(args);
}
