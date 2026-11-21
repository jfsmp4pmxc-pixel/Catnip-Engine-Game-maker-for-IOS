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

## Điều khiển ảo cho GUI (kiểu PojavLauncher)
Khi chương trình dùng SDL, một lớp điều khiển nổi lên trên cửa sổ game. Chương trình CLI thì lớp này **ẩn**.

- **Con trỏ chuột:** kéo ngón tay trên màn hình để di chuyển con trỏ (như bàn chạm laptop). Chạm nhanh = chuột trái, chạm hai ngón = chuột phải, giữ ngón rồi kéo = giữ chuột trái (kéo-thả), kéo hai ngón = cuộn.
- **Nút điều khiển:** mỗi nút gán một phím hoặc nút chuột. Mặc định có W A S D, Space, Shift, E, Esc, chuột trái/phải.
- **Ba nút nhỏ góc trên trái:** ⚙ menu; ⌨ **buộc mở bàn phím ảo**; 👁 ẩn/hiện các nút điều khiển (con trỏ vẫn dùng được).
- **⚙ → Chỉnh sửa nút điều khiển:** kéo để di chuyển nút; chạm vào nút để đổi nhãn, gán phím/chuột (chữ, số, mũi tên, F1–F12, phím đặc biệt, chuột, cuộn), kích thước, độ mờ, chế độ bật/tắt (giữ) và hình (tròn/vuông), hoặc xoá. "+ Thêm nút" thêm nút mới, "Mặc định" đặt lại bố cục.
- **⚙ → Tuỳ chỉnh con trỏ:** kiểu (mũi tên, chấm, chữ thập, vòng), kích thước, màu, độ mờ, tốc độ kéo.
- **⚙ → Chuyển sang chạm trực tiếp:** tắt con trỏ, để SDL nhận chạm như bình thường.
- Bố cục lưu riêng cho từng dự án. Phím và chuột được gửi vào SDL dưới dạng sự kiện, nên chương trình cần đọc bằng `SDL_PollEvent`; `SDL_GetKeyboardState` không thấy phím ảo.

## Giới hạn
- Tính năng **chưa kiểm chứng trên máy thật**; lỗi nạp thư viện sẽ hiện trong console.
- Không có tiến trình riêng: không dừng ép được chương trình lặp vô hạn, ngoài việc thoát app.
- Biên dịch lại từ đầu mỗi lần Chạy (không có bộ nhớ đệm).
