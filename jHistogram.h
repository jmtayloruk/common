/*
 *  jHistogram.h
 *  Simple Preview
 *
 *  Created by Jonathan Taylor on 06/11/2011.
 *  Copyright 2011 Durham University. All rights reserved.
 *
 */

#ifndef __J_HISTOGRAM_H__
#define __J_HISTOGRAM_H__ 1

#include <vector>

class jHistogram
{
  protected:
	std::vector<int> histogram;
	double firstBinStart, binWidth;
	int numMissed;
	bool includeOutliers;
  public:
    jHistogram(double fbs, double binWidth, int numBins, bool includeOutliers = false);
	double operator[](size_t i) const { return histogram[i]; }

	void SetHistogramParams(double fbs, double binWidth, int numBins, bool reset = true);
	void AddDatapoint(double val);
	void Reset(void) { histogram.assign(histogram.size(), 0); }
	int NumMissed(void) const { return numMissed; }
	size_t NumBins(void) const { return histogram.size(); }
	double BinStartVal(int i) const { return firstBinStart + i * binWidth; }
	double MaxVal(void) const;
	void Print(void);
};

#endif
