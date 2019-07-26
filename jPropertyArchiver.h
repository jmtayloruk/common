//
//  jPropertyArchiver.h
//
//  Created by Jonathan Taylor on 26/07/2019.
//
//

#import <Cocoa/Cocoa.h>

NSMutableDictionary *ArchivePropertiesForObject(id object, NSArray *exclude);
void UnarchivePropertiesForObject(id destObject, NSDictionary *properties, NSArray *exclude/*caller handles special processing*/);
