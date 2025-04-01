//
//  jApplication.mm
//  Simple Preview
//
//  Created by Jonathan Taylor on 10/9/15.
//  Copyright 2015 Jonathan Taylor. All rights reserved.
//

#import "jApplication.h"
#import "jDispatchTimer.h"
#import "jNotifications.h"
#import "ConfigSelector.h"

JApplication *baseApp = nil;

@interface JApplication()
	@property (readwrite, retain) NSString *buildVersionString;
	@property (readwrite) bool terminating;
@end

@implementation JApplication

-(id)init
{
	if (!(self = [super init]))
		return nil;

	self.terminating = false;
    
    return self;
}

-(void)dealloc
{
	self.buildVersionString = nil;
	self.configFilename = nil;
	[super dealloc];
}

-(void)applicationDidFinishLaunching:(NSNotification *)note
{
	self.buildVersionString = [JApplication buildVersionString];

    baseApp = self;

	// Create a periodic timer that "tickles" the main event loop to drain autorelease pools.
	// Response from cocoa-dev discussion was that:
	//	 This is a long-standing problem with AppKit. According to the documentation,
	//	 "The Application Kit creates an autorelease pool on the main thread at the
	//	 beginning of every cycle of the event loop, and drains it at the end, thereby
	//	 releasing any autoreleased objects generated while processing an event."
	//	 However, this is somewhat misleading. The "end" of the event loop cycle is
	//   immediately before the beginning. Thus, for example, if your app is in the background
	//   and not receiving events, then the autorelease pool will not be drained. That's why
	//   your memory drops significantly when you click the mouse or switch applications.
    [JDispatchTimer allocRepeatingTimerOnQueue:dispatch_get_main_queue() atInterval:5.0 flex:1.0 critical:true withHandler:^{
		NSEvent *event = [NSEvent otherEventWithType:NSApplicationDefined location:NSZeroPoint modifierFlags:0 timestamp:[NSDate timeIntervalSinceReferenceDate] windowNumber:0 context:nil subtype:0 data1:0 data2:0];
		[NSApp postEvent:event atStart:YES];
	}];
}

-(void)applicationWillTerminate:(NSNotification *)notification
{
	self.terminating = true;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	SendImmediateNotificationOnThisThread(CloseSheetsForTermination, self);
}

-(bool)debugBuild
{
#if DEBUGGING
	return true;
#else
	return false;
#endif
}

-(void)orderFrontStandardAboutPanel:(id)sender
{
	[self orderFrontStandardAboutPanelWithOptions:
				[NSDictionary dictionaryWithObjectsAndKeys:self.buildVersionString, @"Version", nil]];
}

-(void)alertWithText:(NSString *)mainText andExplanation:(NSString *)text2
{
	[self alertWithText:mainText andExplanation:text2 iconName:nil];
}

-(void)alertWithText:(NSString *)mainText andExplanation:(NSString *)text2 iconName:(NSString*)iconName
{
	if (self.terminating)
		printf("Suppress alert as we are terminating. %s. %s\n", mainText.UTF8String, text2.UTF8String);
	else
	{
		NSAlert *alert = [NSAlert alertWithMessageText:mainText
										 defaultButton:@"OK"
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:@"%@", text2];
		if (iconName != nil)
			alert.icon = [NSImage imageNamed:iconName];
		[alert runModal];
	}
}

-(void)addGlobalMetadataToDictionary:(NSMutableDictionary *)dict
{
}

+(NSString *)buildVersionString
{
	// Determine the build version, e.g. for the about box and possibly for debug messages
	// Read the git build number from the relevant file
	// That file is written from a "script" build phase defined in the xcode project
	NSString *versionPath = [[NSBundle mainBundle] pathForResource:@"git-sha" ofType:@"txt"];
	FILE *versionFile = fopen(versionPath.UTF8String, "r");
	if (CHECK(versionFile != NULL))
	{
		char versionChars[1000];
		fscanf(versionFile, "%999s", versionChars);
		fclose(versionFile);
		return [SWF:@"%s", versionChars];
	}
	else
		return @"<unknown version>";
}

+(NSString *)dateTimeStringForDate:(NSDate *)date
{
    // It might seem silly to have a dedicated function for this, but it allows us
    // to just define the format in one place only.
    NSDateFormatter *outputFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [outputFormatter setDateFormat:@"yyyy-MM-dd HH.mm.ss"];
    return [outputFormatter stringFromDate:date];
}

+(NSString *)currentDateTimeString
{
    return [JApplication dateTimeStringForDate:[NSDate date]];
}

-(NSString *)currentDateTimeString
{
	return [JApplication currentDateTimeString];
}

+(NSString *)logFileDirectoryPath
{
    return [SWF:@"%@/Spim GUI Logs", GetUserDocumentDirectory()];
}

+(NSString *)timestampedLogFilePathWithIdentifier:(NSString *)identifier
{
    return [SWF:@"%@/%@.%@.txt", [JApplication logFileDirectoryPath], self.currentDateTimeString, identifier];
}

