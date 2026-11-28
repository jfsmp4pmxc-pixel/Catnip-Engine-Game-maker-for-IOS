# Chương 3: Rẽ nhánh và vòng lặp

Chương trình chỉ chạy tuần tự từ trên xuống thì rất hạn chế. **Cấu trúc điều khiển** cho phép chương trình *quyết định* (rẽ nhánh) và *lặp lại* (vòng lặp). Hai thứ này cùng với biến tạo nên gần như mọi thuật toán.

## 3.1. Câu lệnh `if` / `else`

```text
if (điều_kiện) {
    // chạy khi điều_kiện đúng
} else if (điều_kiện_khác) {
    // chạy khi điều kiện trên sai nhưng điều_kiện_khác đúng
} else {
    // chạy khi tất cả đều sai
}
```

Điều kiện là một biểu thức `bool` (hoặc số: 0 là sai, khác 0 là đúng). Các nhánh được kiểm tra **từ trên xuống**, nhánh đầu tiên đúng được chạy và những nhánh sau bị bỏ qua.

```cpp
#include <iostream>

int main() {
    int diem = 7;

    if (diem >= 9) {
        std::cout << "Xuất sắc\n";
    } else if (diem >= 7) {
        std::cout << "Khá\n";
    } else if (diem >= 5) {
        std::cout << "Trung bình\n";
    } else {
        std::cout << "Yếu\n";
    }
}
```

```text
Khá
```

Luôn dùng ngoặc nhọn `{ }` ngay cả khi nhánh chỉ có một lệnh. Nếu bỏ, chỉ lệnh *đầu tiên* thuộc nhánh — nguồn gốc của rất nhiều lỗi khi sau này thêm lệnh mà quên thêm ngoặc:

```cpp
if (x > 0)
    std::cout << "dương\n";
    std::cout << "luôn in dòng này\n";   // KHÔNG thuộc if dù thụt lề giống thế
```

C++17 cho phép khai báo biến ngay trong `if`, giới hạn phạm vi gọn gàng:

```cpp
if (int du = n % 2; du == 0) { /* chẵn */ } else { /* lẻ, du == 1 */ }
```

## 3.2. Toán tử điều kiện `?:`

`điều_kiện ? giá_trị_nếu_đúng : giá_trị_nếu_sai` là biểu thức (có giá trị), tiện cho lựa chọn ngắn:

```cpp
#include <iostream>

int main() {
    int a = 12, b = 20;
    int lon = (a > b) ? a : b;
    std::cout << "Lớn hơn: " << lon << '\n';
    std::cout << (a % 2 == 0 ? "a chẵn" : "a lẻ") << '\n';
}
```

```text
Lớn hơn: 20
a chẵn
```

Đừng lồng nhiều `?:` — dùng `if` cho dễ đọc.

## 3.3. Câu lệnh `switch`

Khi so sánh một biểu thức **nguyên / ký tự / enum** với nhiều giá trị cố định, `switch` gọn hơn chuỗi `else if`:

```cpp
#include <iostream>

int main() {
    int thu = 3;
    switch (thu) {
        case 2:  std::cout << "Thứ hai\n"; break;
        case 3:  std::cout << "Thứ ba\n";  break;
        case 7:
        case 8:  std::cout << "Cuối tuần\n"; break;
        default: std::cout << "Không hợp lệ\n"; break;
    }
}
```

```text
Thứ ba
```

Điểm cần nhớ:
- `break` thoát khỏi `switch`. **Thiếu `break`** thì chương trình chạy tiếp sang `case` kế tiếp (gọi là *rơi xuống*, fall-through) — thường là lỗi. Ở ví dụ, `case 7:` và `case 8:` cố ý dùng chung một nhánh.
- `switch` không dùng được với chuỗi `std::string` hay số thực.
- Luôn có `default` để xử lý giá trị lạ.
- Muốn khai báo biến trong `case`, bao bằng `{ }`.

## 3.4. Vòng lặp `while`

Lặp **khi điều kiện còn đúng**. Điều kiện được kiểm tra *trước* mỗi lần lặp, nên có thể không chạy lần nào.

