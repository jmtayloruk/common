#ifndef __JCOORD_H__
#define __JCOORD_H__

#include <math.h>
#include <complex>
#include "jCommon.h"
#include "jComplex.h"

// This is defined in jUtils.h, but we get some circular header problems and it's easier just to define it here as well
extern const double PI;

/************************ 2D COORDINATE CLASS *******************************/

struct coord2
{
	// Note that not all operators are implemented - I have only implemented the ones I need.
  public:
	double	x, y;

	coord2() { }
	coord2(double inX, double inY) { x = inX; y = inY; }
	coord2& operator += (coord2 n) { x += n.x; y += n.y; return *this; }
	coord2 operator + (coord2 n) const { return coord2(*this) += n; }
	coord2& operator -= (coord2 n) { x -= n.x; y -= n.y; return *this; }
	coord2 operator - (coord2 n) const { return coord2(*this) -= n; }
	coord2& operator *= (double n) { x *= n; y *= n; return *this; }
	coord2 operator * (double n) const { return coord2(*this) *= n; }
	coord2& operator /= (double n) { x /= n; y /= n; return *this; }
	coord2 operator / (double n) const { return coord2(*this) /= n; }
	
	// Dot product
	double Dot(coord2 n) const { return x * n.x + y * n.y; }

	coord2& operator = (coord2 n) { x = n.x; y = n.y; return *this; }
	void Set(double inX, double inY) { x = inX; y = inY; }
	
	coord2& Normalize(void) { double invLen = 1 / sqrt(x*x + y*y); x *= invLen; y *= invLen; return *this; }
	double DistanceTo(coord2 &b) const { return sqrt(SQUARE(x - b.x) + SQUARE(y - b.y)); }
	double AngleWith(coord2 &b) const
	{
		double angle = b.Angle() - Angle();
		if (angle > PI) angle -= 2.0 * PI;
		if (angle < -PI) angle += 2.0 * PI;
		return angle;
	}
	inline double LengthSquared(void) const { return SQUARE(x) + SQUARE(y); }
	inline double Length(void) const { return sqrt(LengthSquared()); }
	double Angle(void) const { return atan2(y, x); }
	void Print(void) const { printf("(%.12lg, %.12lg)", x, y); }
};

inline void Print(coord2 c) { c.Print(); }

inline coord2 operator*(const double l, const coord2 r)
{
	return r * l;
}

inline coord2 operator-(const double l, const coord2 r)
{
	return coord2(l - r.x, l - r.y);
}

inline coord2 operator-(const coord2 &r)
{
	return coord2(-r.x, -r.y);
}

#define USE_FLOATS 0

/************************ 3D COORDINATE CLASS *******************************/

struct coord3
{
	// Note that not all operators are implemented - I have only implemented the ones I need.
  public:
#if USE_FLOATS
	float	x, y, z;
#else
	double	x, y, z;
#endif

	/*	Constructors - to create a coord3 object, write something like:
			coord3 a(1.0, 1.4, 1.1);
			a += coord3(2.4, 1.2, 0.0);		*/
	coord3() { }
	coord3(double inX, double inY, double inZ) { x = inX; y = inY; z=inZ; }

  #ifdef __GSL_COMPLEX_H__
	// These are extra constructors for interfacing with the open source GSL library
	// They should only be compiled in if you include the GSL headers
	// (so this file will work fine if you do not have GSL installed or have never heard of it)
				coord3(gsl_vector *inVector);
				coord3(gsl_vector *inVector, long offset);
	gsl_vector	*AllocGSLVector(void) const;
  #endif

	/*	Overloaded operators which allow you to write code like:
			myCoord = myOtherCoord + coord3(2.4, 1.2, 0.0);			*/
	coord3& operator += (const coord3 &n) { x += n.x; y += n.y; z += n.z; return *this; }
	coord3 operator + (const coord3 &n) const { return coord3(*this) += n; }
	coord3& operator -= (const coord3 &n) { x -= n.x; y -= n.y; z -= n.z; return *this; }
	coord3 operator - (const coord3 &n) const { return coord3(*this) -= n; }
	coord3& operator *= (double n) { x *= n; y *= n; z *= n; return *this; }
	coord3 operator * (double n) const { return coord3(*this) *= n; }
	coord3& operator /= (double n) { return (*this) *= (1/n); }
	coord3 operator / (double n) const { return coord3(*this) /= n; }
	inline coord3& operator = (const coord3 &n) { x = n.x; y = n.y; z = n.z; return *this; }
	// Comparison operators (BUT be warned about FP comparisons which may not give the results you expect!)
	bool operator == (const coord3 &n) { return ((x == n.x) && (y == n.y) && (z == n.z)); }
	bool operator != (const coord3 &n) { return !(operator==(n)); }
	
