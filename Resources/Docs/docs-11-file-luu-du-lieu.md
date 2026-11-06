# File và lưu dữ liệu — `love.filesystem`

## Nguyên tắc sandbox

LÖVE **không** cho game ghi vào đâu tuỳ ý. Mọi file đọc/ghi qua `love.filesystem` nằm trong hai vùng:

1. **Thư mục nguồn** (nơi chứa `main.lua`, `assets/`...) — **chỉ đọc** (đọc được).
2. **Thư mục lưu** (save directory) — nơi game **ghi** dữ liệu (điểm cao, cài đặt, tiến trình).

Khi đọc, LÖVE tìm ở thư mục lưu trước, rồi mới tới thư mục nguồn. Toàn bộ đường dẫn dùng dấu `/` và là đường dẫn **tương đối**, không có `..`.

Thư mục lưu được đặt theo **định danh** (identity) — mặc định lấy từ tên thư mục dự án; đổi trong `conf.lua`:

```lua
function love.conf(t)
  t.identity = "game_cua_toi"
end
```

Xem đường dẫn thật (để gỡ lỗi): `love.filesystem.getSaveDirectory()`.

## Ghi và đọc văn bản

```lua
love.filesystem.write("diem.txt", "1250")                  -- tạo/ghi đè
love.filesystem.append("log.txt", "một dòng\n")             -- ghi nối

if love.filesystem.getInfo("diem.txt") then                 -- tồn tại chưa?
  local noiDung = love.filesystem.read("diem.txt")          -- trả về chuỗi
  local diem = tonumber(noiDung) or 0
end
```

`love.filesystem.read` trả về `nil, lỗi` nếu thất bại; dùng `love.filesystem.getInfo(path)` để biết loại/kích thước:

```lua
local info = love.filesystem.getInfo("diem.txt")
if info then
  print(info.type, info.size, info.modtime)     -- "file", số byte, thời điểm sửa
end
```

## Liệt kê, tạo, xoá

```lua
love.filesystem.createDirectory("saves")                      -- tạo thư mục (trong thư mục lưu)
local ds = love.filesystem.getDirectoryItems("saves")          -- tên các mục
for _, ten in ipairs(ds) do print(ten) end

love.filesystem.remove("saves/slot1.txt")                      -- xoá file hoặc thư mục RỖNG
```

## Lưu bảng Lua (table) — tự viết bộ tuần tự hoá

Lưu `{ diem = 100, ten = "An", vatPham = {...} }` cần chuyển thành chuỗi. Cách đơn giản và đọc được: sinh ra code Lua rồi nạp lại bằng `load`.

```lua
local function tuanTu(v, indent)
  indent = indent or ""
  local kieu = type(v)
  if kieu == "number" or kieu == "boolean" then
    return tostring(v)
  elseif kieu == "string" then
    return string.format("%q", v)               -- thêm nháy và thoát ký tự đặc biệt
  elseif kieu == "table" then
    local phan = {}
    for k, val in pairs(v) do
      local khoa
      if type(k) == "string" then khoa = "[" .. string.format("%q", k) .. "]"
      else khoa = "[" .. tostring(k) .. "]" end
      phan[#phan + 1] = indent .. "  " .. khoa .. " = " .. tuanTu(val, indent .. "  ")
    end
    return "{\n" .. table.concat(phan, ",\n") .. "\n" .. indent .. "}"
  end
  error("không lưu được kiểu " .. kieu)
end

function luu(ten, bang)
  love.filesystem.write(ten, "return " .. tuanTu(bang))
end

function nap(ten, macDinh)
  local info = love.filesystem.getInfo(ten)
  if not info then return macDinh end
  local noi = love.filesystem.read(ten)
  local f, loi = load(noi, "=" .. ten)           -- biên dịch chuỗi thành hàm
  if not f then print("lỗi file lưu:", loi); return macDinh end
  local ok, kq = pcall(f)
  if ok and type(kq) == "table" then return kq end
  return macDinh
end
```

Dùng:

```lua
local save = nap("save.lua", { diemCao = 0, tuyChon = { amLuong = 0.8 } })

function love.keypressed(key)
  if key == "return" then
    save.diemCao = save.diemCao + 10
    luu("save.lua", save)
  end
end
```

Hạn chế của cách này: không lưu được vòng tham chiếu (bảng trỏ lại chính nó) hay hàm.

> **Bảo mật:** `load` thực thi code Lua. Chỉ nạp file mà **chính game** ghi ra. Đừng nạp file do người lạ gửi mà không kiểm tra.

## Lưu theo dạng JSON?

LÖVE không có JSON sẵn. Bạn có thể bỏ một thư viện thuần Lua (như `json.lua`) vào dự án rồi `local json = require("json")`. Ưu điểm: trao đổi dữ liệu với công cụ khác. Nhược điểm: khoá bảng phải là chuỗi, mất kiểu số của khoá.

## Nạp dữ liệu trò chơi từ file

Tách dữ liệu khỏi logic giúp sửa nhanh. Ví dụ file `levels/1.lua`:

```lua
-- levels/1.lua
return {
  ten = "Rừng xanh",
  map = {
    "#########",
    "#P  C   #",
    "#   #   #",
    "#   C  E#",
    "#########",
  }
}
```

```lua
local lv = require("levels.1")        -- dấu chấm thay cho "/"
-- hoặc: love.filesystem.load("levels/1.lua")()
for hang, dong in ipairs(lv.map) do
  for cot = 1, #dong do
    local kyTu = dong:sub(cot, cot)
    if kyTu == "#" then ... elseif kyTu == "P" then ... end
  end
end
```

## Đọc dòng theo dòng

```lua
for dong in love.filesystem.lines("data.txt") do
  print(dong)
end
```

## Đọc file nhị phân

```lua
local data = love.filesystem.newFileData("assets/hero.png")   -- FileData
local bytes = love.filesystem.read("assets/hero.png")         -- chuỗi byte
```

Thao tác chi tiết hơn (đọc từng phần, seek): `local f = love.filesystem.newFile("x.bin", "r")` rồi `f:read(n)`, `f:seek(pos)`, `f:close()`.

## Chọn vị trí lưu trên iOS

Trên iOS, thư mục lưu của LÖVE nằm trong vùng riêng của app (sandbox). Dự án của bạn nằm trong **Documents** (nhìn thấy trong ứng dụng Tệp), còn dữ liệu lưu của game chạy qua **Catnip** nằm ở vùng lưu của LÖVE. Ghi dữ liệu game ở đây là cách đúng; **đừng** cố ghi thẳng vào thư mục dự án.

Nếu muốn người chơi xuất file ra ngoài, hãy tìm hướng dùng chia sẻ của hệ điều hành thay vì ghi vào dự án.

## Mẹo

- Ghi file lưu **chỉ khi cần** (qua màn, thoát game), không ghi mỗi khung hình.
- Luôn kiểm tra file tồn tại và dữ liệu hợp lệ trước khi dùng, kẻo file hỏng làm game kẹt.
- Giữ một số phiên bản trong file lưu (`phienBan = 1`) để sau này nâng cấp định dạng mà không phá dữ liệu cũ.
