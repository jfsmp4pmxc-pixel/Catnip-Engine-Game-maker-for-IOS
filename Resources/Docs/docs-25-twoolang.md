# Dự án C2o (.2o)

C2o (Catnip 2oLang) là bản 2oLang tích hợp trong Catnip, file `.2o`. 2oLang là ngôn ngữ nhỏ do Twoo Studio viết. Trình biên dịch (C++17) đọc file `.2o` rồi **sinh thẳng mã máy**, không qua C hay assembler. Trong Catnip, bấm **Chạy**: app biên dịch `main.2o` ra mã **arm64** rồi chạy ngay trong chính tiến trình app (native, không giả lập), kết quả hiện trong terminal.

## Yêu cầu
Giống Clang++: cần app có quyền JIT (cài bằng TrollStore, hoặc bật JIT qua SideStore/StikDebug). Nếu thiếu quyền, terminal báo rõ lý do.

## Cấu trúc một chương trình

```
global { int dem = 0; }          // biến toàn cục (không dùng db)
var { db string ten = "Peter"; } // biến nội bộ (bắt buộc db)
entry {                          // điểm bắt đầu
    msg "Xin chào, " + ten + "\n", green;
    exit;
}
```

- File chính bắt buộc có đủ ba khối `global`, `var`, `entry`.
- `msg` in giá trị, thêm màu: `black red green yellow blue magenta cyan white gray`.
- `if / else if / else`, `while`, `break`, `continue`, `return`, `exit`.
- `define ten(x) { return x * x; }` định nghĩa hàm; `obj` định nghĩa đối tượng (`public` / `private`).
- `drive` là mảng, chỉ số tính từ 1: `drive(a).add("x")`, `drive(a).rm(1)`, `a[2]`.
- Nhập: `ten = input;` đọc một dòng. Gõ vào ô nhập của terminal rồi Enter. `if (input "help")` đọc một dòng rồi so. Trong chuỗi `if / else if` mà mọi điều kiện đều là `input "..."` thì cả chuỗi chỉ đọc **một** dòng và so lần lượt; các `if` rời nhau mỗi cái đọc một dòng riêng.
- `system.console.size`, `system.cursor.*`: terminal của Catnip báo kích thước cửa sổ thật.

## Thư viện
`#import <CioStyle>` nạp thư viện nhúng sẵn. Thư viện khác tải từ kho `2oLang_Objs`: vào **Cài đặt → C2o (.2o) → Cập nhật**. File tải về lưu trong app; `#import <Tên>` tự tìm ở đó. `#import "file.2o"` nạp file của dự án.

## Lỗi biên dịch
Trình biên dịch báo toàn bộ lỗi một lượt, mỗi lỗi có `file:dòng:cột`, dòng mã và dấu `^`. Sửa từ trên xuống vì một lỗi có thể kéo theo lỗi phụ.

## Giới hạn
- Số nguyên 63 bit (tràn thì tự chuyển sang số thực).
- Heap 256 MB, không thu gom rác.
- Phím tắt (`input alt + f4`) cần terminal thật; terminal của Catnip chỉ nhập theo dòng.
