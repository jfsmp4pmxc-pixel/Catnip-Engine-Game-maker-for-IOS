# Game mẫu hoàn chỉnh

Hai game nhỏ để bạn chép vào `main.lua`, chạy thử và sửa. Cả hai đều dùng chạm/chuột nên chạy được trên iPhone/iPad.

## 1. Pong một người chơi (đánh bóng vào tường)

```lua
local W, H = 800, 600
local vot, bong, diem, tamThua

function datLai()
  vot  = { x = W / 2 - 50, y = H - 40, w = 100, h = 14 }
  bong = { x = W / 2, y = H / 2, r = 8, vx = 220, vy = 260 }
  diem, tamThua = 0, false
end

function love.load()
  love.window.setMode(W, H)
  love.graphics.setFont(love.graphics.newFont(24))
  datLai()
end

local function dieuKhien(x)             -- đặt vợt theo vị trí ngón tay/chuột
  vot.x = math.max(0, math.min(W - vot.w, x - vot.w / 2))
end

function love.mousepressed(x, y)
  if tamThua then datLai() else dieuKhien(x) end
end
function love.mousemoved(x) if not tamThua then dieuKhien(x) end end

function love.update(dt)
  if tamThua then return end
  if love.keyboard.isDown("left")  then dieuKhien(vot.x + vot.w / 2 - 500 * dt) end
  if love.keyboard.isDown("right") then dieuKhien(vot.x + vot.w / 2 + 500 * dt) end

  bong.x = bong.x + bong.vx * dt
  bong.y = bong.y + bong.vy * dt

  -- chạm tường trái/phải/trên
  if bong.x < bong.r then bong.x, bong.vx = bong.r, -bong.vx end
  if bong.x > W - bong.r then bong.x, bong.vx = W - bong.r, -bong.vx end
  if bong.y < bong.r then bong.y, bong.vy = bong.r, -bong.vy end

  -- chạm vợt
  if bong.vy > 0 and bong.y + bong.r >= vot.y and bong.y - bong.r <= vot.y + vot.h
     and bong.x >= vot.x and bong.x <= vot.x + vot.w then
    bong.y = vot.y - bong.r
    -- góc nảy phụ thuộc chỗ chạm: giữa vợt thì thẳng, mép thì xiên
    local t = (bong.x - (vot.x + vot.w / 2)) / (vot.w / 2)      -- -1..1
    local toc = math.sqrt(bong.vx ^ 2 + bong.vy ^ 2) * 1.04       -- nhanh dần
    local goc = t * math.rad(60)
    bong.vx = toc * math.sin(goc)
    bong.vy = -toc * math.cos(goc)
    diem = diem + 1
  end

  if bong.y > H + bong.r then tamThua = true end
end

function love.draw()
  love.graphics.setColor(0.1, 0.1, 0.14); love.graphics.rectangle("fill", 0, 0, W, H)
  love.graphics.setColor(0.3, 0.7, 1);    love.graphics.rectangle("fill", vot.x, vot.y, vot.w, vot.h, 6, 6)
  love.graphics.setColor(1, 0.9, 0.3);    love.graphics.circle("fill", bong.x, bong.y, bong.r)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Điểm: " .. diem, 12, 10)
  if tamThua then
    love.graphics.printf("Thua rồi! Chạm để chơi lại", 0, H / 2 - 12, W, "center")
  end
end
```

**Ý chính:** góc nảy phụ thuộc điểm bóng chạm vợt (`t`), nên người chơi có thể ngắm hướng. Bóng nhanh dần (`* 1.04`) để tăng độ khó.

## 2. Rắn săn mồi (Snake)

Dùng **lưới**, **hẹn giờ** bước đi và **hàng đợi** các đốt thân.

