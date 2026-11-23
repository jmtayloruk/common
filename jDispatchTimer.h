//
//	jDispatchTimer.h
//
//	Copyright 2010-2015 Jonathan Taylor. All rights reserved.
//
//	Cocoa class wrapping a timer, which will execute a block on a GCD queue after a specified interval
//

#import <Cocoa/Cocoa.h>

@interface JDispatchTimer : NSObject
{
	dispatch_source_t	timerSource;
	uint64_t			intervalNs, repeatIntervalNs, flexibilityNs;
	bool				firedOneShot;
    double             _oneoffTimeDue;  // I have not implemented this for repeating timers just because it would be a little more complicated, and I haven't needed that feature
}

// The convenience function oneShotTimerOnQueue returns an autoreleased timer. Both "newXXX" factories return owned timers.
+(id)oneShotTimerOnQueue:(dispatch_queue_t)queue afterInterval:(double)dt flex:(double)flexibility critical:(bool)critical withHandler:(dispatch_block_t)handler;
+(id)newOneShotTimerOnQueue:(dispatch_queue_t)queue afterInterval:(double)dt flex:(double)flexibility critical:(bool)critical withHandler:(dispatch_block_t)handler;
+(id)newRepeatingTimerOnQueue:(dispatch_queue_t)queue atInterval:(double)dt flex:(double)flexibility critical:(bool)critical withHandler:(dispatch_block_t)handler;
-(void)suspend;
-(void)restart;
-(void)cancelAndRelease; // Cancels the timer and consumes one reference owned by the caller.
-(void)restartOneShotTimer;
-(void)restartOneShotTimerWithIntervalInSecsFromNow:(double)newIntervalFromNow;
-(void)fireOneShotTimerNow;
-(void)adjustNextInterval:(double)newInterval;

@property (readonly) double oneoffTimeDue;

@end
