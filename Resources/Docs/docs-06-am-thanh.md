# Âm thanh — `love.audio`

## Phát âm thanh

```lua
local nhac, tiengNhay

function love.load()
  -- "stream": đọc dần từ đĩa. Hợp với nhạc nền dài
  nhac = love.audio.newSource("assets/music.ogg", "stream")
  nhac:setLooping(true)       -- lặp lại mãi
  nhac:setVolume(0.6)         -- 60% âm lượng
  nhac:play()

  -- "static": nạp hết vào bộ nhớ. Hợp với hiệu ứng ngắn (nhảy, bắn, nổ)
  tiengNhay = love.audio.newSource("assets/jump.wav", "static")
end

function love.keypressed(key)
  if key == "space" then
    tiengNhay:stop()          -- phát lại từ đầu nếu đang phát dở
    tiengNhay:play()
  end
end
```

**Chọn `"static"` hay `"stream"`:**

| | `"static"` | `"stream"` |
|---|---|---|
| Dùng cho | Hiệu ứng ngắn (< vài giây) | Nhạc nền, lời thoại dài |
| Bộ nhớ | Nạp hết vào RAM | Chỉ nạp từng đoạn |
| Độ trễ khi phát | Rất thấp | Cao hơn một chút |

Nhập file âm thanh vào dự án bằng nút nhập ở thanh bên. Định dạng hỗ trợ: **WAV, OGG (Vorbis), MP3, FLAC** và nhạc tracker (MOD, XM, IT, S3M). Với nhạc nền, nên dùng OGG.

## Điều khiển một nguồn âm

```lua
src:play()                 -- phát (hoặc tiếp tục nếu đang tạm dừng)
src:pause()                -- tạm dừng, phát tiếp từ chỗ dừng
src:stop()                 -- dừng và về đầu
src:isPlaying()            -- đang phát không?
src:setVolume(0.5)         -- 0 đến 1
src:getVolume()
src:setPitch(1.5)          -- tốc độ/cao độ: 1 = gốc, 2 = nhanh gấp đôi và cao hơn 1 quãng tám
src:setLooping(true)
src:seek(10, "seconds")    -- nhảy tới giây thứ 10
src:tell("seconds")        -- đang ở giây nào
src:getDuration("seconds") -- độ dài
```

Âm lượng toàn cục: `love.audio.setVolume(0.8)`. Dừng tất cả: `love.audio.stop()`.

## Phát chồng nhiều lần cùng một âm

Một `Source` chỉ phát một lần tại một thời điểm. Muốn tiếng súng nổ liên tiếp chồng lên nhau, nhân bản bằng `clone`:

```lua
local tiengBan

function love.load()
  tiengBan = love.audio.newSource("assets/shoot.wav", "static")
end

function phatTiengBan()
  local ban = tiengBan:clone()    -- bản sao dùng chung dữ liệu, rẻ
  ban:play()
end
```

Với nhiều hiệu ứng, giữ một "hồ" nguồn dùng lại thay vì tạo mới liên tục:

```lua
local Ho = {}
Ho.__index = Ho

function Ho.new(src, soLuong)
  local self = setmetatable({ list = {}, i = 0 }, Ho)
  for n = 1, soLuong do self.list[n] = src:clone() end
  return self
end

function Ho:phat()
  self.i = self.i % #self.list + 1
  local s = self.list[self.i]
  s:stop()
  s:play()
end
```

## Đổi cao độ ngẫu nhiên để đỡ nhàm

```lua
local s = tiengBan:clone()
s:setPitch(0.9 + love.math.random() * 0.2)     -- từ 0,9 đến 1,1
s:play()
```

## Mờ dần (fade out) nhạc

LÖVE không có sẵn fade; tự làm trong `update`:

```lua
local mo = { dang = false, thoiGian = 0, tong = 2 }

function bamMo() mo.dang, mo.thoiGian = true, 0 end

function love.update(dt)
  if mo.dang then
    mo.thoiGian = mo.thoiGian + dt
    local t = math.min(mo.thoiGian / mo.tong, 1)
    nhac:setVolume(0.6 * (1 - t))
    if t >= 1 then nhac:stop(); mo.dang = false end
  end
end
```

## Âm thanh theo vị trí (3D)

Với nguồn **mono**, đặt vị trí rồi đặt vị trí người nghe:

```lua
src:setPosition(x, y, 0)
love.audio.setPosition(playerX, playerY, 0)
```

Âm thanh stereo không dùng được vị trí. Với game 2D, thường chỉ cần tự tính âm lượng theo khoảng cách.

## Mẹo

- Giữ mọi `Source` ở biến mà bạn còn dùng, hoặc ít nhất đừng tạo `newSource` mỗi khung hình.
- Xoá file âm thanh dung lượng lớn khỏi dự án khi không dùng: app lưu dự án trong Documents.
- Nếu không nghe thấy gì, kiểm tra nút gạt im lặng và âm lượng của thiết bị.
