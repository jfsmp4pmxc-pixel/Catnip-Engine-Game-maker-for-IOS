# Chương 2: Biến, kiểu dữ liệu và toán tử

Chương này dạy cách lưu trữ và tính toán với dữ liệu: **biến**, các **kiểu dữ liệu** cơ bản, **hằng số** và **toán tử**. Đây là nền móng; mọi chương sau đều dùng lại.

## 2.1. Biến là gì?

**Biến** (variable) là một vùng nhớ có tên, chứa một giá trị. Trong C++ mỗi biến có một **kiểu** (type) cố định, quyết định (1) nó chứa loại dữ liệu gì và (2) chiếm bao nhiêu byte. Cú pháp khai báo:

```text
kiểu tên = giá_trị_ban_đầu;
```

```cpp
#include <iostream>

int main() {
    int tuoi = 20;
    double chieuCao = 1.68;
    char hang = 'A';
    bool daDiHoc = true;

    std::cout << tuoi << " " << chieuCao << " " << hang << " " << daDiHoc << '\n';

    tuoi = 21;            // gán giá trị mới (kiểu không đổi)
    tuoi = tuoi + 1;      // dùng chính giá trị cũ để tính giá trị mới
    std::cout << tuoi << '\n';
}
```

```text
20 1.68 A 1
22
```

Lưu ý: `bool` in ra `1` (true) hoặc `0` (false). Muốn in chữ `true`/`false`, dùng `std::boolalpha` (Chương 9).

Quy tắc đặt tên: gồm chữ cái, chữ số, dấu gạch dưới `_`; **không** bắt đầu bằng chữ số; không trùng từ khoá (`int`, `class`, `return`...); phân biệt hoa/thường. Nên đặt tên có nghĩa (`soLuong` tốt hơn `x`). Nhiều người viết kiểu `camelCase` (`chieuCao`) hoặc `snake_case` (`chieu_cao`) — hãy chọn một kiểu và dùng nhất quán.

> **Biến chưa khởi tạo là cái bẫy.** `int x;` (không có `= giá_trị`) khiến `x` chứa *rác* — giá trị bất kỳ còn sót trong bộ nhớ. Đọc nó là **hành vi không xác định** (undefined behavior, UB). Luôn khởi tạo biến ngay khi khai báo.

## 2.2. Các kiểu số nguyên

| Kiểu | Kích thước thường gặp | Khoảng giá trị |
|------|----------------------|----------------|
| `short` | 2 byte | −32 768 … 32 767 |
| `int` | 4 byte | khoảng ±2,1 tỉ |
| `long long` | 8 byte | khoảng ±9,2 × 10¹⁸ |
| `unsigned int` | 4 byte | 0 … khoảng 4,29 tỉ |

Chuẩn C++ chỉ đảm bảo `short ≥ 16 bit`, `int ≥ 16 bit`, `long long ≥ 64 bit`. Trên iPhone (arm64) `int` là 32 bit. Muốn kích thước chính xác, dùng các kiểu trong `<cstdint>`: `int8_t`, `int16_t`, `int32_t`, `int64_t`, `uint8_t`, `uint32_t`, ...

Dùng `sizeof` để hỏi kích thước (tính bằng byte) và `<limits>` để hỏi giới hạn:

```cpp
#include <iostream>
#include <limits>
#include <cstdint>

int main() {
    std::cout << "int: " << sizeof(int) << " byte\n";
    std::cout << "long long: " << sizeof(long long) << " byte\n";
    std::cout << "int max: " << std::numeric_limits<int>::max() << '\n';
    std::cout << "uint8_t max: " << int(std::numeric_limits<uint8_t>::max()) << '\n';
}
```

```text
int: 4 byte
long long: 8 byte
int max: 2147483647
uint8_t max: 255
```

### Tràn số (overflow)

