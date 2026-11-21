# Dự án C++ (Clang++)

Loại dự án **C++** biên dịch và chạy code bằng **Clang++ ngay trong app** (không qua shell iSH).

## Cài Clang++
Clang++ không nằm trong bản cài để app nhẹ. Ở lần mở đầu (hoặc **Cài đặt → Công cụ → Clang++**) app tải gói về một lần: trình biên dịch, header C++ chuẩn (libc++), header hệ thống và SDL3. Cần mạng và vài trăm MB trống. Có thể bỏ qua và cài sau; bấm Chạy khi chưa cài sẽ mở lại màn hình này.

> **Quyền JIT:** Clang biên dịch ra mã máy rồi chạy ngay trong app, nên iOS yêu cầu app có quyền JIT (cài bằng TrollStore, hoặc bật JIT qua AltStore/SideStore). Thiếu quyền, nút Chạy báo lỗi rõ ràng thay vì treo.

## Chạy chương trình
- Dự án mới có sẵn `main.cpp`. Bấm **▶︎ Chạy** trên thanh trên.
- Mọi file `.cpp/.cc/.cxx` trong dự án được biên dịch; `main.cpp` chạy sau cùng. Header của bạn: `#include "ten.hpp"` (thư mục dự án nằm sẵn trong đường tìm header).
- Chuẩn mặc định: C++20.

## Console tương tác
Cửa sổ console hiện `cout`/`cerr`; gõ vào ô bên dưới rồi Enter để gửi cho `cin`/`getline`. Nút **Gửi EOF** đóng stdin (như Ctrl-D). Nhấn **Đóng** để thoát.

## GUI với SDL
File có `SDL` được chạy trên luồng chính của iOS. Hiện hỗ trợ **SDL3** (dùng chung bản đi kèm lõi LÖVE nên chỉ có khi bản build nhúng LÖVE); SDL2 chưa có.

```cpp
#include <SDL3/SDL.h>
int main() {
    SDL_Init(SDL_INIT_VIDEO);
    SDL_Window* w = SDL_CreateWindow("Xin chào", 640, 480, 0);
    SDL_Delay(2000);
    SDL_DestroyWindow(w);
    SDL_Quit();
}
```

## Giới hạn
- Tính năng **chưa kiểm chứng trên máy thật**; lỗi nạp thư viện sẽ hiện trong console.
- Không có tiến trình riêng: không dừng ép được chương trình lặp vô hạn, ngoài việc thoát app.
- Biên dịch lại từ đầu mỗi lần Chạy (không có bộ nhớ đệm).
