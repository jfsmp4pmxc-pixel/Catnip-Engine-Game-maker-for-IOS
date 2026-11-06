# `conf.lua` — cấu hình game

`conf.lua` là file đặc biệt, LÖVE chạy **trước** khi tạo cửa sổ, để đọc cài đặt. Đặt cạnh `main.lua`.

```lua
function love.conf(t)
  t.identity = "game_cua_toi"       -- tên thư mục lưu dữ liệu
  t.version = "11.5"                -- phiên bản LÖVE game nhắm tới (xem lưu ý bên dưới)

  t.window.title = "Game của tôi"
  t.window.width = 800
  t.window.height = 600
  t.window.resizable = false
  t.window.vsync = 1                -- 1 = bật vsync (mượt, tiết kiệm pin)
  t.window.msaa = 0                 -- khử răng cưa: 0, 2, 4, 8

  -- tắt module không dùng để khởi động nhanh hơn
  t.modules.joystick = false
  t.modules.physics = false
  t.modules.video = false
end
```

## Các mục hay dùng

| Mục | Ý nghĩa |
|---|---|
| `t.identity` | Tên thư mục lưu (xem **File và lưu dữ liệu**) |
| `t.window.width/height` | Kích thước cửa sổ. Trên iOS luôn toàn màn hình, nhưng giá trị này vẫn là gợi ý |
| `t.window.fullscreen` | `true` để toàn màn hình |
| `t.window.highdpi` | `true` để dùng đủ độ phân giải màn hình Retina |
| `t.window.title` | Tiêu đề cửa sổ |
| `t.window.vsync` | 1 = bật, 0 = tắt, -1 = thích ứng |
| `t.window.msaa` | Mức khử răng cưa |
| `t.window.depth` / `t.window.stencil` | Bật bộ đệm độ sâu/stencil nếu cần |
| `t.console` | Chỉ ý nghĩa trên Windows |
| `t.gammacorrect` | Màu theo không gian tuyến tính (nâng cao) |
| `t.modules.*` | Bật/tắt từng module: `audio`, `data`, `event`, `font`, `graphics`, `image`, `joystick`, `keyboard`, `math`, `mouse`, `physics`, `sound`, `system`, `thread`, `timer`, `touch`, `video`, `window` |

## Quy tắc quan trọng

- Khi `love.conf` chạy, hầu hết module (`love.graphics`, `love.window`, `love.audio`...) **chưa được nạp**; đừng gọi chúng ở đây. Chỉ nên đặt giá trị vào bảng `t`.
- Lỗi trong `conf.lua` làm game không chạy được; kiểm tra cú pháp kỹ.
- Nếu một module bị tắt (`t.modules.physics = false`) mà code vẫn gọi `love.physics`, bạn sẽ gặp lỗi `attempt to index field 'physics' (a nil value)`.

## Phiên bản (`t.version`)

`t.version` cho biết game được viết cho phiên bản LÖVE nào. Nếu runtime khác phiên bản, LÖVE hiện cảnh báo. Catnip nhúng bản LÖVE **12.0 (đang phát triển)**, và API đã thay đổi so với 11.x ở một vài chỗ. Nếu muốn tắt cảnh báo hãy đặt `t.version` khớp phiên bản bạn dùng; hoặc bỏ dòng này.

## Đổi kích thước lúc đang chạy

```lua
love.window.setMode(1024, 768, { resizable = true, vsync = 1 })
love.window.setTitle("Tên mới")
local w, h = love.graphics.getDimensions()
```

Báo khi cửa sổ đổi kích thước (xoay iPhone, kéo cửa sổ iPad):

```lua
function love.resize(w, h)
  print("kích thước mới", w, h)
  -- dựng lại canvas, bố cục UI...
end
```

## Truy cập tham số dòng lệnh

```lua
function love.load(arg, unfilteredArg)
  for i, a in ipairs(arg) do print(i, a) end
end
```

Ít dùng trên iOS.

## Đọc cài đặt hiện tại

```lua
local w, h, flags = love.window.getMode()
print(w, h, flags.fullscreen, flags.vsync, flags.msaa)

local major, minor, revision, codename = love.getVersion()
print(major, minor, revision, codename)
```

## Mẫu `conf.lua` cho game cảm ứng

```lua
function love.conf(t)
  t.identity = "game_cam_ung"
  t.window.title = "Game cảm ứng"
  t.window.highdpi = true
  t.window.vsync = 1
  t.modules.physics = false      -- bỏ nếu không dùng Box2D
  t.modules.video = false
end
```
