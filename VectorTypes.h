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
    #if _MSC_VER
        /*  Unlike everybody else in the world, MSVC does not define the lesser instruction sets
            that are also available, e.g. __SSE2__ etc. We'll have to set those up here ourselves, which is a bit tedious. */
        #if defined ( __SSE4_2__ )
            // SSSE4.2
            #ifndef __SSE4_1__
                #define __SSE4_1__ 1
            #endif
            #ifndef __SSSE3__
                #define __SSSE3__ 1
            #endif
            #ifndef __SSE3__
                #define __SSE3__ 1
            #endif
            #ifndef __SSE2__
                #define __SSE2__ 1
            #endif
        #elif defined ( __SSE4_1__ )
            // SSSE4.1
            #ifndef __SSSE3__
                #define __SSSE3__ 1
            #endif
            #ifndef __SSE3__
                #define __SSE3__ 1
            #endif
            #ifndef __SSE2__
                #define __SSE2__ 1
            #endif
        #elif defined ( __SSSE3__ )
            // SSSE3
            #ifndef __SSE3__
                #define __SSE3__ 1
            #endif
            #ifndef __SSE2__
                #define __SSE2__ 1
            #endif
        #elif defined( __SSE3__ )
            // SSE3
            #ifndef __SSE2__
                #define __SSE2__ 1
            #endif
        #elif defined(_M_AMD64) || defined(_M_X64) || defined(__x86_64__) || (_M_IX86_FP == 2)
            // SSE2
            #ifndef __SSE2__
                #define __SSE2__ 1
            #endif
        #endif		
    #endif

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
     */

    #if _MSC_VER
        /*  It's difficult to work with SSE code on Windows, because MSVC does not distinguish different integer vector types.
            They are all __m128i. To be able to distinguish between them when expanding a template,
            we need separate wrapper classes for each type, to replace some of the roles of the GCC types
         */
        #include "vectori128.h"
        typedef Vec16uc vUInt8;
        typedef Vec8us  vUInt16;
        typedef Vec4ui  vUInt32;
        typedef Vec2uq  vUInt64;
        typedef Vec16c  vInt8;
        typedef Vec8s   vInt16;
        typedef Vec4i   vInt32;
        typedef Vec2q   vInt64;
        // On Windows I have compile errors with my floating-point vector code.
        // Since I don't have a need for that at the moment, I will just disable support for that here.
        //typedef __m128 vFloat;
        //typedef __m128d vDouble;
        #define NO_FLOAT_VECTOR 1
    #else
        /*  The subsequent alternative code does not work on all machines or gcc versions
            but it successfully distinguishes between signed and unsigned types on a mac.
            That is very useful for checking I am not mixing types unintentionally.   */
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
#elif __ARM_NEON__
    #include <arm_neon.h>
    typedef uint8x8_t vUInt8;
    typedef uint8x8_t vUInt16;
    typedef uint32x4_t vUInt32;
    typedef uint64x2_t vUInt64;
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
    typedef struct
    {
        int16_t i[8];
    } vInt32;
#endif

#endif
