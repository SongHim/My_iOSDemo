#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>

#include <sys/select.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <dirent.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <time.h>
#include <sys/time.h>

#include "msg.h"

#if 1
//test client for xingpeng
#define WORK_DIR_STR    "/root/SyncMedia/file/"
#define ABSPATH_LEN     278
#endif

//only in this file
#define SEND_RETRYNUM       3
#define MD5_SIZE            16
#define READ_FILE_SIZE      1024

struct serverids
{
    u64 s_sessionid;
    u32 s_xid;
};

#if 0
#define PRINT(fmt, args...) printf(fmt, ## args)
#else
#define PRINT(fmt, args...)
#endif

struct serverids server;

int SockConnect(char *addr, int port)
{
    int sockfd = -1;
    int flags = 0;
    int maxfds = 0;
    int num = 0;
    struct sockaddr_in saddr;
    fd_set fds;
    struct timeval timeout = {4, 0};

    memset(&saddr, 0, sizeof(struct sockaddr_in));
    saddr.sin_family = AF_INET;
    saddr.sin_port = htons(port);
    saddr.sin_addr.s_addr = inet_addr(addr);

    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd == -1) {
        goto err;
    }

    flags = fcntl(sockfd, F_GETFL, 0);
    if (!(flags & O_NONBLOCK)) {
        fcntl(sockfd, F_SETFL, flags);
    }

    if (connect(sockfd, (struct sockaddr *)&saddr, sizeof(struct sockaddr)) != 0) {
        if (errno != EINPROGRESS) {
            PRINT("connect failed: %s\n", strerror(errno));
            goto err;
        }
    }

    maxfds = sockfd + 1;
    while (1) {
        num = 0;
        FD_ZERO(&fds);
        FD_SET(sockfd, &fds);

        switch (num = select(maxfds, NULL, &fds, NULL ,&timeout)) {
            case -1:
                goto err;
            case 0:
                goto err;
            default:
                if (FD_ISSET(sockfd, &fds)) {
                    goto set;
                }
        }
    }

set:
    timeout.tv_sec = 10;
    if (setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) < 0) {
        PRINT("set sock recv timeout failed\n");
        goto err;
    }
    if (setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout)) < 0) {
        PRINT("set sock send timeout failed\n");
        goto err;
    }

    flags = fcntl(sockfd, F_GETFL, 0);
    fcntl(sockfd, F_SETFL, flags & ~O_NONBLOCK);
    return sockfd;
err:
    close(sockfd);
    return -1;
}

int SockSend(int sockfd, void *buffer, int size)
{
    int ret = -EINVAL;
    int bufsize = size;
    int retrynum = SEND_RETRYNUM;

    while (size > 0) {
        ret = send(sockfd , buffer, size, 0);
        if (ret > 0) {
            if (ret == size) {
                return bufsize;
            }
            if (ret > size) {
                ret = -EINVAL;
                break;
            }
            buffer = (void *)(((char *)buffer) + ret);
            size -= ret;
        } else if (ret < 0) {
            if ((errno == EAGAIN) && (retrynum > 0)) {
                retrynum--;
                continue;
            }
            ret = -errno;
            break;
        }
    }

    return ret;
}

int SockRecv(int sockfd ,void *buffer, int size)
{
    int ret = -EINVAL;
    int bufsize = size;

    while (size > 0) {
        ret = recv(sockfd, buffer, size, 0);
        if (ret > 0) {
            if (ret == size) {
                return bufsize;
            }
            if (ret > size) {
                ret = -EINVAL;
                break;
            }
            buffer = (void *)(((char *)buffer) + ret);
            size -= ret;
        } else if (ret < 0) {
            ret = -errno;
            break;
        } else {
            ret = 0;
            break;
        }
    }

    return ret;
}

