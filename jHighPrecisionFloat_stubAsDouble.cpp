/*
 *	jHighPrecisionFloat_stubAsDouble.cpp
 *
 *  Class representing a floating-point number, but potentially to higher (or lower) precision
 *	than supported by the ubiquitous 'double' type.
 *
 *	This implementation is just a wrapper around the 'double' type.
 *	Its purpose is just to help test the migration of existing code to the jHighPrecisionFloat type,
 *	but without actually adding any extra precision(!). 
 *	A modern compiler should hopefully be able to compile this into code that has little or no overhead
 *	compared to the native 'double' type.
 */

#if USE_JREAL

void Print(jHighPrecisionFloat x)
{
	x.Print();
}

int floor_int(const jHighPrecisionFloat &val) { return int(floor(val.doubleVal())); } 		// Calculate floor(val) and convert to int
bool is_nan(const jHighPrecisionFloat &val) { return val.doubleVal() != val.doubleVal(); }
jHighPrecisionFloat fabs(const jHighPrecisionFloat &val) { return AllowPrecisionLossOnParam(fabs(val.doubleVal())); }
jHighPrecisionFloat abs(const jHighPrecisionFloat &val) { return AllowPrecisionLossOnParam(fabs(val.doubleVal())); }
jHighPrecisionFloat exp(const jHighPrecisionFloat &val) { return AllowPrecisionLossOnParam(exp(val.doubleVal())); }
jHighPrecisionFloat sqrt(const jHighPrecisionFloat &val) { return AllowPrecisionLossOnParam(sqrt(val.doubleVal())); }
jHighPrecisionFloat log(const jHighPrecisionFloat &val) { return AllowPrecisionLossOnParam(log(val.doubleVal())); }
jHighPrecisionFloat sin(const jHighPrecisionFloat &val) { return AllowPrecisionLossOnParam(sin(val.doubleVal())); }
jHighPrecisionFloat sinh(const jHighPrecisionFloat &val) { return AllowPrecisionLossOnParam(sinh(val.doubleVal())); }
jHighPrecisionFloat cos(const jHighPrecisionFloat &val) { return AllowPrecisionLossOnParam(cos(val.doubleVal())); }
jHighPrecisionFloat cosh(const jHighPrecisionFloat &val) { return AllowPrecisionLossOnParam(cosh(val.doubleVal())); }
jHighPrecisionFloat tan(const jHighPrecisionFloat &val) { return AllowPrecisionLossOnParam(tan(val.doubleVal())); }
jHighPrecisionFloat asin(const jHighPrecisionFloat &val) { return AllowPrecisionLossOnParam(asin(val.doubleVal())); }
jHighPrecisionFloat acos(const jHighPrecisionFloat &val) { return AllowPrecisionLossOnParam(acos(val.doubleVal())); }
jHighPrecisionFloat atan2(const jHighPrecisionFloat &x, const jHighPrecisionFloat &y) { return AllowPrecisionLossOnParam(atan2(x.doubleVal(), y.doubleVal())); }
jHighPrecisionFloat sign(const jHighPrecisionFloat &val) { return AllowPrecisionLossOnParam(copysign(1.0, val.doubleVal())); }

jHighPrecisionFloat jHighPrecisionFloat::dbl_max(void) { return AllowPrecisionLossOnParam(DBL_MAX); }
jHighPrecisionFloat jHighPrecisionFloat::dbl_min(void) { return AllowPrecisionLossOnParam(DBL_MIN); }
jHighPrecisionFloat jHighPrecisionFloat::nan(void) { return AllowPrecisionLossOnParam(GSL_NAN); }
jHighPrecisionFloat jHighPrecisionFloat::lnpi(void) { return AllowPrecisionLossOnParam(M_LNPI); }
jHighPrecisionFloat jHighPrecisionFloat::ln2(void) { return AllowPrecisionLossOnParam(M_LN2); }
jHighPrecisionFloat jHighPrecisionFloat::epsilon(void) { return AllowPrecisionLossOnParam(GSL_DBL_EPSILON); }

jComplexR exp_i(jreal radianAngle)
{
	return jComplexR(cos(radianAngle), sin(radianAngle));
}

jComplexR exp_i(jComplexR z)
{
	// exp(i(a+ib)) = exp(ia) * exp(-b)
	return exp_i(z.real()) * exp(-z.imag());
}

int CallThrough(jreal a, jreal b, hp_sf_result *result, int (*gslFunc)(double a, double b, gsl_sf_result *r))
{
	gsl_sf_result r;
	int gslResult = gslFunc(AllowPrecisionLossReadingValue(a), AllowPrecisionLossReadingValue(b), &r);
	result->val = AllowPrecisionLossOnParam(r.val);
	result->err = AllowPrecisionLossOnParam(r.err);
	return gslResult;
}

jreal gsl_sf_lnpoch(const jreal a, const jreal x)
{
	return AllowPrecisionLossOnParam(gsl_sf_lnpoch(AllowPrecisionLossReadingValue(a), AllowPrecisionLossReadingValue(x)));
}
int gsl_sf_legendre_sphPlm_array(const int lmax, int m, const jreal x, jreal * result_array)
{
	double resultDouble[lmax+1];
	int gslResult = gsl_sf_legendre_sphPlm_array(lmax, m, AllowPrecisionLossReadingValue(x), resultDouble);
	for (int i = 0; i <= lmax; i++)
		result_array[i] = AllowPrecisionLossOnParam(resultDouble[i]);
	return gslResult;
}

