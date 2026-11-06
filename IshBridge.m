//
//  Catnip Engine: game maker for IOS
//
//  Copyright (C) 2026 jfsmp4pmxc-pixel <ihhjnkk@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program. If not, see <https://www.gnu.org/licenses/>.
//   


#import "IshBridge.h"

#include <resolv.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <pthread.h>

#include "debug.h"
#include "kernel/calls.h"
#include "kernel/init.h"
#include "kernel/task.h"
#include "fs/devices.h"
#include "fs/path.h"
#include "fs/real.h"
#include "fs/sock.h"
#include "fs/tty.h"
#include "tools/fakefs.h"

// MARK: - Phiên (một pty)

@interface IshSession : NSObject {
@public
    struct tty *tty;
    int pid;
}
@property (copy) IshOutputBlock output;
@property (copy) IshExitBlock exitBlock;
@property NSMutableData *pending;
@property NSCondition *cond;
@property BOOL flushScheduled;
@end

static const NSUInteger kMaxPending = 1 << 16;

@implementation IshSession
- (instancetype)init {
    if (self = [super init]) {
        _pending = [NSMutableData new];
        _cond = [NSCondition new];
    }
    return self;
}

// Gọi từ luồng của tiến trình giả lập khi chương trình ghi ra terminal.
- (int)write:(const void *)buf length:(size_t)len {
    [self.cond lock];
    // Chặn bên ghi nếu giao diện chưa kịp hiển thị, để `yes` hay `cat /dev/zero` không ăn hết RAM.
    // Main thread là nơi duy nhất xả bộ đệm nên không được ngủ ở đó (vd khi echo phím gõ).
    while (!NSThread.isMainThread && self.pending.length > kMaxPending)
        [self.cond wait];
    [self.pending appendBytes:buf length:len];
    BOOL schedule = !self.flushScheduled;
    self.flushScheduled = YES;
    [self.cond unlock];
    if (schedule) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self flush]; });
    }
    return (int) len;
}

- (void)flush {
    [self.cond lock];
    NSData *data = [self.pending copy];
    [self.pending setLength:0];
    self.flushScheduled = NO;
    [self.cond broadcast];
    [self.cond unlock];
    if (data.length > 0 && self.output)
        self.output(data);
}
@end

// MARK: - Driver tty

static int catnip_tty_init(struct tty *tty) {
    tty->data = NULL; // tty_alloc dùng malloc nên trường này chưa được khởi tạo
    return 0;
}

static int catnip_tty_write(struct tty *tty, const void *buf, size_t len, bool blocking) {
    IshSession *session = (__bridge IshSession *) tty->data;
    if (session == nil)
        return (int) len; // console của init: bỏ qua
    return [session write:buf length:len];
}

static void catnip_tty_cleanup(struct tty *tty) {
    if (tty->data != NULL) {
        IshSession *session = CFBridgingRelease(tty->data);
        tty->data = NULL;
        session->tty = NULL;
    }
}

static struct tty_driver_ops catnip_tty_ops = {
    .init = catnip_tty_init,
    .write = catnip_tty_write,
    .cleanup = catnip_tty_cleanup,
};
DEFINE_TTY_DRIVER(catnip_console_driver, &catnip_tty_ops, TTY_CONSOLE_MAJOR, 64);
static struct tty_driver catnip_pty_driver = {.ops = &catnip_tty_ops};

// MARK: - Trạng thái toàn cục

static BOOL gBooted = NO;
static IshSession *gSession;

static void catnip_exit_hook(struct task *task, int code) {
    // Chỉ quan tâm init và con trực tiếp của init (các phiên shell).
    if (task->parent != NULL && task->parent->parent != NULL)
        return;
    pid_t pid = task->pid;
    dispatch_async(dispatch_get_main_queue(), ^{
        IshSession *session = gSession;
        if (session != nil && session->pid == pid) {
            gSession = nil;
            // Nội dung còn dồn lại thì hiện nốt trước khi báo thoát.
            [session flush];
            IshExitBlock block = session.exitBlock;
            if (block) block(code);
        }
    });
}

