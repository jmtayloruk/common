//
//	jCache.mm
//
//	Copyright 2018 Jonathan Taylor. All rights reserved.
//
//	Basically a reimplementation of NSCache that will actually enforce the limits provided!
//

#import "jCache.h"

@interface ObjectAndCost : NSObject
{
	id			_object;
	NSUInteger	_cost;
	double		_timeCreated, _timeLastAccessed;
}
@property (retain) id object;
@property NSUInteger cost;
@property double timeCreated;
@property double timeLastAccessed;

@end

@implementation ObjectAndCost

+(id)ocForObject:(id)inObject cost:(NSUInteger)inCost
{
	return [[[ObjectAndCost alloc] initForObject:inObject cost:inCost] autorelease];
}

-(id)initForObject:(id)inObject cost:(NSUInteger)inCost
{
	if (!(self = [super init]))
		return nil;
	self.object = inObject;
	self.cost = inCost;
	self.timeCreated = GetTime();
	self.timeLastAccessed = self.timeCreated;
	return self;
}

-(void)dealloc
{
	self.object = nil;
	[super dealloc];
}

@synthesize object = _object;
@synthesize timeCreated = _timeCreated;
@synthesize timeLastAccessed = _timeLastAccessed;
@synthesize cost = _cost;

@end

@implementation JCache

-(id)init
{
	if (!(self = [super init]))
		return nil;
	cachedObjects = [NSMutableDictionary new];
	return self;
}

-(void)dealloc
{
	[cachedObjects release];
	[super dealloc];
}


-(id)objectForKey:(NSString *)key
{
	@synchronized(self)
	{
        // Apparently [NSDictionary objectForKey:] does not retain/autorelease,
        // so we should do that here to avoid a window condition potentially leading to a crash.
		ObjectAndCost *obj = [[[cachedObjects objectForKey:key] retain] autorelease];
//		double temp = obj.timeLastAccessed;
		obj.timeLastAccessed = GetTime();
//		printf("Accessing key %s last accessed %lf now %lf\n", key.UTF8String, temp, obj.timeLastAccessed);
		return obj.object;
	}
}

-(void)setObject:(id)obj forKey:(NSString *)key; // 0 cost
{
	@synchronized(self)
	{
		[self setObject:obj forKey:key cost:0];
	}
}

-(void)setObject:(id)obj forKey:(NSString *)key cost:(NSUInteger)cost
{
	@synchronized(self)
	{
//		printf("About to add key %s cost %zd\n", key.UTF8String, cost);
		if (totalCost > self.totalCostLimit)
        {
//            printf("Removing all objects (%ld exceeds limit of %ld)\n", totalCost, self.totalCostLimit);
			[self removeAllObjects];
        }
		else if (totalCost + cost > self.totalCostLimit)
			[self purgeToSize:self.totalCostLimit-cost];
		if (CHECK([cachedObjects objectForKey:key] == nil))
		{
			[cachedObjects setObject:[ObjectAndCost ocForObject:obj cost:cost] forKey:key];
			totalCost += cost;
//			printf("Total cost now %zd/%zd\n", totalCost, self.totalCostLimit);
		}
	}
}

-(void)purgeToSize:(size_t)target
{
	@synchronized(self)
	{
		// This could certainly be more efficient, but shouldn't be a bottleneck as long as we only have a few large things in the cache
		if (cachedObjects.count == 0)
			return;
		NSArray *keysByAge = [cachedObjects keysSortedByValueUsingComparator:^(id obj1, id obj2){ return DiffToNSComparisonResult(((ObjectAndCost*)obj1).timeLastAccessed - ((ObjectAndCost*)obj2).timeLastAccessed); }];

		for (size_t i = 0; i < keysByAge.count; i++)
		{
			ObjectAndCost *oc = [cachedObjects objectForKey:[keysByAge objectAtIndex:i]];
//			printf("Purging key %s cost %zd last accessed %lf\n", ((NSString *)[keysByAge objectAtIndex:i]).UTF8String, oc.cost, oc.timeLastAccessed);
			CHECK(oc.cost <= totalCost);
			totalCost -= oc.cost;
			[cachedObjects removeObjectForKey:[keysByAge objectAtIndex:i]];
			if (totalCost <= target)
				break;
		}
	}
}

-(void)removeObjectForKey:(NSString *)key
{
	@synchronized(self)
	{
		ObjectAndCost *oc = [cachedObjects objectForKey:key];
		if (oc != nil)
		{
//			printf("Removing key %s cost %zd last accessed %lf\n", key.UTF8String, oc.cost, oc.timeLastAccessed);
			CHECK(oc.cost <= totalCost);
			totalCost -= oc.cost;
			[cachedObjects removeObjectForKey:key];
		}
	}
}

-(void)removeAllObjects
{
	@synchronized(self)
	{
		[cachedObjects removeAllObjects];
		totalCost = 0;
	}
}

@synthesize totalCostLimit = _totalCostLimit;

@end
