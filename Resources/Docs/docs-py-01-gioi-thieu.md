# Python: giới thiệu và chương trình đầu tiên

Chương này trả lời ba câu hỏi: Python là gì, chạy Python trong Catnip Engine như thế nào, và một chương trình Python nhỏ nhất trông ra sao. Cuối chương bạn sẽ tự viết và chạy được những chương trình in chữ ra màn hình.

## 1. Python là gì?

**Chương trình** là một dãy lệnh viết cho máy tính, máy làm từng lệnh từ trên xuống dưới. **Ngôn ngữ lập trình** là bộ quy tắc để viết các lệnh ấy sao cho máy hiểu. **Python** là một ngôn ngữ như vậy, do Guido van Rossum tạo ra và phát hành năm 1991. Nó nổi tiếng vì dễ đọc: nhiều dòng Python gần giống tiếng Anh thông thường.

Những đặc điểm bạn cần biết ngay từ đầu:

- **Thông dịch**: bạn viết file văn bản chứa mã nguồn (đuôi `.py`), rồi một chương trình tên là *trình thông dịch* (interpreter) đọc và thực hiện từng câu lệnh. Bạn không phải biên dịch trước như C++.
- **Thụt lề có ý nghĩa**: Python dùng khoảng trắng đầu dòng để gom các lệnh thành khối. Nhiều ngôn ngữ khác dùng dấu ngoặc nhọn `{ }`, Python thì không.
- **Kiểu động**: một tên (biến) có thể trỏ tới số, rồi sau đó trỏ tới chuỗi. Python kiểm tra kiểu lúc chương trình chạy chứ không phải lúc viết. Chương 2 nói kỹ hơn.
- **"Pin kèm theo"**: thư viện chuẩn của Python có sẵn rất nhiều thứ (toán, ngày giờ, đọc ghi file, JSON...). Chương 7 sẽ giới thiệu.

Trong Catnip Engine, Python chạy bằng **CPython 3.13** (bản Python chính thức, viết bằng C) được nhúng sẵn vào app và chạy **native** ngay trong tiến trình của app. Bạn không cần cài gì thêm, và kết quả giống như chạy Python 3.13 trên máy tính.

## 2. Chạy Python trong Catnip

### Tạo dự án

1. Ở màn hình danh sách dự án, tạo dự án mới và chọn loại **Python**.
2. Catnip tạo sẵn một thư mục dự án chứa file `main.py` với nội dung mẫu: hỏi tên bạn rồi chào.
3. Mở `main.py` trong trình soạn thảo, sửa, rồi bấm nút **▶︎ Chạy** ở thanh trên.

Kết quả hiện trong một **terminal** kiểu iSH: màn hình đen chữ sáng, giống cửa sổ dòng lệnh. Chương trình in chữ ra đó, và khi chương trình hỏi dữ liệu bằng `input()` thì bạn gõ vào ô nhập của terminal rồi nhấn Enter.

### Những quy ước cần nhớ

| Điều cần biết | Ý nghĩa |
|---|---|
| `main.py` là file chạy | Nút Chạy luôn chạy `main.py` của dự án. Các file `.py` khác chỉ chạy khi `main.py` nạp chúng bằng `import` (chương 5). |
| Thư mục làm việc | Là thư mục dự án. Mở file bằng tên tương đối như `open("ghi_chu.txt")` sẽ tìm trong thư mục dự án (chương 6). |
| `input()` theo dòng | Terminal gửi cả một dòng cho chương trình khi bạn nhấn Enter. Chương trình không nhận từng phím riêng lẻ (không có kiểu "bấm phím nào đi luôn"). |
| Không có REPL | **REPL** là chế độ gõ một lệnh, Python trả lời ngay (dấu nhắc `>>>`) mà bạn thấy trong nhiều sách Python. Catnip **không có** chế độ này: bạn luôn viết file rồi bấm Chạy. Nếu sách khác viết `>>> 1 + 1` thì trong Catnip hãy viết `print(1 + 1)`. |
| Chạy lại là chạy mới | Mỗi lần bấm Chạy, chương trình bắt đầu từ đầu, các biến cũ không còn. |

