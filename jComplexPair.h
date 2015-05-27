/*
 *	jComplexPair.h
 *
 *  Class representing two complex numbers.
 *	There are in fact two variants, one which stores the values as two jComplex types,
 *	and one based on two altivec/SSE vectors, one for the real parts and one for the complex parts.
 *	The latter is generally extremely efficient on systems that support it. It has not yet been
 *	implemented for altivec - this would probably require a bit of alternative code to be written.
 */

#ifndef __JCOMPLEX_PAIR_H__
#define __JCOMPLEX_PAIR_H__

#include "jComplex.h"
#include "VectorTypes.h"
#include "jComplexPairSplit.h"

#if HAS_SSE
    #define COMPLEX_PAIR_IS_VECTOR 1
  #if HAS_AVX
    #include "jComplexPairAsVector256.h"
    typedef jComplexPairAsVector256 jComplexPair;
  #else
	#include "jComplexPairAsVector.h"
	typedef jComplexPairAsVector jComplexPair;
  #endif
#else
    #define COMPLEX_PAIR_IS_VECTOR 0
	typedef jComplexPairSplit jComplexPair;
#endif

#endif