int SendMsg(int sockfd, void *buf, int size, int msgtype)
{
    int ret = 0;
    struct ls_msg *ls_req = NULL;

    ls_req = (struct ls_msg *)malloc(sizeof(struct ls_msg));
    if (ls_req == NULL) {
        ret = -ENOMEM;
        goto err;
    }

    memset(ls_req, 0, sizeof(struct ls_msg));

    if (msgtype == REGISTER) {
        ls_req->hdr.sessionid = 0;
        server.s_xid = time(NULL);
    } else {
        ls_req->hdr.sessionid = server.s_sessionid;
        server.s_xid++;
    }

    ls_req->hdr.magic = LS_NET_MAGIC;
    ls_req->hdr.type = msgtype;
    ls_req->hdr.datalen = size;
    ls_req->hdr.xid = server.s_xid;

    if (size > 0 && size <= LS_PACKAGE_MAX) {
        memcpy(ls_req->u.data, buf, size);
    } else if (size > LS_PACKAGE_MAX){
        ret = -EINVAL;
        goto err;
    }

    ret = SockSend(sockfd, ls_req, (sizeof(struct ls_msghdr) + size));
    if (ret < 0) {
        goto err;
    }

    free(ls_req);
    return 0;
err:
    if (ls_req != NULL) {
        free(ls_req);
    }
    return ret;
}

int RecvMsg(int sockfd, void *buf, int size)
{
    int ret = 0;
    struct ls_msg *ls_res = NULL;

    ls_res = (struct ls_msg *)malloc(sizeof(struct ls_msg));
    if (ls_res == NULL) {
        ret = -ENOMEM;
        goto err;
    }
    memset(ls_res, 0, sizeof(struct ls_msg));

    ret = SockRecv(sockfd, &(ls_res->hdr), sizeof(struct ls_msghdr));
    if (ret <= 0) {
        goto err;
    }

    if (ls_res->hdr.datalen > 0) {
        ret = SockRecv(sockfd, ls_res->u.data, ls_res->hdr.datalen);
        if (ret <= 0) {
            goto err;
        }

        if (ls_res->hdr.datalen <= (unsigned int)size) {
            memcpy(buf, ls_res->u.data, ls_res->hdr.datalen);
        } else {
            ret = -EINVAL;
            goto err;
        }
    }

    if (ls_res->hdr.type == REGISTER) {
        server.s_sessionid = ls_res->hdr.sessionid;
    } else if (ls_res->hdr.type == UNREGISTER) {
        server.s_sessionid = 0;
    }
	
    ret = ls_res->hdr.ret;
	free(ls_res);
	return ret;
err:
    if (ls_res != NULL) {
        free(ls_res);
    }
    return ret;
}

int Connected(char *addr, int port)
{
    int ret = 0;
    int sockfd = -1;
    char recvbuf[LS_PACKAGE_MAX];

    memset(recvbuf, 0, LS_PACKAGE_MAX);

    if ((sockfd = SockConnect(addr, port)) < 0) {
        ret = sockfd;
        goto err;
    }


    if ((ret = SendMsg(sockfd, NULL, 0, REGISTER)) < 0) {
        goto err;
    }

    if ((ret = RecvMsg(sockfd, recvbuf, LS_PACKAGE_MAX)) < 0) {
        goto err;
    }

    if (ret != MEDIA_OK) {
        PRINT("register failed\n");
        ret = -EINVAL;
        goto err;
    }

    return sockfd;

err:
    if (sockfd > 0) {
        close(sockfd);
    }
    return ret;
}

int disConnected(int sockfd)
{
    int ret = 0;
    char buf[LS_PACKAGE_MAX];

    if ((ret = SendMsg(sockfd, NULL, 0, UNREGISTER)) < 0) {
        goto err;
    }

    if ((ret = RecvMsg(sockfd, buf, LS_PACKAGE_MAX)) < 0) {
        goto err;
    }

    close(sockfd);
err:
    return ret;
}

int Read(int fd, char *buffer, int size, u64 offset)
{
    int n = 0;
    int nread = 0;

    while (size > 0) {
        nread = pread(fd, buffer + n, size, offset + n);
        if (nread < 0) {
            return -errno;
        } else if (nread == 0) {
            return n;
        }
        n += nread;
        size -= nread;
    }

    return n;
}

char *mac_alloc(size_t size)
{
	char * ret =NULL;
	
	ret = (char *)malloc(size);
	if (ret)
	{
		memset(ret, 0, size);
	}
	return ret;
}