Số nguyên có giới hạn. Với kiểu **không dấu** (`unsigned`), vượt giới hạn thì quay vòng (modulo 2ⁿ) — được định nghĩa rõ. Với kiểu **có dấu** (`int`), vượt giới hạn là hành vi không xác định: kết quả có thể là bất cứ gì, và trình biên dịch tối ưu có thể làm chương trình hỏng một cách khó hiểu.

```cpp
#include <iostream>
#include <cstdint>

int main() {
    uint8_t b = 250;
    b = b + 10;                 // 260 mod 256 = 4
    std::cout << int(b) << '\n';

    unsigned int u = 0;
    u = u - 1;                  // quay vòng xuống mức lớn nhất
    std::cout << u << '\n';
}
```

```text
4
4294967295
```

Khi cần số lớn (ví dụ giai thừa), dùng `long long` hoặc `unsigned long long`.

## 2.3. Số thực

| Kiểu | Kích thước | Độ chính xác |
|------|-----------|--------------|
| `float` | 4 byte | khoảng 6–7 chữ số thập phân |
| `double` | 8 byte | khoảng 15–16 chữ số |

Mặc định dùng `double`; `float` chỉ khi cần tiết kiệm bộ nhớ (ví dụ mảng khổng lồ, hoặc đồ hoạ — SDL dùng `float` cho toạ độ).

Số thực được lưu dạng nhị phân nên **không biểu diễn chính xác** nhiều số thập phân quen thuộc:

```cpp
#include <iostream>
#include <iomanip>
#include <cmath>

int main() {
    double a = 0.1 + 0.2;
    std::cout << std::setprecision(17) << a << '\n';
    std::cout << std::boolalpha << (a == 0.3) << '\n';           // false!
    std::cout << (std::abs(a - 0.3) < 1e-9) << '\n';             // so sánh có sai số
}
```

```text
0.30000000000000004
false
true
```

**Quy tắc:** không so sánh hai số thực bằng `==`; hãy kiểm tra hiệu của chúng nhỏ hơn một **sai số** (epsilon).

## 2.4. Ký tự, logic, và chuỗi

- `char` — một ký tự ASCII, chiếm 1 byte, đồng thời là số nguyên nhỏ: `'A'` có mã 65.
- `bool` — chỉ nhận `true` hoặc `false`.
- `std::string` — chuỗi (Chương 5).

```cpp
#include <iostream>

int main() {
    char c = 'A';
    std::cout << c << " " << int(c) << " " << char(c + 1) << '\n';
}
```

```text
A 65 B
```

Chữ tiếng Việt có dấu (như `ế`) **không** vừa một `char`: trong UTF-8 chúng chiếm 2–3 byte. In chúng bằng chuỗi `"..."` thì bình thường, nhưng đếm độ dài bằng `size()` sẽ ra số byte chứ không phải số chữ. Lưu ý này quay lại ở Chương 5.

## 2.5. Hằng số và `auto`

**Hằng** là biến không được sửa sau khi khởi tạo. Dùng `const` (hoặc `constexpr` cho hằng tính được lúc biên dịch):

```cpp
#include <iostream>

constexpr double PI = 3.14159265358979;

int main() {
    const int soNguoi = 4;
    // soNguoi = 5;   // lỗi biên dịch: không gán được cho hằng
    double banKinh = 2.0;
    std::cout << "Chu vi = " << 2 * PI * banKinh << '\n';
    std::cout << "Mỗi người ăn " << 10.0 / soNguoi << " cái bánh\n";
}
```

```text
Chu vi = 12.5664
Mỗi người ăn 2.5 cái bánh
```

Dùng hằng có tên thay cho "số ma thuật" (magic number): `PI` rõ nghĩa hơn `3.14159`, và chỉ cần sửa một chỗ khi đổi.

`auto` bảo trình biên dịch tự suy ra kiểu từ giá trị khởi tạo. Biến vẫn có kiểu cố định, chỉ là bạn không phải viết:

