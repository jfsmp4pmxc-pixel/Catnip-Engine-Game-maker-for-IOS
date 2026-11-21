# Catnip Engine — ghi chú cho Claude

Catnip Engine: app iOS để soạn code và làm game, chạy game bằng LÖVE (Love2D) nhúng sẵn, có shell Linux thật (iSH).
Chủ dự án nói tiếng Việt: **trả lời bằng tiếng Việt**. Giao diện app và tài liệu cũng bằng tiếng Việt.

## Quy ước
- **Không sửa `README.md`** (của chủ dự án). `README-vi.md` và `CHANGELOG.md` do chủ dự án quản lý, chỉ sửa khi được yêu cầu.
- Commit: `git pull --rebase` trước khi push; kết thúc message bằng các dòng trailer theo system-reminder của phiên (Co-Authored-By / Claude-Session).
- Không có trình biên dịch Swift ở môi trường Claude: **không build được local**. Chủ dự án chạy workflow GitHub Actions rồi gửi log; sửa theo log.
- Version: 0.3.x xong; đang làm 0.4.x "The True Workspaces".

## Cấu trúc
- Swift/UIKit, `main.swift` là điểm vào (AppDelegate). File chính: `Editor.swift`, `EditorSidebar.swift` (cây file, copy/cut/paste), `UI.swift` (danh sách dự án + Cài đặt), `Storage.swift` (đường dẫn, `AppSettings`, `ProjectStore`), `Models.swift` (Theme, tô màu), `Themes.swift` (.tmTheme), `MarkdownPreview.swift` (WKWebView, offline), `Docs.swift` (tài liệu "?"), `Shell.swift` (shell tích hợp + `presentShell`), `EditorSync.swift` (phát hiện sửa file bên ngoài, menu Build/xuất .zip, nút GitHub), `GitHub.swift`/`GitHubUI.swift` (kết nối GitHub), `TextMate.swift` (định cú pháp .tmLanguage/.tmbundle), `SpellCheck.swift` (soát chính tả tiếng Việt cho .md, không cần từ điển), `IshShell.swift` + `IshBridge.h/.m` (iSH), `GameRun.swift` + `LoveBridge.h/.mm` (LÖVE).
- Dự án người dùng nằm trong **Documents** (xem được bằng app Tệp). Tên dành riêng: `Inbox`, `iSH`.
- Cài đặt thêm trường mới vào `AppSettings` (Storage.swift): giải mã chịu lỗi bằng `decodeIfPresent` + giá trị mặc định.
- Hướng dẫn (trước là "Tài liệu LÖVE") tiếng Việt: `Resources/Docs/docs-NN-*.md` (23 chương; 17–22 là dự án UI/SwiftUI, 23 là tô màu + trình xem file), danh sách ở `DocsCatalog.topics` trong Docs.swift. Ví dụ Lua được kiểm cú pháp bằng LuaJIT; tên hàm kiểm theo mã nguồn LÖVE 12.

