# Hình ảnh, sprite và hoạt ảnh

## Nạp và vẽ ảnh

Nhập ảnh vào dự án bằng nút **nhập file** ở thanh bên (biểu tượng tải xuống), thường đặt vào thư mục `assets/`. Định dạng hỗ trợ: PNG (khuyên dùng, có trong suốt), JPG, BMP, TGA.

```lua
local hero

function love.load()
  hero = love.graphics.newImage("assets/hero.png")   -- nạp MỘT LẦN
end

function love.draw()
  love.graphics.setColor(1, 1, 1)                    -- trắng: giữ màu gốc của ảnh
  love.graphics.draw(hero, 100, 100)
end
```

`love.graphics.draw` nhận đầy đủ các tham số:

```lua
-- draw(ảnh, x, y, xoay, scaleX, scaleY, tâmX, tâmY, nghiêngX, nghiêngY)
love.graphics.draw(hero, 200, 200, math.rad(45), 2, 2, hero:getWidth() / 2, hero:getHeight() / 2)
```

Kích thước ảnh: `hero:getWidth()`, `hero:getHeight()`, hoặc `hero:getDimensions()`.

## Tâm (origin) — xoay và phóng quanh điểm giữa

Mặc định `x, y` là **góc trên trái** của ảnh, và ảnh xoay quanh góc đó. Muốn xoay quanh tâm, đặt tâm (`ox, oy`) ở giữa ảnh:

```lua
local w, h = hero:getDimensions()
love.graphics.draw(hero, x, y, goc, 1, 1, w / 2, h / 2)
-- (x, y) giờ là vị trí của TÂM ảnh
```

## Lật ảnh

Dùng scale âm. Khi lật phải đặt tâm ở giữa, nếu không ảnh nhảy sang chỗ khác:

```lua
local huongPhai = true
local sx = huongPhai and 1 or -1
love.graphics.draw(hero, x, y, 0, sx, 1, w / 2, h / 2)
```

## Pixel art: phóng to không bị mờ

Mặc định LÖVE làm mịn (nội suy) khi phóng to nên pixel art bị nhoè. Đặt bộ lọc **trước khi nạp ảnh**:

```lua
function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")   -- áp dụng cho ảnh nạp sau đó
  hero = love.graphics.newImage("assets/hero.png")
end
```

Hoặc riêng cho một ảnh: `hero:setFilter("nearest", "nearest")`.

## Sprite sheet và Quad

Nhiều khung hình gộp trong một ảnh (sprite sheet) vừa gọn vừa nhanh. Một **Quad** là hình chữ nhật chỉ ra phần nào của ảnh cần vẽ.

```lua
local sheet, quad

function love.load()
  sheet = love.graphics.newImage("assets/sheet.png")
  -- newQuad(x, y, rộng, cao, rộngẢnh, caoẢnh)
  quad = love.graphics.newQuad(0, 0, 32, 32, sheet:getDimensions())
end

function love.draw()
  love.graphics.draw(sheet, quad, 100, 100)     -- có thêm tham số quad sau ảnh
end
```

### Cắt sheet dạng lưới

Nếu mọi khung cùng cỡ và xếp thành lưới:

```lua
local function catLuoi(anh, rong, cao)
  local khung = {}
  local aw, ah = anh:getDimensions()
  for y = 0, ah - cao, cao do
    for x = 0, aw - rong, rong do
      khung[#khung + 1] = love.graphics.newQuad(x, y, rong, cao, aw, ah)
    end
  end
  return khung
end

local khung = catLuoi(sheet, 32, 32)    -- khung[1], khung[2], ... theo từng hàng, trái qua phải
```

## Hoạt ảnh (animation)

Ý tưởng: giữ một bộ đếm thời gian; đủ giờ thì chuyển sang khung kế.

```lua
local Anim = {}
Anim.__index = Anim

function Anim.new(anh, khung, fps)
  return setmetatable({
    anh = anh, khung = khung,
    thoiGianMoiKhung = 1 / fps,
    dem = 0, chiSo = 1
  }, Anim)
end

function Anim:update(dt)
  self.dem = self.dem + dt
  while self.dem >= self.thoiGianMoiKhung do
    self.dem = self.dem - self.thoiGianMoiKhung
    self.chiSo = self.chiSo % #self.khung + 1      -- quay vòng 1..n
  end
end

function Anim:draw(x, y, sx, sy)
  love.graphics.draw(self.anh, self.khung[self.chiSo], x, y, 0, sx or 1, sy or 1)
end
```

Dùng:

```lua
local chay

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  local sheet = love.graphics.newImage("assets/run.png")      -- vd 6 khung 32×32 nằm ngang
  chay = Anim.new(sheet, catLuoi(sheet, 32, 32), 10)          -- 10 khung hình/giây
end

function love.update(dt) chay:update(dt) end
function love.draw() chay:draw(100, 100, 3, 3) end
```

Mẹo: một nhân vật thường có nhiều hoạt ảnh (đứng yên, chạy, nhảy). Giữ mỗi hoạt ảnh là một đối tượng `Anim` và chọn cái phù hợp theo trạng thái:

```lua
local hienTai = anh.dung
if dangChay then hienTai = anh.chay end
if dangNhay then hienTai = anh.nhay end
hienTai:update(dt)
```

## SpriteBatch — vẽ hàng trăm sprite cùng ảnh thật nhanh

Khi cần vẽ rất nhiều hình dùng chung một ảnh (bản đồ ô, sao, đạn), gom vào một SpriteBatch để chỉ tốn một lần gọi vẽ.

```lua
local gach, batch

function love.load()
  gach = love.graphics.newImage("assets/tiles.png")
  local quad = love.graphics.newQuad(0, 0, 16, 16, gach:getDimensions())
  batch = love.graphics.newSpriteBatch(gach, 2000)       -- tối đa 2000 sprite
  for ty = 0, 29 do
    for tx = 0, 39 do
      batch:add(quad, tx * 16, ty * 16)                  -- add(quad, x, y, ...)
    end
  end
end

function love.draw()
  love.graphics.draw(batch)
end
```

Xoá và dựng lại khi bản đồ đổi: `batch:clear()` rồi `batch:add(...)` lại.

## Bản đồ ô (tilemap) đơn giản

```lua
local map = {
  {1, 1, 1, 1, 1},
  {1, 0, 0, 0, 1},
  {1, 0, 2, 0, 1},
  {1, 0, 0, 0, 1},
  {1, 1, 1, 1, 1},
}
local O = 32   -- cạnh mỗi ô

function love.draw()
  for hang = 1, #map do
    for cot = 1, #map[hang] do
      local loai = map[hang][cot]
      if loai == 1 then love.graphics.setColor(0.4, 0.4, 0.5)       -- tường
      elseif loai == 2 then love.graphics.setColor(1, 0.8, 0.2)     -- vật phẩm
      else love.graphics.setColor(0.12, 0.12, 0.15) end             -- sàn
      love.graphics.rectangle("fill", (cot - 1) * O, (hang - 1) * O, O - 1, O - 1)
    end
  end
end
```

Đổi vị trí pixel sang ô và ngược lại:

```lua
local cot  = math.floor(x / O) + 1
local hang = math.floor(y / O) + 1
```

## Hệ thống hạt (particle) — lửa, khói, tia lửa

```lua
local ps

function love.load()
  -- Cần một ảnh nhỏ làm hạt. Ở đây tự tạo một chấm tròn mờ bằng canvas:
  local canvas = love.graphics.newCanvas(16, 16)
  love.graphics.setCanvas(canvas)
  love.graphics.setColor(1, 1, 1)
  love.graphics.circle("fill", 8, 8, 7)
  love.graphics.setCanvas()

  ps = love.graphics.newParticleSystem(canvas, 500)    -- tối đa 500 hạt
  ps:setParticleLifetime(0.5, 1.5)                     -- sống 0,5–1,5 giây
  ps:setEmissionRate(80)                               -- 80 hạt mỗi giây
  ps:setSizes(1, 0.2)                                  -- to dần rồi nhỏ lại
  ps:setSpeed(40, 120)
  ps:setSpread(math.pi / 3)                            -- toả trong góc 60°
  ps:setDirection(-math.pi / 2)                        -- hướng lên
  ps:setLinearAcceleration(0, -60, 0, -20)
  ps:setColors(1, 0.8, 0.2, 1,  1, 0.2, 0, 0)          -- vàng đục → đỏ trong suốt
end

function love.update(dt)
  ps:setPosition(love.mouse.getPosition())
  ps:update(dt)
end

function love.draw()
  love.graphics.setBlendMode("add")                    -- cộng sáng cho đẹp
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(ps)
  love.graphics.setBlendMode("alpha")
end
```

Phát một đợt hạt một lần (nổ): `ps:setEmissionRate(0)` rồi gọi `ps:emit(50)` khi có sự kiện.

## Vẽ chữ thành đối tượng

Nếu chữ ít đổi mà vẽ nhiều lần, dùng `Text` để nhanh hơn:

```lua
local font = love.graphics.newFont(24)
local text = love.graphics.newText(font, "Điểm: 0")

function capNhatDiem(n)
  text:set("Điểm: " .. n)
end

function love.draw()
  love.graphics.draw(text, 10, 10)
end
```
