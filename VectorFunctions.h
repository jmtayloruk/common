/*
 *	VectorFunctions.h
 *
 *	Copyright 2010-2015 Jonathan Taylor. All rights reserved.
 *
 *  Platform-independent wrappers around basic CPU vector operations
 *
 */

// TODO: There is a mix here of relying on my defines like HAS_ALTIVEC, and compiler ones like __SSE3__. I should consolidate.

#ifndef __VECTOR_FUNCTIONS_H__
#define __VECTOR_FUNCTIONS_H__

#include <cstdint>
#include "VectorTypes.h"

#if HAS_SSE     /* SSE instruction set for Intel processors */
    #if __SSSE3__
        #include <tmmintrin.h>		// SSSE3 (supplemental SSE3)
	#elif __SSE3__
		#include <pmmintrin.h>
	#else
		#include <emmintrin.h>
		#include <xmmintrin.h>
	#endif

    inline vUInt16 vZeroUInt16(void) { return (vUInt16)_mm_setzero_si128(); }
    inline vUInt32 vZeroUInt32(void) { return (vUInt32)_mm_setzero_si128(); }
    inline vUInt64 vZeroUInt64(void) { return (vUInt64)_mm_setzero_si128(); }
    inline vFloat vZero(void) { return _mm_setzero_ps(); }
    inline vDouble vZeroD(void) { return _mm_setzero_pd(); }

    // This function can be used to guarantee that a load will succeed even if the address is unaligned.
    // Without this, the compiler will implicitly use an aligned load when an address is dereferenced.
    // If we cannot guarantee that the address is aligned, we must explicitly protect using this function here.
    template<class T> T vLoadUnaligned(T *addr) { return (T)_mm_loadu_si128((__m128i*)addr); }

    template<class T> T vAdd(T a, T b)	{ return a + b; }
    // We can't just define vSub with a template because the signed/unsigned interpretation gets a bit complicated in the case of unsigned types
    inline vInt8 vSub(vUInt8 a, vUInt8 b)	{ return (vInt8)(a - b); }
    inline vInt16 vSub(vUInt16 a, vUInt16 b)	{ return (vInt16)(a - b); }
    inline vInt32 vSub(vUInt32 a, vUInt32 b)	{ return (vInt32)(a - b); }
    inline vFloat vSub(vFloat a, vFloat b)	{ return a - b; }

	inline vFloat vMul( vFloat a, vFloat b )	{ return _mm_mul_ps( a, b ); }
	inline vFloat vMAdd( vFloat a, vFloat b, vFloat c )	{ return vAdd( c, vMul( a, b ) ); }
	inline vFloat vNegate( vFloat a ) { return _mm_xor_ps(a, (vFloat) { -0.0, -0.0, -0.0, -0.0 }); }
	inline vFloat vNegateReal( vFloat a ) { return _mm_xor_ps(a, (vFloat) { -0.0, 0.0, -0.0, 0.0 }); }
	inline vFloat vNegateImag( vFloat a ) { return _mm_xor_ps(a, (vFloat) { 0.0, -0.0, 0.0, -0.0 }); }
    /*	nmsub:			result = Ð( arg1 * arg2 - arg3 )
        equivalent to	result =  ( arg3 - arg1 * arg2 )*/
	inline vFloat vNMSub(vFloat a, vFloat b, vFloat c) { return vSub( c, vMul(a, b) ); }
	inline vFloat vAbs( vFloat a) { return _mm_andnot_ps((vFloat) { -0.0, -0.0, -0.0, -0.0 }, a); }
	#define vRSqrtEst _mm_rsqrt_ps
	#define vREst _mm_rcp_ps

	inline vFloat vXOR(vFloat a, vFloat b) { return _mm_xor_ps(a, b); }

    inline vUInt32 vOr(vUInt32 a, vUInt32 b) { return a | b; }
    // Note: it is somewhat a matter of preference whether the return values from the next two functions are typed as signed or unsigned.
    // I have gone with unsigned, because I think that reflects the use of the absolute operator - but the result would also make sense
    // if interpreted as a signed integer (it will not overflow).
    // It surely makes sense for the input type to vAbs to be signed.
    inline vUInt32 vAbs(vInt32 a)	{ return (vUInt32)__builtin_ia32_pabsd128( a ); }
    // Strangely, the builtin expects a signed input, but the instruction definition is very clear that it operates on unsigned chars.
    // I appear to have to include a cast on a and b to make this work.
    inline vUInt64 vSad_u8_to_u64(vUInt8 a, vUInt8 b)	{ return (vUInt64)__builtin_ia32_psadbw128( (vInt8)a, (vInt8)b ); }
    // These next two functions mirror _mm_unpacklo/hi_epi16, but with proper type safety
    inline vUInt32 vUnpackLo(vUInt16 a, vUInt16 b) { return (vUInt32)__builtin_shufflevector((__v8hi)a, (__v8hi)b, 0, 8+0, 1, 8+1, 2, 8+2, 3, 8+3); }
    inline vUInt32 vUnpackHi(vUInt16 a, vUInt16 b) { return (vUInt32)__builtin_shufflevector((__v8hi)a, (__v8hi)b, 4, 8+4, 5, 8+5, 6, 8+6, 7, 8+7); }

    inline vFloat vSplatFirstValue(vFloat a) { return (vFloat)_mm_shuffle_epi32((__m128i)a, _MM_SHUFFLE(0, 0, 0, 0)); }
	inline vFloat vSplatSecondValue(vFloat a) { return (vFloat)_mm_shuffle_epi32((__m128i)a, _MM_SHUFFLE(1, 1, 1, 1)); }
	inline vFloat vSplatThirdValue(vFloat a) { return (vFloat)_mm_shuffle_epi32((__m128i)a, _MM_SHUFFLE(2, 2, 2, 2)); }
	inline vFloat vSplatFourthValue(vFloat a) { return (vFloat)_mm_shuffle_epi32((__m128i)a, _MM_SHUFFLE(3, 3, 3, 3)); }
	inline vFloat vSplatReal(vFloat a) { return (vFloat)_mm_shuffle_epi32((__m128i)a, _MM_SHUFFLE(2, 2, 0, 0)); }
	inline vFloat vSplatImag(vFloat a) { return (vFloat)_mm_shuffle_epi32((__m128i)a, _MM_SHUFFLE(3, 3, 1, 1)); }
	#define vExtractShort(SOURCE, I) _mm_extract_epi16((SOURCE), (I))

	// Permute to swap the pairs: return { v2, v3, v0, v1 }
	inline vFloat vSwapHiLo(vFloat a) { return (vFloat)_mm_shuffle_epi32((__m128i)a, _MM_SHUFFLE(1, 0, 3, 2)); }
	// Permute to swap the real and imaginary: return { v1, v0, v3, v2 }
	inline vFloat vSwapReIm(vFloat a) { return (vFloat)_mm_shuffle_epi32((__m128i)a, _MM_SHUFFLE(2, 3, 0, 1)); }

	// Special operation used in complex multiply.
	// a should contain the same value four times over.
	// { a0, a1, a2, a3 } * { -b1, b0, -b3, b2 } + sum is returned
	#if __SSE3__
		inline vFloat vCMulRearrangeAndAdd(vFloat a, vFloat sum) { return _mm_addsub_ps(sum, (vFloat)_mm_shuffle_epi32((__m128i)a, _MM_SHUFFLE(2, 3, 0, 1))); }
		inline vFloat vSpecialCMul(vFloat a, vFloat b, vFloat sum) { return _mm_addsub_ps(sum, vMul(a, (vFloat)_mm_shuffle_epi32((__m128i)b, _MM_SHUFFLE(2, 3, 0, 1)))); }
		inline vFloat vCMulRearrangeSwapAndAdd(vFloat a, vFloat sum) { return _mm_addsub_ps(sum, (vFloat)_mm_shuffle_epi32((__m128i)a, _MM_SHUFFLE(0, 1, 2, 3))); }
		inline vFloat vSpecialCMulSwapHiLoOnP2(vFloat a, vFloat b, vFloat sum) { return _mm_addsub_ps(sum, vMul(a, (vFloat)_mm_shuffle_epi32((__m128i)b, _MM_SHUFFLE(0, 1, 2, 3)))); }

		// Four-value horizontal add
		inline float vHAdd(vFloat a)
		{
			// b = { a1+a2, a3+a4, a1+a2, a3+a4 }
			vFloat b = _mm_hadd_ps(a, a);
			// c = { a1+a2+a3+a4 } *4
			vFloat c = _mm_hadd_ps(b, b);
			// Extract the first float. Should in fact be optimized out by the compiler
			float result; 
			_mm_store_ss(&result, c);
			return result;
		}
	#else
		// The cray doesn't have SSE3 so we can't use the _mm_addsub_ps instruction unfortunately
		inline vFloat vCMulRearrangeAndAdd(vFloat a, vFloat sum)
		{
			// Negate the imaginary parts, then swap the real and imaginary parts and add to sum
			a = _mm_xor_ps(a, (vFloat) { 0.0, -0.0, 0.0, -0.0 });
			return vAdd(sum, (vFloat)_mm_shuffle_epi32((__m128i)a, _MM_SHUFFLE(2, 3, 0, 1)));
		}
		inline vFloat vSpecialCMul(vFloat a, vFloat b, vFloat sum)
		{
			vFloat c = vMul(a, (vFloat)_mm_shuffle_epi32((__m128i)b, _MM_SHUFFLE(2, 3, 0, 1)));
			a = _mm_xor_ps(c, (vFloat) { 0.0, -0.0, 0.0, -0.0 });
			return vAdd(sum, c);
		}
		inline vFloat vCMulRearrangeSwapAndAdd(vFloat a, vFloat sum)
		{
			// Negate the imaginary parts, then swap the real and imaginary parts and add to sum
			a = _mm_xor_ps(a, (vFloat) { 0.0, -0.0, 0.0, -0.0 });
			return vAdd(sum, (vFloat)_mm_shuffle_epi32((__m128i)a, _MM_SHUFFLE(0, 1, 2, 3)));
		}
		inline vFloat vSpecialCMulSwapHiLoOnP2(vFloat a, vFloat b, vFloat sum)
		{	
			vFloat c = vMul(a, (vFloat)_mm_shuffle_epi32((__m128i)b, _MM_SHUFFLE(0, 1, 2, 3)));
			a = _mm_xor_ps(c, (vFloat) { 0.0, -0.0, 0.0, -0.0 });
			return vAdd(sum, c);
		}
	#endif

	// Multiply by -i: return { a1, -a0, a3, -a2 }
	inline vFloat vMultiplyByMinusI(vFloat a) { return _mm_xor_ps((vFloat)_mm_shuffle_epi32((__m128i)a, _MM_SHUFFLE(2, 3, 0, 1)), (vFloat) { 0.0, -0.0, 0.0, -0.0 }); }
	
	// Return { a0, a1, b0, b1 }
	inline vFloat vCombineLowHalves(vFloat a, vFloat b) { return _mm_shuffle_ps(a, b, _MM_SHUFFLE(1, 0, 1, 0)); }
	
	inline vDouble vSwapD(vDouble a) { return _mm_shuffle_pd(a, a, _MM_SHUFFLE2(0, 1)); }
	inline vDouble vNegate(vDouble a) { return _mm_xor_pd(a, (vDouble) { -0.0, -0.0 }); }

	#if __SSE3__
        inline double vLower(vDouble a)
		// *** TODO: This doesn't compile on Mountain Lion. I need to work out what the modern equivalent is...
		{
		//double result; _mm_store_sd(&result, a); return result;
		return _mm_cvtsd_f64(a);
		//ALWAYS_ASSERT(0); return 0.0; /*return __builtin_ia32_vec_ext_v2df(a, 0);*/
        }
		inline double vUpper(vDouble a) { return vLower(vSwapD(a)); }
