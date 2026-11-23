//  TwooBridge.h — cầu nối C cho trình biên dịch 2oLang nhúng (TwooLang/) và bộ nạp-chạy ảnh iOS64 (arm64) trong tiến trình app.
#ifndef TwooBridge_h
#define TwooBridge_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Biên dịch input.2o thành ảnh iOS64 ghi vào output. Thông báo lỗi in ra stderr. Trả 0 nếu thành công.
/// userLibDir: thư mục chứa thư viện .2o do app tải về (có thể NULL); thư viện nhúng sẵn luôn dùng được.
int twoo_compile(const char *input, const char *output, const char *userLibDir);

/// Nạp ảnh iOS64 vào bộ nhớ thực thi và chạy tới khi exit. Trả mã thoát, hoặc -1 nếu không chạy được (lý do in ra stderr).
/// Đọc/ghi qua fd 0/1/2 hiện tại của tiến trình (app đã chuyển hướng bằng pipe).
int twoo_run_image(const char *path);

/// Giả lập terminal ở stdout: bật màu (msg ..., red) và báo kích thước cửa sổ cho system.console.size.
void twoo_set_terminal(int enabled, int rows, int cols);

#ifdef __cplusplus
}
#endif

#endif