static void catnip_die_handler(const char *msg) {
    NSLog(@"iSH die: %s", msg);
    abort();
}

// MARK: - Tiện ích file trong Linux

static void write_guest_file(const char *path, const char *buf, size_t size) {
    struct fd *fd = generic_open(path, O_WRONLY_ | O_CREAT_ | O_TRUNC_, 0644);
    if (IS_ERR(fd))
        return;
    fd->ops->write(fd, buf, size);
    fd_close(fd);
}

// Ghi /etc/resolv.conf theo DNS hiện tại của iOS (giống AppDelegate của iSH).
static void configure_dns(void) {
    struct __res_state res;
    if (res_ninit(&res) != 0)
        return;
    NSMutableString *conf = [NSMutableString new];
    if (res.dnsrch[0] != NULL) {
        [conf appendString:@"search"];
        for (int i = 0; res.dnsrch[i] != NULL; i++)
            [conf appendFormat:@" %s", res.dnsrch[i]];
        [conf appendString:@"\n"];
    }
    union res_sockaddr_union servers[NI_MAXSERV];
    int found = res_getservers(&res, servers, NI_MAXSERV);
    char address[NI_MAXHOST];
    for (int i = 0; i < found; i++) {
        union res_sockaddr_union s = servers[i];
        if (s.sin.sin_len == 0)
            continue;
        getnameinfo((struct sockaddr *) &s.sin, s.sin.sin_len, address, sizeof(address), NULL, 0, NI_NUMERICHOST);
        [conf appendFormat:@"nameserver %s\n", address];
    }
    if (conf.length == 0)
        [conf appendString:@"nameserver 1.1.1.1\nnameserver 8.8.8.8\n"];
    current = pid_get_task(1);
    write_guest_file("/etc/resolv.conf", conf.UTF8String, strlen(conf.UTF8String));
}

// MARK: - IshBridge

@implementation IshBridge

+ (BOOL)isRootInstalledAtPath:(NSString *)root {
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDir = NO;
    return [fm fileExistsAtPath:[root stringByAppendingPathComponent:@"data"] isDirectory:&isDir] && isDir
        && [fm fileExistsAtPath:[root stringByAppendingPathComponent:@"meta.db"]];
}

static void import_progress(void *cookie, double progress, const char *message, bool *cancel) {
    IshProgressBlock block = (__bridge IshProgressBlock) cookie;
    if (block)
        block(progress, [NSString stringWithUTF8String:message ?: ""]);
}

+ (NSString *)installRootFromArchive:(NSString *)archive toPath:(NSString *)root progress:(IshProgressBlock)progress {
    NSFileManager *fm = NSFileManager.defaultManager;
    // Giải nén ra thư mục tạm cùng ổ đĩa rồi đổi tên, để lỡ dừng giữa chừng không để lại rootfs dở dang.
    NSString *tmp = [root.stringByDeletingLastPathComponent
                     stringByAppendingPathComponent:[NSString stringWithFormat:@".iSH-import-%@", NSUUID.UUID.UUIDString]];
    struct fakefsify_error err;
    memset(&err, 0, sizeof(err));
    IshProgressBlock cookieBlock = [progress copy];
    BOOL ok = fakefs_import(archive.fileSystemRepresentation, tmp.fileSystemRepresentation, &err,
                            (struct progress) {(__bridge void *) cookieBlock, import_progress});
    if (!ok) {
        NSString *message = [NSString stringWithFormat:@"%s (dòng %d, mã %d)",
                             err.message ? err.message : "lỗi không rõ", err.line, err.code];
        free(err.message);
        [fm removeItemAtPath:tmp error:nil];
        return message;
    }
    [fm removeItemAtPath:root error:nil];
    NSError *moveError = nil;
    if (![fm moveItemAtPath:tmp toPath:root error:&moveError]) {
        [fm removeItemAtPath:tmp error:nil];
        return moveError.localizedDescription;
    }
    return nil;
}

+ (BOOL)isBooted { return gBooted; }

