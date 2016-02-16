/*
 *	jHighPrecisionFloat_stubAsDouble.h
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

#ifndef __JHIGH_PRECISION_FLOAT_STUB_DOUBLE_H__
#define __JHIGH_PRECISION_FLOAT_STUB_DOUBLE_H__

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
	// However at present the error propagation is not properly implemented
protected:
	double __val, __err;
	
public:
	static const long precision;
	
	jHighPrecisionFloat() { __val = 0; __err = 0; }		// This must construct a value of zero - std::complex appears to expect this!
	
	double doubleVal(void) const { return __val; }
	double doubleErr(void) const { return __err; }
	
	explicit jHighPrecisionFloat(double inVal) { __val = inVal; __err = GSL_DBL_EPSILON * inVal; }
	explicit jHighPrecisionFloat(double inVal, double inErr) { __val = inVal; __err = inErr; }
	jHighPrecisionFloat(int inVal) { __val = inVal; __err = 0.0; }
	jHighPrecisionFloat(long inVal) { __val = inVal; __err = 0.0; }
	jHighPrecisionFloat(long long inVal) { __val = inVal; __err = 0.0; }
	jHighPrecisionFloat(const char *numString, double inErr) { __val = strtod(numString, NULL); __err = inErr; }
	
	jHighPrecisionFloat& operator += (const jHighPrecisionFloat &n) { __val += n.doubleVal(); return *this; }
	jHighPrecisionFloat operator + (const jHighPrecisionFloat &n) const { return jHighPrecisionFloat(*this) += n; }
	jHighPrecisionFloat& operator -= (const jHighPrecisionFloat &n) { __val -= n.doubleVal(); return *this; }
	jHighPrecisionFloat operator - (const jHighPrecisionFloat &n) const { return jHighPrecisionFloat(*this) -= n; }
	jHighPrecisionFloat& operator *= (const jHighPrecisionFloat &n) { __val *= n.doubleVal(); return *this; }
	jHighPrecisionFloat operator * (const jHighPrecisionFloat &n) const { return jHighPrecisionFloat(*this) *= n; }
	jHighPrecisionFloat& operator /= (const jHighPrecisionFloat &n) { __val /= n.doubleVal(); return *this; }
	jHighPrecisionFloat operator / (const jHighPrecisionFloat &n) const { return jHighPrecisionFloat(*this) /= n; }
	
	jHighPrecisionFloat GetNegative(void) const { return jHighPrecisionFloat(-__val, __err); }
	
	static jHighPrecisionFloat dbl_max(void);
	static jHighPrecisionFloat dbl_min(void);
	static jHighPrecisionFloat nan(void);
	static jHighPrecisionFloat lnpi(void);
	static jHighPrecisionFloat ln2(void);
	static jHighPrecisionFloat epsilon(void);

	void Print(const char *suffix = "") const
	{
		printf("%lg%s", __val, suffix);
	}
};

void Print(jHighPrecisionFloat x, const char *suffix = "");

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
jHighPrecisionFloat atan2(const jHighPrecisionFloat &y, const jHighPrecisionFloat &x);
jHighPrecisionFloat sign(const jHighPrecisionFloat &val);

#include <vector>
typedef std::vector<jreal> realVector;

#endif
