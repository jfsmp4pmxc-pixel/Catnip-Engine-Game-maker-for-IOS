# Vật lý Box2D — `love.physics`

Dùng khi bạn muốn vật rơi, nảy, lăn, xếp chồng, nối bằng khớp một cách "thật". Nếu chỉ cần va chạm đơn giản, xem chương **Va chạm tự làm**.

## Ba khái niệm

- **World**: thế giới vật lý. Có trọng lực.
- **Body**: vật thể: có vị trí, vận tốc, góc xoay. Không có hình dạng.
- **Shape + Fixture**: hình dạng gắn vào body (hộp, tròn, đa giác). **Fixture** gắn shape vào body, kèm độ nảy, ma sát, mật độ.

## Đơn vị: mét

Box2D được tinh chỉnh cho vật khoảng 0,1–10 **mét**. Đặt 1 mét = 64 pixel để thế giới trông hợp lý:

```lua
love.physics.setMeter(64)
```

Gọi **trước** khi tạo `World`. Sau đó mọi toạ độ bạn truyền vào vẫn tính bằng pixel; LÖVE tự đổi.

## Ví dụ: hộp rơi xuống đất

```lua
local world, dat, hop

function love.load()
  love.physics.setMeter(64)
  world = love.physics.newWorld(0, 9.81 * 64, true)     -- trọng lực (x, y) theo pixel/s²; true = cho vật "ngủ" khi đứng yên

  -- đất: body tĩnh
  dat = {}
  dat.body = love.physics.newBody(world, 400, 560, "static")
  dat.shape = love.physics.newRectangleShape(800, 40)   -- rộng, cao
  dat.fixture = love.physics.newFixture(dat.body, dat.shape)

  -- hộp: body động
  hop = {}
  hop.body = love.physics.newBody(world, 400, 100, "dynamic")
  hop.shape = love.physics.newRectangleShape(60, 60)
  hop.fixture = love.physics.newFixture(hop.body, hop.shape, 1)   -- 1 = mật độ
  hop.fixture:setRestitution(0.4)                                  -- độ nảy 0..1
  hop.fixture:setFriction(0.5)
end

function love.update(dt)
  world:update(dt)                                      -- BẮT BUỘC mỗi khung
end

function love.draw()
  love.graphics.setColor(0.4, 0.4, 0.5)
  love.graphics.polygon("fill", dat.body:getWorldPoints(dat.shape:getPoints()))
  love.graphics.setColor(0.9, 0.6, 0.2)
  love.graphics.polygon("fill", hop.body:getWorldPoints(hop.shape:getPoints()))
end
```

**Vị trí đặt hình chữ nhật:** `newRectangleShape(w, h)` tạo hình **căn giữa tại gốc body**. Vì vậy vị trí body = tâm hình.

## Các loại body

| Loại | Ý nghĩa |
|---|---|
| `"static"` | Đứng yên mãi, không bị tác động (đất, tường). Rẻ nhất |
| `"dynamic"` | Chịu lực, trọng lực, va chạm. Vật chơi chính |
| `"kinematic"` | Bạn tự điều khiển vận tốc; không bị lực đẩy (thang máy, nền di động) |

## Các hình

```lua
love.physics.newRectangleShape(w, h)                 -- hộp căn giữa
love.physics.newRectangleShape(x, y, w, h, goc)      -- hộp lệch tâm
love.physics.newCircleShape(r)
love.physics.newPolygonShape(x1,y1, x2,y2, x3,y3)    -- đa giác LỒI, tối đa 8 đỉnh
love.physics.newEdgeShape(x1, y1, x2, y2)            -- đoạn thẳng (địa hình)
love.physics.newChainShape(false, x1,y1, x2,y2, x3,y3)  -- chuỗi đoạn (địa hình gồ ghề); true = khép kín
```

Đa giác lõm phải chia thành các đa giác lồi nhỏ, mỗi cái một fixture.

