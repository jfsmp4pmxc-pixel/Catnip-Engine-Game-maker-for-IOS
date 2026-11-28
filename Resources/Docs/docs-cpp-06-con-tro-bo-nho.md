# Chương 6: Con trỏ và quản lý bộ nhớ

Con trỏ là khái niệm làm nhiều người mới học C++ lo ngại, nhưng ý tưởng rất đơn giản. Hiểu nó là hiểu máy tính lưu dữ liệu ở đâu — và cũng là chìa khoá để dùng các thư viện như SDL, vì chúng trả về nhiều thứ dưới dạng con trỏ (`SDL_Window*`, `SDL_Renderer*`...).

## 6.1. Bộ nhớ và địa chỉ

Hãy hình dung bộ nhớ là một dãy rất dài các ô đánh số 0, 1, 2, ... Mỗi ô chứa 1 byte; số thứ tự của ô là **địa chỉ**. Mỗi biến chiếm một hoặc vài ô liên tiếp. Toán tử `&` (đặt trước một biến) cho biết **địa chỉ** của biến đó.

```cpp
#include <iostream>

int main() {
    int a = 42;
    std::cout << "giá trị a = " << a << '\n';
    std::cout << "địa chỉ a  = " << &a << '\n';       // một số dạng 0x16d2f...
}
```

Địa chỉ in ra thay đổi mỗi lần chạy; đừng dùng số cụ thể.

## 6.2. Con trỏ là biến chứa địa chỉ

**Con trỏ** (pointer) là biến lưu một địa chỉ. Khai báo bằng dấu `*` sau kiểu: `int* p` đọc là "`p` là con trỏ tới `int`". Toán tử `*` đặt trước con trỏ (**giải tham chiếu**, dereference) đi theo địa chỉ để lấy/sửa giá trị tại đó.

```cpp
#include <iostream>

int main() {
    int a = 42;
    int* p = &a;            // p chứa địa chỉ của a

    std::cout << *p << '\n';   // 42: đọc giá trị tại địa chỉ đó
    *p = 100;                  // ghi vào a thông qua p
    std::cout << a << '\n';    // 100

    int b = 7;
    p = &b;                    // cho p trỏ sang biến khác
    *p += 1;
    std::cout << a << ' ' << b << '\n';
}
```

```text
42
100
100 8
```

Ghi nhớ hai ý nghĩa của dấu `*` và `&`:

| Ký hiệu | Trong **khai báo** | Trong **biểu thức** |
|---------|--------------------|----------------------|
| `*` | `int* p` — p là con trỏ | `*p` — giá trị mà p trỏ tới |
| `&` | `int& r` — r là tham chiếu | `&a` — địa chỉ của a |

## 6.3. `nullptr` — con trỏ không trỏ đâu cả

Con trỏ chưa có đích nên gán `nullptr` (không phải số 0, không phải `NULL`). Giải tham chiếu `nullptr` làm chương trình **sập**. Luôn kiểm tra trước khi dùng, đặc biệt với con trỏ nhận từ hàm có thể thất bại (SDL trả `nullptr` khi lỗi):

```cpp
#include <iostream>

int main() {
    int* p = nullptr;
    if (p == nullptr) std::cout << "p chưa trỏ đâu cả\n";
    if (!p)           std::cout << "cách viết ngắn: !p\n";

    int x = 5;
    p = &x;
    if (p) std::cout << "giờ p trỏ tới " << *p << '\n';
}
```

```text
p chưa trỏ đâu cả
cách viết ngắn: !p
giờ p trỏ tới 5
```

> Con trỏ **chưa khởi tạo** (`int* p;`) chứa địa chỉ rác — còn nguy hiểm hơn `nullptr`. Luôn khởi tạo.

## 6.4. Con trỏ, mảng và số học con trỏ

Tên một mảng có thể dùng như con trỏ tới phần tử đầu. Cộng `1` vào con trỏ thì nhảy sang phần tử **kế tiếp** (cộng đúng `sizeof(kiểu)` byte):

```cpp
#include <iostream>

int main() {
    int m[4] = {10, 20, 30, 40};
    int* p = m;                       // trỏ tới m[0]
    std::cout << *p << ' ' << *(p + 2) << '\n';    // 10 30
    std::cout << p[3] << '\n';                      // p[i] chính là *(p + i)

    for (int* q = m; q != m + 4; q++) std::cout << *q << ' ';
    std::cout << '\n';
}
```

```text
10 30
40
10 20 30 40 
```

Đây là lý do mảng đánh số từ 0 (phần tử `i` ở vị trí đầu + `i`) và vì sao ra ngoài biên là nguy hiểm. Khi truyền mảng vào hàm, thực chất chỉ truyền con trỏ đầu — hàm không biết độ dài, nên phải truyền kèm. Vì thế nên dùng `std::vector`/`std::span`.

## 6.5. Con trỏ và hàm: sửa biến của người gọi