```cpp
#include <iostream>

int main() {
    auto a = 42;        // int
    auto b = 3.5;       // double
    auto c = 'x';       // char
    auto d = 2.0f;      // float (hậu tố f)
    auto e = 10LL;      // long long (hậu tố LL)
    std::cout << sizeof(a) << sizeof(b) << sizeof(c) << sizeof(d) << sizeof(e) << '\n';
}
```

```text
48148
```

## 2.6. Toán tử số học

| Toán tử | Ý nghĩa | Ví dụ |
|---------|---------|-------|
| `+ - *` | cộng, trừ, nhân | `3 * 4` → 12 |
| `/` | chia | `7 / 2` → **3** (số nguyên!) |
| `%` | chia lấy dư (chỉ cho số nguyên) | `7 % 2` → 1 |
| `++ --` | tăng / giảm 1 | `i++` |
| `+= -= *= /= %=` | gán kèm phép tính | `x += 5` ≡ `x = x + 5` |

**Điểm hay nhầm nhất:** chia hai số nguyên cho ra số nguyên (phần thập phân bị cắt bỏ về 0). Muốn kết quả thực, ít nhất một vế phải là số thực.

```cpp
#include <iostream>

int main() {
    std::cout << 7 / 2 << '\n';          // 3
    std::cout << 7 % 2 << '\n';          // 1
    std::cout << -7 / 2 << '\n';         // -3 (cắt về 0)
    std::cout << -7 % 2 << '\n';         // -1 (dấu theo số bị chia)
    std::cout << 7 / 2.0 << '\n';        // 3.5
    int a = 7, b = 2;
    std::cout << double(a) / b << '\n';  // 3.5 (ép kiểu một vế)

    int i = 5;
    std::cout << i++ << ' ' << i << '\n';   // in 5 rồi mới tăng
    std::cout << ++i << ' ' << i << '\n';   // tăng rồi mới in
}
```

```text
3
1
-3
-1
3.5
3.5
5 6
7 7
```

Thứ tự ưu tiên giống toán học: `*` `/` `%` trước, `+` `-` sau, ngoặc đơn trên hết. Khi không chắc, thêm ngoặc.

`i++` (hậu tố) trả về giá trị **cũ** rồi mới tăng; `++i` (tiền tố) tăng rồi trả về giá trị **mới**. Khi chỉ cần tăng một mình, hai cách như nhau.

## 2.7. Toán tử so sánh và logic

So sánh cho ra `bool`: `==` (bằng), `!=` (khác), `<`, `>`, `<=`, `>=`.

Logic: `&&` (và), `||` (hoặc), `!` (phủ định). `&&` và `||` **đoản mạch** (short-circuit): vế phải chỉ được tính khi cần.

```cpp
#include <iostream>

int main() {
    int x = 15;
    bool trongKhoang = (x >= 10) && (x <= 20);
    bool ngoai = !trongKhoang;
    std::cout << std::boolalpha << trongKhoang << ' ' << ngoai << '\n';

    int chia = 0;
    // Vế phải sẽ chia cho 0 nếu được tính, nhưng && dừng sớm vì vế trái sai:
    bool an_toan = (chia != 0) && (10 / chia > 1);
    std::cout << an_toan << '\n';
}
```

```text
true false
false
```

> **Nhầm lẫn kinh điển:** `=` là **gán**, `==` là **so sánh**. `if (x = 5)` gán 5 cho `x` rồi coi điều kiện là đúng (vì 5 ≠ 0) — gần như chắc chắn là lỗi. Bật cảnh báo `-Wall` sẽ nhắc bạn.

## 2.8. Toán tử trên bit (tham khảo)

Dùng trong đồ hoạ, cờ trạng thái, nén dữ liệu: `&` (và), `|` (hoặc), `^` (xor), `~` (đảo bit), `<<` `>>` (dịch bit).

