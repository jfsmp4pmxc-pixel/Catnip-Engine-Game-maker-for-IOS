# Nhập liệu: bàn phím, chuột, cảm ứng

## Bàn phím

```lua
function love.update(dt)
  if love.keyboard.isDown("left")  then x = x - 200 * dt end
  if love.keyboard.isDown("right") then x = x + 200 * dt end
end

function love.keypressed(key)
  if key == "return" then print("Enter") end
end
```

Tên phím hay dùng: `"a"`–`"z"`, `"space"`, `"return"`, `"escape"`, `"left"`, `"right"`, `"up"`, `"down"`, `"lshift"`.

## Chuột và chạm

Trên iOS, một lần chạm cũng gửi sự kiện chuột (`istouch` là `true`):

```lua
function love.mousepressed(x, y, button, istouch)
  if button == 1 then       -- 1 = chuột trái / chạm
    print("bấm tại", x, y, istouch and "(chạm)" or "(chuột)")
  end
end

-- Hoặc đọc vị trí bất cứ lúc nào:
local mx, my = love.mouse.getPosition()
```

## Đa chạm

```lua
local ngonTay = {}

function love.touchpressed(id, x, y)  ngonTay[id] = { x = x, y = y } end
function love.touchmoved(id, x, y)    ngonTay[id] = { x = x, y = y } end
function love.touchreleased(id)       ngonTay[id] = nil end

function love.draw()
  for id, t in pairs(ngonTay) do
    love.graphics.circle("fill", t.x, t.y, 40)
  end
end
```

## Nút ảo trên màn hình cảm ứng

```lua
local nut = { x = 20, y = 300, w = 120, h = 80 }

local function trongNut(n, px, py)
  return px >= n.x and px <= n.x + n.w and py >= n.y and py <= n.y + n.h
end

function love.mousepressed(x, y)
  if trongNut(nut, x, y) then print("đã bấm nút") end
end
```

## Bàn phím ảo

```lua
love.keyboard.setTextInput(true)   -- hiện bàn phím ảo
function love.textinput(t) ten = (ten or "") .. t end
```
