/*	Module InvertMatrix.cpp

	Copyright 2010-2015 Jonathan Taylor. All rights reserved.

	Functions used to invert matrices (some of which make use of LAPACK)
	These are kept in a separate module because Accelerate.h conflicts with the GSL headers:
	this way there is more control about how things are compiled
 
	This is a bit of a mixed-up file, and it probably contains some overlap between functions 
	that do the same thing (for historical reasons!). I'm going to leave it as-is for now, though.
 */
	
#include "InvertMatrix.h"

#include "jOSMacros.h"
#include "jAssert.h"

#if OS_X
	#include <Accelerate/Accelerate.h>
#elif FEDORA_LINUX
	extern "C"
	{
		#include </opt/intel/mkl/10.0.1.014/include/mkl_lapack.h>
		typedef MKL_INT __CLPK_integer;
	}
#elif __athlon__
	#include <acml.h>
	void dgetrf_(int *m, int *n, double *a, int *lda, int *ipiv, int *info) { dgetrf(*m, *n, a, *lda, ipiv, info); }
	void dgetri_(int *n, double *a, int *lda, int *ipiv, int *info) { dgetri(*n, a, *lda, ipiv, info); }
	void sgetrf_(int *m, int *n, float *a, int *lda, int *ipiv, int *info) { sgetrf(*m, *n, a, *lda, ipiv, info); }
	void sgetri_(int *n, float *a, int *lda, int *ipiv, int *info) { sgetri(*n, a, *lda, ipiv, info); }
	void dtrtri_(char *uplo, char *diag, int *n, double *a, int *lda, int *info) { dtrtri(*uplo, *diag, *n, a, *lda, info); }
	void dtrtrs_(char *uplo, char *transa, char *diag, int *n, int *nrhs, double *a, int *lda, double *b, int *ldb, int *info) { dtrtrs(*uplo, *transa, *diag, *n, *nrhs, a, *lda, b, *ldb, info); }
	typedef int __CLPK_integer;
#elif 1
	// Until I come up with a reliable solution for providing a version of lapack, I'm just going to introduce stubs instead
	#define STUB 1
#else
	#include "clapack.h"
	typedef int __CLPK_integer;
#endif

#include <stdio.h>

#ifdef STUB

void Fail(void)
{
	printf("FATAL ERROR - not compiled against LAPACK so this matrix inversion function is not available\n");
	ALWAYS_ASSERT(0);
}

void InvertUpperTriangularMatrix(gsl_matrix *matrix) { Fail(); }
void SolveWithUpperTriangularMatrix(gsl_matrix *matrix, gsl_matrix *x) { Fail(); }
void InvertComplexMatrixUsingLAPACK(int inSize, jComplex *matrix) { Fail(); }

#else

void InvertComplexMatrixUsingLAPACK(int inSize, jComplex *matrix)
{
	__CLPK_integer *piv = new __CLPK_integer[inSize];
	__CLPK_integer info = 0;
	__CLPK_integer size = inSize, tda = inSize;
	

	zgetrf_(&size, &size, (__CLPK_doublecomplex*)matrix, &tda, piv, &info);
	ALWAYS_ASSERT(info == 0);

	__CLPK_integer workSize, minusOne = -1;
	jComplex zWorkSize;
	zgetri_(&size, (__CLPK_doublecomplex*)matrix, &tda, piv, (__CLPK_doublecomplex*)&zWorkSize, &minusOne, &info);
	ALWAYS_ASSERT(info == 0);
	workSize = (__CLPK_integer)zWorkSize.real();
	
	ALWAYS_ASSERT(workSize > 0);
	jComplex *work = new jComplex[workSize];
	zgetri_(&size, (__CLPK_doublecomplex*)matrix, &tda, piv, (__CLPK_doublecomplex*)work, &workSize, &info);
	ALWAYS_ASSERT(info == 0);
	delete[] work;
	delete[] piv;
}

