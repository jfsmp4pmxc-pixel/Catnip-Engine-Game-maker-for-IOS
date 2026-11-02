# Bắt đầu với LÖVE

LÖVE là framework làm game 2D bằng **Lua**. Game của bạn là một thư mục chứa file `main.lua`. Trong Catnip, tạo dự án loại **LÖVE** rồi bấm nút ▶︎ để chạy.

## Cấu trúc dự án

```
my-game/
├── main.lua      -- bắt buộc: code chính
├── conf.lua      -- tuỳ chọn: cấu hình cửa sổ, module
├── player.lua    -- các file code khác
└── assets/
    ├── hero.png
    └── jump.wav
```

## Hello World

```lua
function love.draw()
  love.graphics.print("Hello World!", 400, 300)
end
```

## Ba hàm quan trọng nhất

```lua
local x = 0

function love.load()
  -- chạy 1 lần lúc bắt đầu: nạp ảnh, âm thanh, khởi tạo biến
end

function love.update(dt)
  -- chạy mỗi khung hình; dt = số giây từ khung hình trước
  x = x + 100 * dt   -- di chuyển 100 pixel mỗi giây
end

function love.draw()
  -- chạy mỗi khung hình sau update: chỉ vẽ ở đây
  love.graphics.circle("fill", x, 200, 20)
end
```

> Luôn nhân tốc độ với `dt` để game chạy cùng tốc độ trên mọi máy.

## Chia code ra nhiều file

```lua
-- player.lua
local Player = {}
function Player.new(x, y) return { x = x, y = y } end
return Player

-- main.lua
local Player = require("player")      -- không có đuôi .lua
local p = Player.new(10, 20)
```

Với file trong thư mục con, dùng dấu chấm: `require("src.enemy")` nạp `src/enemy.lua`.

## Tài liệu chính thức

Danh sách đầy đủ mọi hàm: <https://love2d.org/wiki/Main_Page>