//		inline double vUpper(vDouble a) { return __builtin_ia32_vec_ext_v2df(a, 1); }
			// this actually seems to perform worse than the version above!?

		inline double vHAddLower(vDouble a) { return vLower(_mm_hadd_pd(a, a)); }
		inline vDouble vHAdd2(vDouble a, vDouble b) { return _mm_hadd_pd(a, b); }
	#else
		// It seems the Cray doesn't know about __builtin_ia32_vec_ext_v2df.
		// Hopefully this code will be optimized fairly well by the compiler.
		inline double vLower(vDouble a)
		{
			double x;
			_mm_storel_pd(&x, a);
			return x;
		}
		inline double vUpper(vDouble a)
		{
			double x;
			_mm_storeh_pd(&x, a);
			return x;
		}

		inline double vHAddLower(vDouble a) { return vLower(_mm_add_pd(a, vSwapD(a))); }
		inline vDouble vHAdd2(vDouble a, vDouble b)
		{
			vDouble c = _mm_add_pd(a, vSwapD(a));
			vDouble d = _mm_add_pd(b, vSwapD(b));
			return _mm_shuffle_pd(c, d, _MM_SHUFFLE2(0, 0));
		}
	#endif
#elif __ARM_NEON__       /* NEON instruction set for ARM processors */
    // Note that ARM support here is incomplete - I am just adding functions as and when I need them
    inline vUInt32 vZeroUInt32(void) { return vmovq_n_u32(0); }
    /*  It seems that ARM accepts unaligned loads by default, so there is no need for special code here.
        Incidentally, it sounds like it may be possible to include "alignment specifiers" to make *aligned* loads faster,
        but I have not currently looked into that at all. */
    inline vInt32 vLoadUnalignedInt32(void *addr) { return ((vInt32*)addr)[0]; }
    inline vUInt32 vLoadUnalignedUInt32(void *addr) { return ((vUInt32*)addr)[0]; }

    inline vUInt32 vOr(vUInt32 a, vUInt32 b) { return vorrq_u32(a, b); }
    inline vInt32 vAdd(vInt32 a, vInt32 b)	{ return vaddq_s32( a, b ); }
    inline vInt32 vSub(vInt32 a, vInt32 b)	{ return vsubq_s32( a, b ); }
    inline vInt32 vAbs(vInt32 a)            { return vabsq_s32( a ); }
