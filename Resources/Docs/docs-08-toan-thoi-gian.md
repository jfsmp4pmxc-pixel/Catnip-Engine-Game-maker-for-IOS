# Toán học và thời gian

## Các hàm toán của Lua (`math`)

```lua
math.floor(3.7)        --> 3     làm tròn xuống
math.ceil(3.2)         --> 4     làm tròn lên
math.abs(-5)           --> 5
math.min(1, 5, 3)      --> 1
math.max(1, 5, 3)      --> 5
math.sqrt(16)          --> 4
math.sin(x) math.cos(x) math.atan2(y, x)    -- lượng giác, đơn vị là RADIAN
math.rad(180)          --> 3.14159…   độ → radian
math.deg(math.pi)      --> 180        radian → độ
math.pi                --> 3.14159…
math.huge              --> vô cực
```

Làm tròn gần nhất (Lua không có sẵn):

```lua
local function lamTron(x) return math.floor(x + 0.5) end
```

## Số ngẫu nhiên: `love.math`

Nên dùng `love.math.random` thay `math.random` vì nó được gieo hạt ngẫu nhiên sẵn mỗi lần chạy:

```lua
love.math.random()          -- số thực trong [0, 1)
love.math.random(6)         -- số nguyên 1..6
love.math.random(10, 20)    -- số nguyên 10..20
love.math.randomNormal(1, 0)  -- phân phối chuẩn (độ lệch, trung bình)
```

Muốn kết quả lặp lại được (cho màn chơi sinh theo hạt giống - seed):

```lua
local rng = love.math.newRandomGenerator(12345)   -- cùng seed → cùng dãy số
print(rng:random(1, 100))
```

Chọn phần tử ngẫu nhiên:

```lua
local function chonNgauNhien(ds) return ds[love.math.random(#ds)] end
local mau = chonNgauNhien({ "đỏ", "xanh", "vàng" })
```

Xáo trộn danh sách (Fisher–Yates):

```lua
local function xao(ds)
  for i = #ds, 2, -1 do
    local j = love.math.random(i)
    ds[i], ds[j] = ds[j], ds[i]
  end
  return ds
end
```

## Hàm tiện ích hay dùng

```lua
local function kep(x, lo, hi)          -- clamp: ép x vào [lo, hi]
  return math.max(lo, math.min(hi, x))
end

local function lerp(a, b, t)           -- nội suy tuyến tính, t từ 0 đến 1
  return a + (b - a) * t
end

local function khoangCach(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

local function chuanHoa(x, y)          -- đưa vector về độ dài 1
  local d = math.sqrt(x * x + y * y)
  if d == 0 then return 0, 0 end
  return x / d, y / d
end

local function dau(x)                  -- dấu: -1, 0, 1
  return x > 0 and 1 or (x < 0 and -1 or 0)
end

local function anhXa(x, a1, a2, b1, b2)   -- map: chuyển x từ khoảng [a1,a2] sang [b1,b2]
  return b1 + (x - a1) / (a2 - a1) * (b2 - b1)
end
```

### Di chuyển chéo không nhanh hơn

Đi chéo bằng cách cộng cả hai trục khiến tốc độ lớn hơn ~41%. Hãy chuẩn hoá hướng:

```lua
local dx, dy = 0, 0
if love.keyboard.isDown("left")  then dx = dx - 1 end
if love.keyboard.isDown("right") then dx = dx + 1 end
if love.keyboard.isDown("up")    then dy = dy - 1 end
if love.keyboard.isDown("down")  then dy = dy + 1 end
dx, dy = chuanHoa(dx, dy)
x = x + dx * tocDo * dt
y = y + dy * tocDo * dt
```

### Hướng tới mục tiêu và góc

```lua
-- góc từ (x1,y1) tới (x2,y2)
local goc = math.atan2(y2 - y1, x2 - x1)

-- đi theo góc đó
x = x + math.cos(goc) * tocDo * dt
y = y + math.sin(goc) * tocDo * dt
```

