/*
 *	jCommon.h
 *
 *  A selection of generic macros etc
 */

#ifndef __JCOMMON_H__
#define __JCOMMON_H__
 
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "jOSMacros.h"
#include "jAssert.h"

/*	There are some asserts which cause the code to run
	ORDERS OF MAGNITUDE more slowly if they are compiled in.
	They are truly for debugging purposes only.
	There should be higher-level tests which will spot that _something_
	has gone wrong if these asserts are failed.		*/
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

#define SOCKET_ERROR        -1
extern const int noSigPipe;

#if CRAY
	// The cray compiler doesn't seem to accept this attribute on template functions (which don't have a prototype prior to being defined)
	#define WANT_INLINE
#else
	#define WANT_INLINE __attribute__((always_inline))
#endif

// On an intel mac __builtin_expect seems to generate poor code. I should probably look into that more,
// and definitely evaluate it on ppc...
#define EXPECT(COMPARISON, RESULT) (COMPARISON)

inline double random_01(void)
{
	return ((double)random()) / 2147483647.0;		// (2^31 - 1)
}

inline double random_pm1(void)
{
	return -1.0 + ((double)random()) / 1073741823.0;		// (2^30 - 1)
}

#endif
