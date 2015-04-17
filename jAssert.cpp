/*
 *	jAssert.h
 *
 *  Copyright 2011-2015 Jonathan Taylor. All rights reserved.
 *
 *  Code to handle assertions
 */

#include "jAssert.h"
#include "assert.h"

static BaseAssertionHandler defaultHandler;
BaseAssertionHandler *assertionHandler = &defaultHandler;

void BaseAssertionHandler::AssertionFailed(long line, const char *file)
{
	// Report the error
	// This code was moved out of assertion macro for code brevity and to make modification easier
	printf("Assertion failed on line %ld, file %s\n", line, file);
	PullDownCode();
	// Included to satisfy the compiler, which wants to see unambiguously that this function will never return
	assert(false);
}

void BaseAssertionHandler::PullDownCode(void)
{
	/*	We are going to force an instant crash in order to trigger a break in the debugger (if present)
		As a result we need to flush buffers first - otherwise the message about the assertion may
		never show up!	*/
	fflush(stdout);
	fflush(stderr);
	
	// Now trigger the crash by dereferencing a null pointer
	// Note that the analyzer doesnt like this, so we hide it from the analyzer
#ifndef __clang_analyzer__
	*((volatile long *)0L) = 0;
#endif
	// Included to satisfy the compiler, which wants to see unambiguously that this function will never return
	assert(false);
}

bool BaseAssertionHandler::CheckCondition(bool condition, long line, const char *file)
{
	if (!condition)
	{
		// Report the error
		printf("Check failed on line %ld, file %s\n", line, file);
	}
	return condition;
}
