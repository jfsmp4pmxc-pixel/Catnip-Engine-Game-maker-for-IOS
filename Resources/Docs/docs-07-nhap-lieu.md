# Nhập liệu: bàn phím, chuột, cảm ứng

LÖVE có hai cách nhận nhập liệu:

- **Sự kiện (callback)**: LÖVE gọi hàm của bạn đúng lúc xảy ra, như `love.keypressed`. Dùng cho hành động **một lần** (nhảy, bấm nút).
- **Hỏi trạng thái (polling)**: bạn hỏi "phím này có đang giữ không?" trong `love.update`. Dùng cho hành động **liên tục** (đi, ngắm).

## Bàn phím

```lua
function love.update(dt)
  -- đang giữ phím?
  if love.keyboard.isDown("left")  then x = x - 200 * dt end
  if love.keyboard.isDown("right") then x = x + 200 * dt end
  if love.keyboard.isDown("a", "left") then ... end   -- bất kỳ phím nào trong danh sách
end

function love.keypressed(key, scancode, isrepeat)
  if key == "space" then nhay() end
  if key == "escape" then love.event.quit() end
end

function love.keyreleased(key)
  if key == "space" then ... end
end
```

Tên phím hay dùng: `"a"`–`"z"`, `"0"`–`"9"`, `"space"`, `"return"`, `"escape"`, `"tab"`, `"backspace"`, `"left"`, `"right"`, `"up"`, `"down"`, `"lshift"`, `"rshift"`, `"lctrl"`, `"lalt"`.

**`key` và `scancode`:** `key` là ký tự theo bố cục bàn phím của người dùng; `scancode` là vị trí vật lý của phím (hợp cho điều khiển WASD, vì dù người dùng dùng bố cục AZERTY thì vị trí vẫn đúng). Dùng `love.keyboard.isScancodeDown("w")`.

Cho phép lặp phím khi giữ (hợp với nhập chữ): `love.keyboard.setKeyRepeat(true)`.

### Nhập chữ

```lua
local ten = ""

function love.textinput(t)               -- t là ký tự vừa gõ (đã đúng chữ hoa/thường, dấu)
  ten = ten .. t
end

function love.keypressed(key)
  if key == "backspace" then
    -- cắt bớt MỘT ký tự UTF-8 (không cắt dở byte của chữ có dấu)
    local utf8 = require("utf8")
    local byteoffset = utf8.offset(ten, -1)
    if byteoffset then ten = ten:sub(1, byteoffset - 1) end
  end
end
```

Trên iPhone/iPad, bàn phím ảo chỉ hiện khi bạn gọi `love.keyboard.setTextInput(true)` và tắt bằng `setTextInput(false)`.

## Chuột và chạm

Trên iOS, **một lần chạm cũng gửi sự kiện chuột** (với `istouch = true`), nên code viết cho chuột chạy luôn được trên màn hình cảm ứng:

```lua
function love.mousepressed(x, y, button, istouch, presses)
  if button == 1 then                  -- 1 = chuột trái / chạm; 2 = phải; 3 = giữa
    print("bấm tại", x, y, istouch and "(chạm)" or "(chuột)")
  end
end

function love.mousereleased(x, y, button) end

function love.mousemoved(x, y, dx, dy, istouch)
  -- dx, dy: quãng di chuyển từ lần trước. Dùng để kéo thả
end

-- Hoặc hỏi bất cứ lúc nào:
local mx, my = love.mouse.getPosition()
local dangGiu = love.mouse.isDown(1)
```

## Đa chạm

Để dùng nhiều ngón tay cùng lúc (hai ngón điều khiển hai nút), dùng sự kiện chạm có `id` riêng mỗi ngón:

```lua
local ngonTay = {}

function love.touchpressed(id, x, y)  ngonTay[id] = { x = x, y = y } end
function love.touchmoved(id, x, y)    ngonTay[id] = { x = x, y = y } end
function love.touchreleased(id)       ngonTay[id] = nil end

function love.draw()
  for id, t in pairs(ngonTay) do
    love.graphics.circle("fill", t.x, t.y, 40)
  end
end
```

