#ifndef __JUTILS_H__
#define __JUTILS_H__

extern const double PI;
extern const double NaN;

namespace fundamental_constants
{
	extern const double c;
	extern const double e_0;
	extern const double electronic_charge;
	extern const double mu_0;
	extern const double eta_0;
	extern const double k_b;
    extern const double g;
	extern const double root4PiE0, root4PiMu0;
	extern const double L, lambda_b;
}

#include "jCommon.h"
#include "jTimeUtils.h"
#include "jBigNum.h"
#include "jCoord.h"

void *void_aligned_malloc(size_t size, size_t align_size);
void aligned_free(volatile void *inPtr);
template<class C> C *aligned_malloc(size_t size, size_t align_size = 16)
{
	return (C *)void_aligned_malloc(size * sizeof(C), align_size);
}

class LocalEnableDenormalFlushing
{
  protected:
	int	oldmxcsr;
	
  public:
	LocalEnableDenormalFlushing(void);
	~LocalEnableDenormalFlushing();
};

template<class C> void DeleteArrayIfNotNull(C *v)
{
	if (v != NULL)
		delete[] v;
}

template<class C> void DeleteIfNotNull(C *v)
{
	if (v != NULL)
		delete v;
}

const char *GetAddressString(int address, char addressString[128]);

inline double DegreesToRadians(double deg) { return deg / 180.0 * PI; }
inline double RadiansToDegrees(double rad) { return rad * 180.0 / PI; }

char *NewCopyOfString(const char *inString);

#if OS_X
	#include <Carbon/Carbon.h>
	StringPtr ConvertCToPascalString (const char *theString, Str255 pStr);
#endif

bool FileExists(const char *theFile);


#if __OBJC__
    NSURL *PathToURL(NSString *path, NSURL *relativeTo);
    NSURL *PathToURL(NSString *path);
    bool IsDirectory(NSURL *fileURL);

	NSArray *ListImageFilesInDirectory(NSString *dir);
	void UpdateKeys(id owner, ...) NS_REQUIRES_NIL_TERMINATION;
	bool StringIsInList(NSString *s, ...) NS_REQUIRES_NIL_TERMINATION;

	typedef id (^BlockReturningObject)(void);
	@class MAZeroingWeakRef;
	id ResurrectWeakRef(MAZeroingWeakRef *&ref, BlockReturningObject resurrectionBlock);
	id ResurrectAndShowWeakWindowRef(MAZeroingWeakRef *&ref, BlockReturningObject resurrectionBlock);
  #ifdef __BLOCKS__
        void ForEveryImageFileInDirectory(NSString *dir, void (^callback)(NSString *));
        void ForEveryImageFileInDirectoryConcurrent(NSString *dir, void (^callback)(NSString *));
  #endif
    NSString *FirstImageFileNameInDirectory(NSString *dir);
#endif

#if __OBJC__
  #ifdef __BLOCKS__
    void ForEveryImageFileInDirectory(NSString *dir, void (^callback)(NSString *));
    void ForEveryImageFileInDirectoryConcurrent(NSString *dir, void (^callback)(NSString *));
  #endif
    NSString *FirstImageFileNameInDirectory(NSString *dir);
#endif

#endif
