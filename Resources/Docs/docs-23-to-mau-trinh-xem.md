# Tô màu cú pháp và trình xem file

## Ngôn ngữ được tô màu

Catnip tự nhận ngôn ngữ theo đuôi file. Bạn cũng có thể chọn tay ở menu **⋯** (mục ngôn ngữ).

| Ngôn ngữ | Đuôi file |
|---|---|
| Lua | `.lua` |
| JavaScript / TypeScript | `.js .mjs .cjs .jsx .ts .tsx` |
| HTML / XML / SVG | `.html .htm .xml .vue .svg` |
| CSS | `.css .scss .less` |
| JSON | `.json .jsonc .json5` |
| Python | `.py .pyw .pyi` |
| Swift | `.swift` |
| C / Objective-C | `.c .h .m` |
| C++ | `.cpp .cc .cxx .hpp .hh .hxx .mm .ino` |
| Java / Kotlin | `.java .kt .kts` |
| C# | `.cs` |
| Rust | `.rs` |
| Go | `.go` |
| Shell | `.sh .bash .zsh` |
| Assembly | `.asm .s .nasm .masm .gas` |
| Fortran | `.f .for .f77 .f90 .f95 .f03 .f08 .ftn .fpp` |
| PHP | `.php .phtml` |
| Ruby | `.rb .rake .gemspec .ru` |
| SQL | `.sql` |
| YAML | `.yml .yaml` |
| TOML / INI | `.toml .ini .cfg .conf .properties` |
| Dart | `.dart` |
| Markdown | `.md .markdown` |

Ngôn ngữ nào chưa có, bạn nhập định cú pháp TextMate (`.tmLanguage` hoặc `.tmbundle`) ở **Cài đặt → Công cụ → Định cú pháp**.

### Quy tắc tô màu

- Chú thích và chuỗi được tô trước và **thắng mọi thứ khác**: sau dấu chú thích luôn là màu chú thích, `//` trong chuỗi không thành chú thích.
- Từ khoá thắng tên hàm: `while (...)` và `while {...}` cùng một màu.
- Assembly: nhãn (`main:`), chỉ thị (`.text`, `section`, `global`), thanh ghi (`rax`, `%eax`, `x0`) và lệnh được tô khác nhau; nhận cả NASM, GAS (AT&T) lẫn ARM.
- Fortran: không phân biệt hoa thường; `.and.`, `.true.` và các toán tử dạng chấm được nhận.

## Trình xem file

Chạm một file không phải văn bản ở thanh bên, Catnip mở trình xem phù hợp ngay trong vùng soạn thảo.

### Ảnh

`png jpg jpeg gif bmp tiff ico icns heic heif webp tga dds`

- Chụm hai ngón để phóng to, chạm đúp để phóng to hoặc thu về vừa khung.
- GIF nhiều khung chạy hoạt hình.
- Dòng dưới ảnh ghi kích thước điểm ảnh, định dạng và dung lượng.
- Một số định dạng game (`tga`, `dds`) tuỳ iOS có đọc được hay không; nếu không, bạn xem được bằng hex editor.

### Video

`mp4 mov m4v 3gp 3g2` (và `avi mkv webm` nếu iOS hỗ trợ bộ giải mã đó)

Dùng bộ điều khiển phát chuẩn của iOS: phát/dừng, tua, toàn màn hình. Định dạng iOS không phát được sẽ có thông báo rõ ràng.

### Âm thanh

`mp3 wav m4a aac caf aif aiff flac ogg oga opus`

Có nút phát/dừng, tua lùi/tới 10 giây, thanh tua, thời gian đã phát và còn lại, và nút lặp lại. `ogg`/`opus` chỉ phát khi iOS có bộ giải mã.

Khi chuyển sang file khác, âm thanh và video tự dừng.

### Hex editor

Mọi file nhị phân không thuộc nhóm trên (`.bin .dat .zip .ttf .so .class .exe`...) và file văn bản lớn hơn 2 MB mở bằng hex editor. Bạn cũng mở được **bất kỳ file nào** bằng hex: menu **⋯ → Mở bằng hex editor**.

- Mỗi dòng gồm offset, các byte hex và cột ký tự ASCII. Số byte mỗi dòng tự co theo chiều rộng màn hình.
- **Sửa:** chạm một dòng, nhập lại các byte hex (ghi đè, giữ nguyên độ dài dòng). Catnip ghi file ngay.
- **Đi tới:** nhập offset thập phân hoặc `0x...`.
- **Tìm:** nhập chuỗi hex (`48 65 6C`) hoặc văn bản thường (`Hello`). Tìm tiếp từ vị trí đang xem, hết file thì quay lại đầu.
- Byte `00` được làm mờ cho dễ nhìn.
- File lớn hơn 8 MB chỉ xem, không sửa; file lớn hơn 64 MB chỉ hiện 64 MB đầu.

Hex editor **ghi đè** byte: chưa hỗ trợ chèn hoặc xoá byte làm thay đổi độ dài file.