void InvertMatrixUsingLAPACK(int inSize, double *matrix, int inTda)
{
	__CLPK_integer *piv = new __CLPK_integer[inSize];
	__CLPK_integer info = 0;
	__CLPK_integer size = inSize, tda = inTda;

	dgetrf_(&size, &size, matrix, &tda, piv, &info);
	ALWAYS_ASSERT(info == 0);

	__CLPK_integer workSize, minusOne = -1;
	double dWorkSize;
	dgetri_(&size, matrix, &tda, piv, &dWorkSize, &minusOne, &info);
	ALWAYS_ASSERT(info == 0);
	workSize = (__CLPK_integer)dWorkSize;

	ALWAYS_ASSERT(workSize > 0);
	double *work = new double[workSize];
	dgetri_(&size, matrix, &tda, piv, work, &workSize, &info);
	ALWAYS_ASSERT(info == 0);
	delete[] work;
	delete[] piv;
}

void InvertMatrixUsingLAPACK(int inSize, float *matrix, int inTda)
{
	__CLPK_integer *piv = new __CLPK_integer[inSize];
	__CLPK_integer info = 0;
	__CLPK_integer size = inSize, tda = inTda;

	sgetrf_(&size, &size, matrix, &tda, piv, &info);
	ALWAYS_ASSERT(info == 0);

	__CLPK_integer workSize, minusOne = -1;
	float sWorkSize;
	sgetri_(&size, matrix, &tda, piv, &sWorkSize, &minusOne, &info);
	ALWAYS_ASSERT(info == 0);
	workSize = (__CLPK_integer)sWorkSize;

	ALWAYS_ASSERT(workSize > 0);
	float *work = new float[workSize];
	sgetri_(&size, matrix, &tda, piv, work, &workSize, &info);
	ALWAYS_ASSERT(info == 0);
	delete[] work;
	delete[] piv;
}

void InvertUpperTriangularMatrixUsingLAPACK(int inSize, double *matrix, int inTda)
{
	__CLPK_integer info = 0;
	__CLPK_integer size = inSize, tda = inTda;

	// We are inverting an upper triangular matrix, but because LAPACK indexes in column-major order
	// (fortran style), we call it a lower triangular matrix here
	dtrtri_((char *)"L", (char *)"N", &size, matrix, &tda, &info);
	ALWAYS_ASSERT(info == 0);
}

void SolveWithUpperTriangularMatrixUsingLAPACK(int inSize1, int inSize2, double *matrix, int inTda, double *rhs, int inTdb)
{
	__CLPK_integer info = 0;
	__CLPK_integer size = inSize1, nRHS = inSize2, tda = inTda, tdb = inTdb;

	// We are solving with an upper triangular matrix, but because LAPACK indexes in column-major order
	// (fortran style), we call it a lower triangular matrix here
	dtrtrs_((char *)"L", (char *)"N", (char *)"N", &size, &nRHS, matrix, &tda, rhs, &tdb, &info);
	ALWAYS_ASSERT(info == 0);
}

void InvertUpperTriangularMatrix(gsl_matrix *matrix)
{
	InvertUpperTriangularMatrixUsingLAPACK(matrix->size1, matrix->data, matrix->tda);
}

void SolveWithUpperTriangularMatrix(gsl_matrix *matrix, gsl_matrix *x)
{
	SolveWithUpperTriangularMatrixUsingLAPACK(matrix->size1, x->size2, matrix->data, matrix->tda, x->data, x->tda);
}

#pragma mark -

void InvertMatrix(gsl_matrix *matrix, int size)
{
	int s, err;
    gsl_matrix *ludecomp = gsl_matrix_calloc(size, size);
    gsl_permutation *perm = gsl_permutation_alloc(size);
	
	gsl_matrix_memcpy(ludecomp, matrix);
	err = gsl_linalg_LU_decomp(ludecomp, perm, &s);
	ALWAYS_ASSERT(err == GSL_SUCCESS);
	err = gsl_linalg_LU_invert(ludecomp, perm, matrix);
	ALWAYS_ASSERT(err == GSL_SUCCESS);
	
	gsl_permutation_free(perm);
	gsl_matrix_free(ludecomp);
}

