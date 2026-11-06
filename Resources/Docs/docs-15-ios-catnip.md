# Dùng LÖVE trên iOS với Catnip

## Dự án nằm ở đâu

Dự án của bạn nằm trong thư mục **Documents** của Catnip. Vì vậy:

- Mở ứng dụng **Tệp (Files)** → *Trên iPhone/iPad của tôi* → **Catnip** để xem, sao chép, chia sẻ dự án.
- Bạn có thể kéo thả file (ảnh, âm thanh, font) vào thư mục dự án ngay từ Tệp.
- Trong Catnip, dùng nút **nhập** ở thanh bên để đưa file từ Tệp, iCloud, Ảnh... vào dự án.

Thư mục `Inbox` và `iSH` là tên **dành riêng** của hệ thống, đừng đặt tên dự án trùng.

## Chạy game

Bấm nút chạy trên thanh trên cùng: game mở trong lớp phủ toàn màn hình. Đóng bằng nút thoát của lớp phủ. Mỗi lần chạy, LÖVE đọc lại dự án từ đĩa, nên **lưu file trước khi chạy**.

`print(...)` và lỗi Lua hiện trong màn hình log của Catnip.

## Màn hình, vùng an toàn và xoay

Các thiết bị có tai thỏ (notch) hoặc đảo động (Dynamic Island), thanh Home... làm một phần viền màn hình bị che. Lấy vùng an toàn:

```lua
local x, y, w, h = love.window.getSafeArea()    -- hình chữ nhật an toàn để đặt UI

function love.draw()
  -- nền phủ toàn màn hình
  love.graphics.setColor(0.1, 0.1, 0.14)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())

  -- nút/điểm số nằm TRONG vùng an toàn
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Điểm: 0", x + 10, y + 10)
end
```

Sau khi xoay thiết bị, kích thước đổi và `love.resize(w, h)` được gọi; hãy tính lại bố cục ở đó.

### Độ phân giải ảo

Mỗi thiết bị một kích thước khác nhau. Cách bền nhất là vẽ vào canvas cố định (vd 360×640) rồi phóng ra vừa màn hình: xem chương **Đồ hoạ**, mục *độ phân giải ảo*. Nhớ đổi toạ độ chạm về hệ ảo:

```lua
local function sangAo(px, py)
  return (px - offX) / scale, (py - offY) / scale
end
```

## Điều khiển cảm ứng

- Chạm một ngón cũng gửi `love.mousepressed` (có `istouch == true`).
- Đa chạm dùng `love.touchpressed/moved/released`.
- Hiển thị bàn phím: `love.keyboard.setTextInput(true)`.
- Hãy làm nút **đủ lớn** (≥ 44×44 điểm) và cách xa mép.

Xem chương **Nhập liệu** để có ví dụ cần ảo, vuốt, nút bấm.

## Hiệu năng và pin

- Giữ `t.window.vsync = 1` để tránh vẽ thừa.
- Không tạo ảnh, font, âm thanh trong `love.update`/`love.draw`; nạp một lần ở `love.load`.
- Dùng sprite sheet, `SpriteBatch` cho nhiều đối tượng cùng ảnh.
- Hạn chế số hạt, đối tượng vật lý: thiết bị di động yếu hơn máy tính.
- Giảm kích thước ảnh nếu không cần: ảnh 4096×4096 chiếm khoảng 64 MB bộ nhớ.

## Tệp được lưu ở đâu khi game chạy

- Dự án (mã, ảnh, âm thanh) → Documents, **chỉ đọc** với game.
- Dữ liệu game ghi (điểm cao, cài đặt) → thư mục lưu của LÖVE, theo `t.identity`.

Chi tiết xem chương **File và lưu dữ liệu**.

## Shell (cửa sổ dòng lệnh)

Bật trong **Cài đặt → Cửa sổ shell**: trên thanh công cụ xuất hiện nút terminal.

- Nếu bản dựng của bạn có **iSH**, đó là một môi trường Linux (Alpine) thật chạy trong app. Thư mục dự án (Documents) được gắn vào `/documents`. Bạn có thể dùng `apk add` để cài thêm công cụ (git, python, lua...), nếu có kết nối mạng.
- Nếu không, Catnip dùng **shell tích hợp** với một số lệnh cơ bản.

Lần đầu mở iSH cần giải nén hệ thống tệp nên có thể mất ít phút.

## Phân phối game của bạn

Catnip là môi trường phát triển và chạy thử. Để phát hành lên App Store, bạn cần đóng gói game vào một dự án iOS riêng, có chứng chỉ ký của Apple Developer; việc này nằm ngoài phạm vi tài liệu.

## Gỡ lỗi nhanh khi game không chạy

1. Xem log: có lỗi `main.lua:LINE:` không?
2. File `main.lua` có nằm ở **gốc** dự án không?
3. Tên file có đúng chữ hoa/thường không? iOS phân biệt hoa/thường: `Hero.png` khác `hero.png`.
4. Có dùng `require("a.b")` đúng tới `a/b.lua` không?

Xem tiếp chương **Gỡ lỗi và lỗi thường gặp**.
