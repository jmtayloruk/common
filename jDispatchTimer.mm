//
//  JDispatchTimer.mm
//  Simple Preview
//
//  Created by Jonathan Taylor on 05/11/2010.
//  Copyright 2010 Durham University. All rights reserved.
//

#import "JDispatchTimer.h"

@interface JDispatchTimer()
    @property (readwrite) double oneoffTimeDue;
@end

@implementation JDispatchTimer

-(void)startTimer		// private
{
//	printf("Start timer %p, source %p with %lld %lld\n", self, timerSource, interval, repeatInterval);
    self.oneoffTimeDue = GetTime() + interval * 1e-9;
	dispatch_source_set_timer(timerSource, dispatch_time(DISPATCH_TIME_NOW, interval), repeatInterval, 0);
}

#if 0
-(id)retain
{
//	printf("JDispatchTimer retain %p (will be %d)\n", self, self.retainCount+1);
	id result;
	@synchronized(self)
	{
	NSArray *symbols = [NSThread callStackSymbols];
	NSLog(@"JDispatchTimer retain %p (will be %d)\n", self, self.retainCount+1);
	NSLog(@"%@", symbols);
	result = [super retain];
	}
	return result;
}
-(void)release
{
//	printf("JDispatchTimer release %p (will be %d)\n", self, self.retainCount-1);
	@synchronized(self)
	{
		NSArray *symbols = [NSThread callStackSymbols];
		printf("JDispatchTimer release %p (will be %d)\n", self, self.retainCount-1);
		NSLog(@"%@", symbols);
		[super release];
	}
}
#endif

-(id)initForQueue:(dispatch_queue_t)queue withInterval:(double)dt repeat:(bool)repeat withHandler:(dispatch_block_t)handler
{
	if (!(self = [super init]))
		return nil;
	
	firedOneShot = false;	
	timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
	
	if (repeat)
	{
		dispatch_source_set_event_handler(timerSource, handler);
	}
	else
	{
		dispatch_block_t handlerCopy = Block_copy(handler);		// Take a copy of the block to be sure it doesn't go out of scope before we use it
//		printf("Init timer %p with handler copy %p of original %p\n", self, (void*)handlerCopy, (void*)handler);

		dispatch_source_set_cancel_handler(timerSource, ^{
//			printf("Dispatch source cancellation handler called for %p, source %p\n", self, timerSource);
			Block_release(handlerCopy);
		});
		dispatch_source_set_event_handler(timerSource, ^{
			if (firedOneShot)
			{
				/*	I currently don't have a solution to the problem where a call to restartOneShotTimer can
					occur after the timer has *actually* fired, but before this handler has been called.
					This seems to be a limitation of the API. For now I am just working around it by
					ignoring a second fire of the same timer	*/
				printf("WARNING - one shot timer fired more than once (known API issue). Ignoring\n");
			}
			else
			{
//				printf("One shot timer %p fired - should be on queue %p\n", self, queue);
				handlerCopy();
				// We do not release handlerCopy here - we do that in the cancel handler
				firedOneShot = true;
				/*	If we get here then the user must consider the timer as "dead" and the timer should go away of its own accord
					Unfortunately there is an implicit 'retain' of self due to the handler block which will have been retained
					during the call to dispatch_source_set_event_handler. We must explicitly cancel the dispatch source in order
					for our own 'release' calls to take the retain count down to zero	*/
//				printf("%p cancel %p\n", self, timerSource);
				dispatch_source_cancel(timerSource);

				[self release];
			}
		});
	}
	interval = (uint64_t)(dt * NSEC_PER_SEC);
	repeatInterval = repeat ? interval : DISPATCH_TIME_FOREVER;

	[self startTimer];
	dispatch_resume(timerSource);

	return self;
}

+(id)newOneShotTimerOnQueue:(dispatch_queue_t)queue afterInterval:(double)dt withHandler:(dispatch_block_t)handler
{
	// Caller gets a retained object that they must release from their one shot callback.
	// Note that we do an *extra* retain here to balance the release that we do from our own event hander above.
	return [[[JDispatchTimer alloc] initForQueue:queue withInterval:dt repeat:false withHandler:handler] retain];
}

+(id)oneShotTimerOnQueue:(dispatch_queue_t)queue afterInterval:(double)dt withHandler:(dispatch_block_t)handler 
{
	// Will release itself after firing
	return [[JDispatchTimer alloc] initForQueue:queue withInterval:dt repeat:false withHandler:handler];
}

+(id)allocRepeatingTimerOnQueue:(dispatch_queue_t)queue atInterval:(double)dt withHandler:(dispatch_block_t)handler
{
	return [[JDispatchTimer alloc] initForQueue:queue withInterval:dt repeat:true withHandler:handler];
}

-(void)suspend
{
//	printf("Suspend %p\n", self);
	ALWAYS_ASSERT(repeatInterval != DISPATCH_TIME_FOREVER);		// Not supported for one-shot fire-and-forget timers
	dispatch_source_set_timer(timerSource, DISPATCH_TIME_FOREVER, DISPATCH_TIME_FOREVER, 0);
}

-(void)restart
{
//	printf("Restart %p (source %p)\n", self, timerSource);
	ALWAYS_ASSERT(repeatInterval != DISPATCH_TIME_FOREVER);		// Not supported for one-shot fire-and-forget timers
	[self startTimer];
}

-(void)adjustNextInterval:(double)newInterval
{
//	printf("Adjust %p\n", self);
	[self suspend];
	interval = repeatInterval = (uint64_t)(newInterval * NSEC_PER_SEC);
	[self startTimer];
}

-(void)restartOneShotTimer
{
	// This has a different name as a reminder that it must only be called *before* the timer has fired.
	// A one shot timer cannot be restarted when it has already fired
	// Note that thought is required here from the caller - the restart must occur on the same queue that
	// the callback will run on, or window conditions are possible.
//	printf("restart one-shot %p (source %p)\n", self, timerSource);
	ALWAYS_ASSERT(!firedOneShot);
	if (timerSource != nil)
	{
		dispatch_source_set_timer(timerSource, DISPATCH_TIME_FOREVER, DISPATCH_TIME_FOREVER, 0);
		[self startTimer];
	}
	else
		ALWAYS_ASSERT(0);
}

-(void)cancel
{
//	printf("Cancel timer %p (source %p)\n", self, timerSource);
	if (!dispatch_source_testcancel(timerSource))
	{
		dispatch_source_cancel(timerSource);
		dispatch_release(timerSource);
		[self release];
	}
}

-(void)dealloc
{
//	printf("Dealloc timer %p (source %p)\n", self, timerSource);
	
	if (!dispatch_source_testcancel(timerSource))
	{
		/*	I'm pretty sure we shouldn't ever get here - we self-retain and release when
			the callback is called or when it is cancelled. Just to be safe I have included
			this code though. Note however that since I am not sure why we would ever get here,
			I am relucant to call dispatch_release as well...	*/
		printf("%p dealloc apparently without cancelling %p\n", self, timerSource);
		CHECK(0);
		dispatch_source_cancel(timerSource);
	}
	
	[super dealloc];
//	printf("Done dealloc timer %p\n", self);
}

@synthesize oneoffTimeDue = _oneoffTimeDue;

@end