Trước khi có tham chiếu (Chương 4), C dùng con trỏ để hàm sửa biến ngoài. Bạn vẫn gặp mẫu này trong nhiều thư viện C (SDL có hàm nhận `int* w, int* h` để *trả* kết quả ra):

```cpp
#include <iostream>

void chiaDu(int a, int b, int* thuong, int* du) {
    *thuong = a / b;
    *du = a % b;
}

int main() {
    int t, d;
    chiaDu(17, 5, &t, &d);       // truyền ĐỊA CHỈ của t và d
    std::cout << t << ' ' << d << '\n';
}
```

```text
3 2
```

**Tham chiếu hay con trỏ?** Tham chiếu: không thể rỗng, không đổi đích, cú pháp gọn — ưu tiên dùng khi viết hàm mới. Con trỏ: có thể rỗng, có thể trỏ đi chỗ khác, dùng khi giao tiếp với thư viện C hoặc cấu trúc như danh sách liên kết.

## 6.6. Con trỏ tới `struct`: toán tử `->`

Truy cập thành viên qua con trỏ dùng `->` (viết gọn của `(*p).thanhVien`):

```cpp
#include <iostream>
#include <string>

struct SinhVien {
    std::string ten;
    double diem;
};

int main() {
    SinhVien sv{"Lan", 8.5};
    SinhVien* p = &sv;
    std::cout << p->ten << ' ' << p->diem << '\n';
    p->diem += 0.5;
    std::cout << sv.diem << '\n';
}
```

```text
Lan 8.5
9
```

## 6.7. Hai vùng nhớ: stack và heap

| | **Stack** (ngăn xếp) | **Heap** (đống) |
|---|----------------------|-----------------|
| Dùng cho | biến cục bộ, tham số | dữ liệu sống lâu hoặc kích thước chỉ biết lúc chạy |
| Cấp phát | tự động khi vào `{ }` | bạn yêu cầu bằng `new` |
| Giải phóng | tự động khi ra `}` | bạn phải trả (`delete`) hoặc để smart pointer trả |
| Tốc độ | rất nhanh | chậm hơn |
| Kích thước | nhỏ (vài MB) | lớn |

Biến thường (`int a;`) nằm trên stack và mất khi ra khỏi phạm vi. Muốn một đối tượng sống lâu hơn hàm tạo ra nó (ví dụ một nhân vật trong game), hoặc có kích thước tuỳ ý, ta cấp phát trên heap.

## 6.8. `new` và `delete`

`new T` cấp phát vùng nhớ cho một `T` trên heap và trả về con trỏ tới nó. Mỗi `new` **phải** có đúng một `delete` tương ứng; `new[]` đi với `delete[]`.

```cpp
#include <iostream>

int main() {
    int* p = new int(5);          // cấp phát 1 int, giá trị 5
    *p += 1;
    std::cout << *p << '\n';
    delete p;                     // trả lại bộ nhớ
    p = nullptr;                  // tránh dùng nhầm sau khi xoá

    int n = 4;
    int* mang = new int[n];       // mảng kích thước chỉ biết lúc chạy
    for (int i = 0; i < n; i++) mang[i] = i * i;
    for (int i = 0; i < n; i++) std::cout << mang[i] << ' ';
    std::cout << '\n';
    delete[] mang;                // dùng delete[] cho mảng
}
```

```text
6
0 1 4 9 
```

Các lỗi bộ nhớ điển hình, cái nào cũng phổ biến:

- **Rò rỉ bộ nhớ** (memory leak): `new` mà quên `delete`. Chương trình chiếm ngày càng nhiều RAM.
- **Con trỏ treo** (dangling pointer): dùng con trỏ sau khi đối tượng đã bị `delete` hoặc đã ra khỏi phạm vi.
- **Xoá hai lần** (double free): `delete` cùng một địa chỉ hai lần.
- **Sai cặp**: `new[]` mà `delete` thường.

```cpp
int* f() {
    int x = 10;
    return &x;       // SAI: x là biến stack, hết hàm là mất; con trỏ trả về bị treo
}
```

Viết `new`/`delete` thủ công dễ sai, đặc biệt khi có ngoại lệ hoặc `return` giữa chừng. C++ hiện đại dùng cách tốt hơn.

## 6.9. RAII và smart pointer

**RAII** (Resource Acquisition Is Initialization) là nguyên tắc: gắn việc giải phóng tài nguyên vào **hàm huỷ** của một đối tượng. Khi đối tượng ra khỏi phạm vi (bất kể bằng cách nào, kể cả có lỗi), hàm huỷ tự chạy và dọn dẹp. `std::vector` và `std::string` đã dùng RAII: bạn không bao giờ `delete` chúng.

**Smart pointer** (`#include <memory>`) áp dụng RAII cho bộ nhớ heap:

- `std::unique_ptr<T>` — **một** chủ sở hữu duy nhất; tự `delete` khi hết phạm vi; không sao chép được, chỉ chuyển quyền (`std::move`). Mặc định nên dùng.
- `std::shared_ptr<T>` — **nhiều** chủ chung; đếm số chủ, huỷ khi chủ cuối biến mất.
- `std::weak_ptr<T>` — tham chiếu yếu tới `shared_ptr`, không tính vào số đếm (tránh vòng tròn).

Tạo bằng `std::make_unique<T>(...)` và `std::make_shared<T>(...)`:

```cpp
#include <iostream>
#include <memory>
#include <string>

struct NhanVat {
    std::string ten;
    explicit NhanVat(std::string t) : ten(std::move(t)) { std::cout << "tạo " << ten << '\n'; }
    ~NhanVat() { std::cout << "huỷ " << ten << '\n'; }
};

int main() {
    {
        auto a = std::make_unique<NhanVat>("Mèo");
        std::cout << "xin chào " << a->ten << '\n';
    }                                           // a ra khỏi phạm vi → tự huỷ
    std::cout << "---\n";

    auto b = std::make_shared<NhanVat>("Chó");
    {
        auto c = b;                             // hai chủ chung
        std::cout << "số chủ: " << b.use_count() << '\n';
    }
    std::cout << "số chủ: " << b.use_count() << '\n';
}                                               // b cuối cùng đi → huỷ
```

```text
tạo Mèo
xin chào Mèo
huỷ Mèo
---
tạo Chó
số chủ: 2
số chủ: 1
huỷ Chó
```

Trong code mới, gần như **không bao giờ cần viết `new`/`delete` trực tiếp**.

### Chuyển quyền sở hữu với `std::move`

```cpp
#include <iostream>
#include <memory>
#include <vector>

int main() {
    auto p = std::make_unique<int>(7);
    // auto q = p;               // LỖI: unique_ptr không sao chép được
    auto q = std::move(p);       // chuyển quyền: p thành rỗng, q giữ đối tượng
    std::cout << std::boolalpha << (p == nullptr) << ' ' << *q << '\n';

    std::vector<std::unique_ptr<int>> ds;
    ds.push_back(std::move(q));
    ds.push_back(std::make_unique<int>(9));
    std::cout << *ds[0] + *ds[1] << '\n';
}
```

```text
true 7
16
```

## 6.10. Con trỏ thô khi giao tiếp với thư viện C

Thư viện như SDL cấp phát tài nguyên và trả về con trỏ thô, cần gọi hàm huỷ riêng của nó (`SDL_DestroyWindow`...). Có thể bọc trong `unique_ptr` với **bộ xoá tuỳ chỉnh**:

```cpp
// Ví dụ khung (cần SDL), dùng ở chương SDL:
// std::unique_ptr<SDL_Window, decltype(&SDL_DestroyWindow)>
//     cuaSo(SDL_CreateWindow("Game", 800, 600, 0), SDL_DestroyWindow);
```

Khi đó cửa sổ tự được huỷ đúng cách, kể cả khi chương trình thoát giữa chừng.

## 6.11. `const` và con trỏ

Ba biến thể, đọc từ phải sang trái:

```cpp
int a = 1, b = 2;
const int* p1 = &a;      // con trỏ tới int HẰNG: không sửa được *p1, nhưng đổi p1 được
int* const p2 = &a;      // con trỏ HẰNG tới int: sửa được *p2, nhưng không đổi p2
const int* const p3 = &a;// cả hai đều hằng
```

`const char*` (con trỏ tới ký tự hằng) là kiểu của chuỗi hằng `"abc"`.

## Tóm tắt

- Con trỏ là biến chứa địa chỉ; `&x` lấy địa chỉ, `*p` đi theo địa chỉ, `p->m` truy cập thành viên.
- Dùng `nullptr`; kiểm tra trước khi giải tham chiếu.
- Stack: tự động, nhanh; heap: `new`/`delete`, sống lâu tuỳ ý.
- Lỗi thường gặp: rò rỉ, con trỏ treo, `delete` hai lần.
- Hiện đại: RAII + `std::unique_ptr` (mặc định) / `std::shared_ptr`; dùng `make_unique`, `make_shared`.

## Bài tập

1. Viết hàm `hoanDoi(int* a, int* b)` bằng con trỏ, và bản dùng tham chiếu; so sánh cú pháp gọi.
2. Tạo mảng `int` kích thước nhập từ bàn phím bằng `new[]`, tính tổng rồi giải phóng; sau đó viết lại bằng `std::vector`.
3. Viết `struct Node { int giaTri; std::unique_ptr<Node> ke; };` và nối ba node thành danh sách liên kết, in ra các giá trị.
4. Giải thích vì sao đoạn `int* f() { int x = 10; return &x; }` sai.

[Chương sau: Lớp và lập trình hướng đối tượng](docs-cpp-07-lop-oop.md)
