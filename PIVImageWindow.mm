//
//  PIVImageWindow.mm
//  Spim Interface
//
//  Created by Jonny Taylor on 30/10/2016.
//
//

#include <stdint.h>         // Seems to be needed on some platforms
#include <float.h>         // Seems to be needed on some platforms
#include "PIVImageWindow.h"
#include "VectorTypes.h"
#include "VectorFunctions.h"

template <class TYPE> TYPE SadFunc(TYPE a, TYPE b);
template<> double SadFunc<double>(double a, double b) { return fabs(a - b); }
template<> int SadFunc<int>(int a, int b) { return abs(a - b); }
// Things get messy for the 8- and 16-bit cases because we were working with an unsigned type!
// Fortunately this shouldn't get called, since I have included a template specialization for that case.
template<> unsigned char SadFunc<unsigned char>(unsigned char a, unsigned char b) { return (unsigned char)abs(int(a) - int(b)); }
template<> unsigned short SadFunc<unsigned short>(unsigned short a, unsigned short b) { return (unsigned short)abs(int(a) - int(b)); }

template<> IntegerPoint ImageWindow<double>::CalculateFlowPeakInteger(void) const
{
	// Look for the location of the minimum (positive-valued...) value in the correlation array
	// We insist on an odd-dimensioned correlation matrix in order to make things simpler
	ALWAYS_ASSERT(width & 1);
	ALWAYS_ASSERT(height & 1);
	ALWAYS_ASSERT(width == elementsPerRow);
	double minVal = DBL_MAX;
	IntegerPoint result(-1,-1);
	for (int y = 0; y < height; y++)
		for (int x = 0; x < width; x++)
		{
			if (PixelXY(x, y) < minVal)
			{
				minVal = PixelXY(x, y);
				result = IntegerPoint(x, y);
			}
		}
    return result;
}
	
template<> coord2 ImageWindow<double>::CalculateFlowPeak(void) const
{
    IntegerPoint resultInt = CalculateFlowPeakInteger();
    int minX = resultInt.x, minY = resultInt.y;
    coord2 result(minX-width/2, minY-height/2);

    // Sub-pixel parabolic fit
    // This code is taken from the python code in openPIV
	if ((minX > 0) && (minX < width-1))
	{
		double cl = PixelXY(minX-1, minY);
		double c = PixelXY(minX, minY);
		double cr = PixelXY(minX+1, minY);
		result.x += (cl-cr)/(2*cl-4*c+2*cr);
	}
	if ((minY > 0) && (minY < height-1))
	{
		double cu = PixelXY(minX, minY+1);
		double c = PixelXY(minX, minY);
		double cd = PixelXY(minX, minY-1);
        result.y += (cd-cu)/(2*cd-4*c+2*cu);
	}
    
	return result;
}

template<> double ImageWindow<double>::CalculateSNR(int threshold) const
{
    // First determine the integer location of the peak value (minimum of SAD)
    IntegerPoint peakPos = CalculateFlowPeakInteger();
    
    // Look for the smallest value outside a region around that point
    double nextMinVal = DBL_MAX;
    for (int y = 0; y < height; y++)
        for (int x = 0; x < width; x++)
        {
            if ((abs(x-peakPos.x) > threshold) ||
                (abs(y-peakPos.y) > threshold))
            {
                if (PixelXY(x, y) < nextMinVal)
                    nextMinVal = PixelXY(x, y);
            }
        }
    
    // Calculate the ratio of values.
    // Due to our use of SAD, we cannot interpret this the same way as would be done in standard PIV,
    // but it should at least be reasonable to say that a larger difference is good!
    return nextMinVal / PixelXY(peakPos.x, peakPos.y);
}

#pragma mark -

