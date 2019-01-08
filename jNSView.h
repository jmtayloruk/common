//
//  JNSView.h
//  Spim Interface
//
//  Created by Jonathan Taylor on 22/05/2015.
//
//

#import <Cocoa/Cocoa.h>

@interface JNSView : NSView
{
    int _viewNeedsRedraw_dummyProperty;
}

@property (readwrite) int viewNeedsRedraw_dummyProperty;

@end
