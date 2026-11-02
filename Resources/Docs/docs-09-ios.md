# Mẹo cho iOS và Catnip

## Chạy và gỡ lỗi

- Bấm ▶︎ để chạy; có nút **Log** và **Thoát** nổi trên game.
- `print(...)` ghi ra Log. Lỗi Lua cũng hiện ở đó kèm số dòng.
- Xem lại log lần chạy gần nhất: menu ⋯ → *Xem log*.

## Nhận biết đang chạy trên iOS

```lua
if love.system.getOS() == "iOS" then
  love.system.vibrate(0.1)    -- rung 0,1 giây
end
```

## Vùng an toàn (tai thỏ, thanh Home)

```lua
local x, y, w, h = love.window.getSafeArea()
-- chỉ đặt giao diện quan trọng trong khung (x, y, w, h)
```

## Xoay màn hình

Game tự chọn hướng. Khi xoay, `love.resize(w, h)` được gọi: hãy tính lại bố cục ở đó.

```lua
function love.resize(w, h)
  chieuRong, chieuCao = w, h
end
```

## Màn hình có độ phân giải cao (Retina)

`love.graphics.getDimensions()` trả về kích thước theo điểm; `love.graphics.getPixelDimensions()` theo pixel thật. Với game pixel art, hãy vẽ lên một `Canvas` nhỏ rồi phóng to ra màn hình.

## Dự án nằm ở đâu

Dự án lưu trong thư mục **Documents** của app. Bật Tệp (Files) → *Trên iPhone* → *Catnip* để xem, sao lưu hoặc chép file vào từ app khác.

## Gợi ý hiệu năng

- Nạp ảnh và âm thanh trong `love.load`, không nạp trong `love.update`/`love.draw`.
- Gom nhiều ảnh nhỏ vào một sprite sheet; dùng `love.graphics.newSpriteBatch` khi vẽ hàng trăm sprite giống nhau.
- Âm thanh ngắn dùng `"static"`, nhạc dài dùng `"stream"`.
