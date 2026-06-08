//
//  JDefaultsHelper.mm
//  Spim Interface
//
//  Created by Jonny Taylor on 12/06/2017.
//
//  Helper class for mirroring properties to NSUserDefaults.
//  It should be able to handle key paths as well as direct keys
//  (Note that I am a little bit wary of having dictionary keys that themselves contain full stops!
//	 Seems to work though)
//

#import "jDefaultsHelper.h"

@interface JDefaultsHelper()
	@property (readwrite, retain) MAZeroingWeakRef *target;
	@property (readwrite, retain) NSSet *properties;
	@property (readwrite, retain) NSString *defaultsKey;
@end

@implementation JDefaultsHelper

+(id)newHelperForProperties:(NSSet*)propertiesToSaveInDefaults onObject:(id)theTarget withKey:(NSString*)theKey
{
	return [[JDefaultsHelper alloc] initForProperties:propertiesToSaveInDefaults onObject:theTarget withKey:theKey];
}

-(id)initForProperties:(NSSet*)propertiesToSaveInDefaults onObject:(id)theTarget withKey:(NSString*)theKey
{
	if (!(self = [super init]))
		return nil;
	
	self.target = [MAZeroingWeakRef refWithTarget:theTarget];
	self.properties = propertiesToSaveInDefaults;
	self.defaultsKey = theKey;
	
	for (NSString *key in self.properties)
	{
		[self.target.target addObserver:self
							 forKeyPath:key
								options:0
								context:NULL];
	}

	return self;
}

-(void)disconnectAndRelease
{
	for (NSString *key in self.properties)
		[self.target.target removeObserver:self forKeyPath:key];
	[self release];
}

-(void)dealloc
{
	self.target = nil;
	self.properties = nil;
	self.defaultsKey = nil;
	[super dealloc];
}

-(void)observeValueForKeyPath:(NSString *)keyPath
					 ofObject:(id)object
					   change:(NSDictionary *)change
					  context:(void *)context
{
	if ([self.properties containsObject:keyPath])
	{
		[self updateDefaults];
		return;
	}

	// (don't call [super observeValueForKeyPath] because NSObject doesn't implement it!
	
	// We shouldn't get here
	printf("WARNING: unexpected value changed notification for path %s\n", keyPath.UTF8String);
}

-(void)updateDefaults
{
	// Transfer all values to user defaults
	NSUserDefaults *theDefaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	for (NSString *key in self.properties)
	{
		id val = [self.target.target valueForKeyPath:key];
		if (CHECK(val != nil))
		{
			ALWAYS_ASSERT(val != nil);		// Redundant, but silences static analysis warning (I haven't found a satisfactory way to get static analyzer to understand the that val!=nil in this branch (thanks to the CHECK macro)
			[dict setObject:val forKey:key];
		}
		else
		{
			// This is rather unsatisfactory - if a text field is empty then we will get nil back.
			// This messes things up! I am not sure if there is a good way of distinguishing between
			// those two scenarios. For now I will just print this out - I don't think we will end
			// up spamming the console too much like this...
			DebugPrintf("Unrecognised key %s (or perhaps the key value was nil)\n", key.UTF8String);
		}
	}
	[theDefaults setObject:dict forKey:self.defaultsKey];
	[theDefaults synchronize];
}

-(void)readDefaults
{
	// Read all values from user defaults
	NSDictionary *theDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:self.defaultsKey];
	if (theDefaults == nil)
		return;
	for (NSString *key in self.properties)
	{
		id val = [theDefaults objectForKey:key];
		/*	We will fail the following check first time we run on a new computer,
			and if I ever add new keys to the list. Aside from that, it should be passed.	
			In addition, NSUserDefaults is a bit weird about empty strings. It seems to 
			not even list a key in allKeys if it is an empty string. Weird and annoying!
			As a result, I cannot tell if an empty string is present - it behaves as if
			the key is absent. We will therefore get spurious warnings here.
			I think I will leave it for now, and hopefully there won't be too much console spam. */
		if (CHECK(val != nil))
        {
            if([val isKindOfClass:[NSArray class]])
            {
                [self.target.target setValue:[val mutableCopy] forKeyPath:key];
            }
            else
            {
                [self.target.target setValue:val forKeyPath:key];
            }
        }
		else
			DebugPrintf("Missing key in defaults %s\n", key.UTF8String);
	}
}

@synthesize target = _target;
@synthesize properties = _properties;
@synthesize defaultsKey = _defaultsKey;

@end
