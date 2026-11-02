# Các hàm callback

LÖVE gọi các hàm này nếu bạn định nghĩa chúng trong `main.lua`.

| Hàm | Khi nào được gọi |
|---|---|
| `love.load(arg)` | Một lần lúc khởi động |
| `love.update(dt)` | Mỗi khung hình, trước khi vẽ |
| `love.draw()` | Mỗi khung hình, để vẽ |
| `love.keypressed(key, scancode, isrepeat)` | Khi nhấn một phím |
| `love.keyreleased(key, scancode)` | Khi thả phím |
| `love.textinput(text)` | Khi gõ ký tự (hợp với bàn phím ảo) |
| `love.mousepressed(x, y, button, istouch, presses)` | Khi bấm chuột **hoặc chạm màn hình** |
| `love.mousereleased(x, y, button, istouch, presses)` | Khi nhả chuột / nhấc ngón tay |
| `love.mousemoved(x, y, dx, dy, istouch)` | Khi di chuyển chuột / kéo ngón tay |
| `love.wheelmoved(x, y)` | Khi lăn chuột |
| `love.touchpressed(id, x, y, dx, dy, pressure)` | Khi một ngón tay chạm xuống |
| `love.touchmoved(id, x, y, dx, dy, pressure)` | Khi ngón tay di chuyển |
| `love.touchreleased(id, x, y, dx, dy, pressure)` | Khi ngón tay nhấc lên |
| `love.resize(w, h)` | Khi kích thước cửa sổ đổi (xoay màn hình) |
| `love.focus(focus)` | Khi cửa sổ mất/lấy tiêu điểm |
| `love.quit()` | Khi sắp thoát; trả về `true` để huỷ việc thoát |

## Ví dụ

```lua
function love.keypressed(key)
  if key == "space" then print("nhảy!") end
  if key == "escape" then love.event.quit() end
end

function love.touchpressed(id, x, y)
  print("chạm tại", x, y)
end
```

Cả `print` và lỗi của game đều hiện trong **Log** của Catnip (menu ⋯ → Xem log).
