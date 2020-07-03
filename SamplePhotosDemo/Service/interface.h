//
//  interface.h
//  PhotoUpload
//
//  Created by niewei on 2019/11/26.
//  Copyright © 2019年 songhm. All rights reserved.
//

#ifndef interface_h
#define interface_h

#include "msg.h"

int Connected(char* addr, int port);
int disConnected(int sockfd);
int SendMsg(int sockfd, void* buf, int size, int msgtype);
int RecvMsg(int sockfd, void* buf, int size);
int Read(int fd, char* buffer, int size, u64 offset);
char * mac_alloc(size_t size);
void mac_free(void * pBuf);
#endif
