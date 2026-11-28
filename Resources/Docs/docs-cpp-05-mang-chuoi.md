# Chương 5: Mảng, vector và chuỗi

Một biến chỉ chứa một giá trị. Chương này dạy cách chứa **nhiều** giá trị cùng lúc: mảng cố định, `std::vector` (mảng co giãn) và `std::string` (chuỗi ký tự).

## 5.1. Mảng kiểu C

**Mảng** là dãy các phần tử cùng kiểu, nằm liền nhau trong bộ nhớ, đánh số từ **0**.

```cpp
#include <iostream>

int main() {
    int diem[5] = {8, 6, 9, 7, 10};
    std::cout << diem[0] << ' ' << diem[4] << '\n';

    diem[1] = 5;                     // sửa phần tử
    int tong = 0;
    for (int i = 0; i < 5; i++) tong += diem[i];
    std::cout << "tổng " << tong << '\n';
}
```

```text
8 10
tổng 39
```

Phần tử đầu là `diem[0]`, phần tử cuối là `diem[4]` (không phải `diem[5]`). Truy cập ngoài khoảng 0…n−1 **không bị chặn**: nó đọc/ghi sang vùng nhớ khác — hành vi không xác định, nguồn của lỗi nghiêm trọng và lỗ hổng bảo mật. Vì mảng C không tự nhớ kích thước và dễ gây lỗi, trong C++ hiện đại nên dùng `std::array` hoặc `std::vector`.

## 5.2. `std::array` — mảng kích thước cố định

Gói mảng thành đối tượng biết kích thước của mình (`#include <array>`):

```cpp
#include <array>
#include <iostream>

int main() {
    std::array<int, 4> a = {3, 1, 4, 1};
    std::cout << a.size() << ' ' << a.front() << ' ' << a.back() << '\n';
    for (int x : a) std::cout << x << ' ';
    std::cout << '\n';
    std::cout << a.at(2) << '\n';        // at() kiểm tra biên: ném ngoại lệ nếu sai
}
```

```text
4 3 1
3 1 4 1 
4
```

Kích thước phải biết lúc biên dịch. Khi số phần tử thay đổi lúc chạy, dùng `vector`.

## 5.3. `std::vector` — mảng co giãn

`vector` (`#include <vector>`) là cấu trúc dữ liệu được dùng nhiều nhất trong C++. Nó tự quản lý bộ nhớ và có thể lớn lên/nhỏ đi.

```cpp
#include <iostream>
#include <vector>

int main() {
    std::vector<int> v;               // rỗng
    v.push_back(10);                  // thêm vào cuối
    v.push_back(20);
    v.push_back(30);
    std::cout << "size = " << v.size() << '\n';

    v[1] = 25;                        // truy cập như mảng
    v.pop_back();                     // bỏ phần tử cuối
    for (size_t i = 0; i < v.size(); i++) std::cout << v[i] << ' ';
    std::cout << '\n';

    std::vector<int> w = {5, 6, 7, 8};
    w.insert(w.begin() + 1, 99);      // chèn 99 vào vị trí 1
    w.erase(w.begin());               // xoá phần tử đầu
    for (int x : w) std::cout << x << ' ';
    std::cout << '\n';

    std::vector<double> z(5, 1.5);    // 5 phần tử, mỗi cái 1.5
    std::cout << z.size() << ' ' << z[4] << '\n';
    w.clear();                        // xoá hết
    std::cout << std::boolalpha << w.empty() << '\n';
}
```

```text
size = 3
10 25 
99 6 7 8 
5 1.5
true
```

Các thao tác chính:

| Thao tác | Ý nghĩa | Chi phí |
|----------|---------|---------|
| `v.push_back(x)` | thêm cuối | nhanh (trung bình) |
| `v.pop_back()` | bỏ cuối | nhanh |
| `v[i]`, `v.at(i)` | truy cập | nhanh (`at` kiểm biên) |
| `v.size()`, `v.empty()` | số phần tử / rỗng? | nhanh |
| `v.insert(it, x)`, `v.erase(it)` | chèn/xoá giữa | chậm (dời phần tử) |
| `v.clear()` | xoá hết | |

`size()` trả về kiểu `size_t` (số nguyên không dấu). So sánh `i < v.size()` với `i` kiểu `int` có thể gây cảnh báo; dùng `size_t i` hoặc **range-for** bên dưới.

### Vòng lặp theo phạm vi (range-for)

```cpp
#include <iostream>
#include <vector>

int main() {
    std::vector<int> v = {1, 2, 3, 4};

    for (int x : v) std::cout << x << ' ';        // x là bản sao
    std::cout << '\n';

    for (int& x : v) x *= 10;                      // x là tham chiếu: sửa được phần tử
    for (const auto& x : v) std::cout << x << ' '; // đọc, không sao chép
    std::cout << '\n';
}
```

