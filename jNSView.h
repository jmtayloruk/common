//
//  JNSView.h
//  Spim Interface
//
//  Created by Jonathan Taylor on 22/05/2015.
//
//  A light wrapper around NSView that implements viewNeedsRedraw_dummyProperty as a convenient way
//  to handle redrawing when a dependent property changes.
//  Subclasses should implement keyPathsForValuesAffectingValueForKey to define which properties should trigger a redraw.
//

#import <Cocoa/Cocoa.h>

@interface JNSView : NSView
{
    int _viewNeedsRedraw_dummyProperty;
    bool _observingForRedraw;
}

@property (readwrite) int viewNeedsRedraw_dummyProperty;

@end
