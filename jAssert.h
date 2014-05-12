/*
 *	jAssert.h
 *
 *  Code to handle assertions
 */
#ifndef __JASSERT_H__
#define __JASSERT_H__

#include <stdio.h>

/*	There is the option of having asserts inline, but the preferred option is to call an
	object which will handle the assertion. This for example opens up the possibility of
	overriding the default assertion handler, as well as potentially keeping the code
	smaller	*/
#ifdef J_INLINE_ASSERTS
	#define ALWAYS_ASSERT(CONDITION) do { if (!(CONDITION)) { printf("Assertion failed on line %ld, file %s\n", (long)__LINE__, __FILE__); fflush(stdout); *((long *)0L) = 0; } } while(0)
	#define CHECK(CONDITION) do { if (!(CONDITION)) { printf("Check failed on line %ld, file %s\n", (long)__LINE__, __FILE__); fflush(stdout); } } while(0)
#else
	class BaseAssertionHandler
	{
	  protected:
		virtual void PullDownCode(void) __attribute__((__noreturn__));
	  public:
		virtual ~BaseAssertionHandler() { }
		/*	I had hoped to designate this next function as noreturn, but that causes endless concerns
			for the static analyzer which sees e.g. blocks prematurely terminated and subsequent code
			encountering uninitialized values etc.	*/
		virtual void AssertionFailed(long line, const char *file) __attribute__((__noreturn__));
		virtual bool CheckCondition(bool condition, long line, const char *file);
	};
	extern BaseAssertionHandler *assertionHandler;

	#define ALWAYS_ASSERT(CONDITION) do { if (__builtin_expect(!(CONDITION), false)) { assertionHandler->AssertionFailed(__LINE__, __FILE__); } } while (0)
	#define CHECK(CONDITION) assertionHandler->CheckCondition((CONDITION), __LINE__, __FILE__)
#endif

#define ALWAYS_ASSERT_NOERR(RESULT) do { if (RESULT != 0) { printf("Error code %ld encountered\n", (long)(RESULT)); ALWAYS_ASSERT(0); } } while(0)
#define IGNORE_CONDITION(CONDITION) do { } while(0)

// Some assertions are only defined in the debug build
#if DEBUGGING
	#define ASSERT(CONDITION) ALWAYS_ASSERT(CONDITION)
	#define HARMLESS_ASSERT(CONDITION) ALWAYS_ASSERT(CONDITION)
	#define ASSERT_NOERR(RESULT) ALWAYS_ASSERT_NOERR((RESULT))
#else
	#define ASSERT(CONDITION) IGNORE_CONDITION(CONDITION)
	#define HARMLESS_ASSERT(CONDITION) IGNORE_CONDITION(CONDITION)
	#define ASSERT_NOERR(RESULT) IGNORE_CONDITION(CONDITION)
#endif

#endif
