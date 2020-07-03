//
//  CommanHeader.h
//  Uploadphoto
//
//  Created by niewei on 2019/12/5.
//  Copyright © 2019年 songhm. All rights reserved.
//

#ifndef CommanHeader_h
#define CommanHeader_h
#define SCREEN_WIDTH [UIScreen  mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

#define IS_IPHONE    ([[UIDevice currentDevice]userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
#define is_iPhoneXSerious @available(iOS 11.0, *) && UIApplication.sharedApplication.keyWindow.safeAreaInsets.bottom > 0.0

#define KHeaterCollectionViewCellWidth(section) (kScreenWidth - (section-1+2)*kFitWidth(10))/(section)
#define kScreenWidth [UIScreen  mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height
#define kFitHeight(height) (height)/(667.0 - 64) * (kScreenHeight - 64)
#define kFitWidth(width) (width)/375.0 * kScreenWidth
#define KModelCollectionViewCellIdentifier @"modelCollectionViewCellIdentifier"

#define PHOTOCACHEPATH [NSTemporaryDirectory() stringByAppendingPathComponent:@"photoCache"]
#define VIDEOCACHEPATH [NSTemporaryDirectory() stringByAppendingPathComponent:@"videoCache"]

#define SERVER_NAME     @"serverName"
#define PORTID          @"port"
#define SOCKFD          @"sockfd"
#define MESSAGE         @"message"
#define IDENTITY        @"identity"
#define MD5ARRAY        @"md5Array"

#define ERR_TASK_ABORTED    199
#define ERR_NO_NAME         200
#define ERR_EXCEED_CACHE    201
#define ERR_WRONG_CHARACTER 202

#define NumberOfComparisons 30

#define KEY_NAME    @"name"
#define KEY_SIZE    @"size"
#define KEY_MTIME   @"mtime"
#define KEY_MD5     @"md5"



typedef enum : NSUInteger{
	STATUS_IO_INIT = 0,
	STATUS_IO_IOING,
	STATUS_IO_SUSPEND,
	STATUS_IO_CANCEL,
	STATUS_IO_ERROR,
	STATUS_IO_DONE
}DiskIOStatusType;


#endif /* CommanHeader_h */
