# Chương 1: Giới thiệu C++ và chương trình đầu tiên

Chương này trả lời ba câu hỏi: C++ là gì, một chương trình C++ đi từ dòng chữ bạn gõ đến kết quả hiện trên màn hình như thế nào, và làm sao chạy chương trình đó trong Catnip Engine. Cuối chương bạn sẽ viết, chạy và hiểu từng dòng của một chương trình hoàn chỉnh.

## 1.1. C++ là gì?

**C++** là một **ngôn ngữ lập trình** (programming language): một cách viết có quy tắc chặt chẽ để ra lệnh cho máy tính. Nó do Bjarne Stroustrup bắt đầu phát triển từ đầu thập niên 1980 như phần mở rộng của ngôn ngữ C, và từ đó được chuẩn hoá nhiều lần (C++11, C++14, C++17, C++20, C++23...). Catnip dùng chuẩn **C++20** mặc định.

C++ là ngôn ngữ **biên dịch** (compiled language). Điều này khác với Lua (ngôn ngữ trong game LÖVE): Lua được một chương trình thông dịch đọc và chạy từng dòng, còn C++ phải được một chương trình tên **trình biên dịch** (compiler) dịch toàn bộ sang **mã máy** (machine code) trước, rồi CPU mới chạy mã máy đó.

Vì sao người ta vẫn dùng C++ nhiều năm như vậy?

- **Nhanh:** mã máy sinh ra gần như tối ưu; game engine, trình duyệt, hệ điều hành, phần mềm đồ hoạ đều có nhiều phần viết bằng C++.
- **Kiểm soát được bộ nhớ:** bạn quyết định dữ liệu nằm ở đâu và sống bao lâu (Chương 6).
- **Kiểm tra kiểu chặt chẽ:** nhiều lỗi bị bắt ngay lúc biên dịch, trước khi chương trình chạy.
- **Hệ sinh thái lớn:** thư viện chuẩn phong phú, và hầu hết thư viện đồ hoạ/âm thanh (như SDL, thư viện nền của LÖVE) đều dùng được từ C++.

Cái giá phải trả: C++ khó hơn nhiều ngôn ngữ khác và cho phép bạn tự bắn vào chân mình (truy cập sai bộ nhớ, chia cho 0...). Giáo trình này đi chậm, từng bước, để bạn hiểu *vì sao* chứ không chỉ *làm thế nào*.

## 1.2. Quy trình: viết, biên dịch, chạy

Từ mã nguồn đến chương trình chạy được có ba bước:

| Bước | Ai làm | Kết quả |
|------|--------|---------|
| 1. **Viết** mã nguồn | Bạn, trong trình soạn thảo | File văn bản `.cpp` |
| 2. **Biên dịch** (compile) | Trình biên dịch Clang++ | Mã máy (hoặc thông báo lỗi) |
| 3. **Chạy** (run) | CPU của thiết bị | Kết quả in ra |

Bước 2 thực ra gồm vài giai đoạn nhỏ: *tiền xử lý* (xử lý các dòng bắt đầu bằng `#`, ví dụ dán nội dung thư viện vào), *biên dịch* thành mã máy từng file, rồi *liên kết* (link) các file lại thành một chương trình hoàn chỉnh. Bạn chưa cần nhớ chi tiết; chỉ cần biết hai loại lỗi:

- **Lỗi biên dịch** (compile error): bạn viết sai quy tắc ngôn ngữ. Chương trình **không** được tạo ra, và trình biên dịch báo dòng bị lỗi.
- **Lỗi lúc chạy** (runtime error) hoặc lỗi logic: chương trình biên dịch được nhưng làm sai, hoặc sập giữa chừng.

> Trong Catnip, cả ba bước diễn ra khi bạn bấm **▶︎ Chạy**. Mỗi lần chạy, mọi file `.cpp` trong dự án được biên dịch lại từ đầu, nên chương trình lớn sẽ chờ lâu hơn chương trình nhỏ.

## 1.3. Chương trình đầu tiên

Tạo một dự án loại **C++** trong Catnip. Dự án mới có sẵn file `main.cpp`. Hãy thay nội dung bằng:

```cpp
#include <iostream>

int main() {
    std::cout << "Xin chào, C++!" << std::endl;
    return 0;
}
```

Bấm **▶︎ Chạy**. Console hiện:

```text
Xin chào, C++!
```

Giải thích từng dòng:

