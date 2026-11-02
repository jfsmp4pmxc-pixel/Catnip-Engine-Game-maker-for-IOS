# Âm thanh — `love.audio`

```lua
local nhac, tiengNhay

function love.load()
  -- "stream": đọc dần, hợp với nhạc nền dài
  nhac = love.audio.newSource("assets/music.ogg", "stream")
  nhac:setLooping(true)
  nhac:setVolume(0.6)
  nhac:play()

  -- "static": nạp hết vào bộ nhớ, hợp với hiệu ứng ngắn
  tiengNhay = love.audio.newSource("assets/jump.wav", "static")
end

function love.keypressed(key)
  if key == "space" then
    tiengNhay:stop()     -- phát lại từ đầu nếu đang phát
    tiengNhay:play()
  end
end
```

| Việc cần làm | Cách làm |
|---|---|
| Phát / dừng / tạm dừng | `src:play()`, `src:stop()`, `src:pause()` |
| Âm lượng (0–1) | `src:setVolume(v)` |
| Lặp lại | `src:setLooping(true)` |
| Đang phát không | `src:isPlaying()` |
| Âm lượng toàn cục | `love.audio.setVolume(v)` |

Định dạng hỗ trợ: WAV, OGG (Vorbis), MP3, FLAC và nhạc tracker (MOD, XM, IT, S3M). Với nhạc nền, nên dùng OGG.

Nhập file âm thanh vào dự án bằng nút nhập ở thanh bên (biểu tượng tải xuống).