	// Dot and cross products - e.g. myCoord.Dot(myOtherCoord);
	inline double Dot(const coord3 &n) const { return x * n.x + y * n.y + z * n.z; }
	coord3 Cross(const coord3 &n) const;

	// Utility functions. Some of these are used for cartesian to spherical conversions etc.
	inline void Set(double inX, double inY, double inZ) { x = inX; y = inY; z = inZ; }
	void	RotateFromSphericalSystem(double theta, double phi);
	void	RotateToSphericalSystem(double theta, double phi);
	void	RotateFromCylindricalSystem(double phi);
	void	RotateToCylindricalSystem(double phi);
	void	MultiplyByComponents(const coord3 &n) { x *= n.x; y *= n.y; z *= n.z; }
	
	// More utility functions
	coord3& Normalize(void) { double invLen = 1 / sqrt(x*x + y*y + z*z); x *= invLen; y *= invLen; z *= invLen; return *this; }
	inline double SquaredDistanceTo(const coord3 &b) const { return (*this - b).LengthSquared(); }
	inline double DistanceTo(const coord3 &b) const { return (*this - b).Length(); }
	inline double LengthSquared(void) const { return SQUARE(x) + SQUARE(y) + SQUARE(z); }
	inline double Length(void) const { return sqrt(LengthSquared()); }
	void Print(void) const { printf("(%.12lg, %.12lg, %.12lg)", x, y, z); }

	// Extract one indexed component of the vector
	// This is not very efficient. Should really redefine x, y, z as a 3 element array, but that will alter rather a lot of the arithmetic code in this struct definition!
	double component(int c) { return (c==0) ? x : ((c==1) ? y : z); }
};

typedef std::vector<coord3> coord3Vector;

inline void Print(coord3 c) { c.Print(); }

/*	More operator overloading to allow mixing with scalar values
	e.g. myCoord = 3.0 * myOtherCoord;	*/
inline coord3 operator*(const double l, const coord3 r)
{
	return r * l;
}

inline coord3 operator-(const double l, const coord3 r)
{
	// Subtract from a scalar. Think carefully about whether you really want to do this!
	return coord3(l - r.x, l - r.y, l - r.z);
}

inline coord3 operator-(const coord3 &r)
{
	// Negation operator
	return coord3(-r.x, -r.y, -r.z);
}

/************************ COMPLEX 3D COORDINATE CLASS *******************************/

/*	It would be nice to have a typed differentiation between polar and scalar coordinates
	to prevent them being mixed by mistake. Can't do that very easily with subclasses, though
	because all the operators return coordC3, so an action like theCoord = theCoord * 2 doesn't compile.
	Might be possible to achieve what I want using a dummy template argument to a templated coordC3.	*/
using std::conj;
struct coordC3
{
	// Note that not all operators are implemented - I have only implemented the ones I need.
  public:
	jComplex	x, y, z;

	coordC3() { }
	coordC3(const jComplex &inX, const jComplex &inY, const jComplex &inZ) { Set(inX, inY, inZ); }
	explicit coordC3(coord3 r) : x(r.x), y(r.y), z(r.z) { }

	coordC3& operator += (const coordC3 &n) { x += n.x; y += n.y; z += n.z; return *this; }
	coordC3 operator + (const coordC3 &n) const { return coordC3(*this) += n; }
	coordC3& operator -= (const coordC3 &n) { x -= n.x; y -= n.y; z -= n.z; return *this; }
	coordC3 operator - (const coordC3 &n) const { return coordC3(*this) -= n; }
	coordC3& operator *= (double n) { x *= n; y *= n; z *= n; return *this; }
	coordC3 operator * (double n) const { return coordC3(*this) *= n; }
	coordC3& operator /= (double n) { return (*this) *= (1/n); }
	coordC3 operator / (double n) const { return coordC3(*this) /= n; }
	coordC3& operator *= (const jComplex &n) { x *= n; y *= n; z *= n; return *this; }
	coordC3 operator * (const jComplex &n) const { return coordC3(*this) *= n; }
	bool operator == (const coordC3 &n) { return ((x == n.x) && (y == n.y) && (z == n.z)); }
	