1. `#include <iostream>` — dòng **chỉ thị tiền xử lý** (preprocessor directive). Nó bảo trình biên dịch "hãy dán nội dung thư viện `iostream` vào đây". `iostream` (input/output stream, luồng nhập/xuất) chứa những thứ để in ra màn hình và đọc từ bàn phím. Không có dòng này thì `std::cout` không tồn tại.
2. `int main() { ... }` — định nghĩa **hàm** `main`. Mọi chương trình C++ bắt đầu chạy từ `main`. `int` nghĩa là hàm trả về một số nguyên; cặp ngoặc `()` là danh sách tham số (ở đây trống); cặp ngoặc nhọn `{ }` bao thân hàm.
3. `std::cout << "Xin chào, C++!" << std::endl;` — một **câu lệnh** (statement). `std::cout` là luồng xuất chuẩn (console). Toán tử `<<` "đẩy" dữ liệu vào luồng. `"Xin chào, C++!"` là một **chuỗi ký tự** (string literal). `std::endl` xuống dòng và đẩy hết chữ ra màn hình. Câu lệnh kết thúc bằng dấu chấm phẩy `;`.
4. `return 0;` — kết thúc `main` và báo cho hệ điều hành "chương trình chạy thành công" (0 = không lỗi).

Tiền tố `std::` nghĩa là "trong không gian tên `std`" — nơi thư viện chuẩn C++ đặt mọi thứ của nó. Mục 1.7 nói kỹ hơn.

> **Ghi nhớ:** C++ phân biệt chữ hoa và chữ thường. `Main`, `MAIN` và `main` là ba tên khác nhau; chỉ có `main` là điểm khởi đầu.

## 1.4. In nhiều thứ, xuống dòng

Có thể nối nhiều giá trị trong một câu lệnh bằng nhiều `<<`. Ký tự `'\n'` cũng xuống dòng và thường được ưa dùng hơn `std::endl` vì không ép đẩy bộ đệm mỗi lần (nhanh hơn khi in nhiều).

```cpp
#include <iostream>

int main() {
    std::cout << "Tuổi của tôi là " << 20 << '\n';
    std::cout << "2 + 3 = " << 2 + 3 << '\n';
    std::cout << "Dòng 1\nDòng 2\n";
    std::cout << "Dấu tab:\tđây\n";
    std::cout << "Dấu ngoặc kép: \"abc\" và gạch chéo ngược: \\\n";
}
```

Kết quả:

```text
Tuổi của tôi là 20
2 + 3 = 5
Dòng 1
Dòng 2
Dấu tab:	đây
Dấu ngoặc kép: "abc" và gạch chéo ngược: \
```

Bảng các **chuỗi thoát** (escape sequence) hay dùng:

| Viết | Ý nghĩa |
|------|---------|
| `\n` | xuống dòng |
| `\t` | dấu tab |
| `\"` | dấu ngoặc kép `"` |
| `\\` | dấu gạch chéo ngược `\` |
| `\'` | dấu nháy đơn `'` |

Lưu ý hai điểm trong ví dụ trên: (1) hàm `main` **được phép bỏ** `return 0;` — nếu không viết, trình biên dịch tự coi như `return 0;`; (2) `2 + 3` trong câu lệnh thứ hai được *tính* trước rồi mới in ra `5`, vì nó nằm ngoài dấu ngoặc kép.

## 1.5. Nhập từ bàn phím với `cin`

Chương trình thú vị hơn khi tương tác với người dùng. `std::cin` là luồng nhập chuẩn, dùng toán tử `>>` để *rút* dữ liệu ra khỏi luồng.

```cpp
#include <iostream>
#include <string>

