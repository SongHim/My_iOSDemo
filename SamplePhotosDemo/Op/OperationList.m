//
//  ShowErrorMsg.m
//  LoongVBox
//
//  Created by milo shi on 4/12/13.
//  Copyright (c) 2013 milo shi. All rights reserved.
//

#import "OperationList.h"

@interface OperationList()

@property(nonatomic,strong) NSMutableArray<id>* syncMutArr;
@property(nonatomic,strong) NSLock* slock;
@property(nonatomic,strong) RequestQueue* reqQueue;
@end

@implementation OperationList


+ (OperationList*)sharedOperationList
{
    static OperationList* sSharedOperationList;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sSharedOperationList = [[OperationList alloc]init];
    });
    
    return sSharedOperationList;
}


- (NSMutableArray*)syncMutArr
{
	@synchronized (self)
	{
		if(!_syncMutArr)
		{
			_syncMutArr = [[NSMutableArray alloc]init];
		}
	}
    return _syncMutArr;
}

- (RequestQueue*)reqQueue
{
	@synchronized (self)
	{
		if(!_reqQueue)
		{
			_reqQueue = [[RequestQueue alloc]init];
		}
	}
    return _reqQueue;
}


//- (NSLock*)slock
//{
//	@synchronized (self)
//	{
//		if(!_slock)
//		{
//			_slock = [[NSLock alloc]init];
//		}
//	}
//
//    return _slock;
//}


@end
