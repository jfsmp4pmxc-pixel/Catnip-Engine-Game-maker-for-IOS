# Chương 4: Hàm

**Hàm** (function) là một đoạn mã có tên, có thể gọi nhiều lần với dữ liệu đầu vào khác nhau. Hàm giúp chia chương trình lớn thành những phần nhỏ dễ hiểu, dễ kiểm tra, và tránh viết đi viết lại cùng một đoạn mã.

## 4.1. Định nghĩa và gọi hàm

```text
kiểu_trả_về tên_hàm(kiểu_1 tham_số_1, kiểu_2 tham_số_2) {
    // thân hàm
    return giá_trị;
}
```

```cpp
#include <iostream>

int binhPhuong(int x) {
    return x * x;
}

double trungBinh(double a, double b) {
    return (a + b) / 2;
}

void chaoHoi(const char* ten) {      // void: không trả về gì
    std::cout << "Xin chào, " << ten << "!\n";
}

int main() {
    std::cout << binhPhuong(7) << '\n';
    std::cout << trungBinh(3, 4) << '\n';
    chaoHoi("Lan");
}
```

```text
49
3.5
Xin chào, Lan!
```

- **Tham số** (parameter) là biến khai báo trong định nghĩa hàm; **đối số** (argument) là giá trị bạn truyền khi gọi.
- `return` kết thúc hàm ngay lập tức và đưa giá trị về nơi gọi. Hàm `void` có thể dùng `return;` không kèm giá trị.
- Hàm không `void` mà có đường chạy không gặp `return` là **lỗi** (hành vi không xác định). Bật `-Wall` để được cảnh báo.

## 4.2. Khai báo trước (prototype)

C++ đọc file từ trên xuống: một hàm phải được **biết** trước khi bị gọi. Có hai cách: định nghĩa hàm trước `main`, hoặc viết **khai báo** (chỉ có chữ ký, kết thúc bằng `;`) ở trên, định nghĩa ở dưới:

```cpp
#include <iostream>

int cong(int a, int b);        // khai báo (prototype)

int main() {
    std::cout << cong(2, 3) << '\n';
}

int cong(int a, int b) {       // định nghĩa
    return a + b;
}
```

```text
5
```

Khai báo trước đặc biệt quan trọng khi chia chương trình ra nhiều file (Chương 11): khai báo đặt trong file `.h`, định nghĩa trong file `.cpp`.

## 4.3. Truyền theo giá trị

Mặc định, tham số là **bản sao** của đối số. Sửa tham số trong hàm không ảnh hưởng biến gốc:

```cpp
#include <iostream>

void tangMot(int x) {
    x = x + 1;
    std::cout << "trong hàm: " << x << '\n';
}

int main() {
    int a = 10;
    tangMot(a);
    std::cout << "ngoài hàm: " << a << '\n';
}
```

```text
trong hàm: 11
ngoài hàm: 10
```

Với số nhỏ, bản sao rất rẻ. Với đối tượng lớn (chuỗi dài, vector nghìn phần tử), sao chép tốn thời gian — dùng tham chiếu.

## 4.4. Tham chiếu (reference)

**Tham chiếu** là *tên khác* của một biến đã có. Khai báo bằng `&` sau kiểu. Truyền tham chiếu cho hàm thì hàm làm việc trên chính biến gốc, không sao chép.

```cpp
#include <iostream>
#include <string>

void tangMot(int& x) {          // x là biệt danh của biến người gọi truyền vào
    x = x + 1;
}

void hoanDoi(int& a, int& b) {
    int tam = a;
    a = b;
    b = tam;
}

int main() {
    int n = 10;
    tangMot(n);
    std::cout << n << '\n';

    int p = 1, q = 2;
    hoanDoi(p, q);
    std::cout << p << ' ' << q << '\n';
}
```

```text
11
2 1
```

### `const` tham chiếu: đọc mà không sao chép

