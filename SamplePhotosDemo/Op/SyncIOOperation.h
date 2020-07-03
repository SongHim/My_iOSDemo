#import <Foundation/Foundation.h>

@interface SyncIOOperation : NSOperation

@property (nonatomic, assign) BOOL needDelete;

@property(nonatomic, strong)NSDictionary *assetAttr;
@property (nonatomic, copy) void (^RequestDoneBlock)(int error);
- (instancetype)initWithDiskItem:(NSDictionary *)assetAttr;

@end
