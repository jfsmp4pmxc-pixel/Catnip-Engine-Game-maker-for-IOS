# Catnip Engine: game maker for IOS
## Catnip Engine
- Catnip Engine: game maker for IOS
## giới thiệu
- Chào mừng bạn đến với Catnip Engine!, đây là một game engine chạy bằng lõi là Love2D. Được thiết kế riêng cho IPhone.
- Công cụ này giúp nhà phát triển lập trình ngay trên thiết bị di động (IPhone).
- Catnip mang đến cho bạn một môi trường lập trình gần như đầy đủ ngay trên IPhone của bạn với: trình soạn thảo mã, quản lý dự án, tuỳ chỉnh,...
## công nghệ
- Catnip được viết bằng Swift, Obj-C và **sử dụng** LÖVE framework để chạy các chương trình mà bạn viết.
- Phiên bản LÖVE là 12.0
## cài đặt
- Bạn cần tải tệp .ipa ở mục *"release"* của repo này sau đó cài qua các công cụ cài đặt bên thứ ba như: Ksign (IOS 16+), Trollstore (IOS 14.0 -> 16.6.1), Sidestore,...

> [!TIP]
> - Catnip yêu cầu IOS 15 trở lên 
> - Catnip hỗ trợ rất tốt IOS 15

| IOS    | Ksign | Esign | Trollstore | 
|--------|:-------:|:-------:|:------------:|
|15.0    |  ❌   |  ✅   |    ✅ (khuyến nghị)|
|15.x    |  ❌   |  ✅   |    ✅ (khuyến nghị)|
|16.0    |  ✅   |  ✅   |    ✅ (khuyến nghị)|
|16.6.1  |  ✅   |  ✅   |    ✅ (khuyến nghị)|
|16.7.11 |  ✅ (khuyến nghị)|  ✅   |    ❌      |
|17.x    |  ✅ (khuyến nghị)|  ✅   |    ❌      |
|18.x    |  ✅ (khuyến nghị)|  ✅   |    ❌      |
|26.x    |  ✅ (khuyến nghị)|  ✅   |    ❌      |
|27.x    |  ✅ (khuyến nghị)|  ✅   |    ❌      |

> [!COUTION] 
> - Việc cài đặt qua Trollstore cũng có rủi ro. Miễn là bạn tải từ mục "release" (vì bản phát hành tốt hơn bản beta) và bạn không cài đặt những ứng dụng từ nguồn đáng tin (vd: decrypt.day, armcovertor, ...) thì không vấn đề gì.

## cấu trúc mã nguồn 
```txt
/
 |___ README.md
 |___ main.swift
 |___ UI.swift
 |___ Storage.swift
 |___ Models.swift
 |___ EditorSidebar.swift
 |___ Editor.swift
 |___ Catnip-Bridging-Header.h
 |___ GameRun.swift
 |___ LoveBridge.h
 |___ LoveBridge.mm
 |___ Docs.swift
 |___ Fonts.swift
 |___ MarkdownPreview.swift
 |___ Shell.swift
 |___ Themes.swift
 |___ THIRD_PARTY_NOTICES.md
 |___ Resources/
 |             |___ Docs/
 |             |        |___ docs-01-bat-dau.md
 |             |        |___ docs-02-callback.md
 |             |        |___ docs-03-do-hoa.md
 |             |        |___ docs-04-am-thanh.md
 |             |        |___ docs-05-nhap-lieu.md
 |             |        |___ docs-06-vat-ly.md
 |             |        |___ docs-07-file-luu-tru.md
 |             |        |___ docs-08-conf.md
 |             |        |___ docs-09-ios.md
 |             |        |___ docs-10-lua-co-ban.md
 |             |___Markdown/
 |                          |___ catnip-markdown.js
 |                          |___ github-markdown-dark.css
 |                          |___ github-markdown-light.css
 |                          |___ highlight.min.css
 |                          |___ hljs-github.min.css
 |                          |___ markdown-it-emoji.min.js
 |                          |___ markdown-it-footnote.min.js
 |                          |___ markdown-it.min.js
 |                          |___ markdown-template.html
 |                          |___ purify.min.js
 |___ .github/
             |___ workflows/
                           |___ main.yml
```
## tiến trình 
- [x] trình soạn thảo mã
- [x] LÖVE
- [ ] kết nối Github
- [ ] build
## giấy phép

Dự án này được phân phối theo **GNU General Public License v3.0** (GPL-3.0-or-later).

Bạn được tự do:
- Sử dụng cho mọi mục đích, kể cả thương mại
- Sửa đổi mã nguồn
- Fork và phân phối lại

Với điều kiện:
- **Ghi công tác giả gốc** — giữ nguyên thông báo bản quyền
- **Công khai mã nguồn** — mọi sản phẩm phái sinh phải dùng cùng giấy phép GPLv3
- Ghi rõ các thay đổi đã thực hiện so với bản gốc

Xem file [LICENSE](LICENSE) để biết chi tiết đầy đủ.

Copyright (C) 2026 **jfsmp4pmxc-pixel** <ihhjnkk@gmail.com>
## tác giả 
```txt
- youtube: @B40Ph4m        |admin
  github : jfsmp4pmxc-pixel
  email  : ihhjnkk@gmail.com

- youtube: @h3ll0-70       |admin
  github : ilovegcc-g00
```




