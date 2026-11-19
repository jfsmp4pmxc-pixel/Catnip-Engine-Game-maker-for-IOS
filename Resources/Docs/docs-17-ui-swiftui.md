# Dự án UI: phác thảo giao diện SwiftUI

Loại dự án **UI** dùng để **phác thảo giao diện** nhanh: bạn viết code theo cú pháp SwiftUI, bấm **Preview** và thử luôn trong Catnip. Bản xem trước bấm được, gõ được, kéo được, chuyển trang được.

## Cách dùng

1. Tạo dự án mới, chọn loại **UI**. Catnip tạo sẵn `ContentView.swift`.
2. Sửa code trong editor.
3. Bấm **Preview** trên thanh trên.
4. Preview **tự cập nhật** khi file `.swift` đổi (kể cả sửa từ app Tệp hay shell) và **giữ nguyên trạng thái** `@State` đang có. Bấm **Tải lại** nếu muốn đặt lại từ đầu.

Dự án UI **không có nút Chạy**, chỉ có Preview.

## Preview hoạt động thế nào

iOS không cho biên dịch Swift ngay trên máy, nên Catnip có sẵn một **bộ thông dịch tập con Swift/SwiftUI**: nó đọc code của bạn, chạy từng dòng rồi vẽ ra giao diện UIKit. Vì vậy:

- Preview **không phải** SwiftUI thật. Giao diện có thể lệch nhẹ so với Xcode, nhất là chi tiết bố cục.
- Mục tiêu là **phác thảo**: gặp thứ chưa hỗ trợ, Preview cố hiện phần còn lại thay vì dừng hẳn.
- Mọi file `.swift` trong dự án đều được nạp. Màn hình gốc là `ContentView`, hoặc khối `#Preview { ... }` nếu có, hoặc struct `View` đầu tiên.

## Khi code có lỗi

- **Lỗi cú pháp trong một khai báo** (struct, func...): khai báo đó bị bỏ, phần còn lại vẫn chạy. Lỗi hiện ở dòng cuối màn hình (màu cam) kèm tên file và số dòng.
- **Lỗi khi dựng giao diện:** Preview **giữ bản vẽ cũ** và hiện lỗi màu đỏ ở dòng cuối. Sửa xong là tự cập nhật.
- **View lạ** (ví dụ `MapView`, `Chart`): hiện thành **khung xám ghi tên view**, nội dung bên trong vẫn vẽ.
- **Modifier lạ:** bị bỏ qua, có cảnh báo ở dòng cuối.

## Các chương học

| Chương | Nội dung |
|---|---|
| 18 | SwiftUI cơ bản: View, Text, Stack, modifier |
| 19 | Trạng thái và nhập liệu: @State, Binding, Button, TextField... |
| 20 | Danh sách, điều hướng, tab, sheet và alert |
| 21 | Swift cho giao diện: struct, enum, closure, mảng, từ điển |
| 22 | Mẫu phác thảo có sẵn và bảng tra cứu |

## Chưa hỗ trợ (tổng quan)

- Generic, protocol thật sự, `async/await`, Combine, `try/catch`.
- `@Observable`, `@Environment` ngoài `dismiss`, animation thật (chỉ có `withAnimation` dạng làm mờ chuyển cảnh).
- DatePicker, Map, Charts, Canvas, hình ảnh từ file, gesture ngoài `onTapGesture`.
- `@State` được lưu theo **tên struct + tên thuộc tính**: hai view cùng struct dùng chung state.

Chi tiết từng phần nằm ở các chương sau.
