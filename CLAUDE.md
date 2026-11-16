# Catnip Engine — ghi chú cho Claude

Catnip Engine: app iOS để soạn code và làm game, chạy game bằng LÖVE (Love2D) nhúng sẵn, có shell Linux thật (iSH).
Chủ dự án nói tiếng Việt: **trả lời bằng tiếng Việt**. Giao diện app và tài liệu cũng bằng tiếng Việt.

## Quy ước
- **Không sửa `README.md`** (của chủ dự án). `README-vi.md` và `CHANGELOG.md` do chủ dự án quản lý, chỉ sửa khi được yêu cầu.
- Commit: `git pull --rebase` trước khi push; kết thúc message bằng các dòng trailer theo system-reminder của phiên (Co-Authored-By / Claude-Session).
- Không có trình biên dịch Swift ở môi trường Claude: **không build được local**. Chủ dự án chạy workflow GitHub Actions rồi gửi log; sửa theo log.
- Version: 0.3.x xong; đang làm 0.4.x "The True Workspaces".

## Cấu trúc
- Swift/UIKit, `main.swift` là điểm vào (AppDelegate). File chính: `Editor.swift`, `EditorSidebar.swift` (cây file, copy/cut/paste), `UI.swift` (danh sách dự án + Cài đặt), `Storage.swift` (đường dẫn, `AppSettings`, `ProjectStore`), `Models.swift` (Theme, tô màu), `Themes.swift` (.tmTheme), `MarkdownPreview.swift` (WKWebView, offline), `Docs.swift` (tài liệu "?"), `Shell.swift` (shell tích hợp + `presentShell`), `EditorSync.swift` (phát hiện sửa file bên ngoài, menu Build/xuất .zip, nút GitHub), `GitHub.swift`/`GitHubUI.swift` (kết nối GitHub), `SpellCheck.swift` (soát chính tả tiếng Việt cho .md, không cần từ điển), `IshShell.swift` + `IshBridge.h/.m` (iSH), `GameRun.swift` + `LoveBridge.h/.mm` (LÖVE).
- Dự án người dùng nằm trong **Documents** (xem được bằng app Tệp). Tên dành riêng: `Inbox`, `iSH`.
- Cài đặt thêm trường mới vào `AppSettings` (Storage.swift): giải mã chịu lỗi bằng `decodeIfPresent` + giá trị mặc định.
- Tài liệu LÖVE tiếng Việt: `Resources/Docs/docs-NN-*.md` (16 chương), danh sách ở `DocsCatalog.topics` trong Docs.swift. Ví dụ Lua được kiểm cú pháp bằng LuaJIT; tên hàm kiểm theo mã nguồn LÖVE 12.

## Đồng bộ với bên ngoài (Tệp/shell)
- Editor quét chữ ký thư mục dự án mỗi 2 giây (luồng nền) khi đang hiện: làm mới cây file, nạp lại file đang mở nếu chưa sửa; `flushSave` không ghi đè khi file trên đĩa khác `baselineText` mà hỏi người dùng.
- Build nằm trong menu "⋯" (xuất .zip bằng `NSFileCoordinator .forUploading`). Nút GitHub (`arrow.triangle.branch`) ở thanh trên → `GitHubViewController` (đăng nhập, chọn/tạo/xoá repo, workflows). Pull/Push/đổi nhánh/đổi tên/xoá repo nằm ở "⋯ → Công cụ" (`makeToolsMenu`, mở màn hình GitHub với `GitHubAction`). Push chỉ đẩy file được tick (duyệt cây, chọn từng file/thư mục con ở mọi cấp; lưu danh sách loại trừ `GitHubLink.pushExclude`, `PushSelection`). Run detail xem log job (`GitHubLogViewController`) và tải artifact .zip. Tô màu cú pháp thêm Swift/C/C++/Java/C#/Rust/Go/Shell (`cLike` trong Models.swift).
- GitHub (`GitHub.swift` + `GitHubUI.swift`): REST API qua URLSession, token PAT trong Keychain (có file dự phòng khi IPA không ký không dùng được Keychain). Liên kết dự án↔repo ở `Application Support/Catnip/github-links.json` (`GitHubLinks`, đổi tên/xoá dự án đã nối). Pull/Push bằng Git Data API (blob→tree→commit→ref), so SHA blob với `synced` lần trước để phát hiện xung đột (hỏi giữ bản nào). Workflows: liệt kê, chạy `workflow_dispatch` (inputs `k=v`), xem runs/jobs/steps, chạy lại/huỷ. Chưa có: OAuth device flow. **Chưa build/kiểm chứng.** Cây file editor ẩn file chấm nên `.github/workflows` sửa qua shell/Tệp.
- Loại dự án: `love`, `scratch` dùng được; `python`, `TwooObj` ("2o obj"), `catnip` ("Catnip Engine") là coming soon.
- Soát chính tả: kiểm quy tắc âm tiết tiếng Việt + bảng cụm từ hay sai + Telex dở dang; bản mẫu Python đã thử trên docs (không báo sai). Thêm cụm sai vào `commonMistakes`.

