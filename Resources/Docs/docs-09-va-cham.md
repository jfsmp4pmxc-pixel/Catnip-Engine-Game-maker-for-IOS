# Va chạm tự làm

Với phần lớn game 2D, không cần thư viện vật lý: vài phép kiểm tra hình học là đủ, và chạy rất nhanh.

## Điểm trong hình chữ nhật

```lua
local function diemTrongHCN(px, py, x, y, w, h)
  return px >= x and px <= x + w and py >= y and py <= y + h
end
```

Dùng cho nút bấm, vùng chạm.

## Hai hình chữ nhật chạm nhau — AABB

AABB (Axis-Aligned Bounding Box): hình chữ nhật không xoay.

```lua
local function aabb(a, b)
  return a.x < b.x + b.w and
         b.x < a.x + a.w and
         a.y < b.y + b.h and
         b.y < a.y + a.h
end
```

Hình dung: hai hộp chỉ **không** chạm khi một cái nằm hoàn toàn bên trái, phải, trên hoặc dưới cái kia. Biểu thức trên là phủ định của cả bốn điều đó.

## Hai hình tròn

So sánh **bình phương** khoảng cách để tránh căn bậc hai (nhanh hơn):

```lua
local function tronTron(a, b)
  local dx, dy = b.x - a.x, b.y - a.y
  local r = a.r + b.r
  return dx * dx + dy * dy <= r * r
end
```

## Hình tròn và hình chữ nhật

```lua
local function tronHCN(c, r)
  -- điểm gần nhất trên HCN tới tâm hình tròn
  local gx = math.max(r.x, math.min(c.x, r.x + r.w))
  local gy = math.max(r.y, math.min(c.y, r.y + r.h))
  local dx, dy = c.x - gx, c.y - gy
  return dx * dx + dy * dy <= c.r * c.r
end
```

## Xử lý va chạm (không chỉ phát hiện)

Biết hai vật chạm chưa đủ: thường phải **đẩy chúng ra** và chặn chuyển động. Mẹo ổn định nhất là **di chuyển và kiểm tra từng trục riêng**:

```lua
local player = { x = 100, y = 100, w = 32, h = 32, vx = 0, vy = 0 }
local tuong = {
  { x = 0, y = 400, w = 800, h = 50 },
  { x = 300, y = 300, w = 100, h = 20 },
}

local function dungTuong(p)
  for _, t in ipairs(tuong) do
    if aabb(p, t) then return t end
  end
end

function love.update(dt)
  -- trục X
  player.x = player.x + player.vx * dt
  local t = dungTuong(player)
  if t then
    if player.vx > 0 then player.x = t.x - player.w        -- đang đi phải → đặt sát cạnh trái tường
    elseif player.vx < 0 then player.x = t.x + t.w end     -- đang đi trái → sát cạnh phải tường
    player.vx = 0
  end

  -- trục Y
  player.vy = player.vy + 900 * dt                          -- trọng lực
  player.y = player.y + player.vy * dt
  player.trenDat = false
  t = dungTuong(player)
  if t then
    if player.vy > 0 then
      player.y = t.y - player.h                             -- đứng trên mặt tường
      player.trenDat = true
    elseif player.vy < 0 then
      player.y = t.y + t.h                                  -- đụng đầu
    end
    player.vy = 0
  end
end

function love.keypressed(key)
  if key == "space" and player.trenDat then player.vy = -450 end
end
```

Tách hai trục là chìa khoá: nếu gộp cả hai, bạn không biết cạnh nào bị chạm nên không đẩy ra đúng hướng được.

## Vật chuyển động rất nhanh xuyên qua tường

Nếu đạn bay 2000 px/giây ở 60 FPS, mỗi khung đi ~33 px; gặp tường mỏng hơn thế nó "nhảy qua". Cách xử lý:

- Chia nhỏ bước: lặp nhiều lần với `dt / n`.
- Hoặc kiểm tra đoạn thẳng thay vì điểm (raycast; xem bên dưới).