void InvertMatrix(gsl_matrix_complex *matrix, int size)
{
	int s, err;
    gsl_matrix_complex *ludecomp = gsl_matrix_complex_calloc(size, size);
    gsl_permutation *perm = gsl_permutation_alloc(size);
	
	gsl_matrix_complex_memcpy(ludecomp, matrix);
	err = gsl_linalg_complex_LU_decomp(ludecomp, perm, &s);
	ALWAYS_ASSERT(err == GSL_SUCCESS);
	err = gsl_linalg_complex_LU_invert(ludecomp, perm, matrix);
	ALWAYS_ASSERT(err == GSL_SUCCESS);
	
	gsl_permutation_free(perm);
	gsl_matrix_complex_free(ludecomp);
}

#include <gsl/gsl_blas.h>
#include <gsl/gsl_cblas.h>
#include <gsl/gsl_matrix.h>
jComplex *qr_solve_complex_with_real(gsl_matrix_complex *m, gsl_vector_complex *a)
{
	/*	This function solves a complex system by turning the complex matrix into a real matrix that's twice as large.
	 It is now redundant since I have successfully implemented qr_solve_complex (see below)	*/
	unsigned int i, j;
	double t1, t2;
	t1 = GetTime();
	
	gsl_matrix *m2 = gsl_matrix_alloc(m->size1*2, m->size2*2);
	for (j = 0; j < m->size2; j++)
		for (i = 0; i < m->size1; i++)
		{
			jComplex z(gsl_matrix_complex_get(m, i, j));
			gsl_matrix_set(m2, i*2, j*2, real(z));
			//			gsl_matrix_set(m2, i*2+1, j*2, -imag(z));
			//			gsl_matrix_set(m2, i*2, j*2+1, imag(z));
			gsl_matrix_set(m2, i*2+1, j*2, imag(z));
			gsl_matrix_set(m2, i*2, j*2+1, -imag(z));
			gsl_matrix_set(m2, i*2+1, j*2+1, real(z));
		}
	
	gsl_vector *a2 = gsl_vector_alloc(a->size *2);
	for (i = 0; i < a->size; i++)
	{
		jComplex z(gsl_vector_complex_get(a, i));
		gsl_vector_set(a2, i*2, real(z));
		gsl_vector_set(a2, i*2+1, imag(z));
	}
	
	// Solve for the a,b coefficients that will give us the desired values at our sample sites in the focal plane
	gsl_matrix	*QR = gsl_matrix_alloc(m->size1*2, m->size2*2);
	gsl_matrix_memcpy(QR, m2);
	gsl_vector *tau = gsl_vector_alloc(m->size2*2);
	int result = gsl_linalg_QR_decomp(QR, tau);
	ALWAYS_ASSERT(result == 0);
	
#if 0
	printf("=== QR ===\n");
	for (j = 0; j < m->size2; j++)
	{
		for (i = 0; i < m->size1; i++)
		{
			printf("%.4lf+%.4lfi\n", gsl_matrix_get(QR, i*2, j*2), gsl_matrix_get(QR, i*2, j*2+1));
		}
		printf("\n");
	}
	
	printf("=== tau ===\n");
	for (j = 0; j < m->size2; j++)
	{
		printf("%.4lf+%.4lfi\n", gsl_vector_get(tau, j*2), gsl_vector_get(tau, j*2+1));
	}
	
	printf("=== reconstructed real response matrix ===\n");
	gsl_matrix *Q = gsl_matrix_alloc(m->size1*2, m->size1*2);
	gsl_matrix *R = gsl_matrix_alloc(m->size1*2, m->size2*2);
	result = gsl_linalg_QR_unpack (QR, tau, Q, R);
	ALWAYS_ASSERT(result == 0);
	gsl_matrix *reconstructed = gsl_matrix_alloc(m->size1*2, m->size2*2);
	gsl_blas_dgemm(CblasNoTrans, CblasNoTrans, 1.0, Q, R, 0.0, reconstructed);
	for (j = 0; j < m->size2*2; j++)
	{
		for (i = 0; i < m->size1*2; i++)
		{
			printf("%.4lf\t%.4lf\n", gsl_matrix_get(m2, i, j), gsl_matrix_get(reconstructed, i, j));
		}
		printf("\n");
	}
	gsl_matrix_free(reconstructed);
	gsl_matrix_free(Q);
	gsl_matrix_free(R);
#endif
	
	// Solve for x
	gsl_vector *x = gsl_vector_alloc(m->size2*2);
	gsl_vector *residual = gsl_vector_alloc(m->size1*2);
	result = gsl_linalg_QR_lssolve(QR, tau, a2, x, residual);
	ALWAYS_ASSERT(result == 0);
	
	jComplex *resultVector = new jComplex[m->size2];
	for (i = 0; i < m->size2; i++)
		resultVector[i] = jComplex(gsl_vector_get(x, i*2), gsl_vector_get(x, i*2+1));
	
#if 0
	printf("=== solution comparison ===\n");
	gsl_vector_complex *x2 = gsl_vector_complex_alloc(m->size2);
	for (i = 0; i < m->size2; i++)
		gsl_vector_complex_set(x2, i, gsl_complex_rect(gsl_vector_get(x, i*2), gsl_vector_get(x, i*2+1)));
	gsl_complex one = gsl_complex_rect(1.0, 0);
	gsl_complex zero = gsl_complex_rect(0, 0);
	gsl_vector_complex *multiplyResult = gsl_vector_complex_alloc(m->size1);
	gsl_blas_zgemv(CblasNoTrans, one, m, x2, zero, multiplyResult);
	
	for (i = 0; i < m->size1; i++)
	{
		jComplex z1 = jComplex(gsl_vector_complex_get(multiplyResult, i));
		jComplex z2 = jComplex(gsl_vector_complex_get(a, i));
		printf("%le\t%le\t%le\t%le\n", real(z1) < 1e-10 ? 0 : real(z1), real(z2) < 1e-10 ? 0 : real(z2),
			   imag(z1) < 1e-10 ? 0 : imag(z1), imag(z2) < 1e-10 ? 0 : imag(z2));
	}
	gsl_vector_complex_free(x2);
	gsl_vector_complex_free(multiplyResult);
	
#endif
	
	t2 = GetTime();
	//	ReportElapsedTime(t1, t2, "Field inversion");
	
	gsl_matrix_free(m2);
	gsl_vector_free(a2);
	gsl_matrix_free(QR);
	gsl_vector_free(tau);
	gsl_vector_free(x);
	gsl_vector_free(residual);
	
	return resultVector;
}

