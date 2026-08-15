/*
 *	jCommon.h
 *
 *  Copyright 2011-2015 Jonathan Taylor. All rights reserved.
 *
 *  A selection of generic macros etc
 */

#ifndef __JCOMMON_H__
#define __JCOMMON_H__
 
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <algorithm>

#include "jOSMacros.h"		// Defines the macro OS_X, among other things!
#if OS_X
	// This should be a proper conditional (from ./configure script...), but for now I'll just use it for parameter checking
	// on my OS X machines without worrying about availability on other machines.
    #include <sys/cdefs.h>      // for __printflike
    #define PRINTFLIKE(A,B) __printflike((A),(B))
    #define SCANFLIKE(A,B)  __scanflike((A),(B))
#else
	#define PRINTFLIKE(A,B) 
    #define SCANFLIKE(A,B)
#endif
#define RESTRICT __restrict

#ifdef __GNUC__
    #define WANT_INLINE __attribute__((always_inline))
    #define NORETURN __attribute__((__noreturn__))
    #define ATOMIC_POSTINCREMENT(ADDR) __sync_fetch_and_add(ADDR, 1)
    #define ATOMIC_POSTDECREMENT(ADDR) __sync_fetch_and_sub(ADDR, 1)
#else
    // This alternative branch is probably for Windows.
    #include <windows.h>
    // Note that we could write proper equivalent code for the following no-op macros.
    // We would check _WIN32 to identify Windows, or _MSC_VER to identify MS compilers
    // (or see https://sourceforge.net/p/predef/wiki/Home/)
    // and the equivalent is probably e.g. __declspec(noreturn), and possibly __declspec(inline)
    #define WANT_INLINE
    #define NORETURN
    #define __PRETTY_FUNCTION__ __FUNCSIG__
    // The following only work for 'long' data types
    #define ATOMIC_POSTINCREMENT(ADDR) (InterlockedIncrement(ADDR)-1)
    #define ATOMIC_POSTDECREMENT(ADDR) (InterlockedDecrement(ADDR)+1)

    // I'm not convinced that defining __attribute__ is wise, but it might be a workaround.
    // Incidentally there's not much point testing #ifndef __attribute__, since it's not a macro on gcc!
    // But no harm in doing it just in case.
    #ifndef __attribute__
        #define __attribute__()
    #endif
#endif

/*	The intention here was to offer a macro to assist with branch prediction,
	by indicating whether the condition is expected to be true or false.
	Intended use: 
		if (EXPECT(COMPARISON, RESULT))
			stuff;
	However I found (around 2011 I suspect?) that on an intel mac __builtin_expect
	seemed to generate poor code. As a result, for now this macro doesn't do anything
	beyond just evaluate the comparison	*/
#define EXPECT(COMPARISON, RESULT) (COMPARISON)

#include "jAssert.h"
#include "jHighPrecisionFloat.h"      // Will just define jreal as double, unless compile-time flag specifically set

/*	There are some asserts which cause the code to run
	ORDERS OF MAGNITUDE more slowly if they are compiled in.
	They are truly for debugging purposes only.
	They should be accompanied by higher-level tests
	which will spot that _something_ has gone wrong.		*/
#define EXTRA_ASSERTS 0
#if EXTRA_ASSERTS
	#define ASSERT2(CONDITION) ALWAYS_ASSERT(CONDITION)
#else
	#define ASSERT2(CONDITION) IGNORE_CONDITION(CONDITION)
#endif

template<class T> T SQUARE(const T &a) { return a*a; }
template<class T> T CUBE(const T &a) { return a*a*a; }

#ifndef MIN
	#define MIN(A, B) std::min((A), (B))
#endif
#ifndef MAX
	#define MAX(A, B) std::max((A), (B))
#endif
#ifndef LIMIT
    #define LIMIT(N, L, U) (std::max(std::min((N), (U)), (L)))
#endif

#ifndef _WIN32
    #define SOCKET_ERROR        -1
#endif
extern const int noSigPipe;

#define SWF NSString stringWithFormat

#endif
