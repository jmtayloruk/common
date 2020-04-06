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
	#if __SSE3__
		#include <pmmintrin.h>
        #include "tmmintrin.h"		// SSSE3 (supplemental SSE3)      // TODO: there should probably be a separate #if switch for this.
	#else
		#include <xmmintrin.h>
	#endif

	typedef __m128 vFloat;
	typedef __m128i vUChar;
    typedef __m128i vUInt32;
    typedef __m128i vInt32;
	typedef __m128d vDouble;
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
	typedef vector unsigned char vUChar;
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
		vUChar	vc;
		float	f[4];
		long	l[4];
		short	s[8];
	} VecUnion;
#endif

#endif
