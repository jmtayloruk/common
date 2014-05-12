/*
 *	jBigNum.cpp
 *
 *  Utility functions associated with jBigNum class (see header file)
 */
#include "jBigNum.h"

double jBigNum::expTable[kBigNumMaxExponentInTable + 1];
double jBigNum::invExpTable[kBigNumMaxExponentInTable + 1];
double jBigNum::logExponent;

void Print(jBigNum z)
{
	Print(z.detail());
	printf(" x e^%ld", z.exponent() * jBigNum::kBigNumExponentPowerOfE);
}

void MakeScientificNotation(double &x, long &exponent)
{
	while (fabs(x) >= 10.0)
	{
		x *= 0.1;
		exponent++;
	}
	while (fabs(x) < 1.0)
	{
		x *= 10.0;
		exponent--;
	}
}

void PrintOneComponent(double detail, long exponent)
{
	double detailPart = detail;
	long decimalExponent = 0;
	long i;

	if (detail == 0.0)
	{
		printf("0.000000e+00");
		return;
	}
	MakeScientificNotation(detailPart, decimalExponent);
	if (exponent >= 0)
	{
		for (i = 0; i < exponent; i++)
		{
			detailPart *= exp(jBigNum::kBigNumExponentPowerOfE);
			MakeScientificNotation(detailPart, decimalExponent);
		}
	}
	else
	{
		for (i = exponent; i < 0; i++)
		{
			detailPart /= exp(jBigNum::kBigNumExponentPowerOfE);
			MakeScientificNotation(detailPart, decimalExponent);
		}
	}
	printf("%.6lfe%+.02ld", detailPart, decimalExponent);
}	
	
void PrintDecimal(jBigNum z)
{
	printf("{");
	PrintOneComponent(real(z.detail()), z.exponent());
	printf(", ");
	PrintOneComponent(imag(z.detail()), z.exponent());
	printf("}");
}


void jBigNum::InitBigNum(void)
{
	for (long i = 0; i <= kBigNumMaxExponentInTable; i++)
	{
		expTable[i] = exp(kBigNumExponentPowerOfE * i);
		invExpTable[i] = 1.0 / expTable[i];
		logExponent = log(exp(kBigNumExponentPowerOfE));
	}
}

bool CheckAgreement(jBigNum val1, jComplex val2, double relError, double absError, bool printOnDisagreement, double *amount)
{
	if (!val1.FitsInDouble())
	{
		if (printOnDisagreement)
		{
			printf("DISAGREEMENT: ");
			Print(val1);
			printf(" and ");
			Print(val2);
		}
		return false;
	}
	return CheckAgreement(val1.to_jcomplex(), val2, relError, absError, printOnDisagreement, amount);
}

bool CheckAgreement(jComplex val1, jBigNum val2, double relError, double absError, bool printOnDisagreement, double *amount)
{
	if (!val2.FitsInDouble())
	{
		if (printOnDisagreement)
		{
			printf("DISAGREEMENT: ");
			Print(val1);
			printf(" and ");
			Print(val2);
		}
		return false;
	}
	return CheckAgreement(val1, val2.to_jcomplex(), relError, absError, printOnDisagreement, amount);
}
