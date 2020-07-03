//
//  TZImageManager.m
//  TZImagePickerController
//
//  Created by 谭真 on 16/1/4.
//  Copyright © 2016年 谭真. All rights reserved.
//

#import "TZImageManager.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "TZAssetModel.h"
#import "TZImagePickerController.h"

#import "CommanHeader.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "HelperMethod.h"
#import "OperationList.h"
#import "RequestQueue.h"
#import "SyncIOOperation.h"
#include "md5.h"
#include "interface.h"

@interface TZImageManager ()
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@property (nonatomic, strong) ALAssetsLibrary *assetLibrary;


//new add
@property (nonatomic, readwrite) int comparedIndex;
@property (nonatomic, readwrite) int num;
@property (nonatomic, strong) NSMutableArray<id> *assetMutArr;
@property (nonatomic, strong) NSMutableArray *assetErrArr;
@property (nonatomic, strong) NSMutableArray *md5Array;
@property (nonatomic, assign) BOOL isfinished;
@property (nonatomic, assign) BOOL executing;
//new end

@end

@implementation TZImageManager

CGSize AssetGridThumbnailSize;
CGFloat TZScreenWidth;
CGFloat TZScreenScale;

static TZImageManager *manager;
static dispatch_once_t onceToken;

+ (instancetype)manager {
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
        if (iOS8Later) {
            // manager.cachingImageManager = [[PHCachingImageManager alloc] init];
            // manager.cachingImageManager.allowsCachingHighQualityImages = YES;
        }
        
        [manager configTZScreenWidth];
    });
    return manager;
}

+ (void)deallocManager {
    onceToken = 0;
    manager = nil;
}


//new add(2020/01/09)

- (instancetype)init
{
	self = [super init];
	if (self) {
		self.assetMutArr = [NSMutableArray array];
		self.assetErrArr = [NSMutableArray array];
		self.md5Array = [NSMutableArray array];
		self.comparedIndex = 0;
		self.num = 0;
		self.isfinished = NO;
		self.executing = YES;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SyncMedia) name:@"SyncMediaNotification" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(CompleteSynchronizationTask) name:@"CompleteSynchronizationTask" object:nil];
	}
	return self;
}

-(void)CompleteSynchronizationTask
{
	//NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
	//NSUserDefaults *defautls = [NSUserDefaults standardUserDefaults];
	//[defautls removePersistentDomainForName:appDomain];
	
	NSString *Sockfd = (NSString*)[[NSUserDefaults standardUserDefaults] objectForKey:SOCKFD];
	int sockfd = [Sockfd intValue];
	if (sockfd > 0)
	{
		disConnected(sockfd);
	}
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:SOCKFD];
	
	NSFileManager *fileManage = [NSFileManager defaultManager];
	[fileManage removeItemAtPath:VIDEOCACHEPATH error:nil];
	[fileManage removeItemAtPath:PHOTOCACHEPATH error:nil];
	
	NSString *message = nil;
	if (self.num < 5)
	{
		message = [[NSString alloc]initWithFormat:@"同步成功文件个数 %d，错误文件: %@, 剩余 %ld 未同步!", self.comparedIndex, self.assetErrArr, (self.assetMutArr.count - self.comparedIndex)];
	}
	else
	{
		message = [[NSString alloc]initWithFormat:@"同步成功文件个数 %d，错误文件个数 %d, 剩余 %ld 未同步!", self.comparedIndex, self.num, (self.assetMutArr.count - self.comparedIndex)];
	}
	NSLog(@"message=%@", message);
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject:message forKey:MESSAGE];
	//NSLog(@"self.md5Array:%@", self.md5Array);
	[userDefaults setObject:self.md5Array forKey:MD5ARRAY];
	
	self.isfinished = YES;
	self.executing = NO;
	self.comparedIndex = 0;
	self.num = 0;
	self.assetErrArr = [NSMutableArray array];
	
}
//将Image保存到缓存路径中
- (NSString*)makeImageMD5:(NSData *)imageData andname:(NSString *)name{
	
	if (self.isfinished == YES)
	{
		//NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
		//NSUserDefaults *defautls = [NSUserDefaults standardUserDefaults];
		//[defautls removePersistentDomainForName:appDomain];
		
		NSFileManager *fileManage = [NSFileManager defaultManager];
		[fileManage removeItemAtPath:VIDEOCACHEPATH error:nil];
		[fileManage removeItemAtPath:PHOTOCACHEPATH error:nil];
		return nil;
	}
	
	/*NSFileManager *fileManager = [NSFileManager defaultManager];
	if (![fileManager fileExistsAtPath:PHOTOCACHEPATH]) {
		
		NSLog(@"路径不存在, 创建路径");
		[fileManager createDirectoryAtPath:PHOTOCACHEPATH
			   withIntermediateDirectories:YES
								attributes:nil
									 error:nil];
	} else {
		
		//NSLog(@"路径存在");
	}
	
	[imageData writeToFile:path atomically:YES];*/
	
	//__block NSString *md5Str;
	//dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		char md5[FILE_MD5_LEN] = "";
		mac_md5_buffer((char*)imageData.bytes, imageData.length, md5);
		NSString *md5Str = [NSString stringWithCString:md5 encoding:NSUTF8StringEncoding];
		NSDictionary *assetAttr = [NSDictionary dictionaryWithObjectsAndKeys:
								   name, @"imgName",
								   md5Str, @"md5",
								   nil];
		[self.md5Array addObject:assetAttr];
		
	//});
	
	return md5Str;
}
//将视频保存到缓存路径中
- (NSString*)makeMD5:(NSString *)path andname:(NSString *)name{
	
	if (self.isfinished == YES)
	{
		//NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
		//NSUserDefaults *defautls = [NSUserDefaults standardUserDefaults];
		//[defautls removePersistentDomainForName:appDomain];
		
		NSFileManager *fileManage = [NSFileManager defaultManager];
		[fileManage removeItemAtPath:VIDEOCACHEPATH error:nil];
		[fileManage removeItemAtPath:PHOTOCACHEPATH error:nil];
		return nil;
	}
	
	/*NSFileManager *fileManager = [NSFileManager defaultManager];
	if (![fileManager fileExistsAtPath:VIDEOCACHEPATH]) {
		
		NSLog(@"路径不存在, 创建路径");
		[fileManager createDirectoryAtPath:VIDEOCACHEPATH
			   withIntermediateDirectories:YES
								attributes:nil
									 error:nil];
	} else {
		
		//NSLog(@"路径存在");
	}
	
	NSError *error;
	[fileManager copyItemAtPath:videoPath toPath:path error:&error];
	if (error) {
		NSLog(@"errorrrrr=%@", error);
		return nil;
	}*/
	NSString *md5Str = nil;
	//dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		char md5[FILE_MD5_LEN] = "";
		int ret = compute_file_md5((char*)path.UTF8String, md5);
		if (ret != 0)
		{
			return nil;
		}
		else
		{
			md5Str = [NSString stringWithCString:md5 encoding:NSUTF8StringEncoding];
			NSDictionary *assetAttr = [NSDictionary dictionaryWithObjectsAndKeys:
						 name, @"imgName",
						 md5Str, @"md5",
						 nil];
			[self.md5Array addObject:assetAttr];
		}
		
	//});
	
	return md5Str;
}

/*- (void)showAlert{
	
	UIAlertView* alert = [[UIAlertView alloc]initWithTitle:nil message:@"正在同步..." delegate:nil cancelButtonTitle:nil otherButtonTitles:nil, nil];
	
	[alert show];
	
	// 2秒后执行
	
	[self performSelector:@selector(dimissAlert:) withObject:alert afterDelay:2.0];
	
}

- (void)dimissAlert:(UIAlertView*)alert {
	
	if(alert)
	{
		[alert dismissWithClickedButtonIndex:[alert cancelButtonIndex] animated:YES];
	}
	
}*/

