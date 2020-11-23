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
    #elif __SSE2__
        #include <emmintrin.h>
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
     
        I have various different versions of code that I have tried, at various points:             */
    #if _MSC_VER
        /*  To compile SSE code on Windows, fundamentally the issue seems to be that I haven’t found a way
            to have the different vector types be truly distinct.
            If they all typedef to __m128i then the compiler can’t distinguish between them when expanding a template,
            so I can’t write separate code for each type and just have e.g. a vAdd wrapper that works for any/all field widths.
            And also, incidentally, operator- and similar are not available for vector types (of course, since they’re all just __m128i).
         */
	    typedef __m128i vUInt8;
	    typedef __m128i vUInt16;
	    typedef __m128i vUInt32;
	    typedef __m128i vUInt64;
	    typedef __m128i vInt8;
	    typedef __m128i vInt16;
	    typedef __m128i vInt32;
	    typedef __m128i vInt64;
		typedef __m128 vFloat;
		typedef __m128d vDouble;
	#elif 0
        // This earlier code seems to work on all machines I have tried, but has the problem that it
        // does not distinguish between signed and unsigned types (they are just synonymous with each other).

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
        /*  The subsequent alternative code does not work on all machines or gcc versions
            [TODO: I think... but I should retry now I understand things better]
            but it successfully distinguishes between signed and unsigned types on a mac.
            That is very useful for checking I am not mixing types unintentionally,
            and I think it may also be vital now that I am using operator- to do subtraction
            (since I think signed/unsigned subtraction are slightly different, aren't they?).   */
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
    typedef uint64x2_t vUInt64;
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
        uint8_t i[16];
    } vUInt8;
    typedef struct
    {
        uint16_t i[8];
    } vUInt16;
    typedef struct
    {
        uint32_t i[4];
    } vUInt32;
    typedef struct
    {
        uint64_t i[2];
    } vUInt64;
    typedef struct
    {
        int8_t i[16];
    } vInt8;
    typedef struct
    {
        int16_t i[8];
    } vInt16;
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