Khi hàm chỉ cần **đọc** đối tượng lớn, dùng `const T&`: không sao chép, và trình biên dịch cấm sửa nhầm.

```cpp
#include <iostream>
#include <string>

int demKyTu(const std::string& s) {      // không sao chép chuỗi, không được sửa
    return static_cast<int>(s.size());
}

int main() {
    std::string cau = "học C++ thật vui";
    std::cout << demKyTu(cau) << '\n';
}
```

```text
20
```

(Số 20 là số **byte**, không phải số chữ: các chữ có dấu như `ọ`, `ậ` chiếm 3 byte UTF-8. Chương 5 nói thêm.)

**Quy tắc chọn cách truyền:**

| Tình huống | Cách truyền |
|------------|-------------|
| Kiểu nhỏ (`int`, `double`, `bool`, `char`), chỉ đọc | `T` (theo giá trị) |
| Kiểu lớn, chỉ đọc | `const T&` |
| Hàm cần **sửa** biến của người gọi | `T&` |

## 4.5. Trả về nhiều giá trị

Một hàm chỉ `return` một giá trị. Muốn trả nhiều, dùng `struct`, `std::pair`/`std::tuple`, hoặc tham chiếu ra ngoài. Cách hiện đại và dễ đọc là trả về `struct` hay `std::pair` rồi dùng **structured binding** (C++17):

```cpp
#include <iostream>
#include <utility>

std::pair<int, int> chiLayDu(int a, int b) {
    return {a / b, a % b};
}

int main() {
    auto [thuong, du] = chiLayDu(17, 5);
    std::cout << "thương " << thuong << ", dư " << du << '\n';
}
```

```text
thương 3, dư 2
```

## 4.6. Đối số mặc định

Tham số có thể có giá trị mặc định (chỉ các tham số **ở cuối** danh sách):

```cpp
#include <iostream>

void ve(int rong, int cao = 3, char ky = '#') {
    for (int i = 0; i < cao; i++) {
        for (int j = 0; j < rong; j++) std::cout << ky;
        std::cout << '\n';
    }
}

int main() {
    ve(4);            // cao = 3, ky = '#'
    ve(2, 2, '*');
}
```

```text
####
####
####
**
**
```

## 4.7. Nạp chồng hàm (overloading)

Nhiều hàm **cùng tên** nhưng khác số lượng hoặc kiểu tham số. Trình biên dịch chọn hàm phù hợp theo đối số.

```cpp
#include <iostream>
#include <string>

int lonNhat(int a, int b)       { return a > b ? a : b; }
double lonNhat(double a, double b) { return a > b ? a : b; }
std::string lonNhat(const std::string& a, const std::string& b) { return a > b ? a : b; }

int main() {
    std::cout << lonNhat(3, 8) << '\n';
    std::cout << lonNhat(2.5, 1.5) << '\n';
    std::cout << lonNhat(std::string("abc"), std::string("abd")) << '\n';
}
```

```text
8
2.5
abd
```

Chỉ khác **kiểu trả về** thì không phải overload. Gọi mơ hồ (ví dụ `lonNhat(3, 2.5)`) gây lỗi biên dịch; hãy ép kiểu tường minh.

(Hàm `lonNhat` viết một lần cho mọi kiểu sẽ dùng **template** — Chương 8.)

## 4.8. Phạm vi, biến `static` cục bộ

Biến khai báo trong hàm là **biến cục bộ**: được tạo mỗi lần gọi hàm, mất khi hàm kết thúc. Thêm `static` thì biến sống suốt chương trình và giữ giá trị giữa các lần gọi:

```cpp
#include <iostream>

int demLanGoi() {
    static int dem = 0;      // khởi tạo một lần duy nhất
    dem++;
    return dem;
}

int main() {
    demLanGoi();
    demLanGoi();
    std::cout << "đã gọi " << demLanGoi() << " lần\n";
}
```

