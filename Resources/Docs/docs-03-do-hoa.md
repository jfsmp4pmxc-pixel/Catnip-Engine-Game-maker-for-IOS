# Đồ hoạ — `love.graphics`

Chỉ gọi các hàm vẽ trong `love.draw`.

## Màu sắc

Từ LÖVE 11, mỗi kênh màu nằm trong khoảng **0 đến 1** (không phải 0–255).

```lua
love.graphics.setBackgroundColor(0.1, 0.1, 0.15)   -- màu nền
love.graphics.setColor(1, 0.5, 0)                  -- cam
love.graphics.setColor(1, 1, 1, 0.5)               -- trắng, trong suốt 50%
```

> Nhớ `love.graphics.setColor(1, 1, 1)` trước khi vẽ ảnh, nếu không ảnh bị nhuộm theo màu hiện tại.

## Hình cơ bản

```lua
love.graphics.rectangle("fill", x, y, rong, cao)   -- "fill" = tô đặc, "line" = viền
love.graphics.circle("line", x, y, bankinh)
love.graphics.line(x1, y1, x2, y2, x3, y3)
love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3)
love.graphics.setLineWidth(3)
```

## Chữ

```lua
love.graphics.print("Điểm: " .. score, 10, 10)
love.graphics.printf("Căn giữa", 0, 100, love.graphics.getWidth(), "center")

local font = love.graphics.newFont(24)             -- font mặc định, cỡ 24
local custom = love.graphics.newFont("assets/f.ttf", 32)
love.graphics.setFont(font)
```

## Ảnh

```lua
local img

function love.load()
  img = love.graphics.newImage("assets/hero.png")
end

function love.draw()
  love.graphics.setColor(1, 1, 1)
  -- draw(ảnh, x, y, góc xoay (radian), scaleX, scaleY, tâm X, tâm Y)
  love.graphics.draw(img, 100, 100, 0, 2, 2)
end
```

Pixel art sắc nét (không bị mờ khi phóng to):

```lua
love.graphics.setDefaultFilter("nearest", "nearest")   -- gọi trước khi newImage
```

## Biến đổi hệ toạ độ

```lua
love.graphics.push()
love.graphics.translate(200, 150)    -- dời gốc toạ độ
love.graphics.rotate(math.pi / 4)    -- xoay 45°
love.graphics.scale(2)               -- phóng to
-- vẽ ở đây
love.graphics.pop()                  -- trả về như cũ
```

## Kích thước màn hình

```lua
local w, h = love.graphics.getDimensions()
```

## Sprite sheet (Quad)

```lua
local sheet = love.graphics.newImage("assets/sheet.png")
-- newQuad(x, y, rộng, cao, rộngẢnh, caoẢnh)
local quad = love.graphics.newQuad(0, 0, 32, 32, sheet:getDimensions())
love.graphics.draw(sheet, quad, 100, 100)
```

## Canvas (vẽ ra ảnh)

```lua
local canvas = love.graphics.newCanvas(256, 256)
love.graphics.setCanvas(canvas)
  love.graphics.clear()
  love.graphics.circle("fill", 128, 128, 50)
love.graphics.setCanvas()            -- quay về màn hình
love.graphics.draw(canvas, 0, 0)
```
