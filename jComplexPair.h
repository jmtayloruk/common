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
  #if 0
	#include "jComplexPairAsVector.h"
	typedef jComplexPairAsVector jComplexPair;
  #else
    #include "jComplexPairAsVector256.h"
	typedef jComplexPairAsVector256 jComplexPair;
#endif
	#define COMPLEX_PAIR_IS_VECTOR 1
#else
	typedef jComplexPairSplit jComplexPair;
	#define COMPLEX_PAIR_IS_VECTOR 0
#endif

#endif
