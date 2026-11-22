/*
 *  jHistogram.cpp
 *
 *  Copyright 2011-2015 Jonathan Taylor. All rights reserved.
 *
 *  C++ class to maintain a histogram based on datapoints that are added one by one
 *  Caller can query contents of any particular histogram bin.
 *
 */

#include "jHistogram.h"
#include <algorithm>

jHistogram::jHistogram(double fbs/*first bin starts at*/, double bw/*bin width*/, int numBins, bool io/*include outliers in end bins*/)
{
	includeOutliers = io;
	SetHistogramParams(fbs, bw, numBins);
	numMissed = 0;
	missedVal = INT_MIN;
}

void jHistogram::SetHistogramParams(double fbs/*first bin starts at*/, double bw/*bin width*/, int numBins, bool reset)
{
	if (includeOutliers)
		CHECK(reset == true);
		
	if (!reset)
	{
		// In some circumstances (unchanged bin width, shift by integer number of bins)
        // we can retain the existing data while extending the histogram range
		const double shift = (fbs - firstBinStart) / bw;
		if (bw == binWidth && std::isfinite(shift) && shift == std::trunc(shift))
		{
			std::vector<int> resized(numBins);
			const int oldBinCount = int(histogram.size());
			// In old-bin coordinates, the new range starts at shift and spans numBins bins.
			if (shift > -numBins && shift < oldBinCount)
			{
				// A rightward shift skips old bins. A leftward shift leaves new bins empty at the front.
				const int firstOldBin = std::max(int(shift), 0);
				const int firstNewBin = std::max(-int(shift), 0);
				const int binsToKeep = std::min(oldBinCount - firstOldBin, numBins - firstNewBin);
				std::copy_n(histogram.begin() + firstOldBin, binsToKeep, resized.begin() + firstNewBin);
			}
			histogram.swap(resized);
			firstBinStart = fbs;
			fbsInt = fbs;
			return;
		}
		else
		{
			// If we are not asked to reset then the caller should have ensured these conditions were met to be able to retain existing data
			CHECK(false);
			// Fall through to reset code
		}
	}
	
	// Resize and reset
	numMissed = 0;
	histogram = std::vector<int>(numBins);
	firstBinStart = fbs;
    fbsInt = fbs;
	binWidth = bw;
}

double jHistogram::MaxVal(void) const
{
	// Greatest value in the histogram
	return *std::max_element(histogram.begin(), histogram.end());
}

void jHistogram::Print(void)
{
	for (size_t i = 0; i < histogram.size(); i++)
		printf("%zd\t%le\t%d\n", i, firstBinStart + i * binWidth, histogram[i]);
}