```lua
local COT, HANG, O = 20, 20, 24
local ran, huong, huongMoi, moi, diem, chet, dem, nhip

function datLai()
  ran = { { x = 10, y = 10 }, { x = 9, y = 10 }, { x = 8, y = 10 } }   -- ran[1] là đầu
  huong = { x = 1, y = 0 }
  huongMoi = huong
  diem, chet, dem, nhip = 0, false, 0, 0.15
  datMoi()
end

function datMoi()
  repeat
    moi = { x = love.math.random(0, COT - 1), y = love.math.random(0, HANG - 1) }
    local trung = false
    for _, d in ipairs(ran) do
      if d.x == moi.x and d.y == moi.y then trung = true end
    end
  until not trung
end

function love.load()
  love.window.setMode(COT * O, HANG * O)
  love.graphics.setFont(love.graphics.newFont(20))
  datLai()
end

-- không cho quay ngược 180°
local function dat(dx, dy)
  if not (dx == -huong.x and dy == -huong.y) then huongMoi = { x = dx, y = dy } end
end

function love.keypressed(key)
  if chet and key == "space" then datLai() end
  if key == "left" then dat(-1, 0) elseif key == "right" then dat(1, 0)
  elseif key == "up" then dat(0, -1) elseif key == "down" then dat(0, 1) end
end

-- vuốt trên màn hình cảm ứng
local bd
function love.touchpressed(id, x, y) bd = { x = x, y = y } end
function love.touchreleased(id, x, y)
  if chet then datLai(); return end
  if not bd then return end
  local dx, dy = x - bd.x, y - bd.y
  if math.abs(dx) > math.abs(dy) then dat(dx > 0 and 1 or -1, 0)
  else dat(0, dy > 0 and 1 or -1) end
  bd = nil
end

function love.update(dt)
  if chet then return end
  dem = dem + dt
  if dem < nhip then return end
  dem = dem - nhip

  huong = huongMoi
  local dau = { x = ran[1].x + huong.x, y = ran[1].y + huong.y }

  -- đụng tường hoặc chính mình
  if dau.x < 0 or dau.x >= COT or dau.y < 0 or dau.y >= HANG then chet = true; return end
  for _, d in ipairs(ran) do
    if d.x == dau.x and d.y == dau.y then chet = true; return end
  end

  table.insert(ran, 1, dau)               -- thêm đầu mới
  if dau.x == moi.x and dau.y == moi.y then
    diem = diem + 1
    nhip = math.max(0.05, nhip - 0.004)   -- nhanh dần
    datMoi()
  else
    table.remove(ran)                     -- bỏ đuôi (ăn mồi thì giữ lại để dài ra)
  end
end

function love.draw()
  love.graphics.setColor(0.08, 0.1, 0.12); love.graphics.rectangle("fill", 0, 0, COT * O, HANG * O)
  love.graphics.setColor(1, 0.3, 0.3);     love.graphics.rectangle("fill", moi.x * O + 2, moi.y * O + 2, O - 4, O - 4, 6, 6)
  for i, d in ipairs(ran) do
    if i == 1 then love.graphics.setColor(0.5, 1, 0.5) else love.graphics.setColor(0.2, 0.8, 0.3) end
    love.graphics.rectangle("fill", d.x * O + 1, d.y * O + 1, O - 2, O - 2, 4, 4)
  end
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Điểm: " .. diem, 8, 6)
  if chet then
    love.graphics.printf("Game over! Chạm hoặc nhấn Space để chơi lại", 0, HANG * O / 2 - 10, COT * O, "center")
  end
end
```

**Ý chính:**

- Rắn là một danh sách các ô; mỗi bước thêm một đầu ở phía trước, bỏ một đuôi ở phía sau.
- `huongMoi` chứa hướng đã chọn, còn `huong` là hướng của bước hiện tại: tránh lỗi bấm hai phím nhanh làm rắn quay ngược 180° trong cùng một bước.

## Ý tưởng mở rộng

- **Pong:** thêm vợt đối thủ do máy điều khiển; thêm âm thanh khi chạm vợt.
- **Snake:** thêm tường chướng ngại, lưu điểm cao bằng `love.filesystem`.
- Thử gộp: viết **menu chính** bằng máy trạng thái (xem chương **Callback**) để chọn giữa hai game.