```text
1 2 3 4 
10 20 30 40 
```

Quy tắc giống Chương 4: `auto x` (bản sao), `auto& x` (sửa), `const auto& x` (chỉ đọc, hiệu quả cho kiểu lớn).

## 5.4. Mảng hai chiều

Vector của vector hoặc mảng của mảng, dùng cho bảng, bản đồ ô lưới (tile map trong game):

```cpp
#include <iostream>
#include <vector>

int main() {
    const int H = 3, W = 4;
    std::vector<std::vector<int>> luoi(H, std::vector<int>(W, 0));   // 3 hàng, 4 cột, toàn 0

    for (int y = 0; y < H; y++)
        for (int x = 0; x < W; x++)
            luoi[y][x] = y * W + x;

    for (const auto& hang : luoi) {
        for (int o : hang) std::cout << o << '\t';
        std::cout << '\n';
    }
}
```

```text
0	1	2	3	
4	5	6	7	
8	9	10	11	
```

`luoi[y][x]`: chỉ số đầu là **hàng** (y), chỉ số sau là **cột** (x).

## 5.5. Thuật toán trong `<algorithm>`

Thư viện chuẩn có sẵn các thuật toán tối ưu. Chúng làm việc trên một **khoảng** `[begin, end)`:

```cpp
#include <algorithm>
#include <iostream>
#include <numeric>
#include <vector>

int main() {
    std::vector<int> v = {5, 2, 9, 1, 7};

    std::sort(v.begin(), v.end());                       // tăng dần
    for (int x : v) std::cout << x << ' ';
    std::cout << '\n';

    std::sort(v.begin(), v.end(), std::greater<int>());  // giảm dần
    for (int x : v) std::cout << x << ' ';
    std::cout << '\n';

    auto it = std::find(v.begin(), v.end(), 7);
    if (it != v.end()) std::cout << "7 ở vị trí " << (it - v.begin()) << '\n';

    std::cout << "lớn nhất " << *std::max_element(v.begin(), v.end()) << '\n';
    std::cout << "tổng " << std::accumulate(v.begin(), v.end(), 0) << '\n';
    std::reverse(v.begin(), v.end());
    std::cout << "đảo: " << v.front() << '\n';
}
```

```text
1 2 5 7 9 
9 7 5 2 1 
7 ở vị trí 1
lớn nhất 9
tổng 24
đảo: 1
```

`v.begin()` và `v.end()` là **iterator** (bộ duyệt), một dạng "con trỏ thông minh" trỏ vào phần tử; `end()` trỏ *sau* phần tử cuối. `*it` lấy giá trị phần tử mà `it` trỏ tới. Chương 8 giải thích sâu hơn.

## 5.6. Chuỗi `std::string`

`std::string` (`#include <string>`) là chuỗi ký tự co giãn, an toàn hơn nhiều so với mảng `char` kiểu C.

```cpp
#include <iostream>
#include <string>

int main() {
    std::string a = "Xin ";
    std::string b = "chào";
    std::string c = a + b + "!";          // nối chuỗi
    std::cout << c << '\n';

    c += " Catnip";
    std::cout << c.size() << '\n';        // số byte
    std::cout << c[0] << '\n';            // ký tự đầu
    c[0] = 'x';
    std::cout << c << '\n';

    std::cout << std::boolalpha << (std::string("abc") == "abc") << '\n';
    std::cout << ("apple" < std::string("banana")) << '\n';    // so sánh từ điển
}
```

```text
Xin chào!
17
X
xin chào! Catnip
true
true
```

### Tìm, cắt, thay thế

```cpp
#include <iostream>
#include <string>

int main() {
    std::string s = "ho tro lap trinh C++";

    size_t pos = s.find("lap");                    // vị trí đầu tiên, hoặc npos
    std::cout << pos << '\n';
    std::cout << s.substr(pos, 3) << '\n';         // (vị trí, độ dài)
    std::cout << s.substr(10) << '\n';             // từ vị trí 10 tới hết (có dấu cách đầu)

    if (s.find("Python") == std::string::npos) std::cout << "không có Python\n";

    s.replace(0, 2, "HO");                         // thay 2 ký tự đầu
    s.insert(0, ">> ");
    std::cout << s << '\n';
    s.erase(0, 3);                                 // xoá 3 ký tự từ đầu
    std::cout << s.length() << '\n';
}
```

```text
7
lap
 trinh C++
không có Python
>> HO tro lap trinh C++
20
```

`std::string::npos` là giá trị đặc biệt nghĩa "không tìm thấy". Luôn kiểm tra nó trước khi dùng vị trí.

