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

/// Khởi động kernel (một lần). `documents` được gắn vào /documents trong Linux.
/// `repositories` (nếu có) ghi vào /etc/apk/repositories. Gọi trên main thread.
/// Trả về 0 nếu thành công, ngược lại là errno âm của iSH.
+ (int)bootWithRoot:(NSString *)root
          documents:(nullable NSString *)documents
       repositories:(nullable NSString *)repositories;

@property (class, readonly) BOOL isBooted;

/// Mở một phiên shell mới (/bin/login -f root trên pty). Gọi trên main thread.
/// `output` được gọi trên main thread với dữ liệu terminal; `exit` khi phiên kết thúc.
/// Trả về 0 nếu thành công, ngược lại là errno âm.
+ (int)startSessionWithOutput:(IshOutputBlock)output exit:(IshExitBlock)exit;

+ (void)sendInput:(NSData *)data;
+ (void)resizeToColumns:(int)columns rows:(int)rows;

@end

NS_ASSUME_NONNULL_END
