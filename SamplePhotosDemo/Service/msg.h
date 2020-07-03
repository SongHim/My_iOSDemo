#ifndef __MSG_H__
#define __MSG_H__

#define ADDR_IP_DEFAULT     "13.15.22.10"
#define ADDR_PORT_DEFAULT   9002

//leosync define
#define LS_PACKAGE_MAX      (256<<10)   //256k
#define LS_PACKAGE_OVERHEAD (8192)      //8k
#define LS_FILEDATA_SIZE    (64<<10)    //64k
#define LS_NET_MAGIC        0x27058019
#define LS_MSG_VECNUM       1024
#if 0
struct iovec
{
    void    *iov_base;
    size_t  iov_len;
};
#endif


#define NAME_LEN_MAX        256
#define MD5_STR_LEN         32

typedef enum {
    REGISTER = 1000,
    UNREGISTER = 1001,
    MEDIA_FILE_META = 1014,
    MEDIA_FILE_DATA = 1015
}dataType;

typedef enum {
    MEDIA_OK = 0,
	MEDIA_EXIST,
    MEDIA_CHECK,
    MEDIA_ERROR
}MediaRet;

typedef unsigned long long  u64;
typedef unsigned int        u32;
typedef signed int          s32;
typedef unsigned char       u8;

struct mediadata
{
    int     size_length;
    u64      time_offset;
    char    name[NAME_LEN_MAX];
    char    md5key[MD5_STR_LEN + 1];
    char    data[0];
};

struct ls_msghdr
{
    u32 magic;
    u32 xid;
    u64 cookie;
    u64 sessionid;
    u32 checksum;
    u32 flags;
    u32 datalen;
    u32 type;
    u32 version;
    s32 ret;
};

struct ls_msg
{
    struct ls_msghdr hdr;
    union
    {
        char data[LS_PACKAGE_MAX];
        struct iovec vecs[LS_MSG_VECNUM];
    }u;

    char buffer[LS_PACKAGE_OVERHEAD];
    struct iovec *iovs;
    int iovlen;
    int buflen;
};


#endif