+ (int)bootWithRoot:(NSString *)root documents:(NSString *)documents repositories:(NSString *)repositories {
    if (gBooted)
        return 0;

    int err = mount_root(&fakefs, [root stringByAppendingPathComponent:@"data"].fileSystemRepresentation);
    if (err < 0)
        return err;

    err = become_first_process();
    if (err < 0)
        return err;

    create_some_device_nodes();
    generic_setattrat(AT_PWD, "/", (struct attr) {.type = attr_mode, .mode = 0755}, false);

    do_mount(&procfs, "proc", "/proc", "", 0);
    do_mount(&devptsfs, "devpts", "/dev/pts", "", 0);

    // Gắn thư mục Documents của Catnip (các dự án) vào /documents để dùng được bằng công cụ Linux.
    if (documents.length > 0) {
        generic_mkdirat(AT_PWD, "/documents", 0755);
        do_mount(&realfs, documents.fileSystemRepresentation, "/documents", "", 0);
    }

    configure_dns();
    if (repositories.length > 0) {
        NSString *header = @"# Do Catnip quản lý (cùng kho với iSH). Sửa file này sẽ bị ghi đè mỗi lần mở shell.\n";
        NSString *text = [header stringByAppendingString:repositories];
        write_guest_file("/etc/apk/repositories", text.UTF8String, strlen(text.UTF8String));
    }

    exit_hook = catnip_exit_hook;
    die_handler = catnip_die_handler;
#if !TARGET_OS_SIMULATOR
    static NSString *sockTmp;
    sockTmp = [NSTemporaryDirectory() stringByAppendingString:@"ishsock"];
    sock_tmp_prefix = strdup(sockTmp.UTF8String);
#endif

    tty_drivers[TTY_CONSOLE_MAJOR] = &catnip_console_driver;
    set_console_device(TTY_CONSOLE_MAJOR, 1);
    err = create_stdio("/dev/console", TTY_CONSOLE_MAJOR, 1);
    if (err < 0)
        return err;

    // Tiến trình init của rootfs (pid 1). Các phiên shell là con của nó.
    const char argv[] = "/sbin/init\0";
    const char envp[] = "TERM=xterm-256color\0";
    err = do_execve("/sbin/init", 1, argv, envp);
    if (err < 0)
        return err;
    task_start(current);

    gBooted = YES;
    return 0;
}

+ (int)startSessionWithOutput:(IshOutputBlock)output exit:(IshExitBlock)exitBlock {
    if (!gBooted)
        return -1;
    int err = become_new_init_child();
    if (err < 0)
        return err;

    struct tty *tty = pty_open_fake(&catnip_pty_driver);
    if (IS_ERR(tty))
        return (int) PTR_ERR(tty);

    IshSession *session = [IshSession new];
    session.output = output;
    session.exitBlock = exitBlock;
    session->tty = tty;
    tty->data = (void *) CFBridgingRetain(session);

    NSString *stdio = [NSString stringWithFormat:@"/dev/pts/%d", tty->num];
    err = create_stdio(stdio.fileSystemRepresentation, TTY_PSEUDO_SLAVE_MAJOR, tty->num);
    if (err < 0)
        return err;
    tty_release(tty);

    const char argv[] = "/bin/login\0-f\0root\0";
    const char envp[] = "TERM=xterm-256color\0";
    err = do_execve("/bin/login", 3, argv, envp);
    if (err < 0)
        return err;
    session->pid = current->pid;
    gSession = session;
    task_start(current);
    return 0;
}

+ (void)sendInput:(NSData *)data {
    IshSession *session = gSession;
    if (session == nil || session->tty == NULL || data.length == 0)
        return;
    tty_input(session->tty, data.bytes, data.length, 0);
}

+ (void)resizeToColumns:(int)columns rows:(int)rows {
    IshSession *session = gSession;
    if (session == nil || session->tty == NULL || columns <= 0 || rows <= 0)
        return;
    struct tty *tty = session->tty;
    lock(&tty->lock);
    tty_set_winsize(tty, (struct winsize_) {.col = columns, .row = rows});
    unlock(&tty->lock);
}

@end
