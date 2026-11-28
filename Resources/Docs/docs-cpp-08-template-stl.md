# Chương 8: Template và thư viện chuẩn (STL)

**STL** (Standard Template Library) là bộ container, iterator và thuật toán có sẵn trong C++. Nó được xây trên **template** — cơ chế viết code một lần dùng cho nhiều kiểu. Hiểu template và STL giúp bạn không phải tự viết lại danh sách, từ điển, sắp xếp...

## 8.1. Template hàm

Chương 4 phải viết ba hàm `lonNhat` cho `int`, `double`, `string`. **Template** cho viết một lần, với `T` là kiểu "chưa biết":

```cpp
#include <iostream>
#include <string>

template <typename T>
T lonNhat(T a, T b) {
    return a > b ? a : b;
}

int main() {
    std::cout << lonNhat(3, 8) << '\n';                       // T = int
    std::cout << lonNhat(2.5, 1.5) << '\n';                   // T = double
    std::cout << lonNhat<std::string>("abc", "abd") << '\n';  // chỉ rõ T
}
```

```text
8
2.5
abd
```

Trình biên dịch **sinh** một bản hàm riêng cho mỗi kiểu được dùng (gọi là *instantiation*), nên không mất tốc độ. Kiểu được dùng phải hỗ trợ các phép toán trong thân hàm (ở đây `>`); nếu không sẽ báo lỗi biên dịch dài dằng dặc — hãy đọc dòng lỗi đầu tiên.

Đa số hàm template nằm trong **header** (Chương 11) vì trình biên dịch cần thấy thân hàm để sinh code.

## 8.2. Template lớp

Cùng ý tưởng cho lớp. Đây là một ngăn xếp nhỏ cho mọi kiểu:

```cpp
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

template <typename T>
class NganXep {
public:
    void day(const T& x) { d_.push_back(x); }
    T lay() {
        if (d_.empty()) throw std::runtime_error("ngăn xếp rỗng");
        T x = d_.back();
        d_.pop_back();
        return x;
    }
    bool rong() const { return d_.empty(); }
private:
    std::vector<T> d_;
};

int main() {
    NganXep<int> a;
    a.day(1); a.day(2); a.day(3);
    while (!a.rong()) std::cout << a.lay() << ' ';
    std::cout << '\n';

    NganXep<std::string> b;
    b.day("xin"); b.day("chào");
    std::cout << b.lay() << ' ' << b.lay() << '\n';
}
```

```text
3 2 1 
chào xin
```

`std::vector<int>` bạn đã dùng chính là một template lớp: `vector<T>`.

## 8.3. Container tuần tự

| Container | Đặc điểm | Dùng khi |
|-----------|----------|----------|
| `std::vector<T>` | mảng co giãn, truy cập `[i]` nhanh, thêm cuối nhanh | **mặc định** cho mọi danh sách |
| `std::array<T, N>` | mảng kích thước cố định | biết trước số phần tử |
| `std::deque<T>` | thêm/xoá hai đầu nhanh | hàng đợi hai đầu |
| `std::list<T>` | liên kết đôi, chèn/xoá giữa nhanh, không truy cập `[i]` | hiếm khi cần |

Lời khuyên: **bắt đầu bằng `vector`**. Nhờ các phần tử nằm liền nhau trong bộ nhớ, nó thường nhanh hơn `list` kể cả với thao tác mà lý thuyết bảo `list` ưu thế.

## 8.4. `std::map` và `std::unordered_map` — từ điển

Lưu cặp **khoá → giá trị**. `map` giữ khoá theo thứ tự sắp xếp (tìm kiếm O(log n)); `unordered_map` dùng bảng băm (tìm kiếm trung bình O(1), không có thứ tự).

```cpp
#include <iostream>
#include <map>
#include <string>
#include <unordered_map>

int main() {
    std::map<std::string, int> diem;
    diem["Lan"] = 9;
    diem["An"] = 7;
    diem["Binh"] = 8;
    diem["An"] += 1;                       // sửa

    for (const auto& [ten, d] : diem) {    // duyệt theo thứ tự khoá (A-B-Z)
        std::cout << ten << ": " << d << '\n';
    }

    if (auto it = diem.find("Cuong"); it == diem.end()) {
        std::cout << "không có Cuong\n";
    }
    std::cout << diem.count("Lan") << ' ' << diem.size() << '\n';

    std::unordered_map<char, int> tanSuat;
    for (char c : std::string("hello world")) tanSuat[c]++;
    std::cout << "l xuất hiện " << tanSuat['l'] << " lần\n";
    diem.erase("Binh");
    std::cout << diem.size() << '\n';
}
```

```text
An: 8
Binh: 8
Lan: 9
không có Cuong
1 3
l xuất hiện 3 lần
2
```

