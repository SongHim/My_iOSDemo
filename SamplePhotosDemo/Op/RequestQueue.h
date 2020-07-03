#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SyncIOOperation.h"

//@class RequestQueue;
//@class GetContactsOperation;
//@protocol RequestQueueProtocol <NSObject>
//@optional
//- (void)loadNetError:(RequestQueue*)downQueue;
//@end

@interface RequestQueue : NSObject

//@property (nonatomic,assign) BOOL isNetworkError;
//
//@property (nonatomic,weak)   id<RequestQueueProtocol>delegate;
//
//@property(nonatomic,strong) NSMutableDictionary *onlineStatusQueueDictionary;

- (instancetype)init;


- (void)addSyncIORequestOp:(SyncIOOperation *)operation;

- (int)getCountsOfSyncReq;

- (void)cancelSync;

@end