#elif __SPU__     /* PS3 SPU vector instruction set */
    #include <spu_intrinsics.h>
    #include <spu_mfcio.h> /* constant declarations for the MFC */

    #define vZero spu_splats(0.0f)
    #define vMul spu_mul
    #define vMAdd spu_madd
    #define vSub spu_sub
    #define vAdd spu_add
    #define vNMSub spu_nmsub

    #define vPermute spu_shuffle
    #define vSel spu_sel
    #define vXOR spu_xor
    #define vcosf cosf4
    #define vsinf sinf4
    #define vRSqrtEst spu_rsqrte
    #define vREst spu_re

    inline vUInt8 vec_splat_u8(unsigned char a) { return spu_splats(a); }
    inline vFloat vSplatFirstValue(vFloat a) { return spu_shuffle(a, a, (vUInt8) { 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3 }); }
    inline vFloat vSplatSecondValue(vFloat a) { return spu_shuffle(a, a, (vUInt8) { 4, 5, 6, 7, 4, 5, 6, 7, 4, 5, 6, 7, 4, 5, 6, 7 }); }
    inline vFloat vSplatThirdValue(vFloat a) { return spu_shuffle(a, a, (vUInt8) { 8, 9, 10, 11, 8, 9, 10, 11, 8, 9, 10, 11, 8, 9, 10, 11 }); }
    inline vFloat vSplatFourthValue(vFloat a) { return spu_shuffle(a, a, (vUInt8) { 12, 13, 14, 15, 12, 13, 14, 15, 12, 13, 14, 15, 12, 13, 14, 15 }); }
    inline int vExtractShort(vUInt8 source, const int i) { return spu_extract((vector unsigned short)source, i); }

