# Chương 7: Lớp và lập trình hướng đối tượng

Các chương trước dùng kiểu có sẵn (`int`, `string`, `vector`). **Lớp** (class) cho phép bạn tạo **kiểu dữ liệu của riêng mình**, gộp dữ liệu và hành động liên quan vào một khối. Game rất hợp với cách nghĩ này: có `NhanVat`, `Dan`, `KeThu`, mỗi thứ có thuộc tính (vị trí, máu) và hành vi (di chuyển, vẽ, nhận sát thương).

## 7.1. `struct`: gộp dữ liệu

`struct` gộp nhiều biến (gọi là **thành viên**, member) thành một kiểu:

```cpp
#include <iostream>
#include <string>

struct Diem {
    double x;
    double y;
};

struct SinhVien {
    std::string ten;
    int tuoi;
    Diem toaDo;
};

int main() {
    Diem d{3.0, 4.0};
    SinhVien sv{"Lan", 19, {1.5, 2.5}};
    sv.tuoi++;
    std::cout << sv.ten << " " << sv.tuoi << " (" << sv.toaDo.x << ", " << sv.toaDo.y << ")\n";
    std::cout << d.x * d.x + d.y * d.y << '\n';
}
```

```text
Lan 20 (1.5, 2.5)
25
```

Truy cập thành viên bằng dấu chấm `.` (hoặc `->` qua con trỏ).

## 7.2. `class`: dữ liệu + hành vi

Lớp thêm **hàm thành viên** (member function, còn gọi **phương thức**) và kiểm soát quyền truy cập:

- `public` — ai cũng dùng được (giao diện mà bên ngoài thấy).
- `private` — chỉ code bên trong lớp dùng được (chi tiết cài đặt).

Với `struct` mặc định là `public`, với `class` mặc định là `private`. Ngoài đó hai từ khoá giống nhau; thói quen: `struct` cho gói dữ liệu đơn giản, `class` khi có ràng buộc và hành vi.

```cpp
#include <iostream>
#include <string>

class TaiKhoan {
public:
    TaiKhoan(std::string chu, double soDuBanDau)       // hàm khởi tạo
        : chu_(std::move(chu)), soDu_(soDuBanDau) {}

    bool rut(double soTien) {
        if (soTien <= 0 || soTien > soDu_) return false;   // bảo vệ ràng buộc
        soDu_ -= soTien;
        return true;
    }
    void nop(double soTien) { if (soTien > 0) soDu_ += soTien; }

    double soDu() const { return soDu_; }                   // hàm const: không sửa đối tượng
    const std::string& chu() const { return chu_; }

private:
    std::string chu_;
    double soDu_;
};

int main() {
    TaiKhoan tk("Lan", 100);
    tk.nop(50);
    std::cout << std::boolalpha << tk.rut(500) << '\n';    // false: không đủ tiền
    std::cout << tk.rut(30) << '\n';
    std::cout << tk.chu() << ": " << tk.soDu() << '\n';
    // tk.soDu_ = 1e9;     // LỖI biên dịch: soDu_ là private
}
```

```text
false
true
Lan: 120
```

Đây là **đóng gói** (encapsulation): dữ liệu `soDu_` bị khoá; mọi thay đổi phải đi qua `rut`/`nop` nên luôn đúng quy tắc. Quy ước hay gặp: đặt thêm dấu `_` ở cuối tên thành viên private để phân biệt với tham số.

Mấy điểm trong ví dụ:
- **Hàm khởi tạo** (constructor) tên trùng tên lớp, không có kiểu trả về, chạy khi đối tượng được tạo. Phần `: chu_(...), soDu_(...)` là **danh sách khởi tạo** — cách chuẩn để gán giá trị đầu cho thành viên (hiệu quả hơn gán trong thân hàm).
- Hàm có `const` ở cuối (`double soDu() const`) hứa không sửa đối tượng; chỉ hàm `const` mới gọi được trên đối tượng `const`. Các hàm chỉ để *đọc* nên luôn đánh dấu `const`.

## 7.3. Hàm khởi tạo, hàm huỷ, vòng đời

Vòng đời một đối tượng: **tạo** (constructor) → dùng → **huỷ** (destructor, `~TenLop()`). Với đối tượng trên stack, hàm huỷ tự chạy khi ra khỏi `{ }`, theo thứ tự **ngược** với lúc tạo.

```cpp
#include <iostream>

class DauVet {
public:
    explicit DauVet(const char* ten) : ten_(ten) { std::cout << "+ " << ten_ << '\n'; }
    ~DauVet() { std::cout << "- " << ten_ << '\n'; }
private:
    const char* ten_;
};

int main() {
    DauVet a("A");
    {
        DauVet b("B");
        DauVet c("C");
    }
    std::cout << "giữa\n";
}
```