Hoặc hỏi trực tiếp: `love.touch.getTouches()` trả về danh sách id ngón đang chạm, và `love.touch.getPosition(id)` cho vị trí.

> Một lần chạm gọi **cả** `love.touchpressed` **và** `love.mousepressed`. Nếu xử lý cả hai bạn sẽ nhận hai lần. Chọn một: hoặc chỉ dùng mouse (đơn giản, một ngón), hoặc chỉ dùng touch và bỏ qua mouse khi `istouch` là `true`.

## Nút bấm trên màn hình

```lua
local nut = { x = 20, y = 300, w = 140, h = 60, chu = "Nhảy" }

local function trongNut(n, px, py)
  return px >= n.x and px <= n.x + n.w and py >= n.y and py <= n.y + n.h
end

function love.mousepressed(x, y, button)
  if trongNut(nut, x, y) then print("đã bấm", nut.chu) end
end

function love.draw()
  love.graphics.setColor(0.2, 0.5, 0.9)
  love.graphics.rectangle("fill", nut.x, nut.y, nut.w, nut.h, 10, 10)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(nut.chu, nut.x, nut.y + nut.h / 2 - 8, nut.w, "center")
end
```

## Cần điều khiển ảo (virtual joystick)

Cần ảo là mô hình hay dùng cho game cảm ứng: chạm một điểm làm tâm, kéo để chỉ hướng.

```lua
local cap = { dang = false, id = nil, cx = 0, cy = 0, dx = 0, dy = 0, banKinh = 70 }

function love.touchpressed(id, x, y)
  if not cap.dang and x < love.graphics.getWidth() / 2 then    -- chỉ nhận ở nửa trái màn hình
    cap.dang, cap.id, cap.cx, cap.cy = true, id, x, y
    cap.dx, cap.dy = 0, 0
  end
end

function love.touchmoved(id, x, y)
  if cap.dang and id == cap.id then
    local vx, vy = x - cap.cx, y - cap.cy
    local d = math.sqrt(vx * vx + vy * vy)
    if d > cap.banKinh then vx, vy = vx / d * cap.banKinh, vy / d * cap.banKinh end
    cap.dx, cap.dy = vx / cap.banKinh, vy / cap.banKinh        -- giá trị từ -1 đến 1
  end
end

function love.touchreleased(id)
  if id == cap.id then cap.dang, cap.id, cap.dx, cap.dy = false, nil, 0, 0 end
end

function love.update(dt)
  playerX = playerX + cap.dx * 250 * dt
  playerY = playerY + cap.dy * 250 * dt
end

function love.draw()
  if cap.dang then
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.circle("fill", cap.cx, cap.cy, cap.banKinh)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", cap.cx + cap.dx * cap.banKinh, cap.cy + cap.dy * cap.banKinh, 25)
  end
end
```

## Vuốt (swipe)

```lua
local batDau

function love.touchpressed(id, x, y) batDau = { x = x, y = y, t = love.timer.getTime() } end

function love.touchreleased(id, x, y)
  if not batDau then return end
  local dx, dy = x - batDau.x, y - batDau.y
  local thoiGian = love.timer.getTime() - batDau.t
  if math.sqrt(dx * dx + dy * dy) > 60 and thoiGian < 0.5 then
    if math.abs(dx) > math.abs(dy) then
      print(dx > 0 and "vuốt phải" or "vuốt trái")
    else
      print(dy > 0 and "vuốt xuống" or "vuốt lên")
    end
  end
  batDau = nil
end
```

## Tay cầm game (gamepad)

Tay cầm MFi/PS/Xbox kết nối với iPhone/iPad nhận được qua `love.joystick`:

```lua
function love.gamepadpressed(joystick, button)
  if button == "a" then nhay() end
end

function love.update(dt)
  local joysticks = love.joystick.getJoysticks()
  local js = joysticks[1]
  if js then
    local ngang = js:getGamepadAxis("leftx")     -- -1 đến 1
    x = x + ngang * 200 * dt
  end
end
```

## Con trỏ chuột

```lua
love.mouse.setVisible(false)       -- ẩn con trỏ (trên máy có chuột/bàn di)
```