	// Dot and cross products
	inline jComplex Dot(const coordC3 &n) const { return x * n.x + y * n.y + z * n.z; }
	inline jComplex Dot(const coord3 &n) const { return x * n.x + y * n.y + z * n.z; }
	coordC3 Cross(const coordC3 &n) const;

	inline coordC3& operator = (const coordC3 &n) { x = n.x; y = n.y; z = n.z; return *this; }
	inline void Set(const jComplex &inX, const jComplex &inY, const jComplex &inZ) { x = inX; y = inY; z = inZ; }
	void	RotateFromSphericalSystem(double theta, double phi);
	void	RotateToSphericalSystem(double theta, double phi);
	void	RotateFromCylindricalSystem(double phi);
	void	RotateToCylindricalSystem(double phi);
	
	inline double LengthSquared(void) const { return SQUARE(x.real()) + SQUARE(x.imag()) + SQUARE(y.real()) + SQUARE(y.imag()) + SQUARE(z.real()) + SQUARE(z.imag()); }
	inline double Length(void) const { return sqrt(LengthSquared()); }
	coord3 component_abs(void) const { return coord3(abs(x), abs(y), abs(z)); }
	coord3 real(void) const { return coord3(x.real(), y.real(), z.real()); }
	coord3 imag(void) const { return coord3(x.imag(), y.imag(), z.imag()); }
	coordC3 conj(void) const { return coordC3(::conj(x), ::conj(y), ::conj(z)); }
	void Print(void) const { printf("({%.12lg,%.12lg}, {%.12lg,%.12lg}, {%.12lg,%.12lg})", x.real(), x.imag(), y.real(), y.imag(), z.real(), z.imag()); }

//    friend coordC3 operator*(const jComplex &l, const coordC3 &r);
  //  friend coordC3 operator-(const jComplex &l, const coordC3 &r);
};

inline void Print(coordC3 c) { c.Print(); }

inline coordC3 operator*(const jComplex &l, const coordC3 &r)
{
	return r * l;
}

inline coordC3 operator-(const jComplex &l, const coordC3 &r)
{
	return coordC3(l - r.x, l - r.y, l - r.z);
}

inline coordC3 operator-(const coordC3 &r)
{
	return coordC3(-r.x, -r.y, -r.z);
}

inline coordC3 operator * (const coord3 &a, jComplex n) { return coordC3(a.x, a.y, a.z) * n; }

inline coordC3 conj(const coordC3 &r)
{
	return r.conj();
}


coord3 CartesianToSpherical(coord3 source);
coord3 SphericalToCartesian(coord3 source);
coord3 CartesianToCylindrical(coord3 source);
coord3 CylindricalToCartesian(coord3 source);
coordC3 CartesianToSpherical(coordC3 source);
coordC3 SphericalToCartesian(coordC3 source);
coordC3 RotateFromSphericalSystem(coordC3 c, double theta, double phi);
coordC3 RotateToSphericalSystem(coordC3 c, double theta, double phi);
coord3 RotateFromSphericalSystem(coord3 c, double theta, double phi);
coord3 RotateToSphericalSystem(coord3 c, double theta, double phi);
coordC3 RotateFromCylindricalSystem(coordC3 c, double phi);
coordC3 RotateToCylindricalSystem(coordC3 c, double phi);

/************************ UTILITY FUNCTIONS *******************************/

inline coordC3 ConvertToComplex(coord3 &a)
{
	// Type conversion from a real 3D coordinate to a complex 3D coordinate
	return coordC3(a.x, a.y, a.z);
}

/*	Some more rotation utility functions.
	These ones are templated so you can use either the coord3 or the coordC3 class with them
	e.g.
		coord3 myCoord(0, 0, 0);
		coordC3 myComplexCoord(0, 0, 0);
		myCoord = RotateInXYPlane(myCoord, 3.14159);					// both these
		myComplexCoord = RotateInXYPlane(myComplexCoord, 3.14159);		// are valid
*/

template<class COORD> COORD RotateInXYPlane(COORD v, double phi)
{
	double sinPhi = sin(phi), cosPhi = cos(phi);
	return COORD(v.x * cosPhi - v.y * sinPhi,
				 v.x * sinPhi + v.y * cosPhi,
				 v.z);
}

template<class COORD> COORD RotateInXZPlane(COORD v, double phi)
{
	double sinPhi = sin(phi), cosPhi = cos(phi);
	return COORD(v.x * cosPhi - v.z * sinPhi,
				 v.y,
				 v.x * sinPhi + v.z * cosPhi);
}

#endif