### Duyệt từng ký tự, đổi hoa/thường

```cpp
#include <cctype>
#include <iostream>
#include <string>

int main() {
    std::string s = "Hello, World 2026";
    int chuCai = 0, chuSo = 0;
    for (char ch : s) {
        if (std::isalpha(static_cast<unsigned char>(ch))) chuCai++;
        else if (std::isdigit(static_cast<unsigned char>(ch))) chuSo++;
    }
    std::cout << chuCai << " chữ cái, " << chuSo << " chữ số\n";

    for (char& ch : s) ch = static_cast<char>(std::toupper(static_cast<unsigned char>(ch)));
    std::cout << s << '\n';
}
```

```text
10 chữ cái, 4 chữ số
HELLO, WORLD 2026
```

### Chuyển giữa chuỗi và số

```cpp
#include <iostream>
#include <string>

int main() {
    int n = std::stoi("123");            // string → int
    double d = std::stod("3.14");
    std::string s = std::to_string(n * 2) + "!";   // số → string
    std::cout << n + 1 << ' ' << d << ' ' << s << '\n';

    try {
        int bad = std::stoi("abc");      // ném ngoại lệ vì không phải số
        std::cout << bad << '\n';
    } catch (const std::exception& e) {
        std::cout << "không phải số\n";
    }
}
```

```text
124 3.14 246!
không phải số
```

(`try`/`catch` là cơ chế bắt lỗi, xem Chương 9.)

### Đọc cả dòng

```cpp
std::string dong;
std::getline(std::cin, dong);     // đọc đến hết dòng, kể cả dấu cách
```

Nếu trước đó dùng `std::cin >> so;` thì dấu xuống dòng còn sót lại; gọi `std::cin.ignore(1000, '\n');` trước `getline` để bỏ nó.

## 5.7. Chữ tiếng Việt và UTF-8

Mã nguồn và console của Catnip dùng **UTF-8**: mỗi ký tự là 1–4 byte. Chữ ASCII (a–z, 0–9) chiếm 1 byte; chữ có dấu tiếng Việt chiếm 2 hoặc 3 byte. `std::string` đếm và lập chỉ mục theo **byte**, không theo chữ.

```cpp
#include <iostream>
#include <string>

int main() {
    std::string s = "việt";
    std::cout << s.size() << '\n';                  // số byte
    int soChu = 0;
    for (unsigned char ch : s) {
        if ((ch & 0xC0) != 0x80) soChu++;           // bỏ qua byte "đuôi" (10xxxxxx)
    }
    std::cout << soChu << '\n';
}
```

```text
6
4
```

Byte đầu của ký tự UTF-8 không có dạng `10xxxxxx`; các byte tiếp theo của cùng ký tự thì có. Đếm byte đầu cho ra số ký tự. Không nên `substr` hay `s[i]` ngay giữa một chữ có dấu — bạn sẽ cắt đôi ký tự và hiện ra ký tự lỗi. Nếu chỉ in và nối chuỗi thì không vấn đề gì.

## 5.8. Chuỗi kiểu C (tham khảo)

Chuỗi hằng `"abc"` có kiểu `const char[4]` (ba ký tự + byte kết thúc `'\0'`). Nhiều hàm thư viện C và SDL nhận `const char*`. Chuyển `std::string` sang dạng này bằng `.c_str()`:

```cpp
std::string tieude = "Game của tôi";
// SDL_CreateWindow(tieude.c_str(), 800, 600, 0);
```

Con trỏ trả về từ `c_str()` chỉ hợp lệ khi chuỗi gốc còn sống và chưa bị sửa.

## Tóm tắt

- Mảng đánh số từ 0; truy cập ngoài biên là UB. Ưu tiên `std::array`/`std::vector`.
- `vector`: `push_back`, `size`, `[]`, `insert/erase`, range-for.
- `<algorithm>`: `sort`, `find`, `reverse`, `max_element`; `<numeric>`: `accumulate`.
- `std::string`: nối `+`, `find`, `substr`, `replace`, `stoi`/`to_string`, `getline`.
- UTF-8: `size()` đếm byte; chữ có dấu là nhiều byte.

## Bài tập

1. Nhập n số vào một `vector`, in ra số nhỏ nhất, lớn nhất và trung bình.
2. Đảo ngược một chuỗi ASCII không dùng `std::reverse`.
3. Đếm số từ trong một câu (đếm cụm ký tự không phải dấu cách).
4. Tạo bảng 5×5 chứa bảng cửu chương và in ra có căn lề.

[Chương sau: Con trỏ và quản lý bộ nhớ](docs-cpp-06-con-tro-bo-nho.md)
