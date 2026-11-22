// PythonBridge.h — cầu nối tới CPython nhúng (BeeWare Python-Apple-support). Chỉ có nghĩa khi build với CATNIP_HAS_PYTHON.
// Chưa build/kiểm chứng.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CatnipPython : NSObject

/// Bản build có nhúng CPython (và thư viện chuẩn trong bundle) hay không.
+ (BOOL)isAvailable;

/// Chạy một file .py bằng runpy (run_name = "__main__") trong thư mục `directory`.
/// Gọi từ một thread nền. Trả về mã thoát; < 0 khi không khởi tạo được (error có mô tả).
+ (int)runScript:(NSString *)path
       directory:(NSString *)directory
           error:(NSString * _Nullable * _Nullable)error NS_SWIFT_NAME(run(script:directory:error:));

@end

NS_ASSUME_NONNULL_END
