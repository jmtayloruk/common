//
//  MIPProcessing.h
//  Spim Interface
//
//  Created by Jonny Taylor on 10/09/2015.
//
//

void ProcessStacksIntoMIPs(void (^completionBlock)(int mipCounter, NSURL *destinationURL));
void CalcMip(unsigned char *mipPixels, const unsigned char *otherPixels, size_t numPixels, bool fast=true);
void CalcMip(unsigned short *mipPixels, const unsigned short *otherPixels, size_t numPixels, bool fast=true);
void CalcMipForBPP(unsigned char *mipData, const unsigned char *otherData, size_t bytes, int bitsPerPixel, bool fast=true);
void CalcYZMip(NSBitmapImageRep *mipBitmap, int mipYPos, NSBitmapImageRep *frameBitmap, int yOffset = 0/* for shear */);
void UpdateMipWithBitmap(NSBitmapImageRep *mipBitmap, NSBitmapImageRep *frameBitmap);