#elif HAS_ALTIVEC     /* Altivec vector instruction set for PowerPC RISC processors */
    #define vZero (vector float)vec_splat_u32(0)
    inline vFloat vMul( vFloat a, vFloat b )	{ return vec_madd( a, b, vZero ); }
    #define vMAdd vec_madd
    inline vFloat vSub( vFloat a, vFloat b )	{ return vec_sub( a, b ); }
    inline vFloat vAdd( vFloat a, vFloat b )	{ return vec_add( a, b ); }
    #define vPermute vec_vperm
    #define vSel vec_vsel
    #define vXOR vec_xor
    #define vRSqrtEst vec_rsqrte
    #define vREst vec_re
    #define vNMSub vec_nmsub

    inline vFloat vSplatFirstValue(vFloat a) { return vec_splat(a, 0); }
    inline vFloat vSplatSecondValue(vFloat a) { return vec_splat(a, 1); }
    inline vFloat vSplatThirdValue(vFloat a) { return vec_splat(a, 2); }
    inline vFloat vSplatFourthValue(vFloat a) { return vec_splat(a, 3); }
    inline int vExtractShort(vUInt8 source, const int i)
    {
        VecUnion u;
        u.vc = source;
        return u.s[i];
    }

#else       /* Minimal support for the case where no vector instruction set is available */
    inline vUInt32 vZeroUInt32(void) { vUInt32 z = {{ 0, 0, 0, 0 }}; return z; }
