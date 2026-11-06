# Vòng đời game và các hàm callback

LÖVE tự quản lý vòng lặp chính; bạn chỉ cần **định nghĩa các hàm callback** trong `main.lua`. LÖVE gọi chúng đúng lúc.

## Thứ tự chạy

```
love.load(arg)                  ← một lần
┌───────────────────────────────────────────┐
│ xử lý sự kiện → love.keypressed, mousepressed, touchpressed...
│ love.update(dt)
│ love.draw()
└──────────────── lặp lại ──────────────────┘
love.quit()                     ← khi thoát
```

## Callback chính

| Hàm | Khi nào được gọi |
|---|---|
| `love.load(arg, unfilteredArg)` | Một lần lúc khởi động |
| `love.update(dt)` | Mỗi khung hình, trước khi vẽ |
| `love.draw()` | Mỗi khung hình, để vẽ |
| `love.quit()` | Khi sắp thoát. Trả về `true` để **huỷ** việc thoát |

## Callback nhập liệu

| Hàm | Khi nào được gọi |
|---|---|
| `love.keypressed(key, scancode, isrepeat)` | Khi nhấn một phím |
| `love.keyreleased(key, scancode)` | Khi thả phím |
| `love.textinput(text)` | Khi gõ ký tự (hợp với bàn phím ảo) |
| `love.mousepressed(x, y, button, istouch, presses)` | Khi bấm chuột **hoặc chạm màn hình** |
| `love.mousereleased(x, y, button, istouch, presses)` | Khi nhả chuột / nhấc ngón tay |
| `love.mousemoved(x, y, dx, dy, istouch)` | Khi di chuyển chuột / kéo ngón tay |
| `love.wheelmoved(x, y)` | Khi lăn chuột |
| `love.touchpressed(id, x, y, dx, dy, pressure)` | Một ngón tay chạm xuống |
| `love.touchmoved(id, x, y, dx, dy, pressure)` | Ngón tay di chuyển |
| `love.touchreleased(id, x, y, dx, dy, pressure)` | Ngón tay nhấc lên |

## Callback cửa sổ và hệ thống

| Hàm | Khi nào được gọi |
|---|---|
| `love.resize(w, h)` | Kích thước cửa sổ đổi (ví dụ xoay màn hình) |
| `love.focus(focus)` | Cửa sổ có/mất tiêu điểm (`focus` là `true`/`false`) |
| `love.visible(visible)` | Cửa sổ hiện/ẩn (thu nhỏ) |
| `love.lowmemory()` | Hệ thống báo thiếu bộ nhớ: nên giải phóng bớt tài nguyên |
| `love.displayrotated(display, orientation)` | Màn hình bị xoay (bản LÖVE mới) |
| `love.themechanged()` | Người dùng đổi giao diện sáng/tối của hệ thống (bản LÖVE mới) |
| `love.errorhandler(msg)` | Thay màn hình lỗi mặc định (nâng cao) |

## `love.load(arg)`

Chạy một lần. Đây là chỗ nạp tài nguyên và đặt giá trị ban đầu:

```lua
local hinh, tiengNo, font
local diem

function love.load()
  hinh = love.graphics.newImage("assets/ship.png")
  tiengNo = love.audio.newSource("assets/boom.wav", "static")
  font = love.graphics.newFont(24)
  diem = 0
end
```

> Đừng nạp ảnh/âm thanh trong `love.update` hay `love.draw`: việc đọc file mỗi khung hình làm game giật.

## `love.update(dt)`

Cập nhật logic game: di chuyển, va chạm, bộ đếm giờ, AI. **`dt`** là số giây kể từ lần gọi trước.

```lua
local tauX = 100
local tocDo = 250        -- pixel mỗi giây

function love.update(dt)
  if love.keyboard.isDown("right") then tauX = tauX + tocDo * dt end
  if love.keyboard.isDown("left")  then tauX = tauX - tocDo * dt end
end
```

### Bộ đếm giờ

```lua
local thoiGianBan = 0

function love.update(dt)
  thoiGianBan = thoiGianBan - dt
  if thoiGianBan <= 0 then
    print("bắn!")
    thoiGianBan = 0.5          -- mỗi 0,5 giây bắn một lần
  end
end
```

