/*
 *  InvertMatrix.h
 *  scatter
 *
 *  Created by Jonathan Taylor on 17/02/2010.
 *  Copyright 2010 Durham University. All rights reserved.
 *
 */


void InvertUpperTriangularMatrix(gsl_matrix *matrix);
void SolveWithUpperTriangularMatrix(gsl_matrix *matrix, gsl_matrix *x);
void InvertComplexMatrixUsingLAPACK(int inSize, jComplex *matrix);