- (void)SyncMedia
{
	NSLog(@"before CompareMediaAttr /// count : %lu ",self.assetMutArr.count);
	self.isfinished = NO;
	self.executing = YES;
	
	for (int i = 0; i < self.assetMutArr.count; i++)
	{
		id asset = self.assetMutArr[i];
		if([asset isKindOfClass:[PHAsset class]])
		{
			PHAsset* phasset = (PHAsset*)asset;
			NSString *name = [phasset valueForKey:@"filename"];
			NSTimeInterval time = [phasset.modificationDate timeIntervalSince1970];
			long long imgMtime = [[NSNumber numberWithDouble:time] longLongValue];
			NSNumber *longlongNumber = [NSNumber numberWithLongLong:imgMtime];
			NSString *longlongimgMtime = [longlongNumber stringValue];
			NSString *path = nil;
			NSArray *md5Array = [[NSUserDefaults standardUserDefaults] objectForKey:MD5ARRAY];
			
			NSNumber* x = [HelperMethod fileType:name.pathExtension];
			if ([x isEqual:@2])
			{
				path = [VIDEOCACHEPATH stringByAppendingPathComponent:name];
				NSFileManager *fileManager = [NSFileManager defaultManager];
				[[TZImageManager manager]getVideoOutputPathWithAsset:phasset success:^(NSString *outputPath) {
					
					NSString *videosize = nil;
					NSString *md5 = nil;
					[fileManager moveItemAtPath:outputPath toPath:path error:nil];
					if (md5Array != nil && ![md5Array isKindOfClass:[NSNull class]] && md5Array.count != 0)
					{
						for (NSDictionary *dict in md5Array)
						{
							NSString *imgName = [dict objectForKey:@"imgName"];
							if ([name isEqualToString:imgName] == YES)
							{
								md5 = [dict objectForKey:@"md5"];
								//NSLog(@"已存在md5::%@", md5);
							}
							else
							{
								md5 = [self makeMD5:outputPath andname:name];
							}
						}
					}
					else
					{
						md5 = [self makeMD5:outputPath andname:name];
					}
					
					//NSString *md5 = [self saveVideoFromPath:outputPath toCachePath:path];
					if ([fileManager fileExistsAtPath:outputPath]) {
						
						NSDictionary *fileDic = [fileManager attributesOfItemAtPath:outputPath error:nil];//获取文件的属性
						unsigned long long size = [[fileDic objectForKey:NSFileSize] longLongValue];
						//float filesize = 1.0*size/1024;
						videosize = [NSString stringWithFormat:@"%llu",size];
						
					}
					
					NSDictionary *assetAttr = [NSDictionary dictionaryWithObjectsAndKeys:
											   name, @"imgName",
											   path, @"path",
											   longlongimgMtime, @"imgMtime",
											   videosize, @"size",
											   md5, @"md5",
											   nil];
					//NSLog(@"name=%@, path=%@", name, path);
					//NSLog(@"aaaaaa%@", assetAttr);
					[self addDiskIORequest:assetAttr];
					
				} failure:^(NSString *errorMessage, NSError *error) {
					
				}];
				
			}
			else
			{
				path = [PHOTOCACHEPATH stringByAppendingPathComponent:name];
				[[TZImageManager manager]getOriginalPhotoDataWithAsset:phasset completion:^(NSData *data, NSDictionary *info, BOOL isDegraded) {
					
					//NSString *md5 = [self saveImage:data toCachePath:path];
					NSString *md5 = nil;
					[data writeToFile:path atomically:YES];
					if (md5Array != nil && ![md5Array isKindOfClass:[NSNull class]] && md5Array.count != 0)
					{
						for (NSDictionary *dict in md5Array)
						{
							NSString *imgName = [dict objectForKey:@"imgName"];
							if ([name isEqualToString:imgName] == YES)
							{
								
								md5 = [dict objectForKey:@"md5"];
								//NSLog(@"md5::%@", md5);
							}
							else
							{
								md5 = [self makeImageMD5:data andname:name];
							}
						}
					}
					else
					{
						md5 = [self makeImageMD5:data andname:name];
					}
					NSInteger imgsize = data.length;
					NSDictionary *assetAttr = [NSDictionary dictionaryWithObjectsAndKeys:
											   name, @"imgName",
											   path, @"path",
											   longlongimgMtime, @"imgMtime",
											   @(imgsize), @"size",
											   md5, @"md5",
											   nil];
					
					//NSLog(@"aaaaaa%@", assetAttr);
					//NSLog(@"name=%@, size=%ld, md5=%@", name, size, md5);
					[self addDiskIORequest:assetAttr];
					
				}];
			}
		}
		else if ([asset isKindOfClass:[ALAsset class]])//这个需要单独导入头文件
		{
			ALAsset* alasset = (ALAsset*)asset;
			NSLog(@"ALAsset name: %@ , type: %@ , date: %@ , url: %@ ,loc: %@ ",[alasset valueForKey:@"filename"], [alasset valueForProperty: ALAssetPropertyType], [alasset valueForProperty: ALAssetPropertyDate], [alasset valueForProperty: ALAssetPropertyAssetURL], [alasset valueForProperty: ALAssetPropertyLocation]);
			//未完待续。。。
			
		}
		
		/*if ((i == NumberOfComparisons) || (i == self.assetMutArr.count - 1))//够数量，或者没有了
		 {
		 NSFileManager *fileManage = [NSFileManager defaultManager];
		 [fileManage removeItemAtPath:VIDEOCACHEPATH error:nil];
		 [fileManage removeItemAtPath:PHOTOCACHEPATH error:nil];
		 float cacheSize = [self getFileSize:VIDEOCACHEPATH];
		 NSLog(@"视频缓存大小:%f",cacheSize);
		 float Size = [self getFileSize:PHOTOCACHEPATH];
		 NSLog(@"图片缓存大小:%f",Size);
		 }*/
	}
}
-(void)addDiskIORequest:(NSDictionary *)assetAttr
{

	RequestQueue* reqQueue = [[OperationList sharedOperationList]reqQueue];
	if (self.executing == NO)
	{
		[reqQueue cancelSync];
		return;
	}
	SyncIOOperation* op = [[SyncIOOperation alloc]initWithDiskItem:assetAttr];
	//dispatch_semaphore_t signal = dispatch_semaphore_create(0);
	
	[op setRequestDoneBlock:^(int error){
		
		NSLog(@"error==%d", error);
		self.comparedIndex += 1;
		if (error == -1)
		{
			self.num += 1;
			NSString *imgName = [assetAttr objectForKey:@"imgName"];
			[self.assetErrArr addObject:imgName];
			//dispatch_semaphore_signal(signal);
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (self.comparedIndex == self.assetMutArr.count)
			{
				[self CompleteSynchronizationTask];
				[[NSNotificationCenter defaultCenter] postNotificationName:@"MediaSyncEndNotification" object:self];
			}
		});
		
	}];
		
	[reqQueue addSyncIORequestOp:op];
	//dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
	
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"SyncMediaNotification" object:nil];
	//[[NSNotificationCenter defaultCenter] removeObserver:self name:@"StartMediaSyncNotification" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"CompleteSynchronizationTask" object:nil];
}

//add end


- (void)setPhotoWidth:(CGFloat)photoWidth {
    _photoWidth = photoWidth;
    TZScreenWidth = photoWidth / 2;
}

- (void)setColumnNumber:(NSInteger)columnNumber {
    [self configTZScreenWidth];

    _columnNumber = columnNumber;
    CGFloat margin = 4;
    CGFloat itemWH = (TZScreenWidth - 2 * margin - 4) / columnNumber - margin;
    AssetGridThumbnailSize = CGSizeMake(itemWH * TZScreenScale, itemWH * TZScreenScale);
}

- (void)configTZScreenWidth {
    TZScreenWidth = [UIScreen mainScreen].bounds.size.width;
    // 测试发现，如果scale在plus真机上取到3.0，内存会增大特别多。故这里写死成2.0
    TZScreenScale = 2.0;
    if (TZScreenWidth > 700) {
        TZScreenScale = 1.5;
    }
}

- (ALAssetsLibrary *)assetLibrary
{
    if (_assetLibrary == nil)
        _assetLibrary = [[ALAssetsLibrary alloc] init];
    
    return _assetLibrary;
}