int main() {
    std::string ten;
    int tuoi;

    std::cout << "Bạn tên gì? ";
    std::cin >> ten;
    std::cout << "Bạn bao nhiêu tuổi? ";
    std::cin >> tuoi;

    std::cout << "Chào " << ten << ", sang năm bạn " << tuoi + 1 << " tuổi.\n";
}
```

Ở dòng `std::string ten;` ta **khai báo biến** `ten` kiểu `std::string` (chuỗi), và `int tuoi;` khai báo biến số nguyên. Biến được giải thích kỹ ở Chương 2; hiện tại hãy hiểu nó là "cái hộp có tên để chứa một giá trị".

**Cách gõ trong console Catnip:** khi chương trình dừng ở `cin`, hãy chạm vào **ô nhập** ở dưới cửa sổ console, gõ dữ liệu rồi bấm **Enter** để gửi. Với ví dụ trên, gõ `Lan` rồi Enter, sau đó gõ `19` rồi Enter. Console hiện (phần bạn gõ in đậm trong thực tế, ở đây ghi thường):

```text
Bạn tên gì? Lan
Bạn bao nhiêu tuổi? 19
Chào Lan, sang năm bạn 20 tuổi.
```

### `cin >>` dừng ở khoảng trắng

`std::cin >> ten` chỉ đọc đến chỗ có **khoảng trắng** (dấu cách, tab, xuống dòng). Nếu bạn gõ `Nguyễn Lan`, biến `ten` chỉ nhận `Nguyễn`, còn `Lan` vẫn nằm trong luồng và bị `cin >> tuoi` đọc tiếp, dẫn tới lỗi. Để đọc cả dòng có dấu cách, dùng `std::getline`:

```cpp
#include <iostream>
#include <string>

int main() {
    std::string hoTen;
    std::cout << "Họ và tên: ";
    std::getline(std::cin, hoTen);
    std::cout << "Xin chào " << hoTen << "!\n";
}
```

Gõ `Nguyễn Văn Lan` rồi Enter:

```text
Họ và tên: Nguyễn Văn Lan
Xin chào Nguyễn Văn Lan!
```

> **Cạm bẫy kinh điển:** trộn `cin >>` rồi `getline`. Sau `cin >> tuoi`, ký tự xuống dòng (do bạn bấm Enter) vẫn còn trong luồng; `getline` đọc ngay ký tự đó và trả về chuỗi rỗng. Cách chữa nằm ở Chương 5 (mục `getline`).

### Khi bàn phím hết dữ liệu

Nút **Gửi EOF** (End Of File, hết dữ liệu) trên console đóng luồng nhập, giống Ctrl-D trên máy tính. Khi đó `cin` báo "không đọc được nữa". Bạn sẽ dùng điều này để đọc "cho đến hết" ở các chương sau.

## 1.6. Lỗi biên dịch trông như thế nào

Thử bỏ dấu chấm phẩy ở câu lệnh đầu tiên (ví dụ này **cố ý sai**):

```text
#include <iostream>

int main() {
    std::cout << "Xin chào"
    return 0;
}
```

Khi bấm Chạy, console hiện thông báo lỗi do Clang++ sinh ra thay vì kết quả chương trình, ví dụ:

```text
main.cpp:4:29: error: expected ';' after expression
    std::cout << "Xin chào"
                           ^
                           ;
```

Cách đọc: `main.cpp:4:29` là **file, dòng, cột** nơi trình biên dịch nhận ra vấn đề; `error:` là loại thông báo; phần còn lại giải thích ("thiếu `;` sau biểu thức"); dưới đó trình biên dịch trích dòng mã, đánh dấu vị trí bằng `^` và gợi ý sửa. Lưu ý nó báo ở chỗ *nó nhận ra* lỗi, nên đôi khi dòng thật sự sai nằm ngay **trên** dòng được báo.

Ba thói quen khi gặp lỗi biên dịch:

1. **Đọc lỗi đầu tiên.** Một lỗi có thể kéo theo hàng chục lỗi sau; sửa lỗi đầu rồi chạy lại.
2. **Nhìn dòng được báo và dòng ngay trước nó.** Thiếu `;`, thiếu `)` hay `}` thường hiện ra ở dòng kế tiếp.
3. **Đọc từ khoá trong thông báo:** `expected` (mong đợi một thứ), `undeclared identifier` (dùng tên chưa khai báo, thường do gõ sai tên hoặc quên `#include`), `no matching function` (gọi hàm sai kiểu tham số).

Thông báo lỗi chính xác có thể khác đôi chút giữa các phiên bản Clang, nhưng bố cục luôn như trên. Cũng có loại **cảnh báo** (`warning:`): chương trình vẫn chạy được nhưng có chỗ đáng ngờ; đừng bỏ qua chúng.

## 1.7. Cấu trúc một chương trình và chú thích

Một chương trình C++ đơn giản thường có các phần sau, theo thứ tự từ trên xuống:

```cpp
// 1. Các chỉ thị #include (thư viện cần dùng)
#include <iostream>
#include <string>

// 2. Khai báo toàn cục: hằng, hàm của bạn...
const int SO_LAN = 3;

void chaoMung(const std::string& ten) {
    std::cout << "Chào " << ten << "!\n";
}

// 3. Hàm main: điểm bắt đầu
int main() {
    for (int i = 0; i < SO_LAN; i++) {
        chaoMung("bạn");
    }
    return 0;
}
```

Kết quả:

```text
Chào bạn!
Chào bạn!
Chào bạn!
```

Đừng lo nếu `const`, `void`, `for` còn lạ: ba chương tiếp theo sẽ giải thích từng cái. Điều cần nhìn thấy ở đây là *bố cục*: `#include` trước, hàm phụ ở giữa, `main` ở cuối. Trình biên dịch đọc từ trên xuống, nên một hàm phải được **khai báo trước** chỗ dùng nó.

### Chú thích (comment)

**Chú thích** là chữ dành cho người đọc; trình biên dịch bỏ qua hoàn toàn.

```cpp
#include <iostream>

int main() {
    // Đây là chú thích một dòng: từ // đến hết dòng
    std::cout << "A\n"; // chú thích cũng có thể nằm sau câu lệnh

    /* Đây là chú thích nhiều dòng.
       Nó bắt đầu bằng slash-sao
       và kết thúc bằng sao-slash. */
    std::cout << "B\n";

    // std::cout << "C\n";   <- câu lệnh bị "vô hiệu hoá" bằng chú thích
}
```

Kết quả:

```text
A
B
```

Chú thích có hai công dụng chính: giải thích **vì sao** bạn làm vậy (đừng chỉ lặp lại *cái gì*), và tạm tắt một đoạn code khi thử nghiệm. Chú thích `/* ... */` **không lồng nhau được**: gặp `*/` đầu tiên là kết thúc, nên đừng dùng nó để tắt đoạn code đã chứa chú thích kiểu này.

## 1.8. `using namespace std;` và vì sao nên cẩn thận

Viết `std::` trước mỗi `cout`, `string`, `endl` hơi dài. Nhiều sách và bài mẫu dùng một dòng tắt:

```cpp
#include <iostream>
#include <string>
using namespace std;

int main() {
    string ten = "Mèo";
    cout << "Xin chào " << ten << "\n";
}
```

Kết quả:

```text
Xin chào Mèo
```

Dòng `using namespace std;` nói: "mọi tên trong `std` có thể dùng không cần tiền tố". Chạy tốt với chương trình ngắn, nhưng có hai vấn đề khi dự án lớn dần:

1. **Xung đột tên.** Thư viện chuẩn có rất nhiều tên thông dụng (`count`, `distance`, `size`, `max`, `min`, `list`, `map`...). Nếu bạn tự đặt hàm hay biến trùng tên, có thể gặp lỗi mơ hồ hoặc, tệ hơn, chương trình âm thầm gọi nhầm hàm.
2. **Lan sang file khác.** Nếu bạn viết `using namespace std;` trong một file **header** (`.hpp`), mọi file `#include` nó đều bị ảnh hưởng mà người viết file đó không hay biết. Đây là điều **không bao giờ nên làm** trong header.

Ví dụ xung đột có thật (ví dụ này **cố ý lỗi**): trong C++17 trở lên, `std::size` là một hàm của thư viện chuẩn.

```text
#include <iostream>
#include <vector>
using namespace std;

int size = 10;   // biến toàn cục của bạn

int main() {
    vector<int> v = {1, 2, 3};
    cout << size << "\n";   // size nào? ::size hay std::size?
}
```

Trình biên dịch báo `reference to 'size' is ambiguous` (tham chiếu tới `size` mơ hồ), vì cả hai cùng hợp lệ.

Lời khuyên của giáo trình này:

- Trong **file header**: không bao giờ dùng `using namespace std;`.
- Trong file `.cpp` ngắn để học: dùng được, nhưng hãy tập viết `std::` cho quen.
- Lựa chọn trung gian tốt: chỉ đưa vào đúng thứ cần, ví dụ `using std::cout;` và `using std::string;`, đặt trong hàm hoặc đầu file `.cpp`.

Từ chương sau, các ví dụ dùng `std::` đầy đủ để bạn thấy tên nào thuộc thư viện chuẩn.

## 1.9. Dự án nhiều file trong Catnip

Khi chương trình lớn lên, nên tách ra nhiều file. Catnip biên dịch **mọi** file `.cpp` trong dự án và chạy `main.cpp` sau cùng. Ví dụ hai file:

`tienich.hpp` (file **header**: chỉ *khai báo* hàm):

```text
#pragma once
int binhPhuong(int x);
```

`tienich.cpp` (*định nghĩa* hàm):

```text
#include "tienich.hpp"

int binhPhuong(int x) {
    return x * x;
}
```

`main.cpp`:

```text
#include <iostream>
#include "tienich.hpp"

int main() {
    std::cout << binhPhuong(7) << "\n";
}
```

Kết quả: `49`. Ba điểm cần nhớ:

- Header của bạn include bằng **dấu ngoặc kép** `"tienich.hpp"`, header chuẩn bằng **ngoặc nhọn** `<iostream>`.
- `#pragma once` ngăn một header bị dán hai lần vào cùng một file.
- Thư mục dự án đã nằm sẵn trong đường tìm header của Catnip, nên chỉ cần ghi tên file.

## 1.10. Lỗi thường gặp ở chương này

| Triệu chứng | Nguyên nhân thường gặp |
|-------------|-----------------------|
| `expected ';'` | Quên `;` cuối câu lệnh |
| `use of undeclared identifier 'cout'` | Quên `#include <iostream>` hoặc quên `std::` |
| `expected '}'` ở cuối file | Mở `{` mà không đóng; đếm lại cặp ngoặc |
| Chữ hiện ra nhưng không xuống dòng | Quên `'\n'` hoặc `std::endl` |
| Dùng `'` thay `"` cho chuỗi | `'a'` là *một* ký tự; chuỗi phải dùng `"abc"` |
| Chương trình ngắt lúc nhập | Gõ chữ vào chỗ chờ số (xem Chương 2) |

## Bài tập

1. In ra ba dòng: tên bạn, tên trường, và sở thích. Dùng một lần `std::cout` với nhiều `\n`.
2. Viết chương trình hỏi hai số nguyên rồi in tổng của chúng. Gõ hai số cách nhau một dấu cách trên cùng một dòng, hoặc mỗi số một dòng; thử cả hai cách và nhận xét.
3. Viết chương trình hỏi họ tên (cả dòng, có dấu cách) bằng `getline` rồi in lời chào.
4. Cố ý xoá một dấu `}` trong chương trình, bấm Chạy và đọc thông báo lỗi. Cho biết dòng và cột được báo.
5. Cố ý gõ `std::cuot` thay cho `std::cout` và ghi lại thông báo lỗi. Chú ý từ khoá trong thông báo.

### Gợi ý đáp án

<details>
<summary>Bài 2</summary>

```cpp
#include <iostream>

int main() {
    int a, b;
    std::cout << "Nhập hai số: ";
    std::cin >> a >> b;
    std::cout << "Tổng = " << a + b << "\n";
}
```

`cin >> a >> b` bỏ qua cả dấu cách lẫn xuống dòng giữa hai số, nên gõ cách nào cũng được.
</details>

<details>
<summary>Bài 3</summary>

```cpp
#include <iostream>
#include <string>

int main() {
    std::string ten;
    std::cout << "Họ tên: ";
    std::getline(std::cin, ten);
    std::cout << "Chào " << ten << "!\n";
}
```
</details>

## Tóm tắt

- C++ là ngôn ngữ biên dịch: mã nguồn `.cpp` → trình biên dịch → mã máy → chạy. Trong Catnip, nút **▶︎ Chạy** làm cả chuỗi này.
- Chương trình bắt đầu từ hàm `int main()`. Mỗi câu lệnh kết thúc bằng `;`.
- `#include <iostream>` để dùng `std::cout` (xuất, toán tử `<<`) và `std::cin` (nhập, toán tử `>>`).
- `cin >>` dừng ở khoảng trắng; đọc cả dòng dùng `std::getline`.
- Trong console Catnip, gõ dữ liệu vào ô nhập rồi Enter; **Gửi EOF** đóng luồng nhập.
- Lỗi biên dịch hiện ở console dưới dạng `file:dòng:cột: error: ...`; đọc lỗi đầu tiên trước.
- Chú thích: `//` một dòng, `/* */` nhiều dòng.
- Tránh `using namespace std;` trong header; viết `std::` cho rõ ràng.

[Chương sau: Biến, kiểu dữ liệu và toán tử](docs-cpp-02-bien-kieu-toan-tu.md)