## `love.draw()`

Chỉ vẽ ở đây. Mỗi khung hình bắt đầu với màn hình đã xoá (bằng màu nền), nên bạn vẽ lại **mọi thứ** mỗi lần.

```lua
function love.draw()
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(hinh, tauX, 400)
  love.graphics.print("Điểm: " .. diem, 10, 10)
end
```

## Ví dụ: bắt phím và chạm

```lua
function love.keypressed(key, scancode, isrepeat)
  if key == "space" then print("nhảy!") end
  if key == "escape" then love.event.quit() end   -- thoát game
end

function love.touchpressed(id, x, y)
  print("chạm tại", x, y)
end

function love.resize(w, h)
  print("kích thước mới", w, h)     -- gọi khi xoay màn hình
end
```

## Dừng game, thoát, khởi động lại

```lua
love.event.quit()            -- thoát game
love.event.quit("restart")   -- khởi động lại game từ đầu
```

Trong Catnip có thêm nút **Thoát** nổi trên màn hình game.

## Cách chia game thành các màn hình (state)

Một mẫu phổ biến: mỗi màn hình (menu, chơi, thua) là một bảng có `update`/`draw`/`keypressed` riêng, `main.lua` chỉ chuyển tiếp.

```lua
local menu = {}
local choi = {}
local state = menu            -- màn hình hiện tại

function menu.draw()
  love.graphics.printf("CHẠM ĐỂ CHƠI", 0, 200, love.graphics.getWidth(), "center")
end
function menu.press() state = choi end

function choi.update(dt) end
function choi.draw()
  love.graphics.print("Đang chơi", 10, 10)
end
function choi.press() state = menu end

function love.update(dt) if state.update then state.update(dt) end end
function love.draw()     if state.draw then state.draw() end end
function love.mousepressed(x, y) if state.press then state.press(x, y) end end
function love.keypressed(k) if state.press and k == "space" then state.press() end end
```

## Vòng lặp mặc định (`love.run`) — nâng cao

LÖVE có sẵn hàm `love.run` chứa vòng lặp chính. Bạn có thể tự định nghĩa lại nếu muốn kiểm soát thời gian cố định (fixed timestep) hay vẽ theo cách riêng. Đây là bản mặc định của LÖVE (rút gọn), để bạn thấy các callback được gọi như thế nào:

```lua
function love.run()
  if love.load then love.load(love.parsedGameArguments, love.rawGameArguments) end
  if love.timer then love.timer.step() end        -- để dt khung đầu không tính thời gian nạp

  return function()                                -- hàm này được gọi lặp lại mỗi khung hình
    if love.event then
      love.event.pump()
      for name, a, b, c, d, e, f, g, h in love.event.poll() do
        if name == "quit" then
          if c or not love.quit or not love.quit() then
            return a or 0, b                       -- thoát
          end
        end
        love.handlers[name](a, b, c, d, e, f, g, h)  -- gọi love.keypressed, love.mousepressed...
      end
    end

    local dt = love.timer and love.timer.step() or 0
    if love.update then love.update(dt) end

    if love.graphics and love.graphics.isActive() then
      love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())
      if love.draw then love.draw() end
      love.graphics.present()
    end

    if love.timer then love.timer.sleep(0.001) end
  end
end
```

Phần lớn game **không cần** sửa `love.run`. Ở các bản LÖVE cũ hơn (11.x), tham số của `love.load` được lấy bằng `love.arg.parseGameArguments(arg), arg`.

### Thời gian cố định cho vật lý

Nếu game cần mô phỏng ổn định (không phụ thuộc tốc độ khung hình), giữ `love.update` nhưng chia nhỏ `dt`:

```lua
local BUOC = 1 / 60
local tichLuy = 0

function love.update(dt)
  tichLuy = tichLuy + math.min(dt, 0.25)      -- tránh "xoáy ốc" khi bị đứng hình lâu
  while tichLuy >= BUOC do
    capNhatGame(BUOC)                          -- hàm của bạn, luôn nhận bước cố định
    tichLuy = tichLuy - BUOC
  end
end
```
