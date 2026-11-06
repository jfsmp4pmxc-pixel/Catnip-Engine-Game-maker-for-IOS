# Đồ hoạ — `love.graphics`

Mọi lệnh vẽ đều gọi trong `love.draw()`. LÖVE vẽ bằng GPU, nên vẽ hàng nghìn hình mỗi khung hình vẫn mượt.

## Màu sắc

Mỗi kênh màu nằm trong khoảng **0 đến 1** (không phải 0–255) kể từ LÖVE 11.

```lua
love.graphics.setBackgroundColor(0.1, 0.1, 0.15)   -- màu nền, đặt trong love.load
love.graphics.setColor(1, 0.5, 0)                  -- cam (R, G, B)
love.graphics.setColor(1, 1, 1, 0.5)               -- trắng, độ đục 50% (R, G, B, A)
love.graphics.setColor({0.2, 0.8, 0.3})            -- cũng nhận bảng
```

Đổi từ 0–255: chia 255, hoặc dùng `love.math.colorFromBytes(255, 128, 0)`.

> Màu bạn đặt bằng `setColor` **áp dụng cho mọi thứ vẽ sau đó** cho tới khi đổi. Trước khi vẽ ảnh, hãy `setColor(1, 1, 1)` kẻo ảnh bị nhuộm màu.

## Hình cơ bản

```lua
-- Hình chữ nhật: "fill" = tô đặc, "line" = chỉ viền
love.graphics.rectangle("fill", x, y, rong, cao)
love.graphics.rectangle("fill", x, y, rong, cao, 10, 10)   -- bo góc (rx, ry)

-- Hình tròn và elip
love.graphics.circle("fill", x, y, banKinh)
love.graphics.ellipse("line", x, y, banKinhX, banKinhY)

-- Cung tròn (góc bằng radian)
love.graphics.arc("fill", x, y, banKinh, 0, math.pi / 2)

-- Đường thẳng, đa giác, điểm
love.graphics.line(x1, y1, x2, y2, x3, y3)    -- nối liên tiếp các điểm
love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3)
love.graphics.points(100, 100, 102, 100)       -- các điểm lẻ
```

### Độ dày và kiểu nét

```lua
love.graphics.setLineWidth(4)
love.graphics.setLineStyle("smooth")      -- hoặc "rough"
love.graphics.setPointSize(5)
```

## Chữ

```lua
love.graphics.print("Điểm: 100", 10, 10)
love.graphics.print("To gấp đôi", 10, 40, 0, 2, 2)      -- (x, y, góc xoay, scaleX, scaleY)

-- In có xuống dòng tự động và căn lề: printf(chữ, x, y, bềRộngTốiĐa, căn)
love.graphics.printf("Căn giữa", 0, 100, love.graphics.getWidth(), "center")
love.graphics.printf("Căn phải", 0, 130, love.graphics.getWidth(), "right")
```

### Font

```lua
local font24, fontDep

function love.load()
  font24 = love.graphics.newFont(24)                      -- font mặc định, cỡ 24
  fontDep = love.graphics.newFont("assets/font.ttf", 32)  -- font của bạn (.ttf/.otf)
  love.graphics.setFont(font24)                           -- áp dụng cho các lệnh in sau đó
end

function love.draw()
  love.graphics.setFont(fontDep)
  love.graphics.print("Tiêu đề", 10, 10)
end
```

Đo chữ để căn chỉnh:

```lua
local w = font24:getWidth("Xin chào")
local h = font24:getHeight()
love.graphics.print("Xin chào", (love.graphics.getWidth() - w) / 2, 100)
```

> Font mặc định của một số bản LÖVE (nhất là 11.x) **thiếu nhiều chữ có dấu tiếng Việt** (ạ, ế, ữ...). Nếu thấy chữ bị ô vuông hoặc mất dấu, hãy nhập một font `.ttf` hỗ trợ tiếng Việt (ví dụ Noto Sans, Roboto) bằng nút nhập ở thanh bên rồi dùng `love.graphics.newFont("assets/ten-font.ttf", cỡ)`.

## Hình ảnh

```lua
local anh

function love.load()
  anh = love.graphics.newImage("assets/hero.png")
end

function love.draw()
  love.graphics.setColor(1, 1, 1)
  -- draw(ảnh, x, y, xoay, scaleX, scaleY, tâmX, tâmY)
  love.graphics.draw(anh, 100, 100)
  love.graphics.draw(anh, 300, 100, 0, 2, 2)       -- phóng to gấp đôi
end
```

