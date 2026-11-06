# Bắt đầu với LÖVE

**LÖVE** (viết tắt LÖVE2D) là framework làm game 2D miễn phí, mã nguồn mở. Bạn viết game bằng ngôn ngữ **Lua**; LÖVE lo phần khó: mở cửa sổ, vẽ đồ hoạ bằng GPU, phát âm thanh, nhận phím/chạm, đọc file.

Catnip Engine nhúng sẵn lõi LÖVE, nên bạn có thể viết và chạy game ngay trên iPhone/iPad, không cần máy tính.

## Tạo và chạy game đầu tiên

1. Ở màn hình **Dự án**, bấm **+** và chọn loại **LÖVE**. Catnip tạo sẵn `main.lua` và `conf.lua`.
2. Mở `main.lua` bằng thanh bên (biểu tượng ☰ góc trái).
3. Bấm nút **▶︎** (Chạy) ở thanh trên. Game mở toàn màn hình, có nút **Log** và **Thoát** nổi ở góc.
4. Sửa code, bấm **Thoát**, rồi **▶︎** lần nữa để thấy thay đổi.

> Catnip tự lưu file khi bạn gõ, và lưu lại ngay trước khi chạy game.

## Cấu trúc một dự án LÖVE

```
my-game/
├── main.lua        -- BẮT BUỘC: điểm vào của game
├── conf.lua        -- tuỳ chọn: cấu hình (tên, kích thước, module)
├── player.lua      -- các file code của bạn
├── enemy.lua
└── assets/
    ├── hero.png    -- ảnh
    ├── music.ogg   -- âm thanh
    └── font.ttf    -- font chữ
```

Quy tắc đặt tên: tránh dấu cách và chữ có dấu trong tên file, dùng chữ thường như `hero_run.png` để khỏi nhầm khi viết đường dẫn.

## Hello World

```lua
function love.draw()
  love.graphics.print("Hello World!", 400, 300)
end
```

Chỉ vậy thôi: LÖVE gọi `love.draw()` mỗi khung hình và bạn vẽ chữ tại điểm (400, 300).

## Vòng lặp game

Mọi game đều chạy theo một vòng lặp lặp đi lặp lại khoảng 60 lần mỗi giây:

```
┌─ nhận sự kiện (phím, chạm...) ─┐
│  love.update(dt)  → cập nhật   │
│  love.draw()      → vẽ         │
└────────── lặp lại ─────────────┘
```

Ba hàm bạn sẽ dùng nhiều nhất:

```lua
local x = 0

function love.load()
  -- Chạy MỘT LẦN lúc khởi động: nạp ảnh, âm thanh, đặt giá trị ban đầu
  x = 100
end

function love.update(dt)
  -- Chạy MỖI khung hình trước khi vẽ.
  -- dt = số giây từ khung hình trước (khoảng 0.016 nếu 60 khung/giây)
  x = x + 100 * dt        -- di chuyển 100 pixel mỗi giây
end

function love.draw()
  -- Chạy MỖI khung hình sau update. CHỈ vẽ ở đây, không đổi trạng thái game.
  love.graphics.circle("fill", x, 200, 20)
end
```

> **Luôn nhân với `dt`.** Nếu bạn viết `x = x + 2` thì game chạy nhanh gấp đôi trên máy 120 Hz so với máy 60 Hz. Viết `x = x + 120 * dt` thì tốc độ luôn là 120 pixel/giây.

## Hệ toạ độ

- Gốc `(0, 0)` ở **góc trên bên trái** màn hình.
- `x` tăng sang **phải**, `y` tăng xuống **dưới** (ngược với toán học).
- Góc xoay tính bằng **radian**, xoay **theo chiều kim đồng hồ**. Một vòng tròn là `2 * math.pi`; 180° là `math.pi`.

```lua
local w, h = love.graphics.getDimensions()   -- kích thước màn hình
love.graphics.circle("fill", w / 2, h / 2, 30) -- chấm tròn giữa màn hình
```

Đổi độ sang radian: `math.rad(90)`; ngược lại: `math.deg(math.pi)`.

## Chia code ra nhiều file

```lua
-- player.lua
local Player = {}

function Player.new(x, y)
  return { x = x, y = y, speed = 200 }
end

function Player.update(p, dt)
  p.x = p.x + p.speed * dt
end

return Player          -- file module phải return thứ muốn chia sẻ
```

```lua
-- main.lua
local Player = require("player")      -- KHÔNG có đuôi .lua
local hero

function love.load()
  hero = Player.new(50, 100)
end

function love.update(dt)
  Player.update(hero, dt)
end
```

File trong thư mục con dùng dấu chấm: `require("src.enemy")` nạp `src/enemy.lua`.

## In ra để gỡ lỗi

`print(...)` hiện trong **Log** của Catnip (menu ⋯ → *Xem log lần chạy gần nhất*, hoặc nút Log nổi trên game).

```lua
print("x =", x, "y =", y)
print(string.format("FPS: %d", love.timer.getFPS()))
```

## Lộ trình học gợi ý

1. Đọc **Lua cơ bản** nếu bạn chưa biết Lua.
2. **Callback** và **Đồ hoạ**: vẽ hình, chữ, di chuyển.
3. **Nhập liệu**: điều khiển bằng phím và chạm.
4. **Hình ảnh và hoạt ảnh**, **Âm thanh**: làm game có hình có tiếng.
5. **Va chạm** hoặc **Vật lý**: để các vật tương tác.
6. **Mẫu game** để xem game hoàn chỉnh (Pong, Rắn săn mồi).

Tài liệu chính thức (tiếng Anh, đầy đủ nhất): <https://love2d.org/wiki/Main_Page>