/// Return YES if Authorized 返回YES如果得到了授权
- (BOOL)authorizationStatusAuthorized {
    NSInteger status = [self.class authorizationStatus];
    if (status == 0) {
        /**
         * 当某些情况下AuthorizationStatus == AuthorizationStatusNotDetermined时，无法弹出系统首次使用的授权alertView，系统应用设置里亦没有相册的设置，此时将无法使用，故作以下操作，弹出系统首次使用的授权alertView
         */
        [self requestAuthorizationWithCompletion:nil];
    }
    
    return status == 3;
}

+ (NSInteger)authorizationStatus {
    if (iOS8Later) {
        return [PHPhotoLibrary authorizationStatus];
    } else {
        return [ALAssetsLibrary authorizationStatus];
    }
    return NO;
}

- (void)requestAuthorizationWithCompletion:(void (^)(void))completion {
    void (^callCompletionBlock)(void) = ^(){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion();
            }
        });
    };
    
    if (iOS8Later) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                callCompletionBlock();
            }];
        });
    } else {
        [self.assetLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            callCompletionBlock();
        } failureBlock:^(NSError *error) {
            callCompletionBlock();
        }];
    }
}

#pragma mark - Get Album

/// Get Album 获得相册/相册数组
- (void)getCameraRollAlbum:(BOOL)allowPickingVideo allowPickingImage:(BOOL)allowPickingImage needFetchAssets:(BOOL)needFetchAssets completion:(void (^)(TZAlbumModel *model))completion
{
    NSLog(@"get album data ....");
    __block TZAlbumModel *model;
    if (iOS8Later)
    {
        PHFetchOptions *option = [[PHFetchOptions alloc] init];
        if (!allowPickingVideo) option.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", PHAssetMediaTypeImage];
        if (!allowPickingImage) option.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", PHAssetMediaTypeVideo];
        
        // option.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"modificationDate" ascending:self.sortAscendingByModificationDate]];
        if (!self.sortAscendingByModificationDate) {
            option.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:self.sortAscendingByModificationDate]];
        }
		
        PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
        for (PHAssetCollection *collection in smartAlbums)
        {
            // 有可能是PHCollectionList类的的对象，过滤掉
            if (![collection isKindOfClass:[PHAssetCollection class]])
                continue;
            
            // 过滤空相册
            if (collection.estimatedAssetCount <= 0) continue;
            
            if ([self isCameraRollAlbum:collection])
            {
                PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:option];
				
				self.assetMutArr = [[NSMutableArray alloc]init];
				for (PHAsset *asset in fetchResult)
				{
					[self.assetMutArr addObject:asset];
				}
				
                NSLog(@"collection.localizedTitle: %@ ,fetchResult.count : %lu ",collection.localizedTitle,fetchResult.count);
                model = [self modelWithResult:fetchResult name:collection.localizedTitle isCameraRoll:YES needFetchAssets:needFetchAssets];
				
                if (completion) completion(model);
                
                break;
            }
        }
    }
    else
    {
        [self.assetLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            if ([group numberOfAssets] < 1) return;
    
            if ([self isCameraRollAlbum:group])
            {
                NSString *name = [group valueForProperty:ALAssetsGroupPropertyName];
                NSLog(@"<ios8 name: %@ ,count: %lu ",name,[group numberOfAssets]);
                model = [self modelWithResult:group name:name isCameraRoll:YES needFetchAssets:needFetchAssets];
               
                if (completion) completion(model);
                *stop = YES;
            }
        } failureBlock:nil];
    }
}

- (void)getAllAlbums:(BOOL)allowPickingVideo allowPickingImage:(BOOL)allowPickingImage needFetchAssets:(BOOL)needFetchAssets completion:(void (^)(NSArray<TZAlbumModel *> *))completion
{
    NSMutableArray *albumArr = [NSMutableArray array];
    if (iOS8Later)
    {
        PHFetchOptions *option = [[PHFetchOptions alloc] init];
        if (!allowPickingVideo) option.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", PHAssetMediaTypeImage];
        if (!allowPickingImage) option.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", PHAssetMediaTypeVideo];
        
        // option.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"modificationDate" ascending:self.sortAscendingByModificationDate]];
        if (!self.sortAscendingByModificationDate) {
            option.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:self.sortAscendingByModificationDate]];
        }
        // 我的照片流 1.6.10重新加入..
        PHFetchResult *myPhotoStreamAlbum = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumMyPhotoStream options:nil];
        PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
        PHFetchResult *topLevelUserCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
        PHFetchResult *syncedAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumSyncedAlbum options:nil];
        PHFetchResult *sharedAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumCloudShared options:nil];
        
        NSArray *allAlbums = @[myPhotoStreamAlbum,smartAlbums,topLevelUserCollections,syncedAlbums,sharedAlbums];
        for (PHFetchResult *fetchResult in allAlbums)
        {
            //NSLog(@"fetchresult album,  count: %lu , first: %@,last: %@", fetchResult.count, fetchResult.firstObject, fetchResult.lastObject);
            for (PHAssetCollection *collection in fetchResult)
            {
                //NSLog(@"collection name : %@ ,id: %@ ",collection.localizedTitle,collection.localIdentifier);
                
                // 有可能是PHCollectionList类的的对象，过滤掉
                if (![collection isKindOfClass:[PHAssetCollection class]]) continue;
            
                // 过滤空相册
                if (collection.estimatedAssetCount <= 0) continue;
                
                PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:option];
                
                //NSLog(@"[same one? ] fetchresult count: %lu ,first: %@,last: %@",fetchResult.count,fetchResult.firstObject, fetchResult.lastObject);
                
                if (fetchResult.count < 1) continue;
                
                if ([self.pickerDelegate respondsToSelector:@selector(isAlbumCanSelect:result:)]) {
                    if (![self.pickerDelegate isAlbumCanSelect:collection.localizedTitle result:fetchResult]) {
                        continue;
                    }
                }
                
                if (collection.assetCollectionSubtype == PHAssetCollectionSubtypeSmartAlbumAllHidden) continue;
                if (collection.assetCollectionSubtype == 1000000201) continue; //『最近删除』相册
                
                if ([self isCameraRollAlbum:collection]) {
                    [albumArr insertObject:[self modelWithResult:fetchResult name:collection.localizedTitle isCameraRoll:YES needFetchAssets:needFetchAssets] atIndex:0];
                } else {
                    [albumArr addObject:[self modelWithResult:fetchResult name:collection.localizedTitle isCameraRoll:NO needFetchAssets:needFetchAssets]];
                }
            }
        }
        if (completion && albumArr.count > 0) completion(albumArr);
    }
    else
    {
        [self.assetLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            if (group == nil)
            {
                if (completion && albumArr.count > 0) completion(albumArr);
            }
            
            if ([group numberOfAssets] < 1) return;
            
            NSString *name = [group valueForProperty:ALAssetsGroupPropertyName];
            
            if ([self.pickerDelegate respondsToSelector:@selector(isAlbumCanSelect:result:)])
            {
                if (![self.pickerDelegate isAlbumCanSelect:name result:group])
                {
                    return;
                }
            }
            
            if ([self isCameraRollAlbum:group])
            {
                [albumArr insertObject:[self modelWithResult:group name:name isCameraRoll:YES needFetchAssets:needFetchAssets] atIndex:0];
            }
            else if ([[group valueForProperty:ALAssetsGroupPropertyType] intValue] == ALAssetsGroupPhotoStream)
            {
                if (albumArr.count)
                {
                    [albumArr insertObject:[self modelWithResult:group name:name isCameraRoll:NO needFetchAssets:needFetchAssets] atIndex:1];
                }
                else
                {
                    [albumArr addObject:[self modelWithResult:group name:name isCameraRoll:NO needFetchAssets:needFetchAssets]];
                }
            }
            else
            {
                [albumArr addObject:[self modelWithResult:group name:name isCameraRoll:NO needFetchAssets:needFetchAssets]];
            }
        } failureBlock:nil];
    }
}

