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

// LoveBridge.h
// Cầu nối Swift ↔ lõi LÖVE (liblove). Phần cài đặt ở LoveBridge.mm.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Nhận từng đoạn log (stdout + stderr) của game. Có thể được gọi từ thread nền.
typedef void (^CatnipLogHandler)(NSString *text);

@interface CatnipLove : NSObject

/// Nơi nhận log khi đang bắt log (xem startLogCapture).
@property (class, nonatomic, copy, nullable) CatnipLogHandler logHandler;

/// Bắt đầu chuyển stdout/stderr (print(), lỗi Lua...) vào logHandler. Gọi trước runGameAtPath.
+ (void)startLogCapture;

/// Dừng bắt log, trả stdout/stderr về như cũ và chuyển nốt phần còn lại.
+ (void)stopLogCapture;

/// Yêu cầu game thoát (gửi sự kiện quit tới LÖVE). Gọi được từ main thread khi game đang chạy.
+ (void)requestQuit;

/// Chuỗi phiên bản của lõi LÖVE được nhúng, ví dụ "12.0".
+ (NSString *)versionString;

/// Chạy một game LÖVE từ thư mục dự án (thư mục chứa main.lua).
/// Phải gọi trên main thread. Hàm chặn cho tới khi game thoát, rồi trả về mã thoát (0 = bình thường).
/// Trong lúc game chạy, LÖVE tự dựng cửa sổ và vòng lặp riêng (qua SDL).
+ (int)runGameAtPath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