void mac_free(void * pBuf)
{
	free(pBuf);
}

/*int main(int argc, char *argv[])
{
    int ret = 0;
    int fd = -1;
    int readnum = 0;
    u64 offset = 0;
    int sockfd = -1;
    DIR *dir_p = NULL;
    char abspath[ABSPATH_LEN];
    struct dirent *entry = NULL;
    struct stat st;
    char buffer[1024];

    struct mediadata* req = NULL;
    char md5[MD5_STR_LEN + 1];

    req = (struct mediadata *)malloc(LS_PACKAGE_MAX);
    if (req == NULL) {
        goto exit;
    }
    memset(req, 0, LS_PACKAGE_MAX);

    PRINT("connect server request\n");
    sockfd = Connected((char *)ADDR_IP_DEFAULT, ADDR_PORT_DEFAULT);
    if (sockfd < 0) {
        PRINT("connect failed\n");
        goto exit;
    }

    PRINT("=================connect success================\n");
    dir_p = opendir(WORK_DIR_STR);
    if (dir_p == NULL) {
        goto exit;
    }

    while ((entry = readdir(dir_p)) != NULL) {
        if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) {
            continue;
        }

        memset(abspath, 0, ABSPATH_LEN);
        sprintf(abspath, "%s%s", WORK_DIR_STR, entry->d_name);
        if (stat(abspath, &st) != 0) {
            break;
        }

        req->size_length = st.st_size;
        req->time_offset = st.st_mtime;
        strcpy(req->name, entry->d_name);

        PRINT("send file: %s meta\n", entry->d_name);
        if (SendMsg(sockfd, req, sizeof(struct mediadata), MEDIA_FILE_META) < 0) {
            PRINT("send file:%s meta failed\n", entry->d_name);
            goto exit;
        }

        PRINT("recv file: %s meta\n", entry->d_name);
        memset(req, 0, LS_PACKAGE_MAX);
        if ((ret = RecvMsg(sockfd, req, LS_PACKAGE_MAX)) < 0) {
            PRINT("recv file:%s meta failed\n", entry->d_name);
            goto exit;
        }

        if (ret != MEDIA_OK) {
            PRINT("recv errmsg:%s\n", (char *)req);
            continue;
        }

        sleep(2);

        PRINT("send file: %s data\n", entry->d_name);
        fd = open(abspath, O_RDONLY);
        if (fd < 0) {
            printf("open file failed: %s\n", abspath);
            continue;
        }

        offset = 0;
        memset(req, 0, LS_PACKAGE_MAX);
        memset(md5, 0, MD5_STR_LEN + 1);
        ComputeFileMd5(abspath, md5);
        strncpy(req->md5key, md5, MD5_STR_LEN + 1);
        strcpy(req->name, entry->d_name);

        while (offset < st.st_size) {
            readnum = Read(fd, req->data, LS_PACKAGE_MAX - sizeof(struct mediadata), offset);
            if (readnum < 0) {
                printf("read file failed: %s\n", entry->d_name);
                break;
            }
            else if (readnum == 0) {
                printf("file: %s read end\n", entry->d_name);
                break;
            } else {
                req->size_length = readnum;
                req->time_offset = offset;

                PRINT("send file:%s data, offset:%lld, size:%d\n", entry->d_name, offset, readnum);
                if (SendMsg(sockfd, req, readnum + sizeof(struct mediadata), MEDIA_FILE_DATA) < 0) {
                    printf("send file:%s failed\n", entry->d_name);
                    break;
                }
                offset += readnum;

                memset(buffer, 0, 1024);
                ret = RecvMsg(sockfd, buffer, 1024);
                PRINT("recv msg: %s\n", buffer);
                if (ret == MEDIA_ERR) {
                    break;
                }
                sleep(2);
            }
        }

        close(fd);
    }

    sleep(1);
exit:
    if (req != NULL) {
        free(req);
    }
    if (sockfd > 0) {
        disConnected(sockfd);
    }
    if (dir_p != NULL) {
        closedir(dir_p);
    }
    return 0;
}*/

