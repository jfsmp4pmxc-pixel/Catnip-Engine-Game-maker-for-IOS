# Lua cơ bản

LÖVE dùng Lua 5.1. Lua nhỏ gọn, bạn có thể nắm cơ bản trong vài phút.

## Biến và kiểu dữ liệu

```lua
local ten = "Mèo"          -- chuỗi
local tuoi = 3             -- số (cả nguyên lẫn thực)
local song = true          -- boolean
local khong = nil          -- không có giá trị
```

Luôn dùng `local` cho biến để tránh biến toàn cục ngoài ý muốn.

## Toán tử

```lua
a + b   a - b   a * b   a / b   a % b   a ^ b    -- số học
a == b  a ~= b  a < b   a <= b                    -- so sánh (khác là ~=, không phải !=)
a and b   a or b   not a                          -- logic
"xin " .. "chào"                                  -- nối chuỗi
#chuoi                                            -- độ dài
```

Chỉ `nil` và `false` là sai; số `0` và chuỗi rỗng đều là đúng.

## Điều kiện và vòng lặp

```lua
if x > 10 then
  print("lớn")
elseif x > 5 then
  print("vừa")
else
  print("nhỏ")
end

for i = 1, 10 do print(i) end            -- 1 đến 10
for i = 10, 1, -1 do print(i) end        -- đếm ngược
while dk do ... end
repeat ... until dk
```

## Hàm

```lua
local function congHai(a, b)
  return a + b
end

local function chia(a, b)               -- trả về nhiều giá trị
  return math.floor(a / b), a % b
end
local thuong, du = chia(17, 5)
```

## Bảng (table): mảng và từ điển

```lua
local ds = { "táo", "cam", "lê" }       -- mảng, chỉ số bắt đầu từ 1
print(ds[1], #ds)                       -- táo  3
table.insert(ds, "nho")
table.remove(ds, 1)

local nv = { ten = "Mèo", mau = 100 }   -- từ điển
nv.mau = nv.mau - 10

for i, v in ipairs(ds) do print(i, v) end      -- duyệt mảng theo thứ tự
for k, v in pairs(nv)  do print(k, v) end      -- duyệt mọi cặp khoá-giá trị
```

## Đối tượng (metatable)

```lua
local Quai = {}
Quai.__index = Quai

function Quai.new(x, y)
  return setmetatable({ x = x, y = y, mau = 3 }, Quai)
end

function Quai:diChuyen(dt)       -- dấu : tự truyền self
  self.x = self.x + 50 * dt
end

local q = Quai.new(0, 100)
q:diChuyen(0.016)
```

## Hàm toán học hay dùng

```lua
math.floor(x)  math.ceil(x)  math.abs(x)  math.sqrt(x)
math.min(a, b)  math.max(a, b)  math.sin(x)  math.cos(x)  math.pi
love.math.random()        -- số thực 0..1
love.math.random(1, 6)    -- số nguyên 1..6
```

## Tài liệu Lua

- Sách *Programming in Lua* (bản 1 miễn phí): <https://www.lua.org/pil/contents.html>
- Cẩm nang Lua 5.1: <https://www.lua.org/manual/5.1/>