#pragma mark - Get Assets

/// Get Assets 获得照片数组
- (void)getAssetsFromFetchResult:(id)result completion:(void (^)(NSArray<TZAssetModel *> *))completion
{
    TZImagePickerConfig *config = [TZImagePickerConfig sharedInstance];
    return [self getAssetsFromFetchResult:result allowPickingVideo:config.allowPickingVideo allowPickingImage:config.allowPickingImage completion:completion];
}

- (void)getAssetsFromFetchResult:(id)result allowPickingVideo:(BOOL)allowPickingVideo allowPickingImage:(BOOL)allowPickingImage completion:(void (^)(NSArray<TZAssetModel *> *))completion
{
    NSMutableArray *photoArr = [NSMutableArray array];
    if ([result isKindOfClass:[PHFetchResult class]])
    {
        PHFetchResult *fetchResult = (PHFetchResult *)result;
        [fetchResult enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            TZAssetModel *model = [self assetModelWithAsset:obj allowPickingVideo:allowPickingVideo allowPickingImage:allowPickingImage];
            if (model) {
                [photoArr addObject:model];
            }
        }];
    
        if (completion) completion(photoArr);
    }
    else if ([result isKindOfClass:[ALAssetsGroup class]])
    {
        ALAssetsGroup *group = (ALAssetsGroup *)result;
        if (allowPickingImage && allowPickingVideo)
        {
            [group setAssetsFilter:[ALAssetsFilter allAssets]];
        }
        else if (allowPickingVideo)
        {
            [group setAssetsFilter:[ALAssetsFilter allVideos]];
        }
        else if (allowPickingImage)
        {
            [group setAssetsFilter:[ALAssetsFilter allPhotos]];
        }
        
        ALAssetsGroupEnumerationResultsBlock resultBlock = ^(ALAsset *result, NSUInteger index, BOOL *stop)  {
            if (result == nil) {
                if (completion) completion(photoArr);
            }
            TZAssetModel *model = [self assetModelWithAsset:result allowPickingVideo:allowPickingVideo allowPickingImage:allowPickingImage];
            if (model) {
                [photoArr addObject:model];
            }
        };
        
        if (self.sortAscendingByModificationDate) {
            [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                if (resultBlock) { resultBlock(result,index,stop); }
            }];
        } else {
            [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                if (resultBlock) { resultBlock(result,index,stop); }
            }];
        }
    }
	
}

///  Get asset at index 获得下标为index的单个照片
///  if index beyond bounds, return nil in callback 如果索引越界, 在回调中返回 nil
- (void)getAssetFromFetchResult:(id)result atIndex:(NSInteger)index allowPickingVideo:(BOOL)allowPickingVideo allowPickingImage:(BOOL)allowPickingImage completion:(void (^)(TZAssetModel *))completion
{
    if ([result isKindOfClass:[PHFetchResult class]])
    {
        PHFetchResult *fetchResult = (PHFetchResult *)result;
        PHAsset *asset;
        @try {
            asset = fetchResult[index];
        }
        @catch (NSException* e) {
            if (completion) completion(nil);
            return;
        }

        TZAssetModel *model = [self assetModelWithAsset:asset allowPickingVideo:allowPickingVideo allowPickingImage:allowPickingImage];

        if (completion) completion(model);
    }
    else if ([result isKindOfClass:[ALAssetsGroup class]])
    {
        ALAssetsGroup *group = (ALAssetsGroup *)result;
        if (allowPickingImage && allowPickingVideo) {
            [group setAssetsFilter:[ALAssetsFilter allAssets]];
        } else if (allowPickingVideo) {
            [group setAssetsFilter:[ALAssetsFilter allVideos]];
        } else if (allowPickingImage) {
            [group setAssetsFilter:[ALAssetsFilter allPhotos]];
        }
     
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:index];
        @try {
            [group enumerateAssetsAtIndexes:indexSet options:NSEnumerationConcurrent usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                if (!result) return;
                TZAssetModel *model = [self assetModelWithAsset:result allowPickingVideo:allowPickingVideo allowPickingImage:allowPickingImage];
                if (completion) completion(model);
            }];
        }
        @catch (NSException* e) {
            if (completion) completion(nil);
        }
    }
}

- (TZAssetModel *)assetModelWithAsset:(id)asset allowPickingVideo:(BOOL)allowPickingVideo allowPickingImage:(BOOL)allowPickingImage
{
    BOOL canSelect = YES;
    if ([self.pickerDelegate respondsToSelector:@selector(isAssetCanSelect:)]) {
        canSelect = [self.pickerDelegate isAssetCanSelect:asset];
    }
    if (!canSelect) return nil;
    
    TZAssetModel *model;
    TZAssetModelMediaType type = [self getAssetType:asset];
    
    if ([asset isKindOfClass:[PHAsset class]])
    {
        if (!allowPickingVideo && type == TZAssetModelMediaTypeVideo) return nil;
        if (!allowPickingImage && type == TZAssetModelMediaTypePhoto) return nil;
        if (!allowPickingImage && type == TZAssetModelMediaTypePhotoGif) return nil;
        
        PHAsset *phAsset = (PHAsset *)asset;
        if (self.hideWhenCanNotSelect) {
            // 过滤掉尺寸不满足要求的图片
            if (![self isPhotoSelectableWithAsset:phAsset]) {
                return nil;
            }
        }
        
        NSString *timeLength = type == TZAssetModelMediaTypeVideo ? [NSString stringWithFormat:@"%0.0f",phAsset.duration] : @"";
        timeLength = [self getNewTimeFromDurationSecond:timeLength.integerValue];
        
        model = [TZAssetModel modelWithAsset:asset type:type timeLength:timeLength];
    }
    else
    {
        if (!allowPickingVideo)
        {
            model = [TZAssetModel modelWithAsset:asset type:type];
            return model;
        }
        
        /// Allow picking video
        if (type == TZAssetModelMediaTypeVideo)
        {
            NSTimeInterval duration = [[asset valueForProperty:ALAssetPropertyDuration] doubleValue];
            NSString *timeLength = [NSString stringWithFormat:@"%0.0f",duration];
            timeLength = [self getNewTimeFromDurationSecond:timeLength.integerValue];
            
            model = [TZAssetModel modelWithAsset:asset type:type timeLength:timeLength];
        }
        else
        {
            if (self.hideWhenCanNotSelect)
            {
                // 过滤掉尺寸不满足要求的图片
                if (![self isPhotoSelectableWithAsset:asset])
                {
                    return nil;
                }
            }
            model = [TZAssetModel modelWithAsset:asset type:type];
        }
    }
    return model;
}

- (TZAssetModelMediaType)getAssetType:(id)asset
{
    TZAssetModelMediaType type = TZAssetModelMediaTypePhoto;

    if ([asset isKindOfClass:[PHAsset class]])
    {
        PHAsset *phAsset = (PHAsset *)asset;
        if (phAsset.mediaType == PHAssetMediaTypeVideo)
            type = TZAssetModelMediaTypeVideo;
        else if (phAsset.mediaType == PHAssetMediaTypeAudio)
            type = TZAssetModelMediaTypeAudio;
        else if (phAsset.mediaType == PHAssetMediaTypeImage)
        {
            if (iOS9_1Later)
            {
                // if (asset.mediaSubtypes == PHAssetMediaSubtypePhotoLive) type = TZAssetModelMediaTypeLivePhoto;
            }
            
            // Gif
            if ([[phAsset valueForKey:@"filename"] hasSuffix:@"GIF"]) {
                type = TZAssetModelMediaTypePhotoGif;
            }
        }
    }
    else
    {
        if ([[asset valueForProperty:ALAssetPropertyType] isEqualToString:ALAssetTypeVideo]) {
            type = TZAssetModelMediaTypeVideo;
        }
    }
    return type;
}