(Trong LuaJIT/LÖVE, `math.atan2` luôn dùng được.)

## Chuyển động mượt

### Đuổi theo mục tiêu mượt (smoothing)

```lua
-- mỗi khung, đi một phần quãng còn lại. 5 là "độ gắt": càng lớn càng nhanh
camX = camX + (mucTieuX - camX) * math.min(1, 5 * dt)
```

### Easing — tăng giảm tốc

```lua
local function easeOutQuad(t) return 1 - (1 - t) * (1 - t) end
local function easeInOutQuad(t)
  if t < 0.5 then return 2 * t * t end
  return 1 - (-2 * t + 2) ^ 2 / 2
end

-- tween đơn giản
local tw = { t = 0, thoiGian = 1, tu = 0, den = 300 }
function love.update(dt)
  tw.t = math.min(tw.t + dt, tw.thoiGian)
  x = tw.tu + (tw.den - tw.tu) * easeOutQuad(tw.t / tw.thoiGian)
end
```

### Rung màn hình (screen shake)

```lua
local rung = 0

function love.update(dt)
  rung = math.max(0, rung - dt * 30)          -- giảm dần
end

function love.draw()
  love.graphics.push()
  if rung > 0 then
    love.graphics.translate(love.math.random(-rung, rung), love.math.random(-rung, rung))
  end
  -- vẽ cả thế giới ở đây
  love.graphics.pop()
end

-- khi có va chạm mạnh: rung = 12
```

## Nhiễu Perlin/Simplex

`love.math.noise` trả về giá trị mượt, hợp để sinh địa hình hoặc chuyển động tự nhiên:

```lua
love.math.noise(x)            -- 1D, giá trị 0..1
love.math.noise(x, y)         -- 2D
love.math.noise(x, y, z)

-- địa hình đồi núi đơn giản
for cot = 0, 79 do
  local cao = love.math.noise(cot * 0.1, seed) * 200
  love.graphics.rectangle("fill", cot * 8, 400 - cao, 8, cao)
end
```

Đổi `seed` (số thực bất kỳ) để ra địa hình khác.

## Thời gian: `love.timer`

```lua
love.timer.getTime()      -- giây kể từ một mốc cố định, độ chính xác cao. Dùng để đo khoảng thời gian
love.timer.getFPS()       -- khung hình/giây hiện tại
love.timer.getDelta()     -- dt của khung vừa rồi
love.timer.sleep(0.1)     -- ngủ 0,1 giây (hiếm khi cần)
```

Đo thời gian chạy của đoạn code:

```lua
local t0 = love.timer.getTime()
-- ... việc nặng ...
print(string.format("mất %.2f ms", (love.timer.getTime() - t0) * 1000))
```

Hiện FPS lên màn hình:

```lua
love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
```

### Bộ đếm lùi / hẹn giờ

```lua
local hen = {}

function hen.sau(giay, hamGoi)
  hen[#hen + 1] = { con = giay, f = hamGoi }
end

function hen.update(dt)
  for i = #hen, 1, -1 do                  -- duyệt ngược để xoá an toàn
    local h = hen[i]
    h.con = h.con - dt
    if h.con <= 0 then
      table.remove(hen, i)
      h.f()
    end
  end
end

-- hen.sau(2, function() print("2 giây đã trôi") end)
-- gọi hen.update(dt) trong love.update
```

### Ngày giờ thực

```lua
os.date("%H:%M:%S")          --> "14:05:09"
os.date("%d/%m/%Y")          --> "31/10/2026"
os.time()                    -- số giây từ 1970 (timestamp)
```

## UTF-8 (chữ tiếng Việt)

Chuỗi Lua là dãy **byte**; chữ có dấu chiếm 2–3 byte. `#"ế"` là 3, không phải 1. Để làm việc theo ký tự, dùng thư viện `utf8`:

```lua
local utf8 = require("utf8")
print(utf8.len("Xin chào"))                  --> 8
for pos, cp in utf8.codes("việt") do
  print(pos, utf8.char(cp))
end
```
