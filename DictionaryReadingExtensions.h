//
//  DictionaryReadingExtensions.h
//  Spim Interface
//
//  Created by Jonathan Taylor on 20/06/2014.
//
//

#ifndef Spim_Interface_DictionaryReadingExtensions_h
#define Spim_Interface_DictionaryReadingExtensions_h

@interface NSDictionary (KeyReading)

-(NSNumber *)getRequiredNumberForKey:(NSString *)key;
-(NSNumber *)getOptionalNumberForKey:(NSString *)key defaultVal:(NSNumber *)def;
-(int)getRequiredIntForKey:(NSString *)key;
-(bool)getRequiredBoolForKey:(NSString *)key;
-(NSString *)getRequiredStringForKey:(NSString *)key;
-(double)getRequiredDoubleForKey:(NSString *)key;
-(double)getOptionalDoubleForKey:(NSString *)key defaultVal:(double)def;
-(int)getOptionalIntForKey:(NSString *)key defaultVal:(int)def;
-(bool)getOptionalBoolForKey:(NSString *)key defaultVal:(bool)def;

@end

#endif
