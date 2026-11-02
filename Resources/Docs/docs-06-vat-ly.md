# Vật lý — `love.physics` (Box2D)

Box2D dùng **mét**, không phải pixel. Đặt tỉ lệ một lần: 64 pixel = 1 mét.

```lua
local world, ground, ball

function love.load()
  love.physics.setMeter(64)
  world = love.physics.newWorld(0, 9.81 * 64, true)   -- trọng lực hướng xuống

  -- mặt đất: thân tĩnh
  ground = {}
  ground.body  = love.physics.newBody(world, 400, 580, "static")
  ground.shape = love.physics.newRectangleShape(800, 40)
  ground.fixture = love.physics.newFixture(ground.body, ground.shape)

  -- quả bóng: thân động
  ball = {}
  ball.body  = love.physics.newBody(world, 400, 100, "dynamic")
  ball.shape = love.physics.newCircleShape(20)
  ball.fixture = love.physics.newFixture(ball.body, ball.shape, 1)  -- 1 = mật độ
  ball.fixture:setRestitution(0.8)                                  -- độ nảy
end

function love.update(dt)
  world:update(dt)
end

function love.draw()
  love.graphics.polygon("line", ground.body:getWorldPoints(ground.shape:getPoints()))
  love.graphics.circle("line", ball.body:getX(), ball.body:getY(), ball.shape:getRadius())
end
```

## Loại thân (body)

| Loại | Ý nghĩa |
|---|---|
| `"static"` | Đứng yên, không chịu lực (nền, tường) |
| `"dynamic"` | Chịu lực và va chạm (nhân vật, vật rơi) |
| `"kinematic"` | Tự điều khiển vận tốc, không chịu lực |

## Hay dùng

```lua
body:applyForce(fx, fy)
body:applyLinearImpulse(ix, iy)
body:setLinearVelocity(vx, vy)
body:setFixedRotation(true)
```

## Phát hiện va chạm

```lua
world:setCallbacks(function(a, b, contact)   -- beginContact
  print("va chạm!")
end)
```
