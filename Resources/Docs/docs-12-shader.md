# Shader (GLSL)

Shader là chương trình nhỏ chạy trên GPU, quyết định màu của từng pixel (hoặc vị trí của từng đỉnh). Dùng cho hiệu ứng như đổi màu, làm mờ, phát sáng, sóng nước, nhấp nháy khi bị đánh.

LÖVE dùng ngôn ngữ GLSL, nhưng bạn chỉ viết phần cốt lõi; LÖVE bọc phần còn lại.

## Pixel shader đầu tiên

```lua
local shader

function love.load()
  shader = love.graphics.newShader([[
    vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord) {
      vec4 pixel = Texel(tex, texCoord);   // lấy màu pixel của ảnh
      return pixel * color;                // nhân với màu đang đặt bằng setColor
    }
  ]])
  anh = love.graphics.newImage("assets/hero.png")
end

function love.draw()
  love.graphics.setShader(shader)          -- bật
  love.graphics.draw(anh, 100, 100)
  love.graphics.setShader()                -- tắt (QUAN TRỌNG: về lại mặc định)
end
```

Các tham số của `effect`:

| Tham số | Ý nghĩa |
|---|---|
| `color` | màu hiện tại do `setColor` đặt (nhân vào) |
| `tex` | ảnh đang vẽ |
| `texCoord` | toạ độ trong ảnh, 0..1 |
| `screenCoord` | toạ độ pixel trên màn hình |

`Texel(tex, texCoord)` đọc màu tại điểm đó.

## Ví dụ: ảnh xám (grayscale)

```glsl
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 p = Texel(tex, uv);
  float xam = dot(p.rgb, vec3(0.299, 0.587, 0.114));   // trọng số theo độ nhạy mắt
  return vec4(vec3(xam), p.a) * color;
}
```

## Truyền giá trị từ Lua vào shader: uniform

```lua
shader = love.graphics.newShader([[
  uniform float doSang;        // khai báo biến nhận từ Lua

  vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 p = Texel(tex, uv);
    p.rgb += doSang;           // cộng thêm sáng
    return p * color;
  }
]])

function love.update(dt)
  shader:send("doSang", 0.3 * math.sin(love.timer.getTime() * 4))
end
```

`shader:send(ten, ...)` nhận số, vector (`{x, y, z}`), mảng, ma trận, ảnh (cho `Image`), canvas.

### Hiệu ứng nháy trắng khi trúng đòn

```glsl
uniform float nhay;   // 0..1
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 p = Texel(tex, uv);
  p.rgb = mix(p.rgb, vec3(1.0), nhay);    // trộn với trắng
  return p * color;
}
```

```lua
nhay = math.max(0, nhay - dt * 5)   -- giảm dần về 0
shader:send("nhay", nhay)
-- khi trúng đòn: nhay = 1
```

### Chống lỗi khi biến không dùng

Nếu uniform không được dùng trong shader, trình biên dịch có thể bỏ nó, và `send` sẽ báo lỗi. Dùng cách kiểm tra:

```lua
if shader:hasUniform("nhay") then shader:send("nhay", nhay) end
```

## Hiệu ứng toàn màn hình với Canvas

Vẽ cả cảnh vào Canvas, rồi vẽ Canvas với shader:

```lua
local canvas, hieuUng

function love.load()
  canvas = love.graphics.newCanvas()
  hieuUng = love.graphics.newShader([[
    uniform float thoiGian;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
      uv.x += sin(uv.y * 20.0 + thoiGian * 3.0) * 0.005;    // gợn sóng ngang
      return Texel(tex, uv) * color;
    }
  ]])
end

function love.draw()
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0.1, 0.1, 0.15)
  -- ... vẽ mọi thứ như thường ...
  love.graphics.setCanvas()

  love.graphics.setShader(hieuUng)
  hieuUng:send("thoiGian", love.timer.getTime())
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(canvas)
  love.graphics.setShader()
end
```

## Vertex shader — thay đổi vị trí đỉnh

```lua
local s = love.graphics.newShader([[
  uniform float thoiGian;

  vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vertex_position.y += sin(vertex_position.x * 0.05 + thoiGian * 4.0) * 6.0;   // cờ bay
    return transform_projection * vertex_position;
  }
]])
```

Một file shader có thể chứa **cả** `effect` và `position`.

## Mờ (blur) đơn giản

```glsl
uniform vec2 kichThuocPixel;      // {1/rộng, 1/cao}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 tong = vec4(0.0);
  for (int x = -2; x <= 2; x++) {
    for (int y = -2; y <= 2; y++) {
      tong += Texel(tex, uv + vec2(float(x), float(y)) * kichThuocPixel);
    }
  }
  return tong / 25.0 * color;
}
```

```lua
blur:send("kichThuocPixel", { 1 / canvas:getWidth(), 1 / canvas:getHeight() })
```

Mờ tách hai lượt (ngang rồi dọc) nhanh hơn nhiều.

## Vài lưu ý

- Trong GLSL, hằng số thực **phải** có dấu chấm: dùng `1.0`, không phải `1` khi trộn với `float`.
- Chú thích trong GLSL dùng `//` hoặc `/* */` (khác với Lua).
- Biên dịch shader ở `love.load`, không phải mỗi khung hình.
- Lỗi shader hiện ra ngay lúc `newShader` kèm số dòng; xem trong màn hình log của Catnip.
- Viết shader đơn giản, bám theo cú pháp LÖVE (`effect`, `position`) là cách an toàn nhất để chạy được trên thiết bị.
- `love.graphics.setShader()` không đối số trả về shader mặc định: **luôn** gọi sau khi vẽ xong.
