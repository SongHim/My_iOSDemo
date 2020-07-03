
#import "SyncIOOperation.h"
#import <libkern/OSAtomic.h>
#import "UpLoadInterface.h"

@interface SyncIOOperation ()


@property (nonatomic,assign) NSInteger status;
@property (nonatomic,assign) NSInteger lastStatus;

@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;

@end

@implementation SyncIOOperation
{
    OSSpinLock _oslock;
}

@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)initWithDiskItem:(NSDictionary *)assetAttr
{
	self = [super init];
	if(self)
	{
		self.assetAttr = [assetAttr copy];
		self.needDelete = NO;
		self.finished = NO;
		self.executing = NO;
	}
	return self;
}

- (void)main//不执行
{
	if ([self isCancelled])
	{
		return;
	}
}

- (void)start
{
	uint32_t error = 0;
	if (self.isCancelled)
	{
		NSLog(@"!!!!!!!!");
		[self setFinished:YES];
		return;
	}
	UpLoadInterface *upload = [[UpLoadInterface alloc]init];
	error = [upload sendSingleFile:self.assetAttr];
	
	if(self.RequestDoneBlock)
	{
		self.RequestDoneBlock(error);
	}
	
	[self done];
	
}

- (void)cancelInternal
{
	if (self.isFinished) return;
	
	[super cancel];
	
	if (self.isExecuting) self.executing = NO;
}

- (void)cancel {
	
	OSSpinLockLock(&_oslock);
	[self cancelInternal];
	OSSpinLockUnlock(&_oslock);
}


- (void)done
{
	if (self.isFinished )
	{
		return;
	}
	
	self.finished = YES;
	self.executing = NO;
}


- (void)setFinished:(BOOL)finished {
	[self willChangeValueForKey:@"isFinished"];
	_finished = finished;
	[self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
	[self willChangeValueForKey:@"isExecuting"];
	_executing = executing;
	[self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isConcurrent {
	return YES;
}

@end
