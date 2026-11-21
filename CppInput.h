//
//  Catnip Engine: game maker for IOS
//
//  Licensed under GPL-3.0-or-later. See LICENSE.
//

// Đẩy sự kiện bàn phím/chuột ảo vào SDL3 cho chương trình C++ có GUI (nút điều khiển + con trỏ kiểu PojavLauncher).
// Chỉ build khi có LÖVE (SDL3 đi kèm). Chưa build/kiểm chứng.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CatnipInput : NSObject
/// Có cửa sổ SDL để gửi sự kiện vào không.
+ (BOOL)hasWindow;
/// Phím theo tên ("W", "Space", "Shift", "F5", "Up"...).
+ (void)sendKeyNamed:(NSString *)name down:(BOOL)down NS_SWIFT_NAME(sendKey(named:down:));
/// Đặt con trỏ chuột theo toạ độ chuẩn hoá 0...1 của cửa sổ.
+ (void)moveMouseToX:(double)nx y:(double)ny NS_SWIFT_NAME(moveMouse(toX:y:));
/// button: 1 trái, 2 giữa, 3 phải.
+ (void)mouseButton:(int)button down:(BOOL)down NS_SWIFT_NAME(mouseButton(_:down:));
+ (void)scrollX:(double)x y:(double)y NS_SWIFT_NAME(scroll(x:y:));
/// Buộc mở bàn phím ảo của iOS cho cửa sổ SDL.
+ (void)startTextInput;
+ (void)stopTextInput;
/// Gửi SDL_EVENT_QUIT (đóng chương trình đàng hoàng).
+ (void)requestQuit;
@end

NS_ASSUME_NONNULL_END
