//
//  HelperMethod.m
//  PhotosShow
//
//  Created by test1 on 2019/12/13.
//  Copyright © 2019 test1. All rights reserved.
//

#import "HelperMethod.h"

@implementation HelperMethod


+ (NSDictionary *)fileTypeDictionary
{
    NSDictionary *dic = @{
                          @"mp3":@1,@"amr":@1,@"wav":@1,@"aac":@1,@"wma":@1,@"ogg":@1,@"ape":@1,@"m4a":@1,@"m4r":@1,@"MP3":@1,@"AAC":@1,@"WAV":@1,@"M4A":@1,@"M4R":@1,
                          @"mp4":@2,@"avi":@2,@"mpe":@2,@"wmv":@2,@"rmvb":@2,@"mkv":@2,@"rm":@2,@"vob":@2,@"divx":@2,@"mpg":@2,@"mpeg":@2,@"asf":@2,@"3gp":@2,@"flv":@2,@"mpv":@2,@"mov":@2,
                          @"MP4":@2,@"MOV":@2,@"MKV":@2,@"AVI":@2,
                          @"html":@3,@"htm":@3,
                          @"pdf":@4,
                          @"doc":@5,@"docx":@5,
                          @"xls":@6,@"xlsx":@6,@"numbers":@6,
                          @"ppt":@7,@"pptx":@7,
                          @"png":@8,@"jpg":@8,@"jpeg":@8,@"jif":@8,@"bmp":@8,@"tiff":@8,@"tif":@8,@"svg":@8,@"JPG":@8,@"JPEG":@8,@"PNG":@8,@"BMP":@8,@"TIFF":@8,@"TIF":@8,@"HEIC":@8,@"heic":@8,
                          @"txt":@9,@"rtf":@9,@"TXT":@9,@"RTF":@9,
                          @"zip":@10,@"ZIP":@10,
                          @"gif":@11,@"GIF":@11,
                          @"c":@12,@"cc":@12,@"cpp":@12,@"h":@12,@"m":@12,@"plist":@12
                          };
    return dic;
}

+ (NSNumber *)fileType:(NSString *)type
{
    NSDictionary *dic = [self fileTypeDictionary];
    NSNumber *x = [dic objectForKey:type];
    if (!x)
        x = @0;
    
    return x;
}


@end
