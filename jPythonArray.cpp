#define NPY_NO_DEPRECATED_API NPY_1_7_API_VERSION
#include "jPythonArray.h"
#include <complex>

template<> int ArrayType<double>(void) { return NPY_DOUBLE; }
template<> int ArrayType<float>(void) { return NPY_FLOAT; }
template<> int ArrayType<int>(void) { return NPY_INT32; }
template<> int ArrayType<unsigned char>(void) { return NPY_UBYTE; }
template<> int ArrayType<unsigned short>(void) { return NPY_USHORT; }
template<> int ArrayType< std::complex<float> >(void) { return NPY_CFLOAT; }
template<> int ArrayType< std::complex<double> >(void) { return NPY_CDOUBLE; }

bool gPythonArraysOK = true;
