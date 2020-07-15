/*
 *	VectorTypes.h
 *
 *	Copyright 2010-2015 Jonathan Taylor. All rights reserved.
 *
 *  Platform-independent definitions of basic CPU vector types
 *
 */

#ifndef __VECTOR_TYPES_H__
#define __VECTOR_TYPES_H__

#include "jOSMacros.h"

#define HAS_VECTOR_SUPPORT 1        /* will be overridden, below, if we are just using a scalar substitute */

#if HAS_SSE
    #if __SSSE3__
        #include <tmmintrin.h>		// SSSE3 (supplemental SSE3)
    #elif __SSE3__
		#include <pmmintrin.h>
	#else
		#include <xmmintrin.h>
	#endif

    /*  It has turned out to be a bit of a nightmare to handle vector types in a way that:
            1. Is portable across all platforms, including totally different instruction sets
            2. Is type-safe, i.e. does not allow accidential re-interpretation of e.g. vUInt8 as vInt32.
        On the mac, clang seems to default to -flax-vector-conversions, which makes all these type distinctions synonymous anyway.
        If I want to do proper type safety checks I need to explicitly specify -fno-lax-vector-conversions.

        I should also watch out: it is possible that on old versions of gcc there may be problems, at least on OS X.
        vecLibTypes.h (included by Accelerate.h) defines the same types that I use, but on gcc versions <3.3 it looks like
        it defines them all as __m128i. That would cause conflict with what I do here.
        I could solve that problem just by renaming my own types (everywhere!), but hopefully it won't come to that.
     
        The following code seems to work on all machines I have tried, but has the problem that it
        does not distinguish between signed and unsigned types (they are just synonymous with each other).
        The subsequent alternative code does not work on all machines [TODO: I think... but I should retry now I understand things better]
        but successfully distinguishes between signed and unsigned types on a mac.  */
    #if 0
        typedef __v16qi                 vUInt8;
        typedef __v8hi                  vUInt16;
        typedef __v4si                  vUInt32;
        typedef __v2di                  vUInt64;

        typedef __v16qi                 vInt8;
        typedef __v8hi                  vInt16;
        typedef __v4si                  vInt32;
        typedef __v2di                  vInt64;

        typedef __v4sf                  vFloat;
        typedef __v2df                  vDouble;
    #else
        typedef unsigned char           vUInt8          __attribute__ ((__vector_size__ (16)));
        typedef unsigned short          vUInt16         __attribute__ ((__vector_size__ (16)));
        typedef unsigned int            vUInt32         __attribute__ ((__vector_size__ (16)));
        typedef unsigned long long      vUInt64         __attribute__ ((__vector_size__ (16)));

        typedef char                    vInt8           __attribute__ ((__vector_size__ (16)));
        typedef short                   vInt16          __attribute__ ((__vector_size__ (16)));
        typedef int                     vInt32          __attribute__ ((__vector_size__ (16)));
        typedef long long               vInt64          __attribute__ ((__vector_size__ (16)));

        typedef float                   vFloat          __attribute__ ((__vector_size__ (16)));
        typedef double                  vDouble         __attribute__ ((__vector_size__ (16)));
    #endif
#elif __arm__
    #include <arm_neon.h>
    typedef uint32x4_t vUInt32;
    typedef int32x4_t vInt32;
#elif HAS_ALTIVEC
	#if __SPU__
		#include <spu_intrinsics.h>
		#include <spu_mfcio.h> /* constant declarations for the MFC */
		#include <simdmath.h>
	#else
		#ifndef __APPLE_ALTIVEC__
			#include <altivec.h>

			// altivec.h defines bool for its own purposes, but my existing code uses it
			// in its normal form all over the place. Undefine it to prevent compile errors!
			#undef bool
		#endif
	#endif
	
	typedef vector float vFloat;
	typedef vector unsigned int vUInt32;
	typedef vector unsigned char vUInt8;
#else
    // Providing minimal support in the non-vector case, because it may make life easier
    // to be able to write some simple bits of code so they compile and work even in the absence
    // of any vector support at all.
    #undef HAS_VECTOR_SUPPORT
    #define HAS_VECTOR_SUPPORT 0
    // Note that we define this as a struct, because C does not allow us to return an array from a function
    // (but we can return a struct).
    typedef struct
    {
        uint32_t i[4];
    } vUInt32;
#endif

#if HAS_ALTIVEC || HAS_SSE
	typedef union
	{
		vFloat	vf;
	//	vUInt32	v32;
		vUInt8	vc;
		float	f[4];
		long	l[4];
		short	s[8];
	} VecUnion;
#endif

#endif