## Điều khiển body

```lua
body:getX() body:getY() body:getPosition()
body:getAngle()                       -- radian
body:setPosition(x, y)
body:setAngle(a)
body:getLinearVelocity()              -- vx, vy
body:setLinearVelocity(vx, vy)
body:applyForce(fx, fy)               -- lực liên tục (gọi mỗi khung)
body:applyLinearImpulse(ix, iy)       -- cú đẩy tức thì (nhảy, bắn)
body:applyTorque(t)                   -- lực xoay
body:setFixedRotation(true)           -- không xoay (nhân vật platformer)
body:setLinearDamping(0.5)            -- cản (giống ma sát không khí)
body:setBullet(true)                  -- vật nhanh: kiểm tra chống xuyên tường kỹ hơn
body:setGravityScale(0)               -- bỏ qua trọng lực cho riêng body này
body:setActive(false)                 -- tạm tắt
body:destroy()                        -- xoá hẳn khỏi thế giới
```

### Nhảy

```lua
function love.keypressed(key)
  if key == "space" and trenDat then
    local vx = player.body:getLinearVelocity()
    player.body:setLinearVelocity(vx, 0)                -- triệt tiêu vận tốc rơi trước
    player.body:applyLinearImpulse(0, -player.body:getMass() * 350)
  end
end
```

### Đi trái/phải

Đặt thẳng vận tốc ngang nghe "cứng" nhưng dễ điều khiển:

```lua
local vx, vy = body:getLinearVelocity()
local huong = 0
if love.keyboard.isDown("left")  then huong = -1 end
if love.keyboard.isDown("right") then huong =  1 end
body:setLinearVelocity(huong * 200, vy)
```

## Fixture: vật liệu

```lua
fix:setDensity(2)          -- mật độ → khối lượng (khối lượng = mật độ × diện tích)
fix:setFriction(0.3)       -- ma sát 0..1
fix:setRestitution(0.8)    -- độ nảy 0 (không nảy) .. 1 (nảy hoàn hảo)
fix:setSensor(true)        -- cảm biến: phát hiện chạm nhưng không va đập thật
fix:setUserData("coin")    -- gắn nhãn tuỳ ý để nhận ra trong callback
```

Sau khi đổi mật độ nên gọi `body:resetMassData()`.

## Lọc va chạm: danh mục và mặt nạ

Muốn một số vật không chạm nhau (đạn của bạn không trúng bạn):

```lua
-- Danh mục là số 1..16
fixNguoiChoi:setCategory(1)
fixNguoiChoi:setMask(2)         -- KHÔNG va chạm với danh mục 2

fixDanCuaNguoiChoi:setCategory(2)
fixDanCuaNguoiChoi:setMask(1)   -- không chạm danh mục 1
```

Hoặc dùng nhóm: `fix:setGroupIndex(-1)` — các fixture cùng nhóm **âm** không bao giờ va chạm nhau; nhóm **dương** luôn va chạm.

## Callback va chạm

```lua
function love.load()
  world:setCallbacks(batDau, ketThuc, truocXuLy, sauXuLy)
end

function batDau(a, b, coll)
  local x, y = coll:getPositions()
  local nhanA, nhanB = a:getUserData(), b:getUserData()
  if nhanA == "dan" or nhanB == "dan" then
    -- đừng huỷ body NGAY trong callback! Đánh dấu rồi xử lý ở update
  end
end

function ketThuc(a, b, coll) end
function truocXuLy(a, b, coll) end                     -- có thể coll:setEnabled(false) để cho đi xuyên (nền một chiều)
function sauXuLy(a, b, coll, phap, tiep) end           -- có lực xung kích
```

**Quan trọng:** thế giới đang "khoá" trong lúc tính toán; gọi `destroy()` hay tạo body trong callback sẽ gây lỗi. Ghi vào danh sách chờ rồi dọn sau `world:update`:

```lua
local canXoa = {}

function batDau(a, b)
  if a:getUserData() == "dan" then canXoa[#canXoa + 1] = a:getBody() end
end

function love.update(dt)
  world:update(dt)
  for i = #canXoa, 1, -1 do
    if not canXoa[i]:isDestroyed() then canXoa[i]:destroy() end
    canXoa[i] = nil
  end
end
```

## Kiểm tra đang chạm không (trên đất)

Một cách đơn giản: dựa vào danh sách tiếp xúc của body:

```lua
local function trenDat(body)
  for _, c in ipairs(body:getContacts()) do
    if c:isTouching() then
      local nx, ny = c:getNormal()
      if math.abs(ny) > 0.7 then return true end        -- tiếp xúc chủ yếu theo chiều dọc
    end
  end
  return false
end
```

## Khớp (Joint)

Nối hai body:

```lua
-- Khớp bản lề (xoay quanh một điểm)
local j = love.physics.newRevoluteJoint(bodyA, bodyB, x, y)
j:setMotorEnabled(true); j:setMotorSpeed(5); j:setMaxMotorTorque(1000)   -- động cơ quay

-- Khớp khoảng cách (như thanh hoặc lò xo)
local j = love.physics.newDistanceJoint(bodyA, bodyB, xA, yA, xB, yB)
j:setStiffness(50); j:setDamping(5)                     -- mềm như lò xo (LÖVE 12: độ cứng + giảm chấn; bản 11.x dùng setFrequency/setDampingRatio)

-- Khớp nối với con trỏ (kéo thả vật bằng chuột/ngón tay)
local keo = love.physics.newMouseJoint(body, x, y)
keo:setTarget(newX, newY)                               -- cập nhật mỗi khi ngón tay di chuyển
keo:destroy()                                           -- khi thả

-- Khớp tịnh tiến (trượt dọc một trục)
love.physics.newPrismaticJoint(bodyA, bodyB, x, y, axisX, axisY)

-- Khớp hàn (dính cứng)
love.physics.newWeldJoint(bodyA, bodyB, x, y)

-- Khớp bánh xe (cho xe)
love.physics.newWheelJoint(bodyA, bodyB, x, y, axisX, axisY)
```

## Truy vấn thế giới

```lua
-- Vật nào nằm trong hình chữ nhật này?
world:queryBoundingBox(x1, y1, x2, y2, function(fixture)
  print("thấy", fixture:getUserData())
  return true                                           -- true: tiếp tục tìm
end)

-- Bắn tia
world:rayCast(x1, y1, x2, y2, function(fixture, x, y, xn, yn, phan)
  print("tia chạm tại", x, y)
  return 0                                              -- 0: dừng ở lần chạm đầu
end)
```

## Vẽ nhanh để gỡ lỗi

```lua
local function veTatCa(world)
  for _, body in ipairs(world:getBodies()) do
    for _, fix in ipairs(body:getFixtures()) do
      local s = fix:getShape()
      local loai = s:getType()
      if loai == "circle" then
        local cx, cy = body:getWorldPoint(s:getPoint())
        love.graphics.circle("line", cx, cy, s:getRadius())
      elseif loai == "polygon" then
        love.graphics.polygon("line", body:getWorldPoints(s:getPoints()))
      elseif loai == "edge" or loai == "chain" then
        love.graphics.line(body:getWorldPoints(s:getPoints()))
      end
    end
  end
end
```

## Mẹo

- Gọi `world:update(dt)` với `dt` **cố định** (vd 1/60) cho kết quả ổn định hơn; xem chương **Callback** về bước thời gian cố định.
- Đừng đặt vật quá nhỏ (< 0,1 m) hoặc quá lớn (> 10 m): Box2D mất ổn định.
- Xoá body bằng `body:destroy()` khi không dùng, kẻo thế giới nặng dần.
- Đặt `world:setCallbacks` chỉ một lần.
