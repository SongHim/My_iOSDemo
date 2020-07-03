//
//  ShowErrorMsg.h
//  LoongVBox
//
//  Created by milo shi on 4/12/13.
//  Copyright (c) 2013 milo shi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RequestQueue.h"

@interface OperationList : NSObject

+ (OperationList*)sharedOperationList;

- (NSMutableArray*)syncMutArr;

- (RequestQueue*)reqQueue;

- (NSLock*)slock;

@end