- (NSString *)getNewTimeFromDurationSecond:(NSInteger)duration {
    NSString *newTime;
    if (duration < 10) {
        newTime = [NSString stringWithFormat:@"0:0%zd",duration];
    } else if (duration < 60) {
        newTime = [NSString stringWithFormat:@"0:%zd",duration];
    } else {
        NSInteger min = duration / 60;
        NSInteger sec = duration - (min * 60);
        if (sec < 10) {
            newTime = [NSString stringWithFormat:@"%zd:0%zd",min,sec];
        } else {
            newTime = [NSString stringWithFormat:@"%zd:%zd",min,sec];
        }
    }
    return newTime;
}

/// Get photo bytes 获得一组照片的大小
- (void)getPhotosBytesWithArray:(NSArray *)photos completion:(void (^)(NSString *totalBytes))completion
{
    if (!photos || !photos.count)
    {
        if (completion) completion(@"0B");
        return;
    }
    
    __block NSInteger dataLength = 0;
    __block NSInteger assetCount = 0;
    for (NSInteger i = 0; i < photos.count; i++)
    {
        TZAssetModel *model = photos[i];
        if ([model.asset isKindOfClass:[PHAsset class]])
        {
            PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
            options.resizeMode = PHImageRequestOptionsResizeModeFast;
            /*
			[[PHImageManager defaultManager] requestImageDataForAsset:model.asset options:options resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info)
            {
//                if (model.type != TZAssetModelMediaTypeVideo) dataLength += imageData.length;
				dataLength += imageData.length;
            
                assetCount ++;
                if (assetCount >= photos.count)
                {
                    NSString *bytes = [self getBytesFromDataLength:dataLength];
                    if (completion) completion(bytes);
                }
            }];
			*/
			
			PHAssetResource * resource = [[PHAssetResource assetResourcesForAsset:model.asset] firstObject];
            long long fileSize = [[resource valueForKey:@"fileSize"] longLongValue];
            
            dataLength += fileSize;
            assetCount ++;
            if (assetCount >= photos.count)
            {
                NSString *bytes = [self getBytesFromDataLength:dataLength];
                if (completion) completion(bytes);
            }
        }
        else if ([model.asset isKindOfClass:[ALAsset class]])
        {
            ALAssetRepresentation *representation = [model.asset defaultRepresentation];
            if (model.type != TZAssetModelMediaTypeVideo) dataLength += (NSInteger)representation.size;
            if (i >= photos.count - 1) {
                NSString *bytes = [self getBytesFromDataLength:dataLength];
                if (completion) completion(bytes);
            }
        }
    }
}

- (NSString *)getBytesFromDataLength:(NSInteger)dataLength {
    NSString *bytes;
    if (dataLength >= 0.1 * (1024 * 1024)) {
        bytes = [NSString stringWithFormat:@"%0.1fM",dataLength/1024/1024.0];
    } else if (dataLength >= 1024) {
        bytes = [NSString stringWithFormat:@"%0.0fK",dataLength/1024.0];
    } else {
        bytes = [NSString stringWithFormat:@"%zdB",dataLength];
    }
    return bytes;
}

#pragma mark - Get Photo

/// Get photo 获得照片本身
- (int32_t)getPhotoWithAsset:(id)asset completion:(void (^)(UIImage *, NSDictionary *, BOOL isDegraded))completion {
    CGFloat fullScreenWidth = TZScreenWidth;
    if (fullScreenWidth > _photoPreviewMaxWidth) {
        fullScreenWidth = _photoPreviewMaxWidth;
    }
    return [self getPhotoWithAsset:asset photoWidth:fullScreenWidth completion:completion progressHandler:nil networkAccessAllowed:YES];
}

- (int32_t)getPhotoWithAsset:(id)asset photoWidth:(CGFloat)photoWidth completion:(void (^)(UIImage *photo,NSDictionary *info,BOOL isDegraded))completion {
    return [self getPhotoWithAsset:asset photoWidth:photoWidth completion:completion progressHandler:nil networkAccessAllowed:YES];
}

- (int32_t)getPhotoWithAsset:(id)asset completion:(void (^)(UIImage *photo,NSDictionary *info,BOOL isDegraded))completion progressHandler:(void (^)(double progress, NSError *error, BOOL *stop, NSDictionary *info))progressHandler networkAccessAllowed:(BOOL)networkAccessAllowed
{
    CGFloat fullScreenWidth = TZScreenWidth;
    if (fullScreenWidth > _photoPreviewMaxWidth) {
        fullScreenWidth = _photoPreviewMaxWidth;
    }
    return [self getPhotoWithAsset:asset photoWidth:fullScreenWidth completion:completion progressHandler:progressHandler networkAccessAllowed:networkAccessAllowed];
}

- (int32_t)getPhotoWithAsset:(id)asset photoWidth:(CGFloat)photoWidth completion:(void (^)(UIImage *photo,NSDictionary *info,BOOL isDegraded))completion progressHandler:(void (^)(double progress, NSError *error, BOOL *stop, NSDictionary *info))progressHandler networkAccessAllowed:(BOOL)networkAccessAllowed
{
    if ([asset isKindOfClass:[PHAsset class]])
    {
        CGSize imageSize;
        if (photoWidth < TZScreenWidth && photoWidth < _photoPreviewMaxWidth)
        {
            imageSize = AssetGridThumbnailSize;
        }
        else
        {
            PHAsset *phAsset = (PHAsset *)asset;
            CGFloat aspectRatio = phAsset.pixelWidth / (CGFloat)phAsset.pixelHeight;
            CGFloat pixelWidth = photoWidth * TZScreenScale * 1.5;
            
            // 超宽图片
            if (aspectRatio > 1.8) {
                pixelWidth = pixelWidth * aspectRatio;
            }
            // 超高图片
            if (aspectRatio < 0.2) {
                pixelWidth = pixelWidth * 0.5;
            }
            CGFloat pixelHeight = pixelWidth / aspectRatio;
            imageSize = CGSizeMake(pixelWidth, pixelHeight);
        }
        
        __block UIImage *image;
        // 修复获取图片时出现的瞬间内存过高问题
        // 下面两行代码，来自hsjcom，他的github是：https://github.com/hsjcom 表示感谢
        PHImageRequestOptions *option = [[PHImageRequestOptions alloc] init];
        option.resizeMode = PHImageRequestOptionsResizeModeFast;
        
        int32_t imageRequestID = [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:imageSize contentMode:PHImageContentModeAspectFill options:option resultHandler:^(UIImage *result, NSDictionary *info)
        {
            if (result)
            {
                image = result;
            }
            
            BOOL downloadFinined = (![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey]);
            if (downloadFinined && result)
            {
                result = [self fixOrientation:result];
                if (completion) completion(result,info,[[info objectForKey:PHImageResultIsDegradedKey] boolValue]);
            }
            
            // Download image from iCloud / 从iCloud下载图片
            if ([info objectForKey:PHImageResultIsInCloudKey] && !result && networkAccessAllowed)
            {
                NSLog(@"progress handler...");
                
                PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
                options.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (progressHandler) {
                            progressHandler(progress, error, stop, info);
                        }
                    });
                };
                options.networkAccessAllowed = YES;
                options.resizeMode = PHImageRequestOptionsResizeModeFast;
                [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                    UIImage *resultImage = [UIImage imageWithData:imageData scale:0.1];
                    resultImage = [self scaleImage:resultImage toSize:imageSize];
                    if (!resultImage) {
                        resultImage = image;
                    }
                    
                    resultImage = [self fixOrientation:resultImage];
                    if (completion) completion(resultImage,info,NO);
                }];
            }
        }];
        
        return imageRequestID;
    }
    else if ([asset isKindOfClass:[ALAsset class]])
    {
        ALAsset *alAsset = (ALAsset *)asset;
        dispatch_async(dispatch_get_global_queue(0,0), ^{
            CGImageRef thumbnailImageRef = alAsset.thumbnail;
            UIImage *thumbnailImage = [UIImage imageWithCGImage:thumbnailImageRef scale:2.0 orientation:UIImageOrientationUp];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(thumbnailImage,nil,YES);
                
                if (photoWidth == TZScreenWidth || photoWidth == self->_photoPreviewMaxWidth)
                {
                    dispatch_async(dispatch_get_global_queue(0,0), ^{
                        ALAssetRepresentation *assetRep = [alAsset defaultRepresentation];
                        CGImageRef fullScrennImageRef = [assetRep fullScreenImage];
                        UIImage *fullScrennImage = [UIImage imageWithCGImage:fullScrennImageRef scale:2.0 orientation:UIImageOrientationUp];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (completion) completion(fullScrennImage,nil,NO);
                        });
                    });
                }
            });
        });
    }
    
    return 0;
}