## Đồng bộ với bên ngoài (Tệp/shell)
- Editor quét chữ ký thư mục dự án mỗi 2 giây (luồng nền) khi đang hiện: làm mới cây file, nạp lại file đang mở nếu chưa sửa; `flushSave` không ghi đè khi file trên đĩa khác `baselineText` mà hỏi người dùng.
- Build nằm trong menu "⋯" (xuất .zip bằng `NSFileCoordinator .forUploading`). Mọi thứ GitHub nằm ở "⋯ → Công cụ" (không còn nút riêng ở thanh trên): `makeToolsMenu` mở `GitHubViewController` với `GitHubAction` (screen/pull/push/changeBranch/renameRepo/deleteRepo/workflows/runs). Chạy workflow: `GitHubDispatchFormViewController` đọc input từ YAML (`WorkflowYAML.dispatchInputs`, parser tối giản) và dựng form theo kiểu (string/number/boolean/choice/environment) + ô nhập thủ công (`makeToolsMenu`, mở màn hình GitHub với `GitHubAction`). Push: sao chép riêng những file/thư mục được tick sang thư mục tạm rồi đẩy từ bản sao, có hộp xác nhận liệt kê file trước khi commit (mặc định không tick gì; duyệt cây, tick file hoặc thư mục con ở mọi cấp, KHÔNG có ô cho thư mục gốc dự án; đường dẫn trên repo tính từ gốc dự án, không kèm tên dự án; lưu `GitHubLink.pushInclude`, `PushSelection`). Run detail xem log job (`GitHubLogViewController`) và tải artifact .zip. Tô màu cú pháp thêm Swift/C/C++/Java/C#/Rust/Go/Shell (`cLike` trong Models.swift). Tô màu: `paint()` quét chú thích/chuỗi một lượt theo thứ tự văn bản rồi tô đè cuối, nên sau dấu chú thích luôn là màu chú thích.
- GitHub (`GitHub.swift` + `GitHubUI.swift`): REST API qua URLSession, token PAT trong Keychain (có file dự phòng khi IPA không ký không dùng được Keychain). Liên kết dự án↔repo ở `Application Support/Catnip/github-links.json` (`GitHubLinks`, đổi tên/xoá dự án đã nối). Pull/Push bằng Git Data API (blob→tree→commit→ref), so SHA blob với `synced` lần trước để phát hiện xung đột (hỏi giữ bản nào). Workflows: liệt kê, chạy `workflow_dispatch` (inputs `k=v`), xem runs/jobs/steps, chạy lại/huỷ. Chưa có: OAuth device flow. **Chưa build/kiểm chứng.** Cây file ẩn file chấm mặc định; bật Cài đặt → "Hiện file/thư mục ẩn" (`showHiddenFiles`) để sửa `.github/workflows` ngay trong editor (`.git`, `.catnip.json`, `.DS_Store` luôn giấu).
- Định cú pháp TextMate (`TextMate.swift`): nhập `.tmLanguage` hoặc thư mục `.tmbundle` (info.plist + Syntaxes/) ở Cài đặt → Công cụ → "Định cú pháp"; lưu ở `Application Support/Catnip/Grammars`. `TMGrammar` tự tách token theo từng dòng (match/begin/end/captures/include/repository, backref trong end) bằng NSRegularExpression (ICU, không phải Oniguruma), scope quy về `TokenKind` rồi tô theo theme. Editor: `customGrammar` (tự chọn theo `fileTypes`, hoặc chọn tay ở menu ngôn ngữ); tắt khi file > 80k ký tự. **Chưa build/kiểm chứng.**
- Loại dự án: `love`, `scratch`, `ui` dùng được; `python`, `TwooObj` ("2o obj"), `catnip` ("Catnip Engine") là coming soon.
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
- Cài đặt "Cuộn ngang" (`scrollHorizontal`, mặc định tắt = ngắt dòng mềm): bật thì không ngắt dòng, textView cuộn ngang (container 10 000 pt, `.byClipping`). `wrapLines`/`indentWrapped` là trường cũ, không dùng. Chưa build/kiểm chứng. Đã từng làm Chat AI (Claude/DeepSeek) rồi huỷ theo yêu cầu.
- 2o là "Twoo" không phải là "oo".
- 2o là .2o của 2oLang. Sắp được tích hợp vào Catnip.

