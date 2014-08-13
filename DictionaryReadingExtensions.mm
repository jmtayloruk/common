//
//  DictionaryReadingExtensions.m
//  Spim Interface
//
//  Created by Jonathan Taylor on 20/06/2014.
//
//

#import "DictionaryReadingExtensions.h"

@implementation NSDictionary (CompulsoryKeyReading)

-(NSNumber *)getRequiredNumberForKey:(NSString *)key
{
	ALWAYS_ASSERT([self isKindOfClass:[NSDictionary class]]);
	NSNumber *num = [self objectForKey:key];
	ALWAYS_ASSERT([num isKindOfClass:[NSNumber class]]);
	return num;
}

-(NSNumber *)getOptionalNumberForKey:(NSString *)key defaultVal:(NSNumber *)def
{
	ALWAYS_ASSERT([self isKindOfClass:[NSDictionary class]]);
	NSNumber *num = [self objectForKey:key];
    if (num == nil)
        return def;
	ALWAYS_ASSERT([num isKindOfClass:[NSNumber class]]);
	return num;
}

-(int)getRequiredIntForKey:(NSString *)key
{
    return [self getRequiredNumberForKey:key].intValue;
}

-(double)getRequiredDoubleForKey:(NSString *)key
{
    return [self getRequiredNumberForKey:key].doubleValue;
}

-(double)getOptionalDoubleForKey:(NSString *)key defaultVal:(double)def
{
    NSNumber *num = [self getOptionalNumberForKey:key defaultVal:nil];
    if (num == nil)
        return def;
	return num.doubleValue;
}

-(int)getOptionalIntForKey:(NSString *)key defaultVal:(int)def
{
    NSNumber *num = [self getOptionalNumberForKey:key defaultVal:nil];
    if (num == nil)
        return def;
	return num.intValue;
}

-(bool)getOptionalBoolForKey:(NSString *)key defaultVal:(bool)def
{
    NSNumber *num = [self getOptionalNumberForKey:key defaultVal:nil];
    if (num == nil)
        return def;
	return num.boolValue;
}

-(NSString*)getRequiredStringForKey:(NSString *)key
{
	ALWAYS_ASSERT([self isKindOfClass:[NSDictionary class]]);
	NSString *str = [self objectForKey:key];
	ALWAYS_ASSERT([str isKindOfClass:[NSString class]]);
	return str;
}

@end
