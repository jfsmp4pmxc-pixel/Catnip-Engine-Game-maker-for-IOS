# Lua cơ bản

LÖVE dùng **Lua 5.1** (kiểu LuaJIT). Lua rất nhỏ gọn: bạn nắm cơ bản trong khoảng một giờ. Chương này đủ để viết game; muốn sâu hơn xem cuối trang.

## Chú thích

```lua
-- Chú thích một dòng

--[[ Chú thích
     nhiều dòng ]]
```

## Biến và kiểu dữ liệu

```lua
local ten = "Mèo"        -- string (chuỗi)
local tuoi = 3           -- number (số: nguyên hay thực đều là number)
local pi = 3.14159
local song = true        -- boolean
local khong = nil        -- nil: "không có giá trị"

print(type(ten))         --> string
print(type(tuoi))        --> number
print(type(print))       --> function
print(type({}))          --> table
```

**Luôn dùng `local`** khi khai báo biến. Quên `local` tạo biến *toàn cục*: dễ gây lỗi khó tìm, vì mọi file đều thấy và có thể ghi đè nó.

```lua
diem = 10          -- toàn cục (tránh!)
local diem = 10    -- cục bộ (nên dùng)
```

## Toán tử

```lua
a + b   a - b   a * b   a / b     -- cộng trừ nhân chia (chia luôn ra số thực)
a % b                              -- chia lấy dư: 7 % 3 == 1
a ^ b                              -- luỹ thừa: 2 ^ 10 == 1024
-a                                 -- đổi dấu

a == b    a ~= b                   -- bằng / KHÁC (là ~=, không phải !=)
a < b   a <= b   a > b   a >= b

a and b   a or b   not a           -- logic

"xin " .. "chào"                   -- nối chuỗi bằng hai dấu chấm
#"abc"                             -- độ dài chuỗi: 3
```

**Đúng/sai:** chỉ `nil` và `false` là sai. Số `0` và chuỗi rỗng `""` đều là **đúng**.

Mẹo `and`/`or` làm giá trị mặc định và điều kiện ngắn:

```lua
local ten = nhapVao or "Vô danh"            -- nếu nhapVao là nil/false thì lấy "Vô danh"
local huong = (x > 0) and "phải" or "trái"  -- giống toán tử ba ngôi
```

## Chuỗi

```lua
local s = "Xin chào"
print(#s)                          -- độ dài tính theo BYTE (chữ có dấu chiếm nhiều byte)
print(s:upper(), s:lower())
print(s:sub(1, 3))                 --> Xin   (ký tự 1 đến 3)
print(s:find("chào"))              -- vị trí bắt đầu/kết thúc
print(("ab"):rep(3))               --> ababab  (lặp 3 lần)
print(("%d điểm, %.2f giây"):format(10, 3.14159))
print(tostring(12) .. "px")        -- đổi số thành chuỗi
print(tonumber("42") + 1)          --> 43  (đổi chuỗi thành số, sai thì ra nil)
```

Chuỗi nhiều dòng:

```lua
local doan = [[
Dòng 1
Dòng 2
]]
```

## Điều kiện

```lua
if hp <= 0 then
  print("thua")
elseif hp < 20 then
  print("nguy hiểm")
else
  print("ổn")
end
```

## Vòng lặp

```lua
for i = 1, 5 do print(i) end            -- 1 2 3 4 5
for i = 10, 1, -1 do print(i) end       -- đếm ngược, bước -1
for i = 0, 1, 0.25 do print(i) end      -- bước 0.25

local n = 0
while n < 3 do n = n + 1 end

repeat                                   -- chạy ít nhất 1 lần
  n = n - 1
until n <= 0
```

`break` thoát vòng lặp. Lua 5.1 **không có `continue`**; dùng `if` để bỏ qua:

```lua
for i = 1, 10 do
  if i % 2 == 0 then
    print(i)      -- chỉ in số chẵn
  end
end
```

## Hàm

```lua
local function congHai(a, b)
  return a + b
end
print(congHai(2, 3))        --> 5

-- Trả về nhiều giá trị
local function chia(a, b)
  return math.floor(a / b), a % b
end
local thuong, du = chia(17, 5)
print(thuong, du)           --> 3  2

-- Hàm là giá trị: gán được vào biến, truyền được cho hàm khác
local nhanDoi = function(x) return x * 2 end

-- Tham số thiếu sẽ là nil; cho giá trị mặc định bằng `or`
local function chao(ten)
  ten = ten or "bạn"
  print("Chào " .. ten)
end
chao()           --> Chào bạn
chao("Mèo")      --> Chào Mèo

-- Số tham số bất kỳ
local function tong(...)
  local s = 0
  for _, v in ipairs({...}) do s = s + v end
  return s
end
print(tong(1, 2, 3, 4))     --> 10
```

## Bảng (table): mảng và từ điển

Table là cấu trúc dữ liệu **duy nhất** của Lua, dùng làm cả mảng, từ điển, đối tượng.

### Làm mảng (chỉ số bắt đầu từ **1**)

```lua
local ds = { "táo", "cam", "lê" }
print(ds[1])               --> táo      (KHÔNG phải ds[0])
print(#ds)                 --> 3        (độ dài)

table.insert(ds, "nho")        -- thêm vào cuối
table.insert(ds, 1, "xoài")    -- chèn vào vị trí 1
table.remove(ds, 2)            -- xoá phần tử ở vị trí 2
table.remove(ds)               -- xoá phần tử cuối

table.sort(ds)                 -- sắp xếp tăng dần
table.sort(ds, function(a, b) return a > b end)   -- giảm dần

print(table.concat(ds, ", "))  -- nối thành chuỗi
```