```text
+ A
+ B
+ C
- C
- B
giữa
- A
```

`explicit` ngăn trình biên dịch tự chuyển kiểu qua hàm khởi tạo một tham số — nên thêm vào mọi constructor có một tham số.

Hàm huỷ là nơi bạn giải phóng tài nguyên (đóng file, huỷ cửa sổ SDL...). Nhờ RAII (Chương 6) bạn thường không cần viết hàm huỷ nếu mọi thành viên đã tự quản lý: đó là **quy tắc số không** (rule of zero).

## 7.4. Con trỏ `this`, thành viên `static`

Bên trong hàm thành viên, `this` là con trỏ tới đối tượng đang gọi. Thành viên `static` thuộc về **lớp**, chung cho mọi đối tượng:

```cpp
#include <iostream>

class KeThu {
public:
    KeThu() { dem_++; }
    ~KeThu() { dem_--; }
    static int soLuong() { return dem_; }
    KeThu& tangMau(int m) { mau_ += m; return *this; }     // trả về chính mình để nối lời gọi
    int mau() const { return mau_; }
private:
    int mau_ = 100;           // giá trị mặc định cho thành viên
    static inline int dem_ = 0;   // C++17: định nghĩa ngay trong lớp
};

int main() {
    KeThu a, b;
    std::cout << KeThu::soLuong() << '\n';
    {
        KeThu c;
        std::cout << KeThu::soLuong() << '\n';
    }
    std::cout << KeThu::soLuong() << '\n';
    std::cout << a.tangMau(10).tangMau(5).mau() << '\n';
}
```

```text
2
3
2
115
```

## 7.5. Kế thừa

**Kế thừa** (inheritance) cho một lớp **con** (derived) thừa hưởng thành viên của lớp **cha** (base) và bổ sung hoặc thay đổi hành vi. Quan hệ "là một": `Cho` là một `DongVat`.

```cpp
#include <iostream>
#include <string>

class DongVat {
public:
    explicit DongVat(std::string ten) : ten_(std::move(ten)) {}
    void gioiThieu() const { std::cout << "Tôi là " << ten_ << '\n'; }
protected:                      // protected: lớp con dùng được, bên ngoài thì không
    std::string ten_;
};

class Cho : public DongVat {
public:
    explicit Cho(std::string ten) : DongVat(std::move(ten)) {}
    void sua() const { std::cout << ten_ << ": gâu gâu\n"; }
};

int main() {
    Cho c("Lu");
    c.gioiThieu();     // thừa hưởng từ DongVat
    c.sua();
}
```

```text
Tôi là Lu
Lu: gâu gâu
```

## 7.6. Đa hình và hàm `virtual`

Sức mạnh lớn nhất của kế thừa: một con trỏ/tham chiếu tới lớp **cha** có thể trỏ tới đối tượng lớp **con**, và lời gọi hàm `virtual` sẽ chạy bản của lớp con thực sự. Đây là **đa hình** (polymorphism, "nhiều hình dạng").

```cpp
#include <iostream>
#include <memory>
#include <vector>

class DoiTuong {
public:
    virtual ~DoiTuong() = default;          // hàm huỷ ảo: bắt buộc với lớp cha đa hình
    virtual void capNhat() = 0;             // "= 0": hàm ảo thuần tuý → lớp trừu tượng
    virtual const char* ten() const { return "DoiTuong"; }
};

class Nguoi : public DoiTuong {
public:
    void capNhat() override { std::cout << "Người đi bộ\n"; }
    const char* ten() const override { return "Người"; }
};

class Xe : public DoiTuong {
public:
    void capNhat() override { std::cout << "Xe chạy\n"; }
};

int main() {
    std::vector<std::unique_ptr<DoiTuong>> canh;
    canh.push_back(std::make_unique<Nguoi>());
    canh.push_back(std::make_unique<Xe>());
    canh.push_back(std::make_unique<Nguoi>());

    for (auto& o : canh) {
        o->capNhat();                       // gọi đúng bản của lớp con
        std::cout << "  (" << o->ten() << ")\n";
    }
}
```

```text
Người đi bộ
  (Người)
Xe chạy
  (DoiTuong)
Người đi bộ
  (Người)
```

Ghi nhớ:
- `virtual` bật gọi động (chọn hàm lúc chạy theo kiểu thật của đối tượng).
- `override` ở lớp con: nhờ trình biên dịch kiểm tra thật sự đang ghi đè một hàm ảo (gõ sai tên thì báo lỗi). Luôn thêm.
- Lớp có hàm ảo thuần tuý (`= 0`) là **trừu tượng**: không tạo trực tiếp được, chỉ làm giao diện cho lớp con.
- Lớp cha đa hình **phải** có hàm huỷ `virtual`; nếu không, `delete` qua con trỏ cha không huỷ đúng phần lớp con.
- Đa hình dùng được qua **con trỏ** hoặc **tham chiếu**, không dùng qua giá trị (sao chép sẽ "cắt" mất phần lớp con — object slicing).

