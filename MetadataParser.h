//
//  MetadataParser.h
//  Spim Interface
//
//  Created by Jonny Taylor on 22/12/2017.
//
//

/*	Update this version number whenever file format changes in a way that parsers need to know about.
	If we add a new variable, we may not need to update this version, if callers are open to the possibility
	of the key not being present.
	If we move or rename a key, it will probably be very helpful to update this version number.	
 
	kSingleFileMetadataVersion:	Version before we started recording this version in the metadata!
				Most camera and frame keys at the root level of the plist file, with some sub-groupings.
	kArrayAggregatedMetadataVersion: Same key tree, but combined into a 'frames' array with one entry.
				(Needed for MovieBuilder to generate multi-page TIFF metadata from old datasets)
	kMultiTiffMetadataVersion: Camera metadata and other global stuff is at root level of plist file,
				while frame-specific keys are stored in a 'frames' array that has the same number of entries
				as we have frames in the accompanying TIFF file (which will probably be more than one frame)
 */
const int kSingleFileMetadataVersion = 1;
const int kArrayAggregatedMetadataVersion = 2;
const int kMultiTiffMetadataVersion = 3;
const int kCurrentMetadataVersion = kMultiTiffMetadataVersion;

@interface ParserBase : NSObject

-(id)init;
-(id)valueForKeyPath:(NSString *)keyPath;	// Implemented by subclasses

#include "DictionaryReadingExtensionsImplementation.h"

@end

@interface JDictionary : ParserBase
/*	This is just a wrapper for NSDictionary
	I used to have the typed accessors as a category on NSDictionary, but it's convenient to have them
	in a separate class so I can also implement FrameMetadataParser on top of it
	(which does not implement everything in NSDictionary)	*/
{
	NSDictionary *_dict;
}

+(id)jDictionary:(NSDictionary *)inDict;
-(id)initWithDictionary:(NSDictionary *)inDict;
-(id)valueForKeyPath:(NSString *)keyPath;

@end

@class FrameMetadataParser;

@interface MetadataForFrame : ParserBase
// This object knows about the metadata for a single frame
// The backing store for this may be a .plist file that contains information about multiple frames
{
	FrameMetadataParser *_parser;
	size_t				_arrayIndex;
}

+(MetadataForFrame *)metadataForFirstFrameAtImagePath:(NSString *)path;
-(id)initForParser:(FrameMetadataParser *)inParser arrayIndex:(size_t)inArrayIndex;
-(id)valueForKeyPath:(NSString *)keyPath;
-(double)universalComputerTimestamp;
-(NSPoint)driftOffset;
-(NSBitmapImageRep *)frameBitmap;
-(NSString *)frameDescNoPath;
-(int)frameNumber;		// Convenience accessor for information in metadata
-(NSMutableDictionary *)frameSpecificMetadataDictionary;	// Useful if caller is writing out files to disk
-(NSDictionary *)commonMetadataDictionary;	// Useful if caller is writing out files to disk
-(void)setNewObject:(id)obj forFrameKey:(NSString *)key;
-(void)setNewObject:(id)obj forCommonKey:(NSString *)key;
-(void)saveStandaloneMetadataFileAtPath:(NSString *)destPath;

// Use sparingly - we want to hide the underlying file structure as much as possible!
// Very few cases where caller ought to need to know about the underlying file object and its parser
-(NSString *)imageFileFullPath;
@property (readonly) FrameMetadataParser *parser;
@property (readonly) size_t arrayIndex;

@end

@interface FrameMetadataParser : JDictionary
// This object knows about a single .plist file, which may contain information about multiple frames
{
	NSArray		*_frameMetadataArray;
	JAlias		*_folderAlias;
	NSString	*_imageFilename;
	int			metadataVersion;
	size_t		_frameCount;
	bool		metadataWasEdited, _deferMetadataSaving;
}

+(id)parserForImagePath:(NSString *)imagePath;
+(id)parserForImageFilename:(NSString *)inImageFilename inFolder:(JAlias *)inFolderAlias;	// More efficient when processing a whole folder

-(id)valueForKeyPath:(NSString *)keyPath arrayIndex:(size_t)arrayIndex;
-(MetadataForFrame *)metadataForFrame:(size_t)arrayIndex;
-(NSBitmapImageRep *)frameBitmapForArrayIndex:(size_t)arrayIndex;
-(NSMutableDictionary *)frameSpecificMetadataDictionaryForArrayIndex:(size_t)arrayIndex;
-(NSDictionary *)commonMetadataDictionary;
-(void)setNewObject:(id)obj forFrameKey:(NSString *)key arrayIndex:(size_t)arrayIndex;
-(void)setNewObject:(id)obj forCommonKey:(NSString *)key;
-(void)saveMetadataIfNeeded;

@property (readonly) size_t frameCount;
@property (readonly) JAlias *folderAlias;
@property (readonly) NSString *imageFilename;
@property (readonly) NSString *imagePath;
@property (readwrite) bool deferMetadataSaving;

@end
