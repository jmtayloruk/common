//
//  JDispatchTimer.h
//  Simple Preview
//
//  Created by Jonathan Taylor on 05/11/2010.
//  Copyright 2010 Durham University. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface JDispatchTimer : NSObject
{
	dispatch_source_t	timerSource;
	uint64_t			interval, repeatInterval;
	bool				firedOneShot;
}

+(id)oneShotTimerOnQueue:(dispatch_queue_t)queue afterInterval:(double)dt withHandler:(dispatch_block_t)handler;
+(id)newOneShotTimerOnQueue:(dispatch_queue_t)queue afterInterval:(double)dt withHandler:(dispatch_block_t)handler;
+(id)allocRepeatingTimerOnQueue:(dispatch_queue_t)queue atInterval:(double)dt withHandler:(dispatch_block_t)handler;
-(void)suspend;
-(void)restart;
-(void)cancel;
-(void)restartOneShotTimer;
-(void)adjustNextInterval:(double)newInterval;

@end