Cẩn thận: `diem["X"]` với khoá chưa có sẽ **tạo mới** mục `X` với giá trị 0. Chỉ để kiểm tra tồn tại, dùng `find` hoặc `count` (hoặc `contains` từ C++20).

## 8.5. `std::set` — tập hợp

Chứa các phần tử **không trùng**, có thứ tự (`unordered_set` cho bản băm):

```cpp
#include <iostream>
#include <set>
#include <vector>

int main() {
    std::vector<int> v = {5, 3, 5, 1, 3, 9, 1};
    std::set<int> s(v.begin(), v.end());          // lọc trùng và sắp xếp
    for (int x : s) std::cout << x << ' ';
    std::cout << '\n';
    s.insert(4);
    std::cout << std::boolalpha << (s.count(4) > 0) << ' ' << s.size() << '\n';
}
```

```text
1 3 5 9 
true 5
```

## 8.6. Stack, queue, priority_queue

Các **adaptor** bọc container khác để chỉ lộ giao diện cần thiết:

```cpp
#include <iostream>
#include <queue>
#include <stack>

int main() {
    std::stack<int> st;                  // vào sau ra trước (LIFO)
    st.push(1); st.push(2); st.push(3);
    std::cout << st.top() << '\n';
    st.pop();

    std::queue<int> q;                   // vào trước ra trước (FIFO)
    q.push(1); q.push(2); q.push(3);
    std::cout << q.front() << '\n';
    q.pop();
    std::cout << q.size() << '\n';

    std::priority_queue<int> pq;         // lớn nhất ra trước
    pq.push(5); pq.push(9); pq.push(2);
    std::cout << pq.top() << '\n';
}
```

```text
3
1
2
9
```

Ngăn xếp ứng với "hoàn tác" (undo); hàng đợi ứng với danh sách chờ; hàng đợi ưu tiên ứng với thuật toán tìm đường, lập lịch sự kiện.

## 8.7. Iterator

**Iterator** là "con trỏ tổng quát" trỏ vào một phần tử của container, cho phép duyệt mọi container cùng một cách: `begin()` (phần tử đầu), `end()` (sau phần tử cuối), `++it` (sang phần tử kế), `*it` (giá trị).

```cpp
#include <iostream>
#include <list>
#include <vector>

int main() {
    std::vector<int> v = {1, 2, 3};
    for (auto it = v.begin(); it != v.end(); ++it) std::cout << *it << ' ';
    std::cout << '\n';

    std::list<std::string> l = {"a", "b", "c"};
    for (auto it = l.begin(); it != l.end(); ++it) std::cout << *it;
    std::cout << '\n';

    // Xoá phần tử khi duyệt: erase trả iterator tiếp theo
    std::vector<int> w = {1, 2, 3, 4, 5, 6};
    for (auto it = w.begin(); it != w.end(); ) {
        if (*it % 2 == 0) it = w.erase(it);
        else ++it;
    }
    for (int x : w) std::cout << x << ' ';
    std::cout << '\n';
}
```

```text
1 2 3 
abc
1 3 5 
```

Range-for chính là cách viết gọn của vòng duyệt iterator. Lưu ý: sau khi `insert`/`erase`/`push_back` có thể làm iterator cũ **mất hiệu lực** (vector cấp phát lại bộ nhớ), nên không dùng tiếp iterator cũ.

## 8.8. Lambda: hàm ẩn danh

**Lambda** là hàm không tên viết ngay tại chỗ, rất hay đi cùng thuật toán STL.

```text
[bắt_biến](tham_số) { thân }
```

Phần `[...]` (capture) quyết định lambda "thấy" biến nào bên ngoài: `[]` không gì; `[x]` bản sao của `x`; `[&x]` tham chiếu tới `x`; `[=]` sao chép mọi thứ dùng; `[&]` tham chiếu mọi thứ dùng.

```cpp
#include <algorithm>
#include <iostream>
#include <string>
#include <vector>

struct SV { std::string ten; double diem; };

int main() {
    std::vector<SV> ds = {{"Lan", 8.5}, {"An", 9.0}, {"Binh", 7.0}};

    // Sắp xếp giảm dần theo điểm
    std::sort(ds.begin(), ds.end(), [](const SV& a, const SV& b) { return a.diem > b.diem; });
    for (const auto& s : ds) std::cout << s.ten << ' ';
    std::cout << '\n';

    // Đếm số người đạt >= 8, ngưỡng lấy từ biến ngoài
    double nguong = 8.0;
    int dat = std::count_if(ds.begin(), ds.end(), [nguong](const SV& s) { return s.diem >= nguong; });
    std::cout << dat << '\n';

    // Duyệt và thay đổi
    std::for_each(ds.begin(), ds.end(), [](SV& s) { s.diem += 0.5; });
    std::cout << ds[0].diem << '\n';

    auto binhPhuong = [](int x) { return x * x; };   // lambda lưu vào biến
    std::cout << binhPhuong(9) << '\n';
}
```

