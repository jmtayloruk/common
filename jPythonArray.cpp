#include "jPythonArray.h"

template<> int ArrayType<double>(void) { return NPY_DOUBLE; }
template<> int ArrayType<float>(void) { return NPY_FLOAT; }
template<> int ArrayType<int>(void) { return NPY_INT; }
