/*
 *	jHighPrecisionFloat.h
 *
 *  Class representing a floating-point number, but potentially to higher (or lower) precision 
 *	than supported by the ubiquitous 'double' type.
 */

#ifndef __JHIGH_PRECISION_FLOAT_H__
#define __JHIGH_PRECISION_FLOAT_H__

#ifndef USE_JREAL

	class jreal_as_double_consts
	{
	  public:
		static double dbl_max(void) { return GSL_DBL_MAX; }
		static double dbl_min(void) { return GSL_DBL_MIN; }
		static double nan(void) { return GSL_NAN; }
		static double lnpi(void) { return M_LNPI; }
		static double ln2(void) { return M_LN2; }
		static double epsilon(void) { return GSL_DBL_EPSILON; }
	};

	#include <vector>
	typedef std::vector<double> realVector;

#else

#define HIGH_PRECISION_REAL 1

// **** all these need redefining once I have a proper high precision implementation
#define J_DBL_EPSILON jreal(GSL_DBL_EPSILON)
#define J_SQRT_DBL_EPSILON jreal(GSL_SQRT_DBL_EPSILON)
#define J_ROOT4_DBL_EPSILON jreal(GSL_ROOT4_DBL_EPSILON)
#define J_ROOT6_DBL_EPSILON jreal(GSL_ROOT6_DBL_EPSILON)
#define J_DBL_MIN jreal(GSL_DBL_MIN)
#define J_DBL_MAX jreal(GSL_DBL_MAX)
#define J_LOG_DBL_MIN jreal(GSL_LOG_DBL_MIN)
#define J_LOG_DBL_MAX jreal(GSL_LOG_DBL_MAX)
#define J_SQRT_DBL_MIN jreal(GSL_SQRT_DBL_MIN)
#define J_SQRT_DBL_MAX jreal(GSL_SQRT_DBL_MAX)
#define J_POSINF jreal(GSL_POSINF)
#define J_NAN jHighPrecisionFloat::nan()
#define J_LNPI jHighPrecisionFloat::lnpi()
#define J_LN2 jHighPrecisionFloat::ln2()
#define J_REAL_EPSILON jHighPrecisionFloat::epsilon()

class jHighPrecisionFloat
{
	// This class represents a high-precision floating-point number, with associated error on accuracy
protected:
	double __val, __err;
	
public:
	
	jHighPrecisionFloat() { __val = 0; __err = 0; }		// This must construct a value of zero - std::complex appears to expect this!
	
	double doubleVal(void) const { return __val; }
	double doubleErr(void) const { return __err; }
	
	explicit jHighPrecisionFloat(double inVal) { __val = inVal; __err = 0.0; }
	jHighPrecisionFloat(int inVal) { __val = inVal; __err = 0.0; }
	jHighPrecisionFloat(long inVal) { __val = inVal; __err = 0.0; }
	jHighPrecisionFloat(long long inVal) { __val = inVal; __err = 0.0; }
	
	jHighPrecisionFloat& operator += (const jHighPrecisionFloat &n) { __val += n.doubleVal(); return *this; }
	jHighPrecisionFloat operator + (const jHighPrecisionFloat &n) const { return jHighPrecisionFloat(*this) += n; }
	jHighPrecisionFloat& operator -= (const jHighPrecisionFloat &n) { __val -= n.doubleVal(); return *this; }
	jHighPrecisionFloat operator - (const jHighPrecisionFloat &n) const { return jHighPrecisionFloat(*this) -= n; }
	jHighPrecisionFloat& operator *= (const jHighPrecisionFloat &n) { __val *= n.doubleVal(); return *this; }
	jHighPrecisionFloat operator * (const jHighPrecisionFloat &n) const { return jHighPrecisionFloat(*this) *= n; }
	jHighPrecisionFloat& operator /= (const jHighPrecisionFloat &n) { __val /= n.doubleVal(); return *this; }
	jHighPrecisionFloat operator / (const jHighPrecisionFloat &n) const { return jHighPrecisionFloat(*this) /= n; }
	
	jHighPrecisionFloat GetNegative(void) const { return jHighPrecisionFloat(-__val); }
	
	static jHighPrecisionFloat dbl_max(void);
	static jHighPrecisionFloat dbl_min(void);
	static jHighPrecisionFloat nan(void);
	static jHighPrecisionFloat lnpi(void);
	static jHighPrecisionFloat ln2(void);
	static jHighPrecisionFloat epsilon(void);