/// Get postImage / 获取封面图
- (void)getPostImageWithAlbumModel:(TZAlbumModel *)model completion:(void (^)(UIImage *))completion
{
    if (iOS8Later) {
        id asset = [model.result lastObject];
        if (!self.sortAscendingByModificationDate) {
            asset = [model.result firstObject];
        }
    
        [[TZImageManager manager] getPhotoWithAsset:asset photoWidth:80 completion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
            if (completion) completion(photo);
        }];
    }
    else
    {
        ALAssetsGroup *group = model.result;
        UIImage *postImage = [UIImage imageWithCGImage:group.posterImage];
        if (completion) completion(postImage);
    }
}

/// Get Original Photo / 获取原图
- (void)getOriginalPhotoWithAsset:(id)asset completion:(void (^)(UIImage *photo,NSDictionary *info))completion
{
    [self getOriginalPhotoWithAsset:asset newCompletion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded)
    {
        if (completion) {
            completion(photo,info);
        }
    }];
}

- (void)getOriginalPhotoWithAsset:(id)asset newCompletion:(void (^)(UIImage *photo,NSDictionary *info,BOOL isDegraded))completion
{
    if ([asset isKindOfClass:[PHAsset class]])
    {
        PHImageRequestOptions *option = [[PHImageRequestOptions alloc]init];
        option.networkAccessAllowed = YES;
        option.resizeMode = PHImageRequestOptionsResizeModeFast;
        
        [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeAspectFit options:option resultHandler:^(UIImage *result, NSDictionary *info)
        {
            BOOL downloadFinined = (![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey]);
            if (downloadFinined && result) {
                result = [self fixOrientation:result];
                BOOL isDegraded = [[info objectForKey:PHImageResultIsDegradedKey] boolValue];
                if (completion) completion(result,info,isDegraded);
            }
        }];
    }
    else if ([asset isKindOfClass:[ALAsset class]])
    {
        ALAsset *alAsset = (ALAsset *)asset;
        ALAssetRepresentation *assetRep = [alAsset defaultRepresentation];
        
        dispatch_async(dispatch_get_global_queue(0,0), ^{
            CGImageRef originalImageRef = [assetRep fullResolutionImage];
            UIImage *originalImage = [UIImage imageWithCGImage:originalImageRef scale:1.0 orientation:UIImageOrientationUp];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(originalImage,nil,NO);
            });
        });
    }
}

- (void)getOriginalPhotoDataWithAsset:(id)asset completion:(void (^)(NSData *data,NSDictionary *info,BOOL isDegraded))completion
{
    if ([asset isKindOfClass:[PHAsset class]])
    {
        PHImageRequestOptions *option = [[PHImageRequestOptions alloc] init];
        option.networkAccessAllowed = YES;
        if ([[asset valueForKey:@"filename"] hasSuffix:@"GIF"])
        {
            // if version isn't PHImageRequestOptionsVersionOriginal, the gif may cann't play
            option.version = PHImageRequestOptionsVersionOriginal;
        }
        option.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        
        [[PHImageManager defaultManager] requestImageDataForAsset:asset options:option resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
            BOOL downloadFinined = (![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey]);
            if (downloadFinined && imageData)
            {
                if (completion) completion(imageData,info,NO);
            }
        }];
    }
    else if ([asset isKindOfClass:[ALAsset class]])
    {
        ALAsset *alAsset = (ALAsset *)asset;
        ALAssetRepresentation *assetRep = [alAsset defaultRepresentation];
        Byte *imageBuffer = (Byte *)malloc(assetRep.size);
        NSUInteger bufferSize = [assetRep getBytes:imageBuffer fromOffset:0.0 length:assetRep.size error:nil];
        NSData *imageData = [NSData dataWithBytesNoCopy:imageBuffer length:bufferSize freeWhenDone:YES];
       
        if (completion) completion(imageData,nil,NO);
    }
}

#pragma mark - Save photo

- (void)savePhotoWithImage:(UIImage *)image completion:(void (^)(NSError *error))completion {
    [self savePhotoWithImage:image location:nil completion:completion];
}

- (void)savePhotoWithImage:(UIImage *)image location:(CLLocation *)location completion:(void (^)(NSError *error))completion
{
    if (iOS8Later)
    {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            if (iOS9Later)
            {
                NSData *data = UIImageJPEGRepresentation(image, 0.9);
                PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                options.shouldMoveFile = YES;
                PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                [request addResourceWithType:PHAssetResourceTypePhoto data:data options:options];
                if (location) {
                    request.location = location;
                }
                request.creationDate = [NSDate date];
            }
            else
            {
                PHAssetChangeRequest *request = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                if (location)
                {
                    request.location = location;
                }
                request.creationDate = [NSDate date];
            }
        }
        completionHandler:^(BOOL success, NSError *error)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success && completion)
                {
                    completion(nil);
                }
                else if (error)
                {
                    NSLog(@"%@:%@",NSLocalizedString(@"Failed to save photo", @""),error.localizedDescription);
                    if (completion) {
                        completion(error);
                    }
                }
            });
        }];
    }
    else
    {
        [self.assetLibrary writeImageToSavedPhotosAlbum:image.CGImage orientation:[self orientationFromImage:image] completionBlock:^(NSURL *assetURL, NSError *error)
        {
            if (error)
            {
                NSLog(@"%@:%@",NSLocalizedString(@"Failed to save picture", @""),error.localizedDescription);
                if (completion) {
                    completion(error);
                }
            }
            else
            {
                // 多给系统0.5秒的时间，让系统去更新相册数据
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(nil);
                    }
                });
            }
        }];
    }
}

#pragma mark - Save video

- (void)saveVideoWithUrl:(NSURL *)url completion:(void (^)(NSError *error))completion {
    [self saveVideoWithUrl:url location:nil completion:completion];
}

- (void)saveVideoWithUrl:(NSURL *)url location:(CLLocation *)location completion:(void (^)(NSError *error))completion {
    if (iOS8Later) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            if (iOS9Later)
            {
                PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                options.shouldMoveFile = YES;
                PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                [request addResourceWithType:PHAssetResourceTypeVideo fileURL:url options:options];
                if (location) {
                    request.location = location;
                }
                request.creationDate = [NSDate date];
            }
            else
            {
                PHAssetChangeRequest *request = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
                if (location) {
                    request.location = location;
                }
                request.creationDate = [NSDate date];
            }
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success && completion)
                {
                    completion(nil);
                }
                else if (error)
                {
                    NSLog(@"%@:%@",NSLocalizedString(@"Failed to save video", @""),error.localizedDescription);
                    if (completion) {
                        completion(error);
                    }
                }
            });
        }];
    }
    else
    {
        [self.assetLibrary writeVideoAtPathToSavedPhotosAlbum:url completionBlock:^(NSURL *assetURL, NSError *error) {
            if (error) {
                NSLog(@"%@:%@",NSLocalizedString(@"Failed to save video", @""),error.localizedDescription);
                if (completion) {
                    completion(error);
                }
            } else {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(nil);
                    }
                });
            }
        }];
    }
}

#pragma mark - Get Video

/// Get Video / 获取视频
- (void)getVideoWithAsset:(id)asset completion:(void (^)(AVPlayerItem *, NSDictionary *))completion {
    [self getVideoWithAsset:asset progressHandler:nil completion:completion];
}