## Build
- Workflow `.github/workflows/main.yml` ("Build iOS IPA", macos-15, XcodeGen, IPA không ký). Input: version, build number, bundle id, configuration (Release/Preview/Beta/Debug), `with_ish`...
- Không có `project.yml` trong repo: `tools/gen_project_yml.py` sinh ra từ biến môi trường (WITH_LOVE, WITH_ISH, CONFIG…). Thêm file Swift mới phải thêm vào danh sách sources trong script này. Config tuỳ biến (Beta/Preview) cần khối `configs:` (đã có).
- LÖVE nhúng là 12.0-dev (liblove.a + SDL3 + xcframework), xem `love-core.yml`.
- iSH: `tools/build_ish_core.sh` build libish/libish_emu/libfakefs/libarchive bằng xcodebuild và tự biên dịch `tools/fakefs.c` thành `libfakefs_import.a`; tải rootfs về `ish-core/Resources`. Chỉ bật khi `with_ish=true` (định nghĩa `CATNIP_HAS_ISH`). Terminal: SwiftTerm 1.17.0 (SPM, bản mới hơn cần Swift 6).

## iSH (True Workspaces)
- Rootfs ở `Documents/iSH` (fakefs: `meta.db` + `data/`). Mỗi dự án gắn (realfs) vào `/root/<tên>` (khoảng trắng → `_`, trùng thì `_2`…); gắn lại mỗi lần mở phiên mới.
- Mở dự án trong editor → `IshRuntime.openProject` → iSH chạy ngầm, shell `cd` vào dự án qua `/tmp/.catnip-cwd` + `/etc/profile.d/catnip.sh`.
- Lần chạy đầu: `IshSetupViewController` cài `bash vim python3 g++ nasm` (có thể bỏ qua), cờ `ishSetupDone`.
- Chỉ có một phiên pty tại một thời điểm (`gSession`); cài đặt/chuyển dự án đóng phiên shell rồi mở lại.
- **Chưa kiểm chứng trên thiết bị**: mount động, cd tự động, đọc tiến trình apk. Nếu có log lỗi thì sửa theo log.

## Bài học (lỗi đã gặp) và lưu ý
- Nhãn Swift của hàm ObjC không đoán được ("With" lúc bỏ lúc giữ): dùng `NS_SWIFT_NAME` để cố định. `startSession(directory:command:output:exit:)`, `boot(withRoot:repositories:)`.
- Lỗi C trong IshBridge.m: cần `#include "fs/path.h"` cho `AT_PWD`; `fakefs_import` không nằm trong libfakefs.
- Lõi iSH dùng `__thread current`: chỉ mkdir/mount/ghi file guest khi `current` hợp lệ (lúc boot hoặc ngay sau `become_new_init_child`).
- Mã thoát từ kernel iSH là `status << 8`.
- Lua 5.1/LuaJIT: không có `string.rep` với separator, không có `+=`, `!=`.
- Tuỳ chọn "ngắt dòng" (wrap lines) của editor còn lỗi; chủ dự án bảo bỏ qua.
- 2o là "Twoo" không phải là "oo".
- 2o là .2o của 2oLang. Sắp được tích hợp vào Catnip.