template<int correlationType, class TYPE> void CrossCorrelateImageWindows(ImageWindow<TYPE> &window1, ImageWindow<TYPE> &window2, ImageWindow<double> &result)
{
    // Generic version
    // For every possible shift of 'a' relative to 'b', calculate the SAD
    int w1Width = window1.width;
    int w1Height = window1.height;
	int maxDX = window2.width - window1.width;
	int maxDY = window2.height - window1.height;
	
    for (int dy = 0; dy <= maxDY; dy++)
        for (int dx = 0; dx <= maxDX; dx++)
        {
            double sum = 0;
            if (correlationType == kCorrelationSAD)
            {
                // Sum of absolute differences
                for (int y = 0; y < w1Height; y++)
                    for (int x = 0; x < w1Width; x++)
                    {
                        sum += SadFunc<TYPE>(window1.PixelXY(x,y), window2.PixelXY(x+dx,y+dy));
                    }
            }
            else if (correlationType == kCorrelationSSD)
            {
                // Sum of squared differences
                for (int y = 0; y < w1Height; y++)
                    for (int x = 0; x < w1Width; x++)
                    {
                        double diff = (window1.PixelXY(x,y) - window2.PixelXY(x+dx,y+dy));
                        sum += diff*diff;
                    }
            }
            else
            {
                // Direct cross-correlation
				ALWAYS_ASSERT(correlationType == kCorrelationDCC);
                for (int y = 0; y < w1Height; y++)
                    for (int x = 0; x < w1Width; x++)
                    {
                        sum -= (window1.PixelXY(x,y) * window2.PixelXY(x+dx,y+dy)); // Negative is to ensure we find the peak minimum
                    }
            }
            result.SetXY(dx, dy, sum);
        }
}

template<> void CrossCorrelateImageWindows<kCorrelationSAD, unsigned char>(ImageWindow<unsigned char> &window1, ImageWindow<unsigned char> &window2, ImageWindow<double> &result)
{
    // Specialized version for SAD with 8-bit data
    // For every possible shift of 'a' relative to 'b', calculate the SAD
    int w1Width = window1.width;
    int w1Height = window1.height;
    int maxDX = window2.width - window1.width;
    int maxDY = window2.height - window1.height;
    for (int dy = 0; dy <= maxDY; dy++)
        for (int dx = 0; dx <= maxDX; dx++)
        {
            double sum = 0;
            
            /*  These are the inner loops that perform the SAD calculation.
                Fast strategies for computing the SAD are very much platform-dependent,
                especially on ARM where I have not found a natural and simple set of instructions to use.
                As a consequence, I have not been able to abstract this code using my wrappers in VectorFunctions.h,
                and have had to actually write separate code branches for different instruction sets.   */
#if __SSE2__ || __ARM_NEON__
            vUInt64 sumVec = vZeroUInt64();
            for (int y = 0; y < w1Height; y++)
            {
                int x = 0;
                for (; x <= w1Width - 16; x += 16)
                    sumVec = vAdd(sumVec, vSad_u8_to_u64(vLoadUnaligned((vUInt8*)window1.PixelXYAddr(x, y)), vLoadUnaligned((vUInt8*)window2.PixelXYAddr(x+dx, y+dy))));
                for (; x < w1Width; x++)
                    sum += abs(window1.PixelXY(x, y) - window2.PixelXY(x+dx, y+dy));
            }
            sum += SumAcross(&sumVec);
#else
            // Fallback code for when vector instructions are not available.
            // It is possible the compiler may auto-vectorise, although the SAD is specialised enough that I would be impressed
            // if it spontaneously came up with an even close to optimal instruction sequence.
    #if _MSC_VER
        #pragma message("Vector instruction set unavailable - falling back to slower scalar code for uint8 SAD")
    #else//__GNUC__ - may need other defines for different compilers
        #warning "Vector instruction set unavailable - falling back to slower scalar code for uint8 SAD"
    #endif
            for (int y = 0; y < w1Height; y++)
                for (int x = 0; x < w1Width; x++)
                    sum += abs(window1.PixelXY(x, y) - window2.PixelXY(x+dx, y+dy));
            
            /* TODO: I came across this code which looks like it might well perform better than the scalar option, for pre-SSE3.
                http://0x80.pl/notesen/2018-03-11-sse-abs-unsigned.html
                The reasoning is that a saturated subtraction will yield zero for one of the two orderings,
                and the correct answer for the other ordering!
                     __m128i abs_sub_epu8(const __m128i a, const __m128i b)
                     {
                         const __m128i ab = _mm_subs_epu8(a, b);
                         const __m128i ba = _mm_subs_epu8(b, a);
                         return _mm_or_si128(ab, ba);
                     }
                However, I would still need to work out how to handle the accumulate part.
                This code would leave the result in individual 8-bit results, and I would need to do either a horizontal add
                or some sort of pairwise add. Horizontal adds are supposed to be slow. I don't know if I could find a creative
                pairwise add that I could use. The obvious instruction that promotes to a larger data type is... the SAD instruction!
            */
#endif
            // Store the result in the correlation matrix
            result.SetXY(dx, dy, sum);
        }
}