Trong game, mẫu này hợp cho danh sách thực thể có hành vi khác nhau mà vòng lặp chính xử lý chung (`capNhat()`, `ve()`).

## 7.7. Kế thừa hay thành phần (composition)?

Kế thừa mô tả "là một"; **thành phần** mô tả "có một": `Xe` *có* một `DongCo` — khai báo `DongCo dongCo_;` làm thành viên. Nguyên tắc kinh nghiệm: *ưu tiên thành phần hơn kế thừa*; chỉ kế thừa khi thật sự có quan hệ "là một" và cần đa hình. Kế thừa sâu nhiều tầng khiến code khó theo dõi.

## 7.8. Nạp chồng toán tử

C++ cho định nghĩa lại ý nghĩa của toán tử (`+`, `==`, `<<`, ...) cho kiểu của bạn. Hợp lý khi nghĩa tự nhiên, ví dụ vector toán học:

```cpp
#include <iostream>

struct Vec2 {
    double x = 0, y = 0;
    Vec2 operator+(const Vec2& o) const { return {x + o.x, y + o.y}; }
    Vec2 operator*(double k) const { return {x * k, y * k}; }
    bool operator==(const Vec2& o) const { return x == o.x && y == o.y; }
};

std::ostream& operator<<(std::ostream& os, const Vec2& v) {
    return os << '(' << v.x << ", " << v.y << ')';
}

int main() {
    Vec2 vitri{10, 20}, vanToc{1, -2};
    for (int i = 0; i < 3; i++) vitri = vitri + vanToc * 2;
    std::cout << vitri << '\n';
}
```

```text
(16, 8)
```

`operator<<` cho `std::ostream` cho phép in đối tượng bằng `std::cout << vec`. Chỉ nạp chồng khi ý nghĩa rõ ràng; đừng biến `+` thành thứ bất ngờ.

## 7.9. `enum class`

Kiểu liệt kê dùng cho tập giá trị cố định có tên. Dùng `enum class` (có phạm vi, không tự đổi sang số):

```cpp
#include <iostream>

enum class TrangThai { Dung, Chay, Nhay, Chet };

const char* tenTrangThai(TrangThai t) {
    switch (t) {
        case TrangThai::Dung: return "đứng";
        case TrangThai::Chay: return "chạy";
        case TrangThai::Nhay: return "nhảy";
        case TrangThai::Chet: return "chết";
    }
    return "?";
}

int main() {
    TrangThai t = TrangThai::Nhay;
    std::cout << tenTrangThai(t) << '\n';
}
```

```text
nhảy
```

## 7.10. Sao chép và di chuyển (tổng quan)

Khi bạn gán `b = a` hoặc truyền đối tượng theo giá trị, C++ gọi **hàm khởi tạo sao chép** / **toán tử gán sao chép**. Với lớp mà mọi thành viên là kiểu chuẩn (`string`, `vector`, smart pointer...), trình biên dịch tự sinh đúng — bạn không viết gì (**rule of zero**). Chỉ khi lớp tự quản lý tài nguyên thô (con trỏ `new`, handle của thư viện C) mới phải tự viết cả năm hàm (**rule of five**: huỷ, sao chép ×2, di chuyển ×2), hoặc tốt hơn là bọc tài nguyên đó trong smart pointer để không phải làm vậy. Lớp chứa `unique_ptr` tự động không sao chép được nhưng di chuyển được.

## Tóm tắt

- `struct` gộp dữ liệu; `class` thêm hàm thành viên và `private`/`public`.
- Constructor + danh sách khởi tạo; destructor; hàm `const` cho thao tác chỉ đọc.
- Kế thừa (`: public Cha`) cho quan hệ "là một"; `virtual`/`override` cho đa hình; hàm huỷ ảo ở lớp cha.
- Ưu tiên thành phần; chỉ nạp chồng toán tử khi nghĩa tự nhiên.
- `enum class` cho tập giá trị cố định.

## Bài tập

1. Viết lớp `HinhChuNhat` (rộng, cao) với `dienTich()`, `chuVi()` và kiểm tra giá trị âm trong constructor.
2. Viết lớp trừu tượng `Hinh` với `virtual double dienTich() const = 0;`, các lớp `HinhTron`, `HinhVuong`; tính tổng diện tích một `vector<unique_ptr<Hinh>>`.
3. Tạo `NhanVat` có `mau_`, hàm `nhanSatThuong(int)`, `conSong() const`; không để máu xuống dưới 0.
4. Viết `Vec2` có thêm `operator-` và hàm `do_dai()`.

[Chương sau: Template và thư viện chuẩn (STL)](docs-cpp-08-template-stl.md)
