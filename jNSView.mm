//
//  jNSView.m
//  Spim Interface
//
//  Created by Jonathan Taylor on 22/05/2015.
//
//

#import "jNSView.h"

@implementation JNSView

-(void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if (newWindow != nil)
    {
        [self addObserver:self forKeyPath:@"viewNeedsRedraw_dummyProperty" options:0 context:NULL];
        _observingForRedraw = true;
    }
    else
    {
        if (_observingForRedraw)
        {
            [self removeObserver:self forKeyPath:@"viewNeedsRedraw_dummyProperty"];
            _observingForRedraw = false;
        }
    }
    [super viewWillMoveToWindow:newWindow];
}

-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context
{
    if ([keyPath isEqualToString:@"viewNeedsRedraw_dummyProperty"])
        self.needsDisplay = true;
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

@synthesize viewNeedsRedraw_dummyProperty = _viewNeedsRedraw_dummyProperty;

@end