- (void)getVideoWithAsset:(id)asset progressHandler:(void (^)(double progress, NSError *error, BOOL *stop, NSDictionary *info))progressHandler completion:(void (^)(AVPlayerItem *, NSDictionary *))completion
{
    if ([asset isKindOfClass:[PHAsset class]])
    {
        PHVideoRequestOptions *option = [[PHVideoRequestOptions alloc] init];
        option.networkAccessAllowed = YES;
        option.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (progressHandler) {
                    progressHandler(progress, error, stop, info);
                }
            });
        };
        
        [[PHImageManager defaultManager] requestPlayerItemForVideo:asset options:option resultHandler:^(AVPlayerItem *playerItem, NSDictionary *info) {
            if (completion) completion(playerItem,info);
        }];
    }
    else if ([asset isKindOfClass:[ALAsset class]]) 
    {
        ALAsset *alAsset = (ALAsset *)asset;
        ALAssetRepresentation *defaultRepresentation = [alAsset defaultRepresentation];
        NSString *uti = [defaultRepresentation UTI];
        NSURL *videoURL = [[asset valueForProperty:ALAssetPropertyURLs] valueForKey:uti];
        AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithURL:videoURL];
        if (completion && playerItem) completion(playerItem,nil);
    }
}

#pragma mark - Export video

/// Export Video / 导出视频
- (void)getVideoOutputPathWithAsset:(id)asset success:(void (^)(NSString *outputPath))success failure:(void (^)(NSString *errorMessage, NSError *error))failure {
    [self getVideoOutputPathWithAsset:asset presetName:AVAssetExportPreset640x480 success:success failure:failure];
}

- (void)getVideoOutputPathWithAsset:(id)asset presetName:(NSString *)presetName success:(void (^)(NSString *outputPath))success failure:(void (^)(NSString *errorMessage, NSError *error))failure
{
    if ([asset isKindOfClass:[PHAsset class]])
    {
        PHVideoRequestOptions* options = [[PHVideoRequestOptions alloc] init];
        options.version = PHVideoRequestOptionsVersionOriginal;
//        options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
        options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
        options.networkAccessAllowed = YES;
        
        [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset* avasset, AVAudioMix* audioMix, NSDictionary* info)
        {
            AVURLAsset *videoAsset = (AVURLAsset*)avasset;

            
            //NSLog(@"phasset url: %@ ",videoAsset.URL);
            
            [self startExportVideoWithVideoAsset:videoAsset presetName:presetName success:success failure:failure];
        }];
    }
    else if ([asset isKindOfClass:[ALAsset class]])
    {
        NSURL *videoURL =[asset valueForProperty:ALAssetPropertyAssetURL]; // ALAssetPropertyURLs
        
        NSLog(@"asset url: %@ ",videoURL);
        
        AVURLAsset *videoAsset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
        [self startExportVideoWithVideoAsset:videoAsset presetName:presetName success:success failure:failure];
    }
}

/// Deprecated, Use -getVideoOutputPathWithAsset:failure:success:
- (void)getVideoOutputPathWithAsset:(id)asset completion:(void (^)(NSString *outputPath))completion {
    [self getVideoOutputPathWithAsset:asset success:completion failure:nil];
}

- (void)startExportVideoWithVideoAsset:(AVURLAsset *)videoAsset presetName:(NSString *)presetName success:(void (^)(NSString *outputPath))success failure:(void (^)(NSString *errorMessage, NSError *error))failure
{
    // Find compatible presets by video asset.
    NSArray *presets = [AVAssetExportSession exportPresetsCompatibleWithAsset:videoAsset];
    
    // Begin to compress video
    // Now we just compress to low resolution if it supports
    // If you need to upload to the server, but server does't support to upload by streaming,
    // You can compress the resolution to lower. Or you can support more higher resolution.
    if ([presets containsObject:presetName])
    {
        AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:videoAsset presetName:presetName];
        
        NSDateFormatter *formater = [[NSDateFormatter alloc] init];
        [formater setDateFormat:@"yyyy-MM-dd-HH:mm:ss-SSS"];
       
//        NSString *outputPath = [NSHomeDirectory() stringByAppendingFormat:@"/tmp/output-%@.mp4", [formater stringFromDate:[NSDate date]]];
         NSString *outputPath = [NSHomeDirectory() stringByAppendingFormat:@"/tmp/output-%@.MOV", [formater stringFromDate:[NSDate date]]];
        
        // NSLog(@"video outputPath = %@",outputPath);
        session.outputURL = [NSURL fileURLWithPath:outputPath];
        
        // Optimize for network use.
        session.shouldOptimizeForNetworkUse = true;
        
        NSArray *supportedTypeArray = session.supportedFileTypes;
        
//        if ([supportedTypeArray containsObject:AVFileTypeMPEG4])
//        {
//            session.outputFileType = AVFileTypeMPEG4;
//        }
        if([supportedTypeArray containsObject:AVFileTypeQuickTimeMovie])
        {
            session.outputFileType = AVFileTypeQuickTimeMovie;
        }
        else if (supportedTypeArray.count == 0) {
            if (failure) {
                failure(@"该视频类型暂不支持导出", nil);
            }
            NSLog(@"No supported file types %@", NSLocalizedString(@"Do not support to export this format", @""));
            return;
        } else {
            session.outputFileType = [supportedTypeArray objectAtIndex:0];
        }
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:[NSHomeDirectory() stringByAppendingFormat:@"/tmp"]]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:[NSHomeDirectory() stringByAppendingFormat:@"/tmp"] withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        AVMutableVideoComposition *videoComposition = [self fixedCompositionWithAsset:videoAsset];
        if (videoComposition.renderSize.width) {
            // 修正视频转向
            session.videoComposition = videoComposition;
        }
        
        // Begin to export video to the output path asynchronously.
        [session exportAsynchronouslyWithCompletionHandler:^(void)
        {            
            dispatch_async(dispatch_get_main_queue(), ^{
                switch (session.status)
                {
                    case AVAssetExportSessionStatusUnknown:
                    {
                        NSLog(@"AVAssetExportSessionStatusUnknown");
                    }  break;
                    
                    case AVAssetExportSessionStatusWaiting:
                    {
                        NSLog(@"AVAssetExportSessionStatusWaiting");
                    }
                        break;
                    case AVAssetExportSessionStatusExporting: {
                        NSLog(@"AVAssetExportSessionStatusExporting");
                    }  break;
                    
                    case AVAssetExportSessionStatusCompleted: {
                        NSLog(@"AVAssetExportSessionStatusCompleted");
                        if (success) {
                            success(outputPath);
                        }
                    }  break;
                    
                    case AVAssetExportSessionStatusFailed: {
                        NSLog(@"AVAssetExportSessionStatusFailed");
                        if (failure) {
                            failure(NSLocalizedString(@"Failed to export videos", @""), session.error);
                        }
                    }  break;
                    
                    case AVAssetExportSessionStatusCancelled: {
                        NSLog(@"AVAssetExportSessionStatusCancelled");
                        if (failure) {
                            failure(NSLocalizedString(@"Exporting task is cancel", @""), nil);
                        }
                    }  break;
                    default: break;
                }
            });
        }];
    }
    else
    {
        if (failure) {
            NSString *errorMessage = [NSString stringWithFormat:@"%@:%@", NSLocalizedString(@"Current device do not support this settings", @""), presetName];
            failure(errorMessage, nil);
        }
    }
}

/// Judge is a assets array contain the asset 判断一个assets数组是否包含这个asset
- (BOOL)isAssetsArray:(NSArray *)assets containAsset:(id)asset {
    if (iOS8Later) {
        return [assets containsObject:asset];
    } else {
        NSMutableArray *selectedAssetUrls = [NSMutableArray array];
        for (ALAsset *asset_item in assets) {
            [selectedAssetUrls addObject:[asset_item valueForProperty:ALAssetPropertyURLs]];
        }
        return [selectedAssetUrls containsObject:[asset valueForProperty:ALAssetPropertyURLs]];
    }
}