```cpp
#include <iostream>

int main() {
    int n = 5;
    long long giaiThua = 1;
    while (n > 1) {
        giaiThua *= n;
        n--;
    }
    std::cout << "5! = " << giaiThua << '\n';
}
```

```text
5! = 120
```

Nếu điều kiện không bao giờ sai, ta có **vòng lặp vô hạn** (chương trình "đơ"). Bấm nút dừng của console để thoát. Ví dụ `while (true) { ... }` là vòng vô hạn *có chủ ý*, thoát bằng `break`.

## 3.5. `do ... while`

Giống `while` nhưng kiểm tra điều kiện **sau** mỗi lần lặp, nên thân vòng luôn chạy ít nhất một lần — hợp với kiểu "nhập cho đến khi hợp lệ":

```cpp
#include <iostream>

int main() {
    int so;
    do {
        std::cout << "Nhập số dương: ";
        std::cin >> so;
    } while (so <= 0 && std::cin);   // dừng nếu hết dữ liệu nhập
    std::cout << "Bạn nhập " << so << '\n';
}
```

## 3.6. Vòng lặp `for`

Dùng khi biết trước số lần lặp. Gồm ba phần trong ngoặc, cách nhau bằng `;`:

```text
for (khởi_tạo; điều_kiện; bước_nhảy) { thân }
```

Thứ tự: chạy `khởi_tạo` một lần → kiểm tra `điều_kiện` → chạy thân → chạy `bước_nhảy` → quay lại kiểm tra điều kiện.

```cpp
#include <iostream>

int main() {
    for (int i = 1; i <= 5; i++) {
        std::cout << i << ' ';
    }
    std::cout << '\n';

    int tong = 0;
    for (int i = 1; i <= 100; i++) tong += i;
    std::cout << "Tổng 1..100 = " << tong << '\n';

    for (int i = 10; i > 0; i -= 3) std::cout << i << ' ';   // 10 7 4 1
    std::cout << '\n';
}
```

```text
1 2 3 4 5 
Tổng 1..100 = 5050
10 7 4 1 
```

Biến `i` khai báo trong `for` chỉ tồn tại bên trong vòng lặp.

### Lỗi lệch một (off-by-one)

Lỗi hay gặp nhất: dùng `<` thay cho `<=` hoặc ngược lại. Quy ước phổ biến trong C++ là đếm từ 0 và dùng `<`: `for (int i = 0; i < n; i++)` lặp đúng `n` lần với `i` = 0…n−1. Chỉ số của mảng (Chương 5) cũng bắt đầu từ 0 nên quy ước này khớp.

## 3.7. `break` và `continue`

- `break` — thoát hẳn vòng lặp chứa nó.
- `continue` — bỏ qua phần còn lại của lần lặp hiện tại và sang lần kế tiếp.

```cpp
#include <iostream>

int main() {
    // In các số lẻ nhỏ hơn 10, dừng khi gặp 7
    for (int i = 1; i < 10; i++) {
        if (i % 2 == 0) continue;     // bỏ qua số chẵn
        if (i == 7) break;            // dừng hẳn
        std::cout << i << ' ';
    }
    std::cout << '\n';
}
```

```text
1 3 5 
```

Chúng chỉ tác động tới vòng lặp **trong cùng**. Thoát khỏi nhiều vòng lồng nhau thường dùng một biến cờ `bool` hoặc đưa vòng lặp vào hàm rồi `return`.

## 3.8. Vòng lặp lồng nhau

Một vòng lặp nằm trong thân vòng khác. Thân trong chạy *đủ một lượt* cho mỗi lần lặp của vòng ngoài.

```cpp
#include <iostream>

int main() {
    // Bảng cửu chương 2..4, nhân 1..5
    for (int a = 2; a <= 4; a++) {
        for (int b = 1; b <= 5; b++) {
            std::cout << a * b << '\t';
        }
        std::cout << '\n';
    }

    // Tam giác sao
    for (int dong = 1; dong <= 4; dong++) {
        for (int sao = 0; sao < dong; sao++) std::cout << '*';
        std::cout << '\n';
    }
}
```