jComplex *qr_solve_complex(gsl_matrix_complex *m, gsl_vector_complex *a, bool useGMRES)
{
	double t1, t2;
	t1 = GetTime();
	
	// Solve for the a,b coefficients that will give us the desired values at our sample sites in the focal plane
	gsl_matrix_complex	*QR = gsl_matrix_complex_alloc(m->size1, m->size2);
	gsl_matrix_complex_memcpy(QR, m);
	gsl_vector_complex *tau = gsl_vector_complex_alloc(m->size2);
	int result = gsl_linalg_complex_QR_decomp(QR, tau);
	ALWAYS_ASSERT(result == 0);
	
#if 0
	unsigned int j;
	printf("=== QR ===\n");
	for (j = 0; j < m->size2; j++)
	{
		for (unsigned int i = 0; i < m->size1; i++)
		{
			jComplex z1(gsl_matrix_complex_get(QR, i, j));
			printf("%.4lf+%.4lfi\n", real(z1), imag(z1));
		}
		printf("\n");
	}
	
	printf("=== tau ===\n");
	for (j = 0; j < tau->size; j++)
	{
		jComplex z1(gsl_vector_complex_get(tau, j));
		printf("%.4lf+%.4lfi\n", real(z1), imag(z1));
	}
	
	printf("=== reconstructed real response matrix ===\n");
	gsl_matrix_complex *Q = gsl_matrix_complex_alloc(m->size1, m->size1);
	gsl_matrix_complex *R = gsl_matrix_complex_alloc(m->size1, m->size2);
	result = gsl_linalg_complex_QR_unpack (QR, tau, Q, R);
	ALWAYS_ASSERT(result == 0);
	gsl_matrix_complex *reconstructed = gsl_matrix_complex_alloc(m->size1, m->size2);
	gsl_blas_zgemm(CblasNoTrans, CblasNoTrans, gsl_complex_rect(1, 0), Q, R, gsl_complex_rect(0, 0), reconstructed);
	for (j = 0; j < m->size2; j++)
	{
		for (i = 0; i < m->size1; i++)
		{
			jComplex z1(gsl_matrix_complex_get(m, i, j));
			jComplex z2(gsl_matrix_complex_get(reconstructed, i, j));
			printf("%.4lf+%.4lfi\t%.4lf+%.4lfi\n", real(z1), imag(z1), real(z2), imag(z2));
		}
		printf("\n");
	}
	gsl_matrix_complex_free(reconstructed);
	gsl_matrix_complex_free(Q);
	gsl_matrix_complex_free(R);
#endif
	
	// Solve for x
	gsl_vector_complex *x = gsl_vector_complex_alloc(m->size2);
	jComplex *resultVector;
	if (useGMRES)
	{
		/*	GMRES works, but you need a fairly good guess as to what the beam breakdown is before you start,
		 or otherwise it diverges.
		 As a result, I haven't managed to get this to work usefully. I wanted to because it was a reviewer's
		 suggestion for my beam shape coefficient paper. I have done enough to establish that the method
		 seems to take a fair amount of time EVEN if I start with what is basically a perfect guess	*/
		static gsl_vector_complex *x2 = NULL;
		if (x2 == NULL)
		{
			x2 = gsl_vector_complex_alloc(m->size2);
		}
		else if (m->size2 != x2->size)
		{
			gsl_vector_complex_free(x2);
			x2 = gsl_vector_complex_alloc(m->size2);
		}
		gsl_vector_complex *residual = gsl_vector_complex_alloc(m->size1);
		result = gsl_linalg_complex_QR_lssolve(QR, tau, a, x2, residual);
		gsl_vector_complex_free(residual);
		gsl_vector_complex_memcpy(x, x2);
#if 1
		printf("solve\n");
		resultVector = gmres_solve(*m, *a, 1e-6, x);
		printf("done\n");
#else
		resultVector = new jComplex[m->size2];
		for (unsigned int i = 0; i < m->size2; i++)
			resultVector[i] = jComplex(gsl_vector_complex_get(x, i));
#endif
	}
	else
	{
#if 1
		gsl_vector_complex *residual = gsl_vector_complex_alloc(m->size1);
		result = gsl_linalg_complex_QR_lssolve(QR, tau, a, x, residual);
		gsl_vector_complex_free(residual);
#else
		gsl_vector_complex_memcpy(x, a);
		result = gsl_linalg_complex_QR_svx(QR, tau, x);
#endif
		resultVector = new jComplex[m->size2];
		for (unsigned int i = 0; i < m->size2; i++)
			resultVector[i] = jComplex(gsl_vector_complex_get(x, i));
	}
	ALWAYS_ASSERT(result == 0);
	
#if 0
	printf("=== solution comparison ===\n");
	gsl_complex one = gsl_complex_rect(1.0, 0);
	gsl_complex zero = gsl_complex_rect(0, 0);
	gsl_vector_complex *multiplyResult = gsl_vector_complex_alloc(m->size1);
	gsl_blas_zgemv(CblasNoTrans, one, m, x, zero, multiplyResult);
	
	for (unsigned int i = 0; i < m->size1; i++)
	{
		jComplex z1 = jComplex(gsl_vector_complex_get(multiplyResult, i));
		jComplex z2 = jComplex(gsl_vector_complex_get(a, i));
		printf("%le\t%le\t%le\t%le\n", real(z1) < 1e-10 ? 0 : real(z1), real(z2) < 1e-10 ? 0 : real(z2),
			   imag(z1) < 1e-10 ? 0 : imag(z1), imag(z2) < 1e-10 ? 0 : imag(z2));
	}
	gsl_vector_complex_free(multiplyResult);
	
#endif
	
	t2 = GetTime();
	//	ReportElapsedTime(t1, t2, "Field inversion");
	
	
	gsl_matrix_complex_free(QR);
	gsl_vector_complex_free(tau);
	gsl_vector_complex_free(x);
	
	return resultVector;
}

#endif