> Mẹo: vì không có REPL, cách thử nhanh một ý nào đó là tạo vài dòng `print(...)` trong `main.py`, bấm Chạy, xem kết quả, rồi sửa tiếp.

## 3. Chương trình đầu tiên

```python
print("Xin chào, Catnip!")
```

Kết quả:

```text
Xin chào, Catnip!
```

Kết quả xem ngay bên dưới mỗi ví dụ. Đây là chương trình một dòng. `print` là một **hàm** có sẵn: nó nhận thứ cần in đặt trong cặp ngoặc tròn rồi in ra terminal, kết thúc bằng xuống dòng. Chữ nằm trong dấu nháy kép `"..."` gọi là **chuỗi** (string). Dấu nháy đơn `'...'` cũng được, hai cách như nhau.

```python
print("Dòng thứ nhất")
print('Dòng thứ hai')
print("Dòng thứ ba")
```

Kết quả:

```text
Dòng thứ nhất
Dòng thứ hai
Dòng thứ ba
```

Python chạy từng lệnh **theo thứ tự từ trên xuống**: dòng viết trước chạy trước.

### `print` làm được nhiều hơn

`print` nhận nhiều giá trị cách nhau bằng dấu phẩy. Nó in các giá trị đó ra và đặt **một dấu cách** giữa chúng. Số không cần dấu nháy:

```python
print("Tuổi của mèo:", 3)
print("Hai cộng hai bằng", 2 + 2)
print(7, 8, 9)
```

Kết quả:

```text
Tuổi của mèo: 3
Hai cộng hai bằng 4
7 8 9
```

Có hai tham số đặc biệt đặt tên: `sep` (chuỗi đặt giữa các giá trị, mặc định là một dấu cách) và `end` (chuỗi in sau cùng, mặc định là xuống dòng):

```python
print("a", "b", "c", sep="-")
print("Đang tải", end="...")
print("xong!")
print()          # in một dòng trống
print("hết")
```

Kết quả:

```text
a-b-c
Đang tải...xong!

hết
```

Muốn xuống dòng ngay giữa một chuỗi, dùng ký hiệu **escape** `\n`. Muốn in dấu nháy bên trong chuỗi, dùng `\"` hoặc đổi loại nháy bao ngoài. Muốn in chính dấu gạch chéo ngược, viết `\\`:

```python
print("Dòng 1\nDòng 2")
print("Cột A\tCột B")
print("Mèo nói: \"meo\"")
print('Mèo nói: "meo"')
print("Đường dẫn: C:\\Tai_lieu")
```

Kết quả:

```text
Dòng 1
Dòng 2
Cột A	Cột B
Mèo nói: "meo"
Mèo nói: "meo"
Đường dẫn: C:\Tai_lieu
```

Tiếng Việt có dấu in bình thường, vì Python 3 xử lý chữ theo Unicode (chương 2):

```python
print("Việt Nam", "🐱")
```

Kết quả:

```text
Việt Nam 🐱
```

## 4. Chú thích

**Chú thích** (comment) là chữ dành cho người đọc, Python bỏ qua. Mọi thứ từ dấu `#` đến hết dòng là chú thích:

```python
# Đây là chú thích cả dòng, Python bỏ qua.
print("Có chú thích")   # chú thích đặt cuối dòng cũng được
# print("Dòng này bị tắt, không chạy")
```

Kết quả:

```text
Có chú thích
```

Hai việc hay làm với chú thích: giải thích **vì sao** bạn viết thế (đừng chỉ nhắc lại điều mã đã nói rõ), và tạm tắt một dòng khi thử nghiệm. Python không có chú thích nhiều dòng riêng; muốn chú thích nhiều dòng thì đặt `#` đầu mỗi dòng.

## 5. Thụt lề và lỗi đầu tiên

Chương trình chạy từ trên xuống, nhưng ở chương 3 bạn sẽ gặp các lệnh có "thân" (như `if`, `for`). Thân đó được đánh dấu bằng **thụt lề**: lùi vào đầu dòng, thường **4 dấu cách**. Ở chương này chưa cần, nhưng đây là lỗi mới học hay gặp nhất nên xem trước:

```python
print("Bắt đầu")
    print("Thụt lề thừa")
```

Kết quả:

```text
  File "/tmp/claude-0/-home-claude/f7ac3e1b-d7cc-51cc-9078-4ef25b483e63/scratchpad//DuAnCuaToi/main.py", line 2
    print("Thụt lề thừa")
IndentationError: unexpected indent
```

Python từ chối chạy cả chương trình và nói rõ chuyện gì sai. Hãy tập đọc thông báo lỗi ngay từ bây giờ, vì bạn sẽ đọc rất nhiều thông báo như vậy:

- Dòng `File "...main.py", line 2` cho biết lỗi ở **dòng 2**.
- Dòng cuối cho biết **loại lỗi** (`IndentationError`) và lời giải thích.

Một vài lỗi quen thuộc khác:

```python
print("Thiếu ngoặc đóng"
print("dòng sau")
```

Kết quả:

```text
  File "/tmp/claude-0/-home-claude/f7ac3e1b-d7cc-51cc-9078-4ef25b483e63/scratchpad//DuAnCuaToi/main.py", line 1
    print("Thiếu ngoặc đóng"
         ^
SyntaxError: '(' was never closed
```

```python
prin("Gõ sai tên hàm")
```

Kết quả:

```text
Traceback (most recent call last):
  File "/tmp/claude-0/-home-claude/f7ac3e1b-d7cc-51cc-9078-4ef25b483e63/scratchpad//DuAnCuaToi/main.py", line 1, in <module>
    prin("Gõ sai tên hàm")
    ^^^^
NameError: name 'prin' is not defined. Did you mean: 'print'?
```

```python
print(Xin chào)
```

Kết quả:

```text
  File "/tmp/claude-0/-home-claude/f7ac3e1b-d7cc-51cc-9078-4ef25b483e63/scratchpad//DuAnCuaToi/main.py", line 1
    print(Xin chào)
          ^^^^^^^^
SyntaxError: invalid syntax. Perhaps you forgot a comma?
```

Ba lỗi trên thuộc hai nhóm khác nhau, và sự khác biệt rất quan trọng:

- **Lỗi cú pháp** (`SyntaxError`, `IndentationError`): Python đọc cả file trước khi chạy và thấy câu viết sai ngữ pháp, nên **không chạy dòng nào**.
- **Lỗi lúc chạy** (`NameError`, `TypeError`, `ZeroDivisionError`...): ngữ pháp đúng, nhưng khi chạy đến dòng đó thì có chuyện bất thường. Các dòng chạy được *trước* đó đã in ra rồi.

Ví dụ lỗi lúc chạy: dòng đầu in được, dòng thứ hai làm chương trình dừng:

```python
print("Dòng này vẫn in được")
print(10 / 0)
print("Dòng này không bao giờ tới")
```

Kết quả:

```text
Dòng này vẫn in được
Traceback (most recent call last):
  File "/tmp/claude-0/-home-claude/f7ac3e1b-d7cc-51cc-9078-4ef25b483e63/scratchpad//DuAnCuaToi/main.py", line 2, in <module>
    print(10 / 0)
          ~~~^~~
ZeroDivisionError: division by zero
```

## 6. Chương trình tương tác đầu tiên

Chương trình mẫu của Catnip hỏi tên người dùng. Hàm `input()` in câu hỏi, chờ bạn gõ một dòng rồi nhấn Enter, và trả về dòng đó dưới dạng chuỗi. Ở ví dụ này, giá trị bạn gõ ("Mèo Mun") được cho sẵn bằng dữ liệu nhập mẫu để kết quả lặp lại được:

```python
ten = input("Tên bạn là gì? ")
print("Xin chào,", ten)
print(f"Rất vui được gặp {ten}!")
```

Kết quả:

```text
Tên bạn là gì? Xin chào, Mèo Mun
Rất vui được gặp Mèo Mun!
```