template<> void CrossCorrelateImageWindows<kCorrelationSAD, unsigned short>(ImageWindow<unsigned short> &window1, ImageWindow<unsigned short> &window2, ImageWindow<double> &result)
{
    // Specialized version for SAD with 16-bit data
    // For every possible shift of 'a' relative to 'b', calculate the SAD
    int w1Width = window1.width;
    int w1Height = window1.height;
	int maxDX = window2.width - window1.width;
	int maxDY = window2.height - window1.height;
	
    // At present, this code accumulates the result in a uint32, which means there is a limit
    // on how large a correlation matrix we can process without overflowing our data types.
#ifdef Py_ERRORS_H
	if (maxDX * maxDY >= (1<<15))
    {
		PyErr_Format(PyExc_TypeError, "WOAH - that's a seriously big correlation matrix! This integer-based SAD code only accepts IWs that lead to correlation matrices with up to 2^15 entries.");
        throw std::invalid_argument("correlation matrix too large");
    }
#else
	ALWAYS_ASSERT(maxDX * maxDY < (1<<15));
#endif
	
    /*  There may be specific circumstances where I want to force the IWs to be smaller in size, but to still be centered
        in the same places as they would be if they were larger. Under those circumstances it is not trivial to provide
        the correct PIV settings to make that happen, and it's easier to leave the PIV settings as they are but to hack
        this function to reduce the actual area over which we do the processing.
        To do that, set inset to a positive value.  */
    const int inset = 0;
    
    // Do the main comparison loop
	for (int dy = 0; dy <= maxDY; dy++)
        for (int dx = 0; dx <= maxDX; dx++)
        {
            double sum = 0;
            vUInt32 sumVec = vZeroUInt32();
            for (int y = inset; y < w1Height-inset; y++)
            {
                int x = inset;
#if __SSE2__ || __ARM_NEON__
                for (; x <= w1Width - 8-inset; x += 8)
				{
					vUInt16 a = vLoadUnaligned((vUInt16*)window1.PixelXYAddr(x, y));
					vUInt16 b = vLoadUnaligned((vUInt16*)window2.PixelXYAddr(x+dx, y+dy));
                    vUInt32 sad = vSad_u16_to_u32(a, b);
                    sumVec = vAdd(sumVec, sad);
                }
#else
    #if _MSC_VER
        #pragma message("Vector instruction set unavailable - falling back to slower scalar code for uint16 SAD")
    #else//__GNUC__ - may need other defines for different compilers
        #warning "Vector instruction set unavailable - falling back to slower scalar code for uint16 SAD"
    #endif
#endif
                for (; x < w1Width-inset; x++)
                    sum += abs(window1.PixelXY(x, y) - window2.PixelXY(x+dx, y+dy));
            }
            sum += SumAcross(&sumVec);
            result.SetXY(dx, dy, sum);
        }
}

void Check16BitData(ImageWindow<int> &window1)
{
	// Although this is in principle unnecessary and therefore inefficient, I want to include a test to ensure no values
	// are larger than 2^16-1. The test should be quick, and it will catch what would otherwise be nasty bugs
    int w1Width = window1.width;
    int w1Height = window1.height;
	
	vUInt32 orVec = vZeroUInt32();
	int orRest = 0;
	for (int y = 0; y < w1Height; y++)
	{
		int x = 0;
#if HAS_VECTOR_SUPPORT
        for (; x <= w1Width - 4; x += 4)
			orVec = vOr(orVec, vLoadUnaligned((vUInt32 *)window1.PixelXYAddr(x, y)));
#endif
        for (; x < w1Width; x++)
			orRest |= window1.PixelXY(x, y);
	}
	int result = orRest | OrAcross(&orVec);
#ifdef Py_ERRORS_H
	if (result & 0xFFFF0000)
    {
        PyErr_Format(PyExc_TypeError, "ERROR - you passed in values greater than 2^16 - 1 to the fast SAD code!");
        throw std::invalid_argument("value out of range");
    }
#else
	ALWAYS_ASSERT(!(result & 0xFFFF0000));
#endif
}