	void Print(void) const
	{
		printf("%lg", __val);
	}
};

void Print(jHighPrecisionFloat x);

inline jHighPrecisionFloat operator-(const jHighPrecisionFloat &r)
{
	return r.GetNegative();
}

inline jHighPrecisionFloat operator+(const jHighPrecisionFloat &r)
{
	return r;
}

inline jHighPrecisionFloat operator*(const int l, const jHighPrecisionFloat &r)
{
	return r * l;
}

inline jHighPrecisionFloat operator/(const int l, const jHighPrecisionFloat &r)
{
	return jHighPrecisionFloat(l) / r;
}

inline jHighPrecisionFloat operator+(const int l, const jHighPrecisionFloat &r)
{
	return jHighPrecisionFloat(l) + r;
}

inline jHighPrecisionFloat operator-(const int l, const jHighPrecisionFloat &r)
{
	return jHighPrecisionFloat(l) - r;
}

inline bool operator == (const jHighPrecisionFloat &x, const jHighPrecisionFloat &y)
{
	return x.doubleVal() == y.doubleVal();
}

inline bool operator != (const jHighPrecisionFloat &x, const jHighPrecisionFloat &y)
{
	return x.doubleVal() != y.doubleVal();
}

inline bool operator > (const jHighPrecisionFloat &x, const jHighPrecisionFloat &y)
{
	return x.doubleVal() > y.doubleVal();
}

inline bool operator < (const jHighPrecisionFloat &x, const jHighPrecisionFloat &y)
{
	return x.doubleVal() < y.doubleVal();
}

inline bool operator >= (const jHighPrecisionFloat &x, const jHighPrecisionFloat &y)
{
	return x.doubleVal() >= y.doubleVal();
}

inline bool operator <= (const jHighPrecisionFloat &x, const jHighPrecisionFloat &y)
{
	return x.doubleVal() <= y.doubleVal();
}

int floor_int(const jHighPrecisionFloat &val);		// Calculate floor(val) and convert to int
bool is_nan(const jHighPrecisionFloat &val);
jHighPrecisionFloat fabs(const jHighPrecisionFloat &val);
// I would like to eliminate abs and just have fabs for clarity, but std::complex expects abs() to be implemented, so this next function has to remain
jHighPrecisionFloat abs(const jHighPrecisionFloat &val);
jHighPrecisionFloat exp(const jHighPrecisionFloat &val);
jHighPrecisionFloat sqrt(const jHighPrecisionFloat &val);
jHighPrecisionFloat log(const jHighPrecisionFloat &val);
jHighPrecisionFloat sin(const jHighPrecisionFloat &x);
jHighPrecisionFloat sinh(const jHighPrecisionFloat &x);
jHighPrecisionFloat cos(const jHighPrecisionFloat &x);
jHighPrecisionFloat cosh(const jHighPrecisionFloat &x);
jHighPrecisionFloat tan(const jHighPrecisionFloat &x);
jHighPrecisionFloat asin(const jHighPrecisionFloat &x);
jHighPrecisionFloat acos(const jHighPrecisionFloat &x);
jHighPrecisionFloat atan2(const jHighPrecisionFloat &x, const jHighPrecisionFloat &y);
jHighPrecisionFloat sign(const jHighPrecisionFloat &val);

struct hp_sf_result_struct {
	jreal val;
	jreal err;
};
typedef struct hp_sf_result_struct hp_sf_result;

jreal gsl_sf_lnpoch(const jreal a, const jreal x);
int gsl_sf_legendre_sphPlm_array(const int lmax, int m, const jreal x, jreal * result_array);
jreal gsl_sf_log_1plusx(const jreal x);
int gsl_sf_bessel_Jn_array(int nmin, int nmax, jreal x, jreal * result_array);// TODO: when I implement this I need to make sure it can handle underflow gracefully and silently. I should then check everywhere I call this, because it looks like there are hacks in several different places!
int gsl_sf_bessel_jl_array(const int lmax, const jreal x, jreal * result_array);

#include <vector>
typedef std::vector<jreal> realVector;

#endif


double AllowPrecisionLossReadingValue(jreal val);
double AllowPrecisionLossReadingValue_mayAlreadyBeDouble(jreal val);
double AllowPrecisionLossReadingValue_mayAlreadyBeDouble(double val);
jreal AllowPrecisionLossOnParam(double val);

#endif
