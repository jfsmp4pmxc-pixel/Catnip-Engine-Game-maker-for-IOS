# File và lưu dữ liệu — `love.filesystem`

LÖVE chạy game trong một "hộp cát" file:

- **Đọc** file của game (ảnh, âm thanh, code) từ thư mục dự án.
- **Ghi** file chỉ vào **thư mục lưu riêng của game** (trong sandbox của app), không ghi vào thư mục dự án.

```lua
-- Ghi và đọc điểm cao
love.filesystem.write("save.txt", tostring(diemCao))

if love.filesystem.getInfo("save.txt") then
  diemCao = tonumber(love.filesystem.read("save.txt")) or 0
end
```

| Việc cần làm | Cách làm |
|---|---|
| Kiểm tra file tồn tại | `love.filesystem.getInfo(path)` (trả về `nil` nếu không có) |
| Đọc toàn bộ | `love.filesystem.read(path)` |
| Ghi | `love.filesystem.write(path, text)` |
| Thêm vào cuối | `love.filesystem.append(path, text)` |
| Liệt kê thư mục | `love.filesystem.getDirectoryItems("assets")` |
| Tạo thư mục | `love.filesystem.createDirectory("saves")` |
| Xoá | `love.filesystem.remove(path)` |
| Đường dẫn thư mục lưu | `love.filesystem.getSaveDirectory()` |

## Tên thư mục lưu

Đặt trong `conf.lua`:

```lua
function love.conf(t)
  t.identity = "ten-game-cua-toi"
end
```

## Lưu bảng (table) dạng văn bản

Lua không có sẵn JSON. Cách đơn giản là tự viết hàm tuần tự hoá, hoặc dùng thư viện như `json.lua` (đặt vào dự án rồi `require`).