template<> void CrossCorrelateImageWindows<kCorrelationSAD, int>(ImageWindow<int> &window1, ImageWindow<int> &window2, ImageWindow<double> &result)
{
    // Specialized version for SAD with 32-bit data, BUT we assume we will not overflow an int when we sum across a small IW.
    // This probably implies that it should be used with 16-bit input data, and small IW pixel counts <=2^16 !
    
    // For every possible shift of 'a' relative to 'b', calculate the SAD
    int w1Width = window1.width;
    int w1Height = window1.height;
	int maxDX = window2.width - window1.width;
	int maxDY = window2.height - window1.height;
	
	Check16BitData(window1);
	Check16BitData(window2);
#ifdef Py_ERRORS_H
	if (maxDX * maxDY >= (1<<15))
    {
		PyErr_Format(PyExc_TypeError, "WOAH - that's a seriously big correlation matrix! This integer-based SAD code only accepts IWs that lead to correlation matrices with up to 2^15 entries.");
        throw std::invalid_argument("correlation matrix too large");
    }
#else
	ALWAYS_ASSERT(maxDX * maxDY < (1<<15));
#endif
	
	// Now get down to business!
	for (int dy = 0; dy <= maxDY; dy++)
        for (int dx = 0; dx <= maxDX; dx++)
        {
            double sum = 0;
            vUInt32 sumVec = vZeroUInt32();
            for (int y = 0; y < w1Height; y++)
            {
                int x = 0;
#if __SSE2__ || __ARM_NEON__
                // I have not documented why I have used unaligned loads here, but I suspect I decided it did not involve much of a speed penalty,
                // and possibly I did have a use-case where this was necessary...
                for (; x <= w1Width - 4; x += 4)
                    sumVec = vAdd(sumVec, vAbs(vSub(vLoadUnaligned((vUInt32*)window1.PixelXYAddr(x, y)), vLoadUnaligned((vUInt32*)window2.PixelXYAddr(x+dx, y+dy)))));
                /*  TODO: see example code above (not yet implemented) that involves _mm_subs_epu8.
                    That would provide a fallback for the case where vAbs is not available. */
#else
    #if _MSC_VER
        #pragma message("Vector instruction set unavailable - falling back to slower scalar code for int32 SAD")
    #else//__GNUC__ - may need other defines for different compilers
        #warning "Vector instruction set unavailable - falling back to slower scalar code for int32 SAD"
    #endif
#endif
                for (; x < w1Width; x++)
                    sum += abs(window1.PixelXY(x, y) - window2.PixelXY(x+dx, y+dy));
            }
            sum += SumAcross(&sumVec);
            result.SetXY(dx, dy, sum);
        }
}

/*	I haven't worked out a neat way of avoiding link errors due to these not being instantiated,
	so I just force their instantiation. I suspect I should just have all the specializations in a header file,
	but that seems a bit messy in terms of dependencies?	*/
//template void CrossCorrelateImageWindows<kCorrelationSAD, unsigned short>(ImageWindow<unsigned short> &window1, ImageWindow<unsigned short> &window2, ImageWindow<double> &result);
template void CrossCorrelateImageWindows<kCorrelationSSD, unsigned short>(ImageWindow<unsigned short> &window1, ImageWindow<unsigned short> &window2, ImageWindow<double> &result);
template void CrossCorrelateImageWindows<kCorrelationDCC, unsigned short>(ImageWindow<unsigned short> &window1, ImageWindow<unsigned short> &window2, ImageWindow<double> &result);
template void CrossCorrelateImageWindows<kCorrelationSAD, double>(ImageWindow<double> &window1, ImageWindow<double> &window2, ImageWindow<double> &result);
template void CrossCorrelateImageWindows<kCorrelationSSD, double>(ImageWindow<double> &window1, ImageWindow<double> &window2, ImageWindow<double> &result);
template void CrossCorrelateImageWindows<kCorrelationDCC, double>(ImageWindow<double> &window1, ImageWindow<double> &window2, ImageWindow<double> &result);
//template void CrossCorrelateImageWindows<kCorrelationSAD, unsigned char>(ImageWindow<unsigned char> &window1, ImageWindow<unsigned char> &window2, ImageWindow<double> &result);
template void CrossCorrelateImageWindows<kCorrelationSSD, unsigned char>(ImageWindow<unsigned char> &window1, ImageWindow<unsigned char> &window2, ImageWindow<double> &result);
//template void CrossCorrelateImageWindows<kCorrelationSAD, int>(ImageWindow<int> &window1, ImageWindow<int> &window2, ImageWindow<double> &result);
template void CrossCorrelateImageWindows<kCorrelationSSD, int>(ImageWindow<int> &window1, ImageWindow<int> &window2, ImageWindow<double> &result);
