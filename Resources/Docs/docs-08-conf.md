# Cấu hình — `conf.lua`

File `conf.lua` chạy trước mọi thứ khác và đặt cấu hình ban đầu của game.

```lua
function love.conf(t)
  t.identity = "game-cua-toi"        -- tên thư mục lưu dữ liệu
  t.version  = "11.5"                -- phiên bản LÖVE game nhắm tới

  t.window.title  = "Game của tôi"
  t.window.width  = 800
  t.window.height = 600
  t.window.resizable = false

  -- Tắt module không dùng để khởi động nhanh hơn
  t.modules.joystick = false
  t.modules.physics  = false
end
```

> Trên iPhone/iPad, game luôn chiếm toàn màn hình; `width` và `height` chủ yếu quyết định tỉ lệ ban đầu. Hãy dùng `love.graphics.getDimensions()` để biết kích thước thật.

## Lỗi hay gặp

- `conf.lua` **không** được gọi các hàm `love.graphics` hay `love.window`, vì chúng chưa sẵn sàng.
- Lỗi cú pháp trong `conf.lua` làm game không khởi động; xem **Log** để biết dòng bị lỗi.