Hai điều mới ở đây: `ten = input(...)` **gán** kết quả vào một biến tên `ten` (chương 2), và `f"..."` là chuỗi định dạng: các chữ trong `{ }` được thay bằng giá trị. Lưu ý kết quả trên không có chữ "Mèo Mun" ngay sau câu hỏi vì dữ liệu nhập mẫu không hiện lại, còn trên terminal của Catnip thì chữ bạn gõ hiện ngay sau câu hỏi.

## 7. Lỗi thường gặp ở chương này

| Triệu chứng | Nguyên nhân thường gặp |
|---|---|
| `SyntaxError: '(' was never closed` | Mở ngoặc `(` mà quên đóng `)`. |
| `SyntaxError: unterminated string literal` | Mở dấu nháy mà quên đóng, hoặc dùng `"` ở giữa chuỗi bao bằng `"`. |
| `NameError: name 'prin' is not defined` | Gõ sai tên hàm. Python phân biệt chữ hoa chữ thường: `Print` khác `print`. |
| `IndentationError` | Dòng thụt lề thừa, hoặc thiếu ở thân khối. |
| Dùng dấu nháy "cong" `“ ”` | Khi gõ trên điện thoại, bàn phím có thể tự đổi `"` thành dấu nháy cong. Python không hiểu chúng. Hãy dùng dấu nháy thẳng `"`. |
| Gõ chữ có dấu bằng Telex dở dang | Gõ `ddi` mà chưa chuyển thành `đi` sẽ thành tên lạ. Trong chuỗi và chú thích thì chỉ là chữ sai, nhưng ở tên hàm thì gây `NameError`. |

## Bài tập

1. In ra ba dòng: tên bạn, quê bạn, môn bạn thích.
2. In `Mon Tue Wed` trên một dòng nhưng dùng `sep` để ngăn cách bằng dấu `|`. Kết quả mong muốn: `Mon|Tue|Wed`.
3. Dùng `end` để hai lệnh `print` liên tiếp in ra trên cùng một dòng: `Xin chào, thế giới`.
4. In khung hình chữ nhật 3 dòng bằng dấu `*` (mỗi dòng 5 dấu), chỉ dùng các lệnh `print`.
5. Chương trình sau có một lỗi. Tìm và sửa:
   ```python
   print("Xin chào)
   ```
6. Viết chương trình hỏi tên và tuổi (hai lệnh `input`), rồi in `Chào <tên>, bạn <tuổi> tuổi`. (Tuổi lúc này cứ giữ là chuỗi.)

### Gợi ý đáp án

1. `print("Mèo")`, `print("Hà Nội")`, `print("Toán")`, mỗi dòng một lệnh.
2. `print("Mon", "Tue", "Wed", sep="|")`.
3. `print("Xin chào,", end=" ")` rồi `print("thế giới")`.
4. Năm lần chuỗi `"*****"`: `print("*****")` lặp 3 lần.
5. Thiếu dấu nháy đóng: `print("Xin chào")`.
6. `ten = input("Tên: ")`, `tuoi = input("Tuổi: ")`, `print("Chào", ten + ", bạn", tuoi, "tuổi")`. Phép `+` nối chuỗi sẽ học ở chương 2.

## Tóm tắt

- Python là ngôn ngữ thông dịch, dễ đọc, dùng **thụt lề** để gom khối lệnh. Catnip nhúng CPython 3.13 chạy native.
- Tạo dự án loại Python, sửa `main.py`, bấm **▶︎ Chạy**; kết quả hiện trong terminal kiểu iSH. Thư mục làm việc là thư mục dự án.
- `input()` nhận theo dòng. Catnip **không có REPL**: luôn viết file rồi Chạy.
- `print(a, b, sep=..., end=...)` in giá trị; `\n`, `\t`, `\"`, `\\` là các ký hiệu escape.
- `#` bắt đầu chú thích.
- Lỗi cú pháp chặn cả chương trình; lỗi lúc chạy dừng chương trình tại dòng lỗi. Dòng cuối của thông báo cho biết loại lỗi.

Chương sau: Biến, kiểu dữ liệu và toán tử.
