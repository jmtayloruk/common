//
//	jCache.h
//
//	Copyright 2018 Jonathan Taylor. All rights reserved.
//
//	Basically a reimplementation of NSCache that will actually enforce the limits provided!
//

#import <Cocoa/Cocoa.h>

@interface JCache : NSObject
{
	NSUInteger			_totalCostLimit, totalCost;
	NSMutableDictionary	*cachedObjects;
}

- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)obj forKey:(NSString *)key; // 0 cost
- (void)setObject:(id)obj forKey:(NSString *)key cost:(NSUInteger)g;
- (void)removeObjectForKey:(NSString *)key;
- (void)removeAllObjects;

@property NSUInteger totalCostLimit;

@end
