/*
 *	jComplex.cpp
 *
 *  A few utility functions for complex numbers.
 */

#ifdef USES_GSL
	#define COMPILE_JCOMPLEX_GSL_INTERFACE 1
#else
	#ifdef __GSL_COMPLEX_H__
		#define COMPILE_JCOMPLEX_GSL_INTERFACE 1
	#else
		#define COMPILE_JCOMPLEX_GSL_INTERFACE 0
	#endif
#endif

#include "jComplex.h"

void Print(jComplex z)
{
	printf("{%.12le, %.12le}", z.real(), z.imag());
}

#if COMPILE_JCOMPLEX_GSL_INTERFACE
void Print(gsl_complex z)
{
	printf("{%le, %le}", GSL_REAL(z), GSL_IMAG(z));
}

template<> jComplexAsStdBase<double>::jComplexAsStdBase(const gsl_complex &z) : complex<double>(GSL_REAL(z), GSL_IMAG(z))
{
}

#endif

#ifdef __JCOMPLEX_AS_VECTOR_H__
  #if COMPILE_JCOMPLEX_GSL_INTERFACE
	jComplexAsVector::jComplexAsVector(const gsl_complex &inZ)
	{
		SetReIm(GSL_REAL(inZ), GSL_IMAG(inZ));
	}
  #endif
#endif