```lua
local function buocNho(dt, n)
  for _ = 1, n do capNhat(dt / n) end
end
```

## Va chạm trên bản đồ ô (tilemap)

Với lưới, không cần so sánh với mọi tường; chỉ hỏi ô ở vị trí cần:

```lua
local O = 32
local function oTai(px, py)
  local cot = math.floor(px / O) + 1
  local hang = math.floor(py / O) + 1
  return map[hang] and map[hang][cot]
end

local function laTuong(px, py) return oTai(px, py) == 1 end

-- kiểm tra 4 góc của nhân vật
local function chamTuong(x, y, w, h)
  return laTuong(x, y) or laTuong(x + w - 1, y) or
         laTuong(x, y + h - 1) or laTuong(x + w - 1, y + h - 1)
end
```

Áp dụng: thử di chuyển trục X, nếu `chamTuong` thì hoàn tác; rồi làm tương tự với trục Y.

## Chia lưới không gian (spatial hash) cho nhiều vật

Nếu có hàng trăm vật, so từng cặp là `n²` phép. Chia thế giới thành ô lớn và chỉ so các vật trong cùng/ kề ô:

```lua
local Luoi = {}
Luoi.__index = Luoi

function Luoi.new(co) return setmetatable({ co = co, o = {} }, Luoi) end

local function khoa(cx, cy) return cx .. "," .. cy end

function Luoi:them(v)
  local x1, y1 = math.floor(v.x / self.co), math.floor(v.y / self.co)
  local x2, y2 = math.floor((v.x + v.w) / self.co), math.floor((v.y + v.h) / self.co)
  for cx = x1, x2 do
    for cy = y1, y2 do
      local k = khoa(cx, cy)
      self.o[k] = self.o[k] or {}
      table.insert(self.o[k], v)
    end
  end
end

function Luoi:gan(v)                      -- trả về các vật cùng ô với v
  local ket, thay = {}, {}
  local x1, y1 = math.floor(v.x / self.co), math.floor(v.y / self.co)
  local x2, y2 = math.floor((v.x + v.w) / self.co), math.floor((v.y + v.h) / self.co)
  for cx = x1, x2 do
    for cy = y1, y2 do
      for _, u in ipairs(self.o[khoa(cx, cy)] or {}) do
        if u ~= v and not thay[u] then thay[u] = true; ket[#ket + 1] = u end
      end
    end
  end
  return ket
end
```

Mỗi khung: tạo `Luoi.new(64)`, `them` mọi vật, rồi với mỗi vật chỉ kiểm tra `luoi:gan(v)`.

## Raycast: đường thẳng có cắt vật không

Cắt giữa hai đoạn thẳng (dùng cho tia nhìn, đạn tức thời):

```lua
local function cat(x1, y1, x2, y2, x3, y3, x4, y4)
  local d = (x2 - x1) * (y4 - y3) - (y2 - y1) * (x4 - x3)
  if d == 0 then return false end                      -- song song
  local t = ((x3 - x1) * (y4 - y3) - (y3 - y1) * (x4 - x3)) / d
  local u = ((x3 - x1) * (y2 - y1) - (y3 - y1) * (x2 - x1)) / d
  return t >= 0 and t <= 1 and u >= 0 and u <= 1
end
```

Kiểm tra tia với hình chữ nhật: thử cắt với 4 cạnh của nó.

## Vật xoay (OBB) và đa giác

Với hình xoay hoặc đa giác lồi bất kỳ, kỹ thuật chuẩn là **SAT** (định lý trục phân tách), tương đối dài. Cách đơn giản hơn: dùng hình tròn bao quanh, hoặc dùng `love.physics` (chương kế tiếp).

## Mẹo

- Hitbox nên **nhỏ hơn** hình vẽ một chút để game dễ tính hơn và cảm giác công bằng.
- Vẽ hitbox khi gỡ lỗi: `love.graphics.rectangle("line", v.x, v.y, v.w, v.h)`.
