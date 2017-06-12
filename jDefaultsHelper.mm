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
			[dict setObject:val forKey:key];
		else
			printf("Unrecognised key %s\n", key.UTF8String);
	}
//	[dict writeToFile:@"/Users/jonny/temp.plist" atomically:NO];
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
		 and if I ever add new keys to the list. Aside from that, it should be passed.	*/
		if (CHECK(val != nil))
			[self.target.target setValue:val forKeyPath:key];
		else
			printf("Missing key in defaults %s\n", key.UTF8String);
	}
}

@synthesize target = _target;
@synthesize properties = _properties;
@synthesize defaultsKey = _defaultsKey;

@end
