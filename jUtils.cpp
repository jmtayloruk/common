//
//  jUtils.cpp
//
//	Copyright 2010-2015 Jonathan Taylor. All rights reserved.
//
//	A random assortment of utility functions!
//
#include <sys/time.h>
#include <sys/times.h>
#include <sys/resource.h>
#include <netinet/in.h>

#ifdef USES_GSL
	#define USES_MATRIX 1
#else
	#ifdef __GSL_MATRIX_H__
		#define USES_MATRIX 1
	#else
		#define USES_MATRIX 0
	#endif
#endif
#if USES_MATRIX
	#include <gsl/gsl_matrix.h>
	#include "jComplex.h"
#endif

// I define pi myself, even on OS X, because the intel compiler picks up a long double version of pi
// and then warns about loss of precision! (as well as producing problems with operators on complex numbers)
const double PI = 6.0 * asin(0.5);

// Define a variable for NaN.
// The roundabout way of doing this is an attempt to suppress compiler warnings
extern const double _zero;
const double NaN = _zero / _zero;
const double _zero = 0.0;

namespace fundamental_constants
{
	const double c = 299792458.0;
	const double mu_0 = 4.0 * PI * 1e-7;
	const double e_0 = 1.0 / (SQUARE(c) * mu_0);	// 8.8541878176e-12
	const double eta_0 = sqrt(mu_0 / e_0);
	const double k_b = 1.38065e-23;
    const double g = 9.81;
	const double electronic_charge = 1.60217646e-19;
	const double root4PiE0 = sqrt(4.0 * PI * e_0);		// 1.054822e-05
	const double root4PiMu0 = sqrt(4.0 * PI * mu_0);	// 3.973835e-03
	const double L = 6.022e23;
	
	// Bjerrum length (DVLO theory). Remember to use static permittivity of water (~80)!	
	// This is not strictly a constant, but for my purposes it is...
	const double lambda_b = 0.714e-9;
}

LocalEnableDenormalFlushing::LocalEnableDenormalFlushing(void)
{
	// This class can be dropped in to a function to enable denormal flushing
	// i.e. flush denormal [very small] numbers to zero. This is not strict
	// IEEE floating point behaviour, but it can improve performance substantially
	// in cases where we are happy to ignore denormals.
	// Written for my scatter code, probably around 2010, and I can't vouch for it
	// definitely working on more recent architectures!
  #if HAS_SSE
	// Read the MXCSR register.
	oldmxcsr = _mm_getcsr();
	// Make a copy with the FZ  and DAZ bits turned on.
	
	#if __SSE3__
		int newmxcsr = oldmxcsr | _MM_FLUSH_ZERO_ON | _MM_DENORMALS_ZERO_MASK;
	#else
		int newmxcsr = oldmxcsr | _MM_FLUSH_ZERO_ON | 0x0040;
	#endif
	
	// Set the MXCSR register with the new value.
	_mm_setcsr( newmxcsr );
  #endif
}

LocalEnableDenormalFlushing::~LocalEnableDenormalFlushing(void)
{
  #if HAS_SSE
	// Restore the MXCSR register
	_mm_setcsr( oldmxcsr );
  #endif
}

void *void_aligned_malloc(size_t size, size_t align_size)
{
	// Return a malloc'd block aligned to a specified memory boundary
	// e.g. if align_size is 32 then we guarantee the address we return
	// is a multiple of 32.
	char *ptr,*ptr2,*aligned_ptr;
	int align_mask = align_size - 1;

	ptr=(char *)malloc(size + align_size + sizeof(int));
	if(ptr==NULL)
		return(NULL);

	ptr2 = ptr + sizeof(int);
	aligned_ptr = ptr2 + (align_size - ((size_t)ptr2 & align_mask));

	ptr2 = aligned_ptr - sizeof(int);
	*((int *)ptr2)=(int)(aligned_ptr - ptr);

	return(aligned_ptr);
}

void aligned_free(volatile void *inPtr)
{
	// Free a block previously allocated using void_aligned_malloc
	char *ptr = (char *)inPtr;
	int *ptr2=(int *)ptr - 1;
	ptr -= *ptr2;
	free(ptr);
}	

const char *GetAddressString(int address, char addressString[128])
{
	// Turns an IP address into a printable string
	address = ntohl(address);
	sprintf(addressString, "%d.%d.%d.%d", (address >> 24) & 0xFF, (address >> 16) & 0xFF, (address >> 8) & 0xFF, (address >> 0) & 0xFF);
	return addressString;
}

char *NewCopyOfString(const char *inString)
{
	// Returns a second block of memory, allocated using new[],
	// containing the contents of inString
	size_t stringLength = strlen(inString);
	char *result = new char[stringLength + 1];
	ALWAYS_ASSERT(result != NULL);
	memcpy(result, inString, stringLength+1);
	return result;
}

bool FileExists(const char *theFile)
{
	// Checks to see whether a file exists at the specified path (by attempting fopen)
	FILE		*checkExists = fopen(theFile, "r");
	bool		fileExists = (checkExists != NULL);
	if (fileExists)
		fclose(checkExists);
	return fileExists;
}
