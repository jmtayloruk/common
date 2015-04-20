/*
 *  jHistogram.h
 *
 *  Copyright 2011-2015 Jonathan Taylor. All rights reserved.
 *
 *  C++ class to maintain a histogram based on datapoints that are added one by one
 *  Caller can query contents of any particular histogram bin.
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
    int fbsInt;
	int numMissed;
	bool includeOutliers;
  public:
    jHistogram(double fbs, double binWidth, int numBins, bool includeOutliers = false);
	double operator[](size_t i) const { return histogram[i]; }

	void SetHistogramParams(double fbs, double binWidth, int numBins, bool reset = true);
    void AddDatapoint(double val)
    {
        int bin = int((val - firstBinStart) / binWidth);
        if (includeOutliers)
            bin = LIMIT(bin, 0, int(histogram.size()-1));
        if ((bin < 0) || (bin >= int(histogram.size())))
            numMissed++;
        else
            histogram[bin]++;
    }
    
    void AddDatapoint_bw1(int val)
    {
        int bin = val - fbsInt;
        if ((bin < 0) || (bin >= int(histogram.size())))
            numMissed++;
        else
            histogram[bin]++;
    }
	void Reset(void) { histogram.assign(histogram.size(), 0); }
	int NumMissed(void) const { return numMissed; }
	size_t NumBins(void) const { return histogram.size(); }
	double BinStartVal(int i) const { return firstBinStart + i * binWidth; }
	double MaxVal(void) const;
	void Print(void);
};

#endif