```cpp
#include <iostream>

int main() {
    unsigned flags = 0;
    const unsigned CO_AM_THANH = 1u << 0;   // 0001
    const unsigned CO_TOAN_MAN = 1u << 1;   // 0010
    flags |= CO_TOAN_MAN;                    // bật cờ
    std::cout << ((flags & CO_TOAN_MAN) != 0) << ((flags & CO_AM_THANH) != 0) << '\n';
    flags &= ~CO_TOAN_MAN;                   // tắt cờ
    std::cout << flags << '\n';
}
```

```text
10
0
```

Trong SDL, bạn sẽ gặp mẫu này khi truyền nhiều tuỳ chọn bằng `|` (ví dụ `SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY`).

## 2.9. Chuyển đổi kiểu (ép kiểu)

Khi trộn kiểu trong một biểu thức, C++ tự **chuyển đổi ngầm**: số nguyên nhỏ được nâng lên `int`, `int` lên `double` khi đi chung với số thực... Chuyển từ kiểu rộng sang hẹp (`double` → `int`) cắt bỏ phần thập phân và có thể mất dữ liệu.

Để chuyển **tường minh**, dùng `static_cast<kiểu>(giá_trị)` (kiểu C++ đúng chuẩn, tìm kiếm được trong code):

```cpp
#include <iostream>

int main() {
    double pi = 3.99;
    int a = static_cast<int>(pi);          // 3, cắt chứ không làm tròn
    int dem = 7, tong = 2;
    double tb = static_cast<double>(dem) / tong;   // 3.5
    std::cout << a << ' ' << tb << '\n';

    char c = 'a';
    std::cout << static_cast<char>(c - 'a' + 'A') << '\n';   // đổi thành chữ hoa
}
```

```text
3 3.5
A
```

Để khởi tạo an toàn, ưu tiên **ngoặc nhọn** `{}`: nó từ chối chuyển đổi làm mất dữ liệu.

```cpp
int a = 3.5;     // được, âm thầm cắt thành 3
// int b{3.5};   // LỖI biên dịch: narrowing conversion — đúng ý ta muốn
int c{42};       // OK
```

## 2.10. Phạm vi của biến (scope)

Biến chỉ tồn tại trong cặp `{ }` nơi nó được khai báo. Ra khỏi đó, nó bị huỷ và không còn dùng được. Biến ở trong có thể **che** (shadow) biến cùng tên ở ngoài — dễ gây nhầm, nên tránh.

```cpp
#include <iostream>

int main() {
    int x = 1;
    {
        int y = 2;
        std::cout << x + y << '\n';   // 3: thấy cả x lẫn y
    }
    // std::cout << y;                // lỗi: y đã ra khỏi phạm vi
    std::cout << x << '\n';
}
```

```text
3
1
```

## Tóm tắt

- Khai báo `kiểu tên = giá_trị;` và **luôn khởi tạo**.
- Nguyên: `int`, `long long`, `unsigned`; thực: `double` (mặc định) / `float`; ngoài ra `char`, `bool`.
- Chia nguyên cắt phần thập phân; `%` lấy dư; không so sánh số thực bằng `==`.
- `const`/`constexpr` cho hằng; `auto` để suy kiểu; `static_cast` để ép kiểu; `{}` để khởi tạo an toàn.
- `=` gán, `==` so sánh; `&&` `||` đoản mạch.

## Bài tập

1. Viết chương trình đổi nhiệt độ 36.6 độ C sang độ F (công thức `F = C * 9 / 5 + 32`). Thử viết `9 / 5` và `9.0 / 5` để thấy khác biệt.
2. Cho `int phut = 135;` in ra "2 giờ 15 phút" bằng `/` và `%`.
3. Dự đoán rồi chạy: `std::cout << (5 / 2) * 2.0 << ' ' << 5 / 2.0 * 2 << '\n';`

[Chương sau: Rẽ nhánh và vòng lặp](docs-cpp-03-dieu-khien.md)