- (BOOL)isCameraRollAlbum:(id)metadata
{
    if ([metadata isKindOfClass:[PHAssetCollection class]])
    {
        NSString *versionStr = [[UIDevice currentDevice].systemVersion stringByReplacingOccurrencesOfString:@"." withString:@""];
        if (versionStr.length <= 1) {
            versionStr = [versionStr stringByAppendingString:@"00"];
        } else if (versionStr.length <= 2) {
            versionStr = [versionStr stringByAppendingString:@"0"];
        }
    
        CGFloat version = versionStr.floatValue;
        // 目前已知8.0.0 ~ 8.0.2系统，拍照后的图片会保存在最近添加中
        if (version >= 800 && version <= 802) {
            return ((PHAssetCollection *)metadata).assetCollectionSubtype == PHAssetCollectionSubtypeSmartAlbumRecentlyAdded;
        }
        else {
            return ((PHAssetCollection *)metadata).assetCollectionSubtype == PHAssetCollectionSubtypeSmartAlbumUserLibrary;
        }
    }
    
    if ([metadata isKindOfClass:[ALAssetsGroup class]]) {
        ALAssetsGroup *group = metadata;
        return ([[group valueForProperty:ALAssetsGroupPropertyType] intValue] == ALAssetsGroupSavedPhotos);
    }
    
    return NO;
}

- (NSString *)getAssetIdentifier:(id)asset
{
    if (iOS8Later) {
        PHAsset *phAsset = (PHAsset *)asset;
        return phAsset.localIdentifier;
    }
    else
    {
        ALAsset *alAsset = (ALAsset *)asset;
        NSURL *assetUrl = [alAsset valueForProperty:ALAssetPropertyAssetURL];
        return assetUrl.absoluteString;
    }
}

/// 检查照片大小是否满足最小要求
- (BOOL)isPhotoSelectableWithAsset:(id)asset
{
    CGSize photoSize = [self photoSizeWithAsset:asset];
    if (self.minPhotoWidthSelectable > photoSize.width || self.minPhotoHeightSelectable > photoSize.height)
    {
        return NO;
    }
    return YES;
}

- (CGSize)photoSizeWithAsset:(id)asset {
    if (iOS8Later) {
        PHAsset *phAsset = (PHAsset *)asset;
        return CGSizeMake(phAsset.pixelWidth, phAsset.pixelHeight);
    } else {
        ALAsset *alAsset = (ALAsset *)asset;
        return alAsset.defaultRepresentation.dimensions;
    }
}

#pragma mark - Private Method

- (TZAlbumModel *)modelWithResult:(id)result name:(NSString *)name isCameraRoll:(BOOL)isCameraRoll needFetchAssets:(BOOL)needFetchAssets
{
    TZAlbumModel *model = [[TZAlbumModel alloc] init];
    [model setResult:result needFetchAssets:needFetchAssets];
    model.name = name;
    model.isCameraRoll = isCameraRoll;
    
    
    if ([result isKindOfClass:[PHFetchResult class]])
    {
        PHFetchResult *fetchResult = (PHFetchResult *)result;
        model.count = fetchResult.count;
    }
    else if ([result isKindOfClass:[ALAssetsGroup class]])
    {
        ALAssetsGroup *group = (ALAssetsGroup *)result;
        model.count = [group numberOfAssets];
    }
    
    return model;
}

/// 缩放图片至新尺寸
- (UIImage *)scaleImage:(UIImage *)image toSize:(CGSize)size {
    if (image.size.width > size.width) {
        UIGraphicsBeginImageContext(size);
        [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return newImage;
        
        /* 好像不怎么管用：https://mp.weixin.qq.com/s/CiqMlEIp1Ir2EJSDGgMooQ
        CGFloat maxPixelSize = MAX(size.width, size.height);
        CGImageSourceRef sourceRef = CGImageSourceCreateWithData((__bridge CFDataRef)UIImageJPEGRepresentation(image, 0.9), nil);
        NSDictionary *options = @{(__bridge id)kCGImageSourceCreateThumbnailFromImageAlways:(__bridge id)kCFBooleanTrue,
                                  (__bridge id)kCGImageSourceThumbnailMaxPixelSize:[NSNumber numberWithFloat:maxPixelSize]
                                  };
        CGImageRef imageRef = CGImageSourceCreateImageAtIndex(sourceRef, 0, (__bridge CFDictionaryRef)options);
        UIImage *newImage = [UIImage imageWithCGImage:imageRef scale:2 orientation:image.imageOrientation];
        CGImageRelease(imageRef);
        CFRelease(sourceRef);
        return newImage;
         */
    } else {
        return image;
    }
}

- (ALAssetOrientation)orientationFromImage:(UIImage *)image {
    NSInteger orientation = image.imageOrientation;
    return orientation;
}

/// 获取优化后的视频转向信息
- (AVMutableVideoComposition *)fixedCompositionWithAsset:(AVAsset *)videoAsset {
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    // 视频转向
    int degrees = [self degressFromVideoFileWithAsset:videoAsset];
    if (degrees != 0) {
        CGAffineTransform translateToCenter;
        CGAffineTransform mixedTransform;
        videoComposition.frameDuration = CMTimeMake(1, 30);
        
        NSArray *tracks = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
        AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
        
        AVMutableVideoCompositionInstruction *roateInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        roateInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, [videoAsset duration]);
        AVMutableVideoCompositionLayerInstruction *roateLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        
        if (degrees == 90) {
            // 顺时针旋转90°
            translateToCenter = CGAffineTransformMakeTranslation(videoTrack.naturalSize.height, 0.0);
            mixedTransform = CGAffineTransformRotate(translateToCenter,M_PI_2);
            videoComposition.renderSize = CGSizeMake(videoTrack.naturalSize.height,videoTrack.naturalSize.width);
            [roateLayerInstruction setTransform:mixedTransform atTime:kCMTimeZero];
        } else if(degrees == 180){
            // 顺时针旋转180°
            translateToCenter = CGAffineTransformMakeTranslation(videoTrack.naturalSize.width, videoTrack.naturalSize.height);
            mixedTransform = CGAffineTransformRotate(translateToCenter,M_PI);
            videoComposition.renderSize = CGSizeMake(videoTrack.naturalSize.width,videoTrack.naturalSize.height);
            [roateLayerInstruction setTransform:mixedTransform atTime:kCMTimeZero];
        } else if(degrees == 270){
            // 顺时针旋转270°
            translateToCenter = CGAffineTransformMakeTranslation(0.0, videoTrack.naturalSize.width);
            mixedTransform = CGAffineTransformRotate(translateToCenter,M_PI_2*3.0);
            videoComposition.renderSize = CGSizeMake(videoTrack.naturalSize.height,videoTrack.naturalSize.width);
            [roateLayerInstruction setTransform:mixedTransform atTime:kCMTimeZero];
        }
        
        roateInstruction.layerInstructions = @[roateLayerInstruction];
        // 加入视频方向信息
        videoComposition.instructions = @[roateInstruction];
    }
    return videoComposition;
}

/// 获取视频角度
- (int)degressFromVideoFileWithAsset:(AVAsset *)asset {
    int degress = 0;
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if([tracks count] > 0) {
        AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
        CGAffineTransform t = videoTrack.preferredTransform;
        if(t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0){
            // Portrait
            degress = 90;
        } else if(t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0){
            // PortraitUpsideDown
            degress = 270;
        } else if(t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0){
            // LandscapeRight
            degress = 0;
        } else if(t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0){
            // LandscapeLeft
            degress = 180;
        }
    }
    return degress;
}

/// 修正图片转向
- (UIImage *)fixOrientation:(UIImage *)aImage {
    if (!self.shouldFixOrientation) return aImage;
    
    // No-op if the orientation is already correct
    if (aImage.imageOrientation == UIImageOrientationUp)
        return aImage;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, aImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,
                                             CGImageGetBitsPerComponent(aImage.CGImage), 0,
                                             CGImageGetColorSpace(aImage.CGImage),
                                             CGImageGetBitmapInfo(aImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (aImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.width,aImage.size.height), aImage.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

#pragma clang diagnostic pop

@end


//@implementation TZSortDescriptor
//
//- (id)reversedSortDescriptor {
//    return [NSNumber numberWithBool:![TZImageManager manager].sortAscendingByModificationDate];
//}
//
//@end