```text
An Lan Binh 
2
9.5
81
```

## 8.9. Thuật toán thường dùng

Ngoài những cái đã gặp ở Chương 5:

| Hàm | Công dụng |
|-----|-----------|
| `std::count(b, e, x)` / `count_if(b, e, pred)` | đếm |
| `std::find_if(b, e, pred)` | tìm phần tử đầu thoả điều kiện |
| `std::any_of` / `all_of` / `none_of` | kiểm tra điều kiện |
| `std::remove_if` + `erase` | xoá theo điều kiện (idiom erase–remove) |
| `std::transform(b, e, out, f)` | biến đổi từng phần tử |
| `std::min_element` / `max_element` | tìm nhỏ/lớn nhất |
| `std::iota(b, e, v0)` | điền dãy tăng dần (`<numeric>`) |
| `std::unique` | bỏ phần tử trùng liên tiếp |

```cpp
#include <algorithm>
#include <iostream>
#include <numeric>
#include <vector>

int main() {
    std::vector<int> v(8);
    std::iota(v.begin(), v.end(), 1);                  // 1..8

    v.erase(std::remove_if(v.begin(), v.end(), [](int x) { return x % 3 == 0; }), v.end());
    for (int x : v) std::cout << x << ' ';
    std::cout << '\n';

    std::vector<int> b(v.size());
    std::transform(v.begin(), v.end(), b.begin(), [](int x) { return x * 10; });
    for (int x : b) std::cout << x << ' ';
    std::cout << '\n';

    std::cout << std::boolalpha
              << std::any_of(v.begin(), v.end(), [](int x) { return x > 7; }) << ' '
              << std::all_of(v.begin(), v.end(), [](int x) { return x > 0; }) << '\n';
}
```

```text
1 2 4 5 7 8 
10 20 40 50 70 80 
true true
```

Từ C++20 còn có thư viện **ranges** (`std::ranges::sort(v)`, `views::filter`...) viết gọn hơn, đã có trong Clang bản mới.

## 8.10. `pair`, `tuple`, `optional` — kiểu tiện ích

- `std::pair<A, B>` — hai giá trị; `std::make_pair`, truy cập `.first`, `.second`. (Phần tử của `map` chính là `pair`.)
- `std::tuple<A, B, C...>` — nhiều giá trị; truy cập `std::get<0>(t)` hoặc structured binding.
- `std::optional<T>` (C++17) — "có hoặc không có giá trị", thay cho việc trả mã đặc biệt như −1.

```cpp
#include <iostream>
#include <optional>
#include <string>
#include <tuple>

std::optional<int> timViTri(const std::string& s, char c) {
    auto p = s.find(c);
    if (p == std::string::npos) return std::nullopt;
    return static_cast<int>(p);
}

int main() {
    auto t = std::make_tuple(1, "Lan", 9.5);
    auto [id, ten, diem] = t;
    std::cout << id << ' ' << ten << ' ' << diem << '\n';

    if (auto v = timViTri("hello", 'l')) std::cout << "tìm thấy ở " << *v << '\n';
    std::cout << timViTri("hello", 'z').value_or(-1) << '\n';
}
```

```text
1 Lan 9.5
tìm thấy ở 2
-1
```

## 8.11. Chọn container nào?

1. Cần danh sách: **`vector`**.
2. Cần tìm nhanh theo khoá: `unordered_map` (hoặc `map` khi cần thứ tự).
3. Cần tập không trùng: `set` / `unordered_set`.
4. Cần LIFO / FIFO: `stack` / `queue`.
5. Kích thước cố định, biết lúc biên dịch: `array`.

## Tóm tắt

- Template (`template <typename T>`) cho code dùng chung nhiều kiểu, được sinh lúc biên dịch.
- `vector` mặc định; `map`/`unordered_map` cho khoá → giá trị; `set`; `stack`/`queue`.
- Iterator duyệt mọi container; thuật toán `<algorithm>` làm việc trên khoảng `[begin, end)`.
- Lambda `[capture](tham_số){...}` làm đối số cho thuật toán.
- `pair`, `tuple`, `optional` cho các tình huống nhỏ.

## Bài tập

1. Đếm tần suất mỗi từ trong một đoạn văn bằng `unordered_map<string,int>`, in ra theo thứ tự giảm dần của tần suất.
2. Viết template `tong(const std::vector<T>&)` trả về tổng các phần tử.
3. Sắp xếp một `vector<SV>` theo tên rồi theo điểm khi tên trùng, dùng lambda so sánh hai khoá.
4. Dùng `priority_queue` để luôn lấy ra công việc có độ ưu tiên cao nhất.

[Chương sau: Xử lý lỗi, file và stream](docs-cpp-09-loi-file-stream.md)
