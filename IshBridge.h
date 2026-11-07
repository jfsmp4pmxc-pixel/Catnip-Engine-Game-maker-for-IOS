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


// Cầu nối giữa Catnip (Swift) và lõi iSH (emulator x86 + kernel Linux ở user-mode, GPL-3.0).
// Chỉ được biên dịch khi build có nhúng iSH (workflow với_ish). Lõi iSH là tiến trình-toàn-cục,
// nên chỉ boot một lần cho mỗi lần chạy app; mỗi cửa sổ shell là một "phiên" (pty) mới.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^IshOutputBlock)(NSData *data);
typedef void (^IshExitBlock)(int code);
typedef void (^IshProgressBlock)(double fraction, NSString *message);

@interface IshBridge : NSObject

/// Thư mục rootfs đã được cài (có `data/` và `meta.db`) hay chưa.
+ (BOOL)isRootInstalledAtPath:(NSString *)root;

/// Giải nén rootfs .tar.gz thành "fakefs" ở `root` (chậm: nên gọi ở luồng nền).
/// Trả về nil nếu thành công, ngược lại là thông báo lỗi.
+ (nullable NSString *)installRootFromArchive:(NSString *)archive
                                       toPath:(NSString *)root
                                     progress:(nullable IshProgressBlock)progress;

/// Khai báo các dự án cần gắn vào Linux: khoá là tên thư mục trong Linux (dưới /root),
/// giá trị là đường dẫn thật trên iOS. Được áp dụng khi boot và mỗi lần mở phiên mới
/// (gắn thêm dự án mới, gỡ dự án đã mất hoặc đổi chỗ).
+ (void)setProjectMounts:(NSDictionary<NSString *, NSString *> *)mounts NS_SWIFT_NAME(setProjectMounts(_:));

/// Khởi động kernel (một lần). `repositories` (nếu có) ghi vào /etc/apk/repositories.
/// Gọi trên main thread. Trả về 0 nếu thành công, ngược lại là errno âm của iSH.
+ (int)bootWithRoot:(NSString *)root
       repositories:(nullable NSString *)repositories NS_SWIFT_NAME(boot(withRoot:repositories:));

@property (class, readonly) BOOL isBooted;

/// Mở một phiên mới trên pty. Gọi trên main thread.
/// - `directory`: thư mục (đường dẫn trong Linux) mà shell tự `cd` vào; nil = thư mục nhà (/root).
/// - `command`: nil = shell đăng nhập (/bin/login -f root); ngược lại chạy lệnh đó (argv[0] là chương trình).
/// `output` được gọi trên main thread với dữ liệu terminal; `exit` khi phiên kết thúc
/// (mã 0 = thành công).
/// Trả về 0 nếu thành công, ngược lại là errno âm.
+ (int)startSessionInDirectory:(nullable NSString *)directory
                       command:(nullable NSArray<NSString *> *)command
                        output:(IshOutputBlock)output
                          exit:(IshExitBlock)exit NS_SWIFT_NAME(startSession(directory:command:output:exit:));

/// Buộc phiên hiện tại kết thúc (SIGKILL). `exit` của phiên đó sẽ được gọi sau đó.
+ (void)killSession NS_SWIFT_NAME(killSession());

+ (void)sendInput:(NSData *)data;
+ (void)resizeToColumns:(int)columns rows:(int)rows;

@end

NS_ASSUME_NONNULL_END