+(FILE *)timestampedLogFileWithIdentifier:(NSString *)identifier
{
    FILE *outFile = fopen([self timestampedLogFilePathWithIdentifier:identifier].UTF8String, "w");
    return outFile;
}

+(NSString*)runCommand:(NSString*)commandToRun;
{
    // Utility function from https://stackoverflow.com/questions/3145701/relaunching-a-cocoa-app
    // (I am not sure whether that is in turn copied from somewhere else)
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: @"/bin/bash"];
    
    NSArray *arguments = [NSArray arrayWithObjects:
                          @"-c" ,
                          [NSString stringWithFormat:@"%@", commandToRun],
                          nil];
    //NSLog(@"run command: %@",commandToRun);
    [task setArguments: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data;
    data = [file readDataToEndOfFile];
    
    [task autorelease];
    
    NSString *output;
    output = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    if (output.length >= 1)
        return [output substringToIndex:output.length-1];       // Strip final newline
    else
        return output;
}

#pragma mark -
#pragma mark Defaults

-(id)getObjectForDefault:(NSString *)key requiringClass:(Class)c mayBeAbsent:(bool)mayBeAbsent
{
	id obj = [[NSUserDefaults standardUserDefaults] objectForKey:key];
	if ((!mayBeAbsent) && (obj == nil))
	{
		[baseApp alertWithText:[SWF:@"Compulsory key '%@' not found in config file", key] andExplanation:[SWF:@"Needs to be present in the plist file '%@' - speak to Jonny (version %@)", self.configFilename, self.buildVersionString] iconName:NSImageNameCaution];
		ALWAYS_ASSERT(0);
	}
	if ((obj != nil) && (c != nil) && (![obj isKindOfClass:c]))
	{
		[baseApp alertWithText:[SWF:@"Key '%@' in config file was not in expected format", key] andExplanation:[SWF:@"Expected '%@' got '%@' - speak to Jonny (version %@)", NSStringFromClass(c), NSStringFromClass([obj class]), self.buildVersionString] iconName:NSImageNameCaution];
		ALWAYS_ASSERT(0);
	}
	return obj;
}

-(void)setObject:(id)val forDefault:(NSString *)key
{
	[[NSUserDefaults standardUserDefaults] setObject:val forKey:key];
}

-(NSString *)stringForDefault:(NSString *)key mayBeAbsent:(bool)mayBeAbsent
{
	return [self getObjectForDefault:key requiringClass:[NSString class] mayBeAbsent:mayBeAbsent];
}

-(NSDictionary *)dictionaryForDefault:(NSString *)key mayBeAbsent:(bool)mayBeAbsent
{
	return [self getObjectForDefault:key requiringClass:[NSDictionary class] mayBeAbsent:mayBeAbsent];
}

-(NSString *)stringForDefault:(NSString *)key 
{
	NSString *result = [self getObjectForDefault:key requiringClass:[NSString class] mayBeAbsent:false];
	return result;
}

-(NSString *)stringForDefault:(NSString *)key usingIfAbsent:(NSString *)def
{
    NSString *result = [self getObjectForDefault:key requiringClass:[NSString class] mayBeAbsent:true];
    if (result == nil)
        return def;
    return result;
}

-(int)intForDefault:(NSString *)key
{
	NSNumber *num = [self getObjectForDefault:key requiringClass:nil mayBeAbsent:true];
    if ((num != nil) && ([num isKindOfClass:[NSNumber class]]))
        return num.intValue;
    else if ((num != nil) && ([num isKindOfClass:[NSString class]]))
    {
        // We didn't find a number for this key, but the key is present as a string that we can convert to a number
        // (this feature is convenient for allowing us to enter readable hex values into the plist)
        NSString *str = (NSString *)num;    // Typecast - this was actually an NSString
        char *endPtr;
        const char *strUTF8 = str.UTF8String;
        num = [NSNumber numberWithLong:strtoul(strUTF8, &endPtr, 0)];
        CHECK(endPtr == strUTF8 + strlen(strUTF8)); // Check the whole string was converted, with nothing else unexpected
        return num.intValue;
    }
    else
    {
        // We did not find what we were looking for.
        // Search again, insisting this time, just to cause a suitable error dialog to be shown
        [self getObjectForDefault:key requiringClass:[NSNumber class] mayBeAbsent:false];
        return 0; 
    }
}

-(int)intForDefault:(NSString *)key usingIfAbsent:(int)def
{
    NSNumber *num = [self getObjectForDefault:key requiringClass:[NSNumber class] mayBeAbsent:true];
    if (num == nil)
        return def;
    return num.intValue;
}

-(double)doubleForDefault:(NSString *)key
{
	NSNumber *num = [self getObjectForDefault:key requiringClass:[NSNumber class] mayBeAbsent:false];
	return num.doubleValue;
}

-(double)doubleForDefault:(NSString *)key usingIfAbsent:(double)def
{
	NSNumber *num = [self getObjectForDefault:key requiringClass:[NSNumber class] mayBeAbsent:true];
    if (num == nil)
        return def;
	return num.doubleValue;
}

@synthesize buildVersionString = _buildVersionString;
@synthesize configFilename = _configFilename;
@synthesize terminating = _terminating;

@end