jreal gsl_sf_log_1plusx(const jreal x)
{
	return AllowPrecisionLossOnParam(gsl_sf_log_1plusx(AllowPrecisionLossReadingValue(x)));
}

int gsl_sf_bessel_Jn_array(int nmin, int nmax, jreal x, jreal * result_array)
{
	// TODO: when I implement this fully myself I should probably make it so that it handles underflow gracefully and silently.
	// I should then check everywhere I call this, because it looks like there are hacks in several different places!
	double resultDouble[nmax+1];
	int gslResult = gsl_sf_bessel_Jn_array(nmin, nmax, AllowPrecisionLossReadingValue(x), resultDouble);
	ALWAYS_ASSERT(nmin == 0);
	for (int i = 0; i <= nmax; i++)
		result_array[i] = AllowPrecisionLossOnParam(resultDouble[i]);
		return gslResult;
}

int gsl_sf_bessel_jl_array(const int lmax, const jreal x, jreal * result_array)
{
	double resultDouble[lmax+1];
	int gslResult = gsl_sf_bessel_jl_array(lmax, AllowPrecisionLossReadingValue(x), resultDouble);
	for (int i = 0; i <= lmax; i++)
		result_array[i] = AllowPrecisionLossOnParam(resultDouble[i]);
	return gslResult;
}

jComplexR z_bessel_jl(const int l, const jComplexR x)
{
	return AllowPrecisionLossOnParam(z_bessel_jl(l, AllowPrecisionLossReadingValue(x)));
}

jComplexVectorR z_bessel_jl_array(const int lmax, const jComplexR z)
{
	jComplexVectorR resultComplexR(lmax+1);
	jComplexVector resultComplex = z_bessel_jl_array(lmax, AllowPrecisionLossReadingValue(z));
	for (int i = 0; i <= lmax; i++)
		resultComplexR[i] = AllowPrecisionLossOnParam(resultComplex[i]);
	return resultComplexR;
}

jComplexVector z_bessel_h1l_array(const int highestN, const jComplex z)
{
	jComplexVector resultComplex(highestN+1);
	jComplexVectorR resultComplexR = z_bessel_h1l_array(highestN, AllowPrecisionLossOnParam(z));
	for (int i = 0; i <= highestN; i++)
		resultComplex[i] = AllowPrecisionLossReadingValue(resultComplexR[i]);
	return resultComplex;
}

coordC3R AllowPrecisionLossOnParam(coordC3 val) { return coordC3R(AllowPrecisionLossOnParam(val.x), AllowPrecisionLossOnParam(val.y), AllowPrecisionLossOnParam(val.z)); }
jComplexR AllowPrecisionLossOnParam(jComplex val) { return jComplexR(AllowPrecisionLossOnParam(val.real()), AllowPrecisionLossOnParam(val.imag())); }

double AllowPrecisionLossReadingValue(jreal val) { return val.doubleVal(); }
double AllowPrecisionLossReadingValue_mayAlreadyBeDouble(jreal val) { return val.doubleVal(); }
double AllowPrecisionLossReadingValue_mayAlreadyBeDouble(double val) { return val; }
jreal AllowPrecisionLossOnParam(double val) { return jHighPrecisionFloat(val); }

#else

coordC3R AllowPrecisionLossOnParam(coordC3 val) { return coordC3R(AllowPrecisionLossOnParam(val.x), AllowPrecisionLossOnParam(val.y), AllowPrecisionLossOnParam(val.z)); }
jComplexR AllowPrecisionLossOnParam(jComplex val) { return jComplexR(AllowPrecisionLossOnParam(val.real()), AllowPrecisionLossOnParam(val.imag())); }

double AllowPrecisionLossReadingValue(jreal val) { return val; }
double AllowPrecisionLossReadingValue_mayAlreadyBeDouble(jreal val) { return val; }
jreal AllowPrecisionLossOnParam(double val) { return val; }

#endif

coord3R AllowPrecisionLossOnParam(coord3 val) { return coord3R(AllowPrecisionLossOnParam(val.x), AllowPrecisionLossOnParam(val.y), AllowPrecisionLossOnParam(val.z)); }
coord3 AllowPrecisionLossReadingValue(coord3R val) { return coord3(AllowPrecisionLossReadingValue(val.x), AllowPrecisionLossReadingValue(val.y), AllowPrecisionLossReadingValue(val.z)); }
coordC3 AllowPrecisionLossReadingValue(coordC3R val) { return coordC3(AllowPrecisionLossReadingValue(val.x), AllowPrecisionLossReadingValue(val.y), AllowPrecisionLossReadingValue(val.z)); }
jComplex AllowPrecisionLossReadingValue(jComplexR val) { return jComplex(AllowPrecisionLossReadingValue(val.real()), AllowPrecisionLossReadingValue(val.imag())); }
