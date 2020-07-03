//
//  UpLoadInterface.h
//  Uploadphoto
//
//  Created by niewei on 2019/12/10.
//  Copyright © 2019年 songhm. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UpLoadInterface : NSObject

- (int)sendSingleFile:(NSDictionary *)assetAttr;

@end

NS_ASSUME_NONNULL_END