#endif


#if __SPU__ || HAS_ALTIVEC
    inline vFloat vNegate( vFloat a ) { return (vFloat)vXOR((vUInt8)a, (vUInt8) (vFloat){ -0.0, -0.0, -0.0, -0.0 }); }
    inline vFloat vNegateImag( vFloat a ) { return (vFloat)vXOR((vUInt8)a, (vUInt8) (vFloat){ 0.0, -0.0, 0.0, -0.0 }); }
    inline vFloat vNegateReal( vFloat a ) { return (vFloat)vXOR((vUInt8)a, (vUInt8) (vFloat){ -0.0, 0.0, -0.0, 0.0 }); }
    inline vFloat vSplatReal(vFloat a) { return vPermute(a, a, (vUInt8) { 0, 1, 2, 3, 0, 1, 2, 3, 8, 9, 10, 11, 8, 9, 10, 11 }); }
    inline vFloat vSplatImag(vFloat a) { return vPermute(a, a, (vUInt8) { 4, 5, 6, 7, 4, 5, 6, 7, 12, 13, 14, 15, 12, 13, 14, 15 }); }

    // Permute to swap the pairs: return { v2, v3, v0, v1 }
    inline vFloat vSwapHiLo(vFloat a) { return vPermute(a, a, (vUInt8) { 8, 9, 10, 11, 12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7 }); }
    // Permute to swap the real and imaginary: return { v1, v0, v3, v2 }
    inline vFloat vSwapReIm(vFloat a) { return vPermute(a, a, (vUInt8) { 4, 5, 6, 7, 0, 1, 2, 3, 12, 13, 14, 15, 8, 9, 10, 11 }); }

    // Special operation used in complex multiply.
    // a should contain the same value four times over.
    // { a0, a1, a2, a3 } * { -b1, b0, -b3, b2 } + sum is returned
    inline vFloat vCMulRearrangeAndAdd(vFloat a, vFloat sum) { return vAdd(sum, vPermute(a, vNegate(a), (vUInt8) { 20, 21, 22, 23, 0, 1, 2, 3, 28, 29, 30, 31, 8, 9, 10, 11 })); }
    inline vFloat vSpecialCMul(vFloat a, vFloat b, vFloat sum) { return vMAdd(a, vPermute(b, vNegate(b), (vUInt8) { 20, 21, 22, 23, 0, 1, 2, 3, 28, 29, 30, 31, 8, 9, 10, 11 }), sum); }
    inline vFloat vCMulRearrangeSwapAndAdd(vFloat a, vFloat sum) { return vAdd(sum, vPermute(a, vNegate(a), (vUInt8) { 28, 29, 30, 31, 8, 9, 10, 11, 20, 21, 22, 23, 0, 1, 2, 3 })); }
    inline vFloat vSpecialCMulSwapHiLoOnP2(vFloat a, vFloat b, vFloat sum) { return vMAdd(a, vPermute(b, vNegate(b), (vUInt8) { 28, 29, 30, 31, 8, 9, 10, 11, 20, 21, 22, 23, 0, 1, 2, 3 }), sum); }

    // Multiply by -i: return { a1, -a0, a3, -a2 }
    inline vFloat vMultiplyByMinusI(vFloat a) { return vPermute(a, vNegate(a), (vUInt8) { 4, 5, 6, 7, 16, 17, 18, 19, 12, 13, 14, 15, 24, 25, 26, 27 }); }

    // Return { a0, a1, b0, b1 }
    inline vFloat vCombineLowHalves(vFloat a, vFloat b) { return vPermute(a, b, (vUInt8) { 0, 1, 2, 3, 4, 5, 6, 7, 16, 17, 18, 19, 20, 21, 22, 23 }); }