Duyệt mảng theo thứ tự:

```lua
for i, v in ipairs(ds) do
  print(i, v)
end
```

### Làm từ điển / đối tượng

```lua
local nv = { ten = "Mèo", mau = 100, vitri = { x = 10, y = 20 } }
print(nv.ten, nv["ten"])   -- hai cách viết tương đương
nv.mau = nv.mau - 10
nv.vitri.x = nv.vitri.x + 5
nv.vukhi = "kiếm"          -- thêm trường mới
nv.mau = nil               -- xoá trường

for k, v in pairs(nv) do   -- duyệt mọi cặp (THỨ TỰ KHÔNG ĐẢM BẢO)
  print(k, v)
end
```

### Cẩn thận khi xoá lúc đang duyệt

Xoá phần tử trong mảng khi lặp xuôi làm lỡ phần tử kế. **Lặp ngược:**

```lua
for i = #danhSach, 1, -1 do
  if danhSach[i].chet then
    table.remove(danhSach, i)
  end
end
```

## Bảng được truyền theo tham chiếu

```lua
local a = { x = 1 }
local b = a          -- b và a cùng trỏ vào MỘT bảng
b.x = 99
print(a.x)           --> 99

-- Muốn bản sao độc lập (sao chép nông):
local function sao(t)
  local r = {}
  for k, v in pairs(t) do r[k] = v end
  return r
end
```

## Đối tượng và metatable (lập trình hướng đối tượng)

```lua
local Quai = {}
Quai.__index = Quai              -- tra cứu phương thức qua bảng Quai

function Quai.new(x, y)
  local self = setmetatable({}, Quai)
  self.x, self.y = x, y
  self.mau = 3
  return self
end

function Quai:diChuyen(dt)       -- dấu : tự thêm tham số `self`
  self.x = self.x + 50 * dt
end

function Quai:nhanSatThuong(n)
  self.mau = self.mau - n
  return self.mau <= 0           -- true nếu chết
end

local q = Quai.new(0, 100)
q:diChuyen(0.016)                -- viết q:f() = Quai.f(q)
print(q:nhanSatThuong(1))        --> false
```

### Kế thừa

```lua
local QuaiBay = setmetatable({}, { __index = Quai })
QuaiBay.__index = QuaiBay

function QuaiBay.new(x, y)
  local self = Quai.new(x, y)    -- gọi hàm tạo cha
  setmetatable(self, QuaiBay)
  self.cao = 50
  return self
end

function QuaiBay:diChuyen(dt)    -- ghi đè
  Quai.diChuyen(self, dt)        -- gọi lại bản của cha
  self.y = self.y + math.sin(love.timer.getTime()) * 10 * dt
end
```

## Closure (hàm nhớ biến bên ngoài)

```lua
local function boDem()
  local n = 0
  return function()
    n = n + 1
    return n
  end
end

local dem = boDem()
print(dem(), dem(), dem())       --> 1  2  3
```

## Xử lý lỗi

```lua
local ok, loi = pcall(function()
  error("có chuyện rồi")         -- gây lỗi
end)
print(ok, loi)                   --> false  ...có chuyện rồi

-- assert: dừng với thông báo nếu điều kiện sai
local f = assert(love.filesystem.read("save.txt"))   -- lỗi nếu file không đọc được
```

## Thư viện chuẩn hay dùng

```lua
-- math
math.floor(2.7)   --> 2         math.ceil(2.1)  --> 3
math.abs(-5)      --> 5         math.sqrt(16)   --> 4
math.min(3, 7)    --> 3         math.max(3, 7)  --> 7
math.sin(x)  math.cos(x)  math.atan2(dy, dx)    -- lượng giác (radian)
math.pi           --> 3.14159...
math.huge         --> vô cực

-- làm tròn số gần nhất
local function lamTron(x) return math.floor(x + 0.5) end

-- os
os.time()                        -- giây từ 1970
os.date("%Y-%m-%d %H:%M")        -- ngày giờ dạng chữ
os.clock()                       -- thời gian CPU đã dùng
```

Để lấy số ngẫu nhiên, nên dùng `love.math.random` (xem chương *Toán học và thời gian*).

## Những lỗi người mới hay mắc

| Triệu chứng | Nguyên nhân |
|---|---|
| `attempt to index a nil value` | Dùng `a.b` khi `a` là `nil` (quên khởi tạo, sai tên biến) |
| `attempt to call a nil value` | Gọi hàm chưa định nghĩa hoặc gõ sai tên |
| `attempt to perform arithmetic on a nil value` | Tính toán với biến chưa có giá trị |
| `attempt to compare number with nil` | So sánh với biến `nil` |
| Mảng bắt đầu từ 0 | Lua đếm từ **1** |
| `!=` báo lỗi cú pháp | Dùng `~=` |
| Hàm gọi `obj.f()` mà đáng lẽ `obj:f()` | Quên truyền `self` |

## Học thêm

- *Programming in Lua* (bản đầu, Lua 5.0/5.1, miễn phí): <https://www.lua.org/pil/contents.html>
- Cẩm nang Lua 5.1: <https://www.lua.org/manual/5.1/>
