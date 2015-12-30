//
//  jHighPrecisionFloat.cpp
//  scatter
//
//  Created by Jonny Taylor on 29/12/2015.
//
//

#include "jHighPrecisionFloat.h"
#include "jComplex.h"

#if JREAL_DEFINED
jComplexR exp_i(jreal radianAngle)
{
	return jComplexR(cos(radianAngle), sin(radianAngle));
}

jComplexR exp_i(jComplexR z)
{
	// exp(i(a+ib)) = exp(ia) * exp(-b)
	return exp_i(z.real()) * exp(-z.imag());
}

double AllowPrecisionLossReadingValue(jreal val) { return val.doubleVal(); }
double AllowPrecisionLossReadingValue_mayAlreadyBeDouble(jreal val) { return val.doubleVal(); }
double AllowPrecisionLossReadingValue_mayAlreadyBeDouble(double val) { return val; }
jreal AllowPrecisionLossOnParam(double val) { return jreal(val); }

#else

double AllowPrecisionLossReadingValue(jreal val) { return val; }
double AllowPrecisionLossReadingValue_mayAlreadyBeDouble(jreal val) { return val; }
jreal AllowPrecisionLossOnParam(double val) { return val; }

#endif

coord3R AllowPrecisionLossOnParam(coord3 val) { return coord3R(AllowPrecisionLossOnParam(val.x), AllowPrecisionLossOnParam(val.y), AllowPrecisionLossOnParam(val.z)); }
coordC3R AllowPrecisionLossOnParam(coordC3 val) { return coordC3R(AllowPrecisionLossOnParam(val.x), AllowPrecisionLossOnParam(val.y), AllowPrecisionLossOnParam(val.z)); }
jComplexR AllowPrecisionLossOnParam(jComplex val) { return jComplexR(AllowPrecisionLossOnParam(val.real()), AllowPrecisionLossOnParam(val.imag())); }
coord3 AllowPrecisionLossReadingValue(coord3R val) { return coord3(AllowPrecisionLossReadingValue(val.x), AllowPrecisionLossReadingValue(val.y), AllowPrecisionLossReadingValue(val.z)); }
coordC3 AllowPrecisionLossReadingValue(coordC3R val) { return coordC3(AllowPrecisionLossReadingValue(val.x), AllowPrecisionLossReadingValue(val.y), AllowPrecisionLossReadingValue(val.z)); }
jComplex AllowPrecisionLossReadingValue(jComplexR val) { return jComplex(AllowPrecisionLossReadingValue(val.real()), AllowPrecisionLossReadingValue(val.imag())); }