```text
2	4	6	8	10	
3	6	9	12	15	
4	8	12	16	20	
*
**
***
****
```

Số lần chạy thân trong cùng là tích số lần lặp của các vòng; ba vòng lồng 1000 lần mỗi vòng là một tỉ lần — chậm. Hãy cân nhắc khi viết thuật toán.

## 3.9. Một số bài toán mẫu

### Kiểm tra số nguyên tố

```cpp
#include <iostream>

bool laNguyenTo(int n) {
    if (n < 2) return false;
    for (int i = 2; i * i <= n; i++) {      // chỉ cần thử tới căn bậc hai của n
        if (n % i == 0) return false;
    }
    return true;
}

int main() {
    for (int n = 1; n <= 30; n++) {
        if (laNguyenTo(n)) std::cout << n << ' ';
    }
    std::cout << '\n';
}
```

```text
2 3 5 7 11 13 17 19 23 29 
```

(Hàm `laNguyenTo` dùng cú pháp ở Chương 4; ở đây chỉ cần đọc để thấy vòng lặp và `return` sớm.)

### FizzBuzz

In 1 đến 15; bội của 3 in `Fizz`, bội của 5 in `Buzz`, bội của cả hai in `FizzBuzz`. Thứ tự các nhánh quan trọng: phải xét "cả hai" trước.

```cpp
#include <iostream>

int main() {
    for (int i = 1; i <= 15; i++) {
        if (i % 15 == 0)      std::cout << "FizzBuzz";
        else if (i % 3 == 0)  std::cout << "Fizz";
        else if (i % 5 == 0)  std::cout << "Buzz";
        else                  std::cout << i;
        std::cout << ' ';
    }
    std::cout << '\n';
}
```

```text
1 2 Fizz 4 Buzz Fizz 7 8 Fizz Buzz 11 Fizz 13 14 FizzBuzz 
```

### Số ngẫu nhiên (đoán số)

C++ hiện đại dùng `<random>`: một **bộ sinh** (engine) tạo bit ngẫu nhiên, một **phân phối** (distribution) biến chúng thành số trong khoảng mong muốn.

```cpp
#include <iostream>
#include <random>

int main() {
    std::mt19937 gen{std::random_device{}()};          // hạt giống ngẫu nhiên
    std::uniform_int_distribution<int> dist(1, 100);   // đều trong [1, 100]
    int bi_mat = dist(gen);

    int lan = 0, doan;
    do {
        std::cout << "Đoán (1-100): ";
        if (!(std::cin >> doan)) break;                // hết dữ liệu: thoát
        lan++;
        if (doan < bi_mat)      std::cout << "Cao hơn!\n";
        else if (doan > bi_mat) std::cout << "Thấp hơn!\n";
    } while (doan != bi_mat);

    if (doan == bi_mat) std::cout << "Đúng sau " << lan << " lần.\n";
}
```

Muốn dãy số lặp lại được (để gỡ lỗi), thay `std::random_device{}()` bằng một số cố định như `12345`.

## Tóm tắt

- `if / else if / else` chọn nhánh; luôn dùng `{ }`.
- `switch` cho so sánh nhiều giá trị nguyên; nhớ `break`.
- `while` (kiểm trước), `do...while` (chạy ít nhất một lần), `for` (biết số lần).
- `break` thoát vòng; `continue` sang lần tiếp.
- Đếm từ 0 và dùng `<` để tránh lệch một.

## Bài tập

1. In ra tất cả số từ 1 đến 100 chia hết cho cả 4 và 6.
2. Tính tổng các chữ số của một số nguyên dương (dùng `% 10` và `/ 10` trong `while`).
3. In hình chữ nhật rỗng cỡ 5×8 bằng các ký tự `#` (chỉ viền ngoài).
4. (Khó hơn) In dãy Fibonacci các số nhỏ hơn 1000.

[Chương sau: Hàm](docs-cpp-04-ham.md)
