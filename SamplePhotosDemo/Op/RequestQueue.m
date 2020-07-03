#import <libkern/OSAtomic.h>
#import "OperationList.h"


@implementation RequestQueue
{
    NSOperationQueue* _syncIOQueue;
}

- (instancetype)init
{
    self = [super init];
	
    _syncIOQueue = [[NSOperationQueue alloc]init];
    _syncIOQueue.maxConcurrentOperationCount = 1;
    
    return self;
}


- (void)addSyncIORequestOp:(SyncIOOperation*)operation
{
	@synchronized (self){
		 [_syncIOQueue addOperation:operation];
	}
}


- (int)getCountsOfSyncReq
{
    return (int)_syncIOQueue.operationCount;
}

//- (DiskIOOperation*)foundDiskIOpWithIndex:(uint64_t)index
//{
//    for(DiskIOOperation* op in _diskIOQueue.operations)
//    {
//        if(op.myIndex == index)
//        {
//            return op;
//        }
//    }
//
//    return nil;
//}


//- (BOOL)stopDiskIOpWithIndex:(uint64_t)index
//{
//	BOOL found = NO;
//    for(DiskIOOperation* op in _diskIOQueue.operations)
//    {
//        if(op.myIndex == index)
//        {
//			found = YES;
////            op.stop = YES;
//            [op cancel];//有这个，直接判断isCanceled就好
//            break;
//        }
//    }
//    NSLog(@"after _diskIOQueue count: %lu ",_diskIOQueue.operationCount);
//
//	return found;
//}

- (void)cancelSync
{
    @synchronized (self) {
        if (_syncIOQueue)
        {
            [_syncIOQueue cancelAllOperations];
            
            _syncIOQueue = nil;
        }
    }
}

- (void)dealloc
{
    [self cancelSync];
}

@end
