//
//  jDefaultsHelper.h
//  Spim Interface
//
//  Created by Jonny Taylor on 12/06/2017.
//
//

#import <Foundation/Foundation.h>

@interface JDefaultsHelper : NSObject
{
	MAZeroingWeakRef *_target;
	NSSet *_properties;
	NSString *_defaultsKey;
}

+(id)newHelperForProperties:(NSSet*)propertiesToSaveInDefaults onObject:(id)target withKey:(NSString*)theKey;
-(void)disconnectAndRelease;
-(void)updateDefaults;
-(void)readDefaults;

@end
