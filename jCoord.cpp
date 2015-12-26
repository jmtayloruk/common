//
//  jCoord.cpp
//
//	Copyright 2010-2015 Jonathan Taylor. All rights reserved.
//
//	Implementations of utility functions for coordinate objects.
//	Most of these functions are for coordinate transformations.
//
#include "jCoord.h"

void coord3::RotateFromSphericalSystem(double theta, double phi)
{
	// Convert from a local cartesian basis defined for a point in a spherical coordinate system,
	// to a pure global cartesian basis.
	/*		_r_ =		[ cos(phi)sin(theta), sin(phi)sin(theta), cos(theta) ]
			_theta_ =	[ cos(phi)cos(theta), sin(phi)cos(theta), -sin(theta) ]
			_phi_ =		[ -sin(phi), cos(phi), 0 ]			*/
	double		newX = cos(phi) * sin(theta) * x
						+ cos(phi) * cos(theta) * y
						- sin(phi) * z;
	double		newY = sin(phi) * sin(theta) * x
						+ sin(phi) * cos(theta) * y
						+ cos(phi) * z;
	double		newZ = cos(theta) * x
						- sin(theta) * y;
	Set(newX, newY, newZ);
}

void coord3::RotateToSphericalSystem(double theta, double phi)
{
	// Convert to a local cartesian basis defined for a point in a spherical coordinate system,
	// from a pure global cartesian basis.
	/*		_r_ =		[ cos(phi)sin(theta), sin(phi)sin(theta), cos(theta) ]
			_theta_ =	[ cos(phi)cos(theta), sin(phi)cos(theta), -sin(theta) ]
			_phi_ =		[ -sin(phi), cos(phi), 0 ]			*/
	double		newX = cos(phi) * sin(theta) * x
						+ sin(phi) * sin(theta) * y
						+ cos(theta) * z;
	double		newY = cos(phi) * cos(theta) * x
						+ sin(phi) * cos(theta) * y
						- sin(theta) * z;
	double		newZ = -sin(phi) * x
						+ cos(phi) * y;
	Set(newX, newY, newZ);
}

void coordC3::RotateFromSphericalSystem(double theta, double phi)
{
	// Convert from a local cartesian basis defined for a point in a spherical coordinate system,
	// to a pure global cartesian basis.
	/*		_r_ =		[ cos(phi)sin(theta), sin(phi)sin(theta), cos(theta) ]
			_theta_ =	[ cos(phi)cos(theta), sin(phi)cos(theta), -sin(theta) ]
			_phi_ =		[ -sin(phi), cos(phi), 0 ]			*/
	jComplex	newX = cos(phi) * sin(theta) * x
						+ cos(phi) * cos(theta) * y
						- sin(phi) * z;
	jComplex	newY = sin(phi) * sin(theta) * x
						+ sin(phi) * cos(theta) * y
						+ cos(phi) * z;
	jComplex	newZ = cos(theta) * x
						- sin(theta) * y;
	Set(newX, newY, newZ);
}

void coordC3::RotateToSphericalSystem(double theta, double phi)
{
	// Convert to a local cartesian basis defined for a point in a spherical coordinate system,
	// from a pure global cartesian basis.
	/*		_r_ =		[ cos(phi)sin(theta), sin(phi)sin(theta), cos(theta) ]
			_theta_ =	[ cos(phi)cos(theta), sin(phi)cos(theta), -sin(theta) ]
			_phi_ =		[ -sin(phi), cos(phi), 0 ]			*/
	jComplex	newX = cos(phi) * sin(theta) * x
						+ sin(phi) * sin(theta) * y
						+ cos(theta) * z;
	jComplex	newY = cos(phi) * cos(theta) * x
						+ sin(phi) * cos(theta) * y
						- sin(theta) * z;
	jComplex	newZ = -sin(phi) * x
						+ cos(phi) * y;
	Set(newX, newY, newZ);
}

coordC3 RotateFromSphericalSystem(coordC3 c, double theta, double phi)
{
	c.RotateFromSphericalSystem(theta, phi);
	return c;	
}

coordC3 RotateToSphericalSystem(coordC3 c, double theta, double phi)
{
	c.RotateToSphericalSystem(theta, phi);
	return c;	
}

coord3 RotateFromSphericalSystem(coord3 c, double theta, double phi)
{
	c.RotateFromSphericalSystem(theta, phi);
	return c;	
}

coord3 RotateToSphericalSystem(coord3 c, double theta, double phi)
{
	c.RotateToSphericalSystem(theta, phi);
	return c;	
}

void coord3::RotateFromCylindricalSystem(double phi)
{
	/*		_r_ =		[ cos(phi), sin(phi), 0 ]
			_phi_ =		[ -sin(phi), cos(phi), 0 ]			
			_z_ =		[ 0, 0, 1 ]			*/
	double	newX = cos(phi) * x - sin(phi) * y;
	double	newY = sin(phi) * x + cos(phi) * y;
	double	newZ = z;
	Set(newX, newY, newZ);
}

