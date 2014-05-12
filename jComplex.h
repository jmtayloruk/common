/*
 *	jComplex.h
 *
 *  Class to handle complex numbers.
 *	There are in fact two variants, one based on std::complex and one based on an altivec/SSE vector.
 *	The latter is in fact not very efficient on intel because the sort of instructions required for
 *	some operations are slow or unavailable. Fortunately this isn't too much of a problem because
 *	we are generally able to use jComplexPair for performance-critical code, and this works much
 *	better in a vector implementation.
 */
 
#ifndef __JCOMPLEX_H__
#define __JCOMPLEX_H__

#include <stdio.h>

#include <complex>
#include <vector>

#if COMPILE_JCOMPLEX_GSL_INTERFACE
	// We may want to link against GSL, but not include this in a prefix header
	// In that case the macro USES_GSL should be defined in order to ensure the
	// relevant parts of the jComplex class are defined
	#include <gsl/gsl_complex.h>
#endif


using std::complex;

#include "jCommon.h"
#include "jComplexAsStd.h"
#if __SSE3__
	#include "jComplexAsVector.h"
#endif

typedef jComplexAsStd jComplex;
typedef std::vector<jComplex> jComplexVector;

using std::polar;
using std::norm;

inline jComplex exp_i(double radianAngle)
{
	// This is a bit circuitous to make it work with jComplexAsVector and jComplexWrapper
	// The compiler should tidy it all up for us, though
	complex<double> result = std::polar(1.0, radianAngle);
	return jComplex(real(result), imag(result));
}

inline jComplex exp_i(jComplex z)
{
	// exp(i(a+ib)) = exp(ia) * exp(-b)
	return exp_i(z.real()) * exp(-z.imag());
}

inline jComplexAsStdBase<long double> exp_i(long double radianAngle)
{
	// This is a bit circuitous to make it work with jComplexAsVector and jComplexWrapper
	// The compiler should tidy it all up for us, though
	complex<long double> result = std::polar(1.0L, radianAngle);
	return jComplexAsStdBase<long double>(real(result), imag(result));
}

inline jComplex PowerOfI(long n)
{
#if 0
	n = (n & 3);
	if (n == 0)
		return 1.0;
	if (n == 1)
		return jComplex::i();
	if (n == 2)
		return -1.0;
	return jComplex(0, -1);
#else
	const jComplex powers[4] = { jComplex(1, 0), jComplex(0, 1), jComplex(-1, 0), jComplex(0, -1) };
	return powers[n&3];		// Note can't write n%4 as this does the wrong thing for n<0 !
#endif
}

inline jComplex powerOfMinusI(long n)
{
	n = (n & 3);
	if (n == 0)
		return 1.0;
	if (n == 1)
		return jComplex(0, -1);
	if (n == 2)
		return -1.0;
	return jComplex::i();
}

void Print(jComplex z);
#ifdef __GSL_COMPLEX_H__
	void Print(gsl_complex z);
#endif

inline double j_norm(const jComplex &z) { return SQUARE(real(z)) + SQUARE(imag(z)); }

inline jComplex cacos(const jComplex &z)
{
	return -jComplex::i() * log(z + jComplex::i() * sqrt(1.0 - z*z));
}

#endif