```text
đã gọi 3 lần
```

Biến **toàn cục** (khai báo ngoài mọi hàm) cũng sống suốt chương trình nhưng ai cũng sửa được, khó theo dõi lỗi. Hạn chế dùng; nếu cần, đặt `const`/`constexpr`.

## 4.9. Đệ quy

Hàm **tự gọi lại chính nó**. Mỗi hàm đệ quy cần: (1) **trường hợp cơ sở** — dừng đệ quy; (2) **bước đệ quy** — đưa bài toán về bài nhỏ hơn.

```cpp
#include <iostream>

long long giaiThua(int n) {
    if (n <= 1) return 1;              // trường hợp cơ sở
    return n * giaiThua(n - 1);        // bước đệ quy
}

int fibo(int n) {
    if (n < 2) return n;
    return fibo(n - 1) + fibo(n - 2);
}

int main() {
    std::cout << giaiThua(10) << '\n';
    for (int i = 0; i < 10; i++) std::cout << fibo(i) << ' ';
    std::cout << '\n';
}
```

```text
3628800
0 1 1 2 3 5 8 13 21 34 
```

Lời gọi `giaiThua(3)` diễn ra như sau: `3 * giaiThua(2)` → `3 * (2 * giaiThua(1))` → `3 * (2 * 1)` = 6. Mỗi lời gọi chiếm một khung trên **ngăn xếp** (stack); đệ quy quá sâu (hàng trăm nghìn tầng) gây **tràn ngăn xếp** (stack overflow) làm chương trình sập. `fibo` ở trên cũng rất chậm với `n` lớn vì tính lại nhiều lần; dùng vòng lặp hay ghi nhớ kết quả cho bài toán này.

## 4.10. Hàm `inline` và `constexpr`

- `inline` gợi ý trình biên dịch chèn thân hàm vào chỗ gọi, bỏ chi phí gọi hàm. Quan trọng hơn: hàm `inline` được phép định nghĩa trong header (Chương 11) mà không gây lỗi trùng định nghĩa.
- `constexpr` cho phép hàm được **tính lúc biên dịch** nếu đối số là hằng.

```cpp
#include <iostream>

constexpr int binhPhuong(int x) { return x * x; }

int main() {
    constexpr int a = binhPhuong(12);     // tính xong khi biên dịch
    int mang[binhPhuong(3)];              // kích thước mảng cần hằng số lúc biên dịch
    std::cout << a << ' ' << sizeof(mang) / sizeof(int) << '\n';
}
```

```text
144 9
```

## 4.11. Hàm `main` và đối số dòng lệnh

`main` còn có dạng `int main(int argc, char* argv[])` để nhận tham số dòng lệnh. Trong console Catnip bạn thường không truyền tham số nên dạng `int main()` là đủ.

## Tóm tắt

- Hàm: `kiểu_trả_về tên(tham_số) { ... return ...; }`; khai báo trước bằng prototype.
- Truyền theo giá trị (bản sao), `T&` (sửa biến gốc), `const T&` (đọc không sao chép).
- Đối số mặc định ở cuối; nạp chồng hàm cho cùng tên khác kiểu.
- `static` cục bộ giữ giá trị giữa các lần gọi.
- Đệ quy cần trường hợp cơ sở; cẩn thận độ sâu.

## Bài tập

1. Viết `int ucln(int a, int b)` (thuật toán Euclid, dùng đệ quy hoặc vòng lặp).
2. Viết `void sapXepHaiSo(int& a, int& b)` để sau khi gọi, `a <= b`.
3. Viết hàm `bool laPalindrome(int n)` kiểm tra số đối xứng (121, 1331...).
4. Viết `power(double co_so, int mu)` bằng đệ quy; xử lý cả số mũ âm.

[Chương sau: Mảng, vector và chuỗi](docs-cpp-05-mang-chuoi.md)
