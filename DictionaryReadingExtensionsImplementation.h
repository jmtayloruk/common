//
//  DictionaryReadingExtensionsImplementation.h
//  Spim Interface
//
//  Created by Jonny Taylor on 22/12/2017.
//
//

-(NSNumber *)getRequiredNumberForKey:(NSString *)key;
-(int)getRequiredIntForKey:(NSString *)key;
-(bool)getRequiredBoolForKey:(NSString *)key;
-(double)getRequiredDoubleForKey:(NSString *)key;
-(NSString *)getRequiredStringForKey:(NSString *)key;
-(NSArray *)getRequiredArrayForKey:(NSString *)key ofLength:(int)length;
-(NSArray *)getOptionalArrayForKey:(NSString *)key ofLength:(int)length defaultVal:(NSArray *)def;
-(NSDictionary *)getRequiredDictionaryForKey:(NSString *)key;

-(NSNumber *)getOptionalNumberForKey:(NSString *)key defaultVal:(NSNumber *)def;
-(int)getOptionalIntForKey:(NSString *)key defaultVal:(int)def;
-(bool)getOptionalBoolForKey:(NSString *)key defaultVal:(bool)def;
-(double)getOptionalDoubleForKey:(NSString *)key defaultVal:(double)def;
-(NSString *)getOptionalStringForKey:(NSString *)key defaultVal:(NSString *)def;