## Loại dự án "UI" (0.5.x) — tình hình hiện tại
Mục đích (chủ dự án): **phác thảo giao diện** nhanh, bấm thử được. Nút **Preview** (không có Chạy) ở thanh trên Editor (`uiPreviewTapped`). Mẫu `ContentView.swift` ở `UIPreviewTemplate`.
- **Chưa build/kiểm chứng lần nào sau đợt mở rộng.** Lần build gần nhất lỗi `&&`/`||`/`try` đã sửa (857a8ec). Đợt "mở rộng gần đầy đủ SwiftUI" (parser + interp + renderer) và 5 chương tài liệu mới (18–22) viết sau đó, chưa có log. Khi có log: sửa lỗi biên dịch trước, rồi hỏi chủ dự án Preview hiện ra gì.
- Kiến trúc: iOS không biên dịch Swift trên máy nên Preview là **trình thông dịch tập con Swift/SwiftUI**.
  - `SwiftUIParser.swift`: lexer + parser (`SwiftLexer`, `SwiftParser`, `Program`). Phục hồi lỗi theo khai báo cấp cao nhất (`Program.errors`, dựa vào `Tok.col == 0`); `extension` gộp bằng `Program.extensions`.
  - `SwiftUIInterp.swift`: `Interp` (giá trị `V`, `Scope`, `VNode`). `@State` lưu trong `store` theo `Struct.prop`; class (ObservableObject) ghi thuộc tính thì `onChange` dựng lại; `registry` cho `@EnvironmentObject`; `NavigationLink` giữ đích dạng closure (dựng lại mỗi lần). Có tuple, dictionary, enum (raw value, associated value, thuộc tính tính toán, phương thức), init tự viết, static, extension.
  - `UIPreview.swift`: `PVRenderer` vẽ VNode bằng UIKit (stack tự tính `fillW/fillH`, cache control theo path để giữ focus/kéo), overlay (sheet/alert), điều hướng (`navStack`), `TabView`, `Grid`, gradient, `Menu`, `TextEditor`, `DisclosureGroup`, `Link`; `UIPreviewViewController` tự tải lại khi file .swift đổi (giữ state), giữ bản vẽ cũ nếu lỗi, view lạ thành khung xám.
- Tài liệu: chương 17–22 (`docs-17-ui-swiftui` … `docs-22-mau-phac-thao`). Nếu thêm tính năng phải sửa chương tương ứng.
- Chưa có / dễ lỗi: generic, async, Combine, `@Observable`, DatePicker, Map, Chart, Canvas, ảnh từ file, animation thật, gesture ngoài `onTapGesture`; `LazyHGrid` chỉ gần đúng; struct dùng chung tham chiếu như class; `@State` trùng giữa các view cùng struct.
- Thêm file Swift mới phải thêm vào `tools/gen_project_yml.py`.

## Tô màu thêm và trình xem file (chưa build/kiểm chứng)
- `MoreLanguages.swift`: luật tô cho Assembly, Fortran, PHP, Ruby, SQL, YAML, TOML/INI, Dart (`SyntaxHighlighter.moreRules`, dùng raw string `#"..."#`). `paint()` tô luật hàm trước để từ khoá thắng (`while (`). Light (GitHub) lấy màu từ khối mã Markdown.
- `MediaViewer.swift`: `MediaKind.detect` theo đuôi; `MediaViewerController` chứa `ImageViewerViewController` (zoom, GIF), `VideoViewerViewController` (AVPlayerViewController), `AudioViewerViewController` (AVPlayer tự vẽ điều khiển), `HexEditorViewController` (ghi đè byte, đi tới, tìm; >8 MB chỉ xem). Editor: `mediaHost` đè lên textView, `showViewer`/`hideViewer`/`openInHex` ("⋯ → Mở bằng hex editor"). File không phải văn bản (hoặc >2 MB) luôn vào trình xem thay cho thông báo cũ.
- Thêm đuôi nhị phân vào `ProjectStore.binaryExtensions`; thêm ngôn ngữ phải sửa `Language` (displayName, detect, rules) và chương 23.
- Theme editor (`ThemeEditor.swift`): Cài đặt → Giao diện → "Trình sửa theme…" hoặc vuốt trái một theme → "Sửa". Màu bằng `UIColorPickerViewController`, xem trước C + HTML, lưu JSON ở `Application Support/Catnip/Themes/*.json` (`ThemeStore.save`, `reload` đọc cả `.tmTheme` lẫn `.json`). Theme có sẵn/tmTheme khi sửa sẽ thành bản sao "(sửa)".
- cLike: kiểu nguyên thuỷ (`void`, `int`, `i32`, `string`...) tô như từ khoá (rule `.keyword` đặt sau rule `.type`).
- Shell: `ShellChoice` (Shell.swift) — "Catnip Shell" (`ShellViewController` + `BuiltinShell`, luôn có), "iSH (Linux)" (nếu build nhúng), "Tuỳ chỉnh" (`customShell`, chạy `/bin/sh -c "exec <lệnh>"` trong iSH; đổi thì `IshRuntime.restartSession`). Chọn ở Cài đặt → Công cụ → "Loại shell" (`shellKind`: auto/catnip/ish/custom). `presentShell` dùng `topPresenter`. Chưa build/kiểm chứng.