#endif

#if HAS_SSE || HAS_ALTIVEC
//	inline vFloat vCMul(vFloat a, vFloat b, vFloat sum) { return vNMSub(vSplatImag(a), vSwapReIm(b), vMAdd(vSplatReal(a), vNegateImag(b), sum)); }
	inline vFloat vCMul(vFloat a, vFloat b, vFloat sum) { return vMAdd(vSplatImag(a), vNegateReal(vSwapReIm(b)), vMAdd(vSplatReal(a), b, sum)); }
    inline vFloat vCMul(vFloat a, vFloat b) { return vMAdd(vSplatImag(a), vNegateReal(vSwapReIm(b)), vMul(vSplatReal(a), b)); }
	inline vFloat vAdd4(vFloat a, vFloat b, vFloat c, vFloat d) { return vAdd(vAdd(a, b), vAdd(c, d)); }

    inline vFloat vNRInvSqrt(vFloat a)
    {
        vFloat oneHalf = (vFloat){ 0.5, 0.5, 0.5, 0.5 };
        vFloat one = (vFloat){ 1.0, 1.0, 1.0, 1.0 };
        vFloat estimate = vRSqrtEst(a);
        vFloat estSquared = vMul(estimate, estimate);
        vFloat halfEst = vMul(estimate, oneHalf);
        return vMAdd(vNMSub(a, estSquared, one), halfEst, estimate);
    }

    inline vFloat vNRInv( vFloat v )
    {
        //Get the reciprocal estimate
        vFloat estimate = vREst( v );
        //One round of Newton-Raphson refinement
        return vMAdd(vNMSub(estimate, v, (vFloat) { 1.0, 1.0, 1.0, 1.0 } ), estimate, estimate);
    }

    inline vFloat vNRSqrt(vFloat v)
    {
        return vMul(v, vNRInvSqrt(v));
    }
#endif

#if FEDORA_LINUX
	#include <sse_mathfun.h>
	#define vExp exp_ps
#elif OS_X
	#define vExp vexpf
#endif

#if __ARM_NEON__
    // Direct access to vector elements is possible in C code. This may be better for the compiler than the generic code below this?
    inline uint32_t SumAcross(vUInt32 *i)
    {
        return l[0] + l[1] + l[2] + l[3];
    }

    inline uint32_t OrAcross(vUInt32 *i)
    {
        return l[0] | l[1] | l[2] | l[3];
    }
#else
    inline uint64_t SumAcross(vUInt64 *i)
    {
        // _mm_extract_epi64 is SSE4.1 so we have to do this one by hand on most machines
        // TODO: if I have access to any machines that implement this intrinsic, I should implement the option of doing it properly...
        uint64_t *l = (uint64_t *)i;
        return l[0] + l[1];
    }

    inline uint32_t SumAcross(vUInt32 *i)
    {
        uint32_t *l = (uint32_t *)i;
        return l[0] + l[1] + l[2] + l[3];
    }

    inline uint32_t OrAcross(vUInt32 *i)
    {
        uint32_t *l = (uint32_t *)i;
        return l[0] | l[1] | l[2] | l[3];
    }
#endif

// These are not vectorized, but are useful functions to use in conjunction with vectorized code
// They probably could be vectorized, in fact, if performance becomes an issue (c.f. vHAdd)
inline int SumOver32BitInts(void *i)
{
    uint32_t *l = (uint32_t *)i;
    return l[0] + l[1] + l[2] + l[3];
}

inline int OrOver32BitInts(void *i)
{
    uint32_t *l = (uint32_t *)i;
    return l[0] | l[1] | l[2] | l[3];
}

#endif