Xem chương *Hình ảnh, sprite và hoạt ảnh* để biết cách xoay quanh tâm, lật ảnh, cắt sprite sheet.

## Biến đổi hệ toạ độ

Thay vì tính toạ độ thủ công, bạn dịch/xoay/phóng cả hệ toạ độ rồi vẽ:

```lua
love.graphics.push()                 -- lưu trạng thái biến đổi
love.graphics.translate(200, 150)    -- dời gốc toạ độ tới (200, 150)
love.graphics.rotate(math.pi / 4)    -- xoay 45°
love.graphics.scale(2)               -- phóng to gấp đôi
love.graphics.rectangle("fill", -25, -25, 50, 50)   -- hình vuông quanh gốc mới
love.graphics.pop()                  -- trả về như cũ
```

Thứ tự quan trọng: lệnh gọi **sau** tác động lên hệ toạ độ đã bị biến đổi bởi lệnh **trước**.

`love.graphics.origin()` đặt lại hệ toạ độ gốc.

Muốn lưu cả màu, font, độ dày nét: `love.graphics.push("all")` ... `love.graphics.pop()`.

## Cắt vùng vẽ (scissor)

```lua
love.graphics.setScissor(50, 50, 200, 100)   -- chỉ vẽ trong khung (x, y, rộng, cao)
-- ... vẽ ...
love.graphics.setScissor()                    -- bỏ cắt
```

## Chế độ hoà trộn màu (blend mode)

```lua
love.graphics.setBlendMode("add")        -- cộng sáng: lửa, tia sáng, hạt phát sáng
love.graphics.circle("fill", 100, 100, 40)
love.graphics.setBlendMode("alpha")      -- trở về mặc định
```

Chế độ hay dùng: `"alpha"` (mặc định), `"add"` (cộng), `"subtract"`, `"multiply"` (nhân, tối đi), `"screen"`.

## Canvas — vẽ ra một "tờ giấy" riêng

Canvas là ảnh bạn có thể vẽ lên. Dùng để vẽ trước một cảnh phức tạp rồi phóng to, áp hiệu ứng, hoặc để làm **độ phân giải ảo** cho game pixel art.

```lua
local canvas

function love.load()
  canvas = love.graphics.newCanvas(160, 90)       -- tờ giấy nhỏ 160×90
  canvas:setFilter("nearest", "nearest")          -- phóng to không bị mờ
end

function love.draw()
  -- 1. Vẽ lên canvas
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0.1, 0.1, 0.2)
  love.graphics.setColor(1, 0.8, 0)
  love.graphics.circle("fill", 80, 45, 10)
  love.graphics.setCanvas()                       -- quay về màn hình

  -- 2. Vẽ canvas lên màn hình, phóng to cho vừa
  love.graphics.setColor(1, 1, 1)
  local sw, sh = love.graphics.getDimensions()
  local scale = math.min(sw / 160, sh / 90)
  love.graphics.draw(canvas, 0, 0, 0, scale, scale)
end
```

## Kích thước màn hình

```lua
local w, h = love.graphics.getDimensions()
local rong = love.graphics.getWidth()
local cao = love.graphics.getHeight()
```

Khi xoay màn hình `w, h` đổi: hãy tính vị trí giao diện dựa trên chúng thay vì số cố định (xem `love.resize`).

## Màn hình có độ phân giải ảo

Nếu muốn game luôn có kích thước logic cố định (ví dụ 800×600) trên mọi thiết bị, dùng `push`/`scale` toàn cục:

```lua
local LOGIC_W, LOGIC_H = 800, 600

function love.draw()
  local sw, sh = love.graphics.getDimensions()
  local s = math.min(sw / LOGIC_W, sh / LOGIC_H)
  love.graphics.push()
  love.graphics.translate((sw - LOGIC_W * s) / 2, (sh - LOGIC_H * s) / 2)  -- căn giữa
  love.graphics.scale(s)
  -- ... vẽ game ở toạ độ 800×600 ...
  love.graphics.rectangle("line", 0, 0, LOGIC_W, LOGIC_H)
  love.graphics.pop()
end
```

Với cảm ứng, nhớ đổi toạ độ chạm về toạ độ logic: `lx = (x - offsetX) / s`.

## Gợi ý hiệu năng

- Gọi `newImage`, `newFont` trong `love.load`, không gọi mỗi khung hình.
- Vẽ nhiều ảnh cùng một texture: dùng **SpriteBatch** (xem chương *Hình ảnh*).
- Hạn chế đổi `setColor`, `setFont`, `setShader`, `setCanvas` liên tục giữa các lệnh vẽ.