void coord3::RotateToCylindricalSystem(double phi)
{
	// Rotate to a cylindrical system for a point at angle phi in the cylindrical system
	/*		_r_ =		[ cos(phi), sin(phi), 0 ]
			_phi_ =		[ -sin(phi), cos(phi), 0 ]			
			_z_ =		[ 0, 0, 1 ]			*/
	double	newX = cos(phi) * x + sin(phi) * y;
	double	newY = -sin(phi) * x + cos(phi) * y;
	double	newZ = z;
	Set(newX, newY, newZ);
}

void coordC3::RotateFromCylindricalSystem(double phi)
{
	/*		_r_ =		[ cos(phi), sin(phi), 0 ]
			_phi_ =		[ -sin(phi), cos(phi), 0 ]			
			_z_ =		[ 0, 0, 1 ]			*/
	jComplex	newX = cos(phi) * x - sin(phi) * y;
	jComplex	newY = sin(phi) * x + cos(phi) * y;
	jComplex	newZ = z;
	Set(newX, newY, newZ);
}

void coordC3::RotateToCylindricalSystem(double phi)
{
	/*		_r_ =		[ cos(phi), sin(phi), 0 ]
			_phi_ =		[ -sin(phi), cos(phi), 0 ]			
			_z_ =		[ 0, 0, 1 ]			*/
	jComplex	newX = cos(phi) * x + sin(phi) * y;
	jComplex	newY = -sin(phi) * x + cos(phi) * y;
	jComplex	newZ = z;
	Set(newX, newY, newZ);
}

coordC3 RotateFromCylindricalSystem(coordC3 c, double phi)
{
	c.RotateFromCylindricalSystem(phi);
	return c;	
}

coordC3 RotateToCylindricalSystem(coordC3 c, double phi)
{
	c.RotateToCylindricalSystem(phi);
	return c;	
}

coord3 CartesianToSpherical(coord3 source)
{
	// Convert from a Cartesian coordinate to a spherical coordinate
	double	r = sqrt(source.x*source.x + source.y*source.y + source.z*source.z);
	double	theta = acos(source.z / r);
	double	phi = atan2(source.y, source.x);
	
	return coord3(r, theta, phi);
}

coord3 SphericalToCartesian(coord3 source)
{
	// Convert from a spherical coordinate to a Cartesian coordinate
	double	cartX = source.x * cos(source.z) * sin(source.y);
	double	cartY = source.x * sin(source.z) * sin(source.y);
	double	cartZ = source.x * cos(source.y);
	
	return coord3(cartX, cartY, cartZ);
}

#if 1
coordC3 CartesianToSpherical(coordC3 source)
{
	// NOTE: To be honest I'm not even sure what it means to have a complex spherical vector,
	// as well as specific worries such as whether r should use x^2 or |x|^2, for example
	// This might have been of interest with evanescent waves, but I think I'll have to leave it for now!
	// As for the r part, I'm pretty sure I shouldn't use |x|^2...
	jComplex r = sqrt(source.x*source.x + source.y*source.y + source.z*source.z);
	jComplex theta = cacos(source.z / r);
	jComplex val = source.y / source.x;		// **** not sure what to do about quadrants (c.f. atan2...)
	jComplex complexAtan = -jComplex::i() * 0.5 * log((1.0 + jComplex::i() * val) / (1.0 - jComplex::i() * val));
	jComplex phi = complexAtan;
	
	return coordC3(r, theta, phi);
}

coordC3 SphericalToCartesian(coordC3 source)
{
	jComplex cartX = source.x * cos(source.z) * sin(source.y);
	jComplex cartY = source.x * sin(source.z) * sin(source.y);
	jComplex cartZ = source.x * cos(source.y);
	
	return coordC3(cartX, cartY, cartZ);
}
#endif

coord3 CartesianToCylindrical(coord3 source)
{
	double	r = sqrt(source.x*source.x + source.y*source.y);
	double	theta = atan2(source.y, source.x);
	
	return coord3(r, theta, source.z);
}

coord3 CylindricalToCartesian(coord3 source)
{
	double	cartX = source.x * cos(source.y);
	double	cartY = source.x * sin(source.y);
	double	cartZ = source.z;
	
	return coord3(cartX, cartY, cartZ);
}

coord3 coord3::Cross(const coord3 &n) const
{
	return coord3(y * n.z - z * n.y,
				  z * n.x - x * n.z,
				  x * n.y - y * n.x);
}

coordC3 coordC3::Cross(const coordC3 &n) const
{
	return coordC3(y * n.z - z * n.y,
				   z * n.x - x * n.z,
				   x * n.y - y * n.x);
}

#ifdef __GSL_COMPLEX_H__
gsl_vector *coord3::AllocGSLVector(void) const
{
	gsl_vector	*resultVector = gsl_vector_calloc(3);
	gsl_vector_set(resultVector, 0, x);
	gsl_vector_set(resultVector, 1, y);
	gsl_vector_set(resultVector, 2, z);
	return resultVector;
}

coord3::coord3(gsl_vector *inVector)
{
	x = gsl_vector_get(inVector, 0);
	y = gsl_vector_get(inVector, 1);
	z = gsl_vector_get(inVector, 2);
}

coord3::coord3(gsl_vector *inVector, long offset)
{
	x = gsl_vector_get(inVector, offset);
	y = gsl_vector_get(inVector, offset+1);
	z = gsl_vector_get(inVector, offset+2);
}
#endif

