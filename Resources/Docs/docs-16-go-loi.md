# Gỡ lỗi và lỗi thường gặp

## Đọc thông báo lỗi

Khi game có lỗi, LÖVE hiện màn hình **Error** với dạng:

```
Error

main.lua:25: attempt to index a nil value (local 'player')

Traceback
  main.lua:25: in function 'update'
  [C]: in function 'xpcall'
```

Cách đọc:

- `main.lua:25` — file và **số dòng** xảy ra lỗi.
- Phần sau dấu `:` là mô tả.
- *Traceback* cho biết chuỗi hàm đã gọi tới đó (từ dưới lên).

Nhìn dòng đầu tiên: nó thường chỉ thẳng vị trí cần sửa.

## Các lỗi thường gặp

### `attempt to index a nil value (local 'x')`

Bạn dùng `x.y` hoặc `x:phuongThuc()` trong khi `x` đang là `nil`.

```lua
local player          -- quên khởi tạo
print(player.x)       -- lỗi
```

Cách xử lý: kiểm tra `x` được gán chưa; kiểm tra tên biến có gõ sai; kiểm tra `love.load` đã chạy chưa trước khi `update` dùng.

### `attempt to call a nil value (field 'abc')` / `(global 'abc')`

Gọi một hàm không tồn tại: sai tên (`love.graphics.rectange`), sai module, hay hàm chưa được định nghĩa khi gọi.

```lua
love.graphics.circle("fill", 10, 10, 5)     -- đúng
love.graphic.circle("fill", 10, 10, 5)      -- sai: thiếu "s"; ra "attempt to index global 'love.graphic'"
```

Với `local function f()`, hàm chỉ dùng được **sau** dòng khai báo; gọi nó ở dòng phía trên sẽ ra `nil`.

### `attempt to perform arithmetic on a nil value (field 'x')`

Phép tính với `nil`. Biến chưa có giá trị hoặc đặt sai tên khoá trong bảng.

### `attempt to compare number with nil`

So sánh với biến `nil`. Giống trên.

### `attempt to concatenate a nil value`

Ghép chuỗi `..` với `nil`. Dùng `tostring(x)` hoặc kiểm tra `x` trước.

```lua
print("điểm: " .. tostring(diem))
```

### `bad argument #1 to 'draw' (Drawable expected, got nil)`

Ảnh/canvas là `nil`, thường do nạp ảnh thất bại hoặc chưa nạp. Kiểm tra tên file, đường dẫn, và chữ hoa/thường.

### `Could not open file assets/hero.png. Does not exist.`

LÖVE không tìm thấy file:

- Đường dẫn đúng chưa (tương đối từ gốc dự án, dùng `/`)?
- Đã nhập file vào đúng thư mục chưa? Xem cây thư mục.
- Chữ hoa/thường có khớp không?

### `module 'abc' not found`

`require("abc")` không thấy `abc.lua`. Quy tắc: `require("a.b")` ↔ file `a/b.lua`; không viết đuôi `.lua`.

### `'=' expected near ...` / `unexpected symbol near ...` / `'end' expected`

Lỗi **cú pháp**: thiếu `end`, thiếu `then`, thiếu dấu ngoặc, dùng `!=` thay vì `~=`, dùng `+=` (Lua không có).

```lua
if x ~= 5 then ... end        -- đúng
if x != 5 then ... end        -- sai
x = x + 1                      -- đúng
x += 1                         -- sai
```

Dòng báo lỗi đôi khi là dòng **sau** chỗ thực sự bị lỗi (do thiếu `end` ở trên). Nhìn ngược lên vài dòng.

### Lỗi trong `conf.lua`

Game không mở được cửa sổ. Kiểm tra cú pháp `conf.lua` trước; xem chương **conf.lua**.

## In giá trị để dò lỗi

```lua
print("x =", x, "y =", y)
print(string.format("x=%.2f  y=%.2f", x, y))
```

In ra bảng: `print(tbl)` chỉ cho địa chỉ. Hãy in từng phần tử, hoặc dùng hàm này:

```lua
local function inBang(t, thut)
  thut = thut or ""
  for k, v in pairs(t) do
    if type(v) == "table" then
      print(thut .. tostring(k) .. " = {")
      inBang(v, thut .. "  ")
      print(thut .. "}")
    else
      print(thut .. tostring(k) .. " = " .. tostring(v))
    end
  end
end
```

Không `print` mỗi khung hình trong thời gian dài: sẽ làm chậm game và làm ngập log. In có điều kiện:

```lua
if love.keyboard.isDown("f1") then print(x, y) end
```

## Hiển thị thông tin ngay trên màn hình

```lua
local debugBat = true

function love.keypressed(key)
  if key == "f3" then debugBat = not debugBat end
end

function love.draw()
  -- ... vẽ game ...
  if debugBat then
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, 220, 70)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 8, 6)
    love.graphics.print(string.format("RAM: %.1f MB", collectgarbage("count") / 1024), 8, 26)
    love.graphics.print("x, y: " .. math.floor(x) .. ", " .. math.floor(y), 8, 46)
  end
end
```

Vẽ **hitbox** để thấy va chạm: `love.graphics.rectangle("line", ...)`.

## Bắt lỗi để game không sập: `pcall`

```lua
local ok, loi = pcall(function()
  nhiemVuCoTheLoi()
end)
if not ok then
  print("Lỗi:", loi)
end
```

`pcall` hợp để nạp file người dùng cung cấp, đọc file lưu. Đừng lạm dụng nó để giấu lỗi trong logic chính: lỗi bị nuốt rất khó tìm.

Có thể tuỳ biến màn hình lỗi bằng `love.errorhandler(msg)`; xem wiki LÖVE nếu cần.

## Kiểm tra điều kiện: `assert`

```lua
function mauCuaLoai(loai)
  assert(type(loai) == "string", "loai phải là chuỗi")
  ...
end
```

`assert` dừng ngay tại chỗ sai, giúp lỗi lộ ra sớm hơn.

## Chia nhỏ để cô lập lỗi

1. **Tái hiện** được lỗi ổn định chưa? Tìm các bước chính xác gây lỗi.
2. **Thu hẹp**: tắt (comment) từng phần cho đến khi lỗi mất → phần đó có vấn đề.
3. **In** giá trị biến ở thời điểm sắp lỗi.
4. **Đọc lại** hàm bạn nghi ngờ, từng dòng, với giá trị cụ thể.
5. Nếu vẫn bí, tạo `main.lua` nhỏ nhất tái hiện lỗi (chỉ 10–20 dòng).

## Lỗi logic phổ biến

| Triệu chứng | Nguyên nhân thường gặp |
|---|---|
| Vật di chuyển nhanh/chậm khác nhau giữa máy | Quên nhân `dt` khi di chuyển |
| Vật bị mờ khi phóng to | Cần `setDefaultFilter("nearest", "nearest")` |
| Mọi thứ bị tô màu lạ | Quên `setColor(1, 1, 1)` trước khi vẽ ảnh |
| Ảnh không xoay quanh tâm | Chưa đặt tâm `ox, oy` ở giữa ảnh |
| Chạm màn hình xử lý hai lần | Xử lý cả `touchpressed` lẫn `mousepressed` |
| Vật rơi xuyên sàn | Vận tốc quá lớn so với độ dày sàn; chia nhỏ bước hoặc làm sàn dày hơn |
| Game chậm dần theo thời gian | Tạo đối tượng mới mỗi khung mà không xoá cũ; `love.graphics.newImage/newFont` trong `draw` |
| Lỗi khi xoá phần tử lúc duyệt | Duyệt danh sách **ngược** (`for i = #t, 1, -1`) khi `table.remove` |
| Số đếm lệch 1 | Lua đánh chỉ số mảng từ **1**, không phải 0 |
| `if x == "5"` luôn sai | `"5"` (chuỗi) khác `5` (số): dùng `tonumber` |
| Chữ tiếng Việt vỡ/không hiện | Font mặc định có thể thiếu dấu: dùng font `.ttf` hỗ trợ tiếng Việt qua `newFont("assets/font.ttf", 20)` |
| `#` trả về giá trị lạ | Bảng có "lỗ" (phần tử `nil` ở giữa); tránh gán `nil` giữa danh sách |

## Rò rỉ bộ nhớ

```lua
print(collectgarbage("count") / 1024, "MB")     -- bộ nhớ Lua đang dùng
```

Nếu con số tăng mãi: kiểm tra danh sách đạn/hạt/hiệu ứng có được xoá khi hết hạn không, có giữ tham chiếu tới đối tượng cũ không.

## Khi cần hỏi giúp

Khi hỏi trên diễn đàn (như diễn đàn LÖVE), hãy kèm:

- Thông báo lỗi nguyên văn.
- Đoạn code ngắn nhất tái hiện lỗi.
- Bạn đã thử gì.

Wiki chính thức: https://love2d.org/wiki/Main_Page (mở từ nút trong màn hình tài liệu).
