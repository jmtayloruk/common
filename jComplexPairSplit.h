/*
 *	jComplexPairSplit.h
 *
 *  Class representing two complex numbers, storing the values as two jComplex objects
 *	This implementation is generic, but not particularly high performance - if SSE is
 *	available then jComplexPairAsVectoris a much better choice
 */

#ifndef __JCOMPLEX_PAIR_SPLIT_H__
#define __JCOMPLEX_PAIR_SPLIT_H__

#include "jComplex.h"

class jComplexPairSplit
{
	// This class represents two complex numbers
	// This implementation just acts as a container for two instances of jComplex
  protected:
	jComplex __a, __b;
	
  public:

	jComplexPairSplit() { }

	jComplex a(void) const { return __a; }
	jComplex b(void) const { return __b; } 

	explicit jComplexPairSplit(const jComplex &inZ) { __a = inZ; __b = inZ; }
	jComplexPairSplit(const jComplexPairSplit &inAB) { __a = inAB.a(); __b = inAB.b(); }
	jComplexPairSplit(jComplex inA, jComplex inB) { __a = inA; __b = inB; }
	
	void SetA(jComplex inA) { __a = inA; }
	void SetB(jComplex inB) { __b = inB; }
	
	jComplexPairSplit& operator += (const jComplexPairSplit &n) { __a += n.a(); __b += n.b(); return *this; }
	jComplexPairSplit operator + (const jComplexPairSplit &n) const { return jComplexPairSplit(*this) += n; }
	jComplexPairSplit& operator -= (const jComplexPairSplit &n) { __a -= n.a(); __b -= n.b(); return *this; }
	jComplexPairSplit operator - (const jComplexPairSplit &n) const { return jComplexPairSplit(*this) -= n; }
	jComplexPairSplit& operator *= (const jComplexPairSplit &n) { __a *= n.a(); __b *= n.b(); return *this; }
	jComplexPairSplit operator * (const jComplexPairSplit &n) const { return jComplexPairSplit(*this) *= n; }
	jComplexPairSplit& operator /= (const jComplexPairSplit &n) { __a /= n.a(); __b /= n.b(); return *this; }
	jComplexPairSplit operator / (const jComplexPairSplit &n) const { return jComplexPairSplit(*this) /= n; }

	jComplexPairSplit& operator += (const jComplex &n) { __a += n; __b += n; return *this; }
	jComplexPairSplit operator + (const jComplex &n) const { return jComplexPairSplit(*this) += n; }
	jComplexPairSplit& operator -= (const jComplex &n) { __a -= n; __b -= n; return *this; }
	jComplexPairSplit operator - (const jComplex &n) const { return jComplexPairSplit(*this) -= n; }
	jComplexPairSplit& operator *= (const jComplex &n) { __a *= n; __b *= n; return *this; }
	jComplexPairSplit operator * (const jComplex &n) const { return jComplexPairSplit(*this) *= n; }
	jComplexPairSplit& operator /= (const jComplex &n) { __a /= n; __b /= n; return *this; }
	jComplexPairSplit operator / (const jComplex &n) const { return jComplexPairSplit(*this) /= n; }

	jComplexPairSplit& operator += (const double &n) { __a += n; __b += n; return *this; }
	jComplexPairSplit operator + (const double &n) const { return jComplexPairSplit(*this) += n; }
	jComplexPairSplit& operator -= (const double &n) { __a -= n; __b -= n; return *this; }
	jComplexPairSplit operator - (const double &n) const { return jComplexPairSplit(*this) -= n; }
	jComplexPairSplit& operator *= (double n) { __a *= n; __b *= n; return *this; }
	jComplexPairSplit operator * (double n) const { return jComplexPairSplit(*this) *= n; }
	jComplexPairSplit& operator /= (double n) { __a /= n; __b /= n; return *this; }
	jComplexPairSplit operator / (double n) const { return jComplexPairSplit(*this) /= n; }
	
	jComplexPairSplit conj(void) const { return jComplexPairSplit(::conj(__a), ::conj(__b)); }

	double SumReal(void) const { return real(__a) + real(__b); }
	double SumNorm(void) const { return norm(__a) + norm(__b); }
	jComplex SumAcross(void) const { return __a + __b; }
	jComplexPairSplit GetNegative(void) const { return jComplexPairSplit(-__a, -__b); }
	jComplexPairSplit GetSwappedPairs(void) const { return jComplexPairSplit(__b, __a); }
	jComplexPairSplit GetMulWithConjY(const jComplexPairSplit &y) const { return jComplexPairSplit(__a * ::conj(y.a()), __b * ::conj(y.b())); }
	void Print(void) const
	{
		printf("{");
		::Print(a());
		printf(", ");
		::Print(b());
		printf("}");
	}
};

inline jComplexPairSplit operator*(const double l, const jComplexPairSplit &r)
{
	return r * l;
}

inline jComplexPairSplit operator*(const jComplex l, const jComplexPairSplit &r)
{
	return r * l;
}

inline jComplexPairSplit operator/(const double l, const jComplexPairSplit &r)
{
	return jComplexPairSplit(l / r.a(), l / r.b());
}

inline jComplexPairSplit operator/(const jComplex l, const jComplexPairSplit &r)
{
	return jComplexPairSplit(l / r.a(), l / r.b());
}

inline jComplexPairSplit operator-(const double l, const jComplexPairSplit &r)
{
	return jComplexPairSplit(l - r.a(), l - r.b());
}

inline jComplexPairSplit operator-(const jComplexPairSplit &r)
{
	return r.GetNegative();
}

inline jComplexPairSplit operator+(const jComplexPairSplit &r)
{
	return r;
}

inline jComplexPairSplit operator+(const double l, const jComplexPairSplit &r)
{
	return r + l;
}

inline jComplexPairSplit conj(const jComplexPairSplit &z)
{
	return z.conj();
}

inline jComplexPairSplit re_part(const jComplexPairSplit &x) { return jComplexPairSplit(real(x.a()), real(x.b())); }
inline jComplexPairSplit im_part(const jComplexPairSplit &x) { return jComplexPairSplit(imag(x.a()), imag(x.b())); }
inline double SumReal(const jComplexPairSplit &x) { return x.SumReal(); }
inline double SumNorm(const jComplexPairSplit &x) { return x.SumNorm(); }
inline jComplex SumAcross(const jComplexPairSplit &x) { return x.SumAcross(); }
inline jComplexPairSplit MulXConjY(const jComplexPairSplit &x, const jComplexPairSplit &y) { return x.GetMulWithConjY(y); }

inline jComplexPairSplit SwapPairs(const jComplexPairSplit &x) { return jComplexPairSplit(x.GetSwappedPairs()); }

#endif
