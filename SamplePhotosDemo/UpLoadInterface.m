//
//  UpLoadInterface.m
//  Uploadphoto
//
//  Created by niewei on 2019/12/10.
//  Copyright © 2019年 songhm. All rights reserved.
//

#import "UpLoadInterface.h"
#import <sys/stat.h>
#import "CommanHeader.h"
#include "interface.h"
#include "md5.h"

@interface UpLoadInterface()

@end

@implementation UpLoadInterface

- (int)sendSingleFile:(NSDictionary *)assetAttr
{
	
	int ret = 0;
	struct mediadata *fileAttr = (struct mediadata*)malloc(sizeof(struct mediadata));
	NSFileManager *fileManage = [NSFileManager defaultManager];

	NSString *Sockfd = (NSString*)[[NSUserDefaults standardUserDefaults] objectForKey:SOCKFD];
	int sockfd = [Sockfd intValue];
	NSString *imgName = [assetAttr objectForKey:@"imgName"];
	NSString *path = [assetAttr objectForKey:@"path"];
	NSString *imgMtime = [assetAttr objectForKey:@"imgMtime"];
	NSString *imgsize = [assetAttr objectForKey:@"size"];
	NSString *imgmd5 = [assetAttr objectForKey:@"md5"];
	u64 imgmtime = [imgMtime longLongValue];
	int size = [imgsize intValue];
	
	if (sockfd < 0)
	{
		goto EXIT;
	}
	memset(fileAttr, 0, sizeof(struct mediadata));
	strcpy(fileAttr->name, (char *)[imgName UTF8String]);
	fileAttr->time_offset = imgmtime;
	fileAttr->size_length = size;
	NSLog(@"name : %@ ; Time：%lld ; SIZE：%d； md5:%@", imgName, imgmtime, size, imgmd5);
	
	/*BOOL md5isempty = [self isBlankString:imgmd5];
	if (md5isempty)
	{
		int ret = compute_file_md5((char*)path.UTF8String, md5);
		if (ret != 0)
		{
			goto EXIT;
		}
		imgmd5 = [NSString stringWithFormat:@"%s", md5];
		NSDictionary *assetAttr = [NSDictionary dictionaryWithObjectsAndKeys:
								   imgName, @"imgName",
								   imgmd5, @"md5",
								   nil];
		[md5Array addObject:assetAttr];
		NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
		[userDefaults setObject:md5Array forKey:MD5ARRAY];
	}*/
	
	BOOL md5isempty = [self isBlankString:imgmd5];
	if (md5isempty)
	{
		imgmd5 = @"";
	}
	memcpy(fileAttr->md5key, imgmd5.UTF8String, FILE_MD5_LEN);
	ret = SendMsg(sockfd, fileAttr, sizeof(struct mediadata), MEDIA_FILE_META);
	if (ret < 0)
	{
		NSLog(@"ret = %d", ret);
		goto EXIT;
	}
	
	memset(fileAttr, 0, sizeof(struct mediadata));
	ret = RecvMsg(sockfd, fileAttr, sizeof(struct mediadata));
	if (ret < 0)
	{
		goto EXIT;
	}
	if (ret == MEDIA_ERROR) {
		NSLog(@"message:%s", (char *)fileAttr);
		goto EXIT;

	}else if (ret == MEDIA_EXIST){
		mac_free(fileAttr);
		[fileManage removeItemAtPath:path error:nil];
		return 0;
	}else if (ret == MEDIA_OK){
		
		//NSString *imgMd5 = [NSString stringWithFormat:@"%s", fileAttr->md5key];
		ret = [self uploadAssetData:Sockfd andpath:path andname:imgName];
		if (ret)
		{
			goto EXIT;
		}
		mac_free(fileAttr);
		return 0;
	}
	
EXIT:
	if (fileAttr)
	{
		mac_free(fileAttr);
	}
	[fileManage removeItemAtPath:path error:nil];
	return -1;
}

- (int)uploadAssetData:(NSString *)sockfd andpath:(NSString *)path andname:(NSString *)name
{
	int ret = 0, fd = 0, sock = -1;
	uint64_t offset = 0;
	char buffer[NAME_LEN_MAX] = "";
	//NSString *md5string;
	//NSDictionary *assetAttr;
	struct mediadata *singlefileAttr = (struct mediadata*)malloc(LS_PACKAGE_MAX);
	NSFileManager *fileManage = [NSFileManager defaultManager];
	//NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	//NSMutableArray *md5Array = [[NSMutableArray alloc]init];
	bzero(singlefileAttr, LS_PACKAGE_MAX);
	
	/*BOOL isempty = [self isBlankString:md5];
	if (isempty)
	{
		ret = compute_file_md5((char*)[path UTF8String], imgmd5);
		if (ret != 0)
		{
			NSLog(@"MD5生成失败！");
			goto EXIT;
		}
		memcpy(singlefileAttr->md5key, imgmd5, FILE_MD5_LEN);
		md5string = [NSString stringWithFormat:@"%s", imgmd5];
		assetAttr = [NSDictionary dictionaryWithObjectsAndKeys:
					 name, @"imgName",
					 md5string, @"md5",
					 nil];
	}
	else
	{
		memcpy(singlefileAttr->md5key, md5.UTF8String, FILE_MD5_LEN);
		assetAttr = [NSDictionary dictionaryWithObjectsAndKeys:
					 name, @"imgName",
					 md5, @"md5",
					 nil];
	}

	[md5Array addObject:assetAttr];
	[userDefaults setObject:md5Array forKey:MD5ARRAY];
	
	
	memcpy(singlefileAttr->md5key, imgmd5, FILE_MD5_LEN);*/
	
	fd = open((char*)[path UTF8String], O_RDONLY);
	if (fd < 0)
	{
		NSLog(@"open path %s failed with %d", (char*)[path UTF8String], fd);
		ret = errno;
		goto EXIT;
	}
	
	struct stat statBuf;
	fstat(fd, &statBuf);
	
	strcpy(singlefileAttr->name, (char*)[name UTF8String]);
	while (offset < (uint64_t)statBuf.st_size)
	{
		memset(singlefileAttr->data, 0, LS_PACKAGE_MAX - sizeof(struct mediadata));
		uint32_t retlength = Read(fd, singlefileAttr->data, LS_PACKAGE_MAX - sizeof(struct mediadata), offset);
		if (retlength < 0)
		{
			NSLog(@"pread failed with err: %d\n", errno);
			goto EXIT;
		}
		
		singlefileAttr->time_offset = offset;
		singlefileAttr->size_length = retlength;
		sock = [sockfd intValue];
		if (sock < 0)
		{
			goto EXIT;
		}
		ret = SendMsg(sock, singlefileAttr, retlength + sizeof(struct mediadata), MEDIA_FILE_DATA);
		if (ret)
		{
			NSLog(@"writefile_from_local %@, offset: %lld, len: %d, ret: %d\n", path, offset, retlength, ret);
			goto EXIT;
		}
		
		offset += retlength;
		memset(buffer, 0, NAME_LEN_MAX);
		ret = RecvMsg(sock, buffer, NAME_LEN_MAX);
		NSLog(@"buffer= %s",buffer);
		if (ret == MEDIA_ERROR) {
			goto EXIT;
		}
	}
	
	NSLog(@"name= %s",singlefileAttr->name);
	NSLog(@"offset= %lld",singlefileAttr->time_offset);
	NSLog(@"size= %d",singlefileAttr->size_length);
	NSLog(@"----------------------------------");
	
	mac_free(singlefileAttr);
	close(fd);
	[fileManage removeItemAtPath:path error:nil];
	return 0;
	
EXIT:
	if (singlefileAttr)
	{
		mac_free(singlefileAttr);
	}

	if (fd > 0)
	{
		close(fd);
	}
	return -1;
}

- (BOOL)isBlankString:(NSString *)str {
	NSString *string = str;
	if (string == nil || string == NULL) {
		return YES;
	}
	if ([string isKindOfClass:[NSNull class]]) {
		return YES;
	}
	if ([[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) {
		return YES;
	}
	
	return NO;
}
@end
