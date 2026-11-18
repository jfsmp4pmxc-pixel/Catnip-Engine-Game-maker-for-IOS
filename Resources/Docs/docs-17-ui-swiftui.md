# Dự án UI: SwiftUI xem trước tương tác

Loại dự án **UI** cho bạn viết giao diện bằng cú pháp SwiftUI và bấm **Preview** để thử ngay trong Catnip. Bản xem trước bấm được, gõ được, kéo được, nên bạn thử luôn cách giao diện phản ứng.

## Cách dùng

1. Ở danh sách dự án, tạo dự án mới và chọn loại **UI**. Catnip tạo sẵn file `ContentView.swift` mẫu.
2. Sửa code trong editor (file `.swift` được tô màu cú pháp).
3. Bấm **Preview** trên thanh trên. Màn hình xem trước mở toàn màn hình.
4. Sửa code xong thì đóng Preview, hoặc bấm **Tải lại** để đọc lại file.

Dự án UI **không có nút Chạy**, chỉ có Preview.

## Preview hoạt động thế nào

iOS không cho biên dịch Swift ngay trên máy. Vì vậy Catnip có sẵn một **bộ thông dịch tập con Swift/SwiftUI**: nó đọc code của bạn, chạy từng dòng rồi vẽ ra giao diện UIKit. Điều này có nghĩa:

- Preview **không phải** SwiftUI thật. Giao diện có thể khác chút so với khi chạy bằng Xcode.
- Chỉ dùng được phần Swift và SwiftUI được liệt kê dưới đây.
- Mọi file `.swift` trong dự án đều được nạp. Màn hình gốc là struct `ContentView`, hoặc khối `#Preview { ... }` nếu có. Nếu cả hai đều không có, Catnip lấy struct `View` đầu tiên.

## Ví dụ

```swift
import SwiftUI

struct ContentView: View {
    @State private var count = 0
    @State private var name = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Xin chào \(name.isEmpty ? "Catnip" : name)!")
                .font(.title)
            TextField("Nhập tên", text: $name)
            Button("Bấm tôi") { count += 1 }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            Text("Đã bấm: \(count)")
        }
        .padding()
    }
}
```

## View được hỗ trợ

| Nhóm | View |
|---|---|
| Bố cục | `VStack`, `HStack`, `ZStack`, `LazyVStack`, `LazyHStack`, `Group`, `Spacer`, `Divider` |
| Cuộn, danh sách | `ScrollView` (dọc/ngang), `List`, `Form`, `Section` |
| Hiển thị | `Text`, `Image(systemName:)`, `Label`, `ProgressView`, `Color`, `Rectangle`, `RoundedRectangle`, `Circle`, `Capsule`, `Ellipse` |
| Nhập liệu | `Button`, `TextField`, `SecureField`, `Toggle`, `Slider`, `Stepper`, `Picker` |
| Điều hướng | `NavigationView`, `NavigationStack` (chỉ hiện tiêu đề `navigationTitle`, **chưa** chuyển trang), `NavigationLink` (chỉ hiện nhãn) |
| Lặp | `ForEach` trên mảng hoặc khoảng (`0..<5`) |

`Picker` được vẽ dạng thanh chọn (segmented). Mỗi lựa chọn dùng `.tag(giá trị)`.

## Trạng thái và binding

- `@State var x = 0` giữ trạng thái. Khi giá trị đổi, giao diện tự dựng lại.
- `$x` tạo binding để truyền cho `TextField`, `Toggle`, `Slider`, `Stepper`, `Picker`, hoặc cho view con khai báo `@Binding`.
- `@State` được lưu theo **tên struct + tên thuộc tính**. Hai view cùng một struct sẽ **dùng chung** state.
- `@Binding`, `@StateObject`, `@AppStorage` được đọc cú pháp. Chỉ `@State` và `@Binding` thực sự hoạt động đầy đủ.

## Modifier được hỗ trợ

- **Chữ và màu:** `font`, `foregroundColor`, `foregroundStyle`, `bold`, `italic`, `fontWeight`, `multilineTextAlignment`, `lineLimit`, `tint`, `fill`, `stroke`.
- **Bố cục:** `padding` (cả `.horizontal`, `.top`..., kèm số), `frame` (`width`, `height`, `minWidth`, `maxWidth: .infinity`...), `offset`, `scaleEffect`, `rotationEffect(.degrees(...))`.
- **Nền và viền:** `background` (màu hoặc view), `overlay`, `cornerRadius`, `clipShape`, `border`, `shadow`, `opacity`.
- **Tương tác:** `onTapGesture`, `onAppear`, `disabled`.
- **Khác:** `navigationTitle`, `ignoresSafeArea` (màu nền phủ toàn màn hình).

Modifier không có trong danh sách sẽ **bị bỏ qua** và hiện cảnh báo ở dòng cuối màn hình Preview. Nhiều modifier chỉ để giữ code không bị lỗi (`resizable`, `buttonStyle`, `pickerStyle`...) và không có tác dụng thật.

## Màu và font

- Màu: `Color.red`, `.blue`, `.green`, `.orange`, `.yellow`, `.pink`, `.purple`, `.gray`, `.black`, `.white`, `.clear`, `.primary`, `.secondary`, `.indigo`, `.teal`, `.cyan`, `.mint`, `.brown`, `Color(red:green:blue:)`, và `.opacity(x)`.
- Font: `.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.subheadline`, `.body`, `.callout`, `.footnote`, `.caption`, `.system(size:weight:)`.

## Phần Swift được hỗ trợ

- `struct` (View và kiểu thường), `class` cơ bản, `enum` đơn giản (có `.allCases`), `func`, `var`/`let`, thuộc tính tính toán.
- `if`/`else`, `if let`, `guard`, `for ... in`, `while`, `switch`, `return`, `break`, `continue`.
- Closure (có tham số, `$0`), trailing closure, toán tử số học/so sánh/logic, `??`, toán tử ba ngôi, khoảng `a...b` và `a..<b`.
- Chuỗi có nội suy `"\(x)"`, chuỗi nhiều dòng.
- Mảng và các hàm `append`, `remove(at:)`, `insert`, `removeAll`, `count`, `isEmpty`, `map`, `filter`, `forEach`, `sorted`, `reversed`, `contains`, `joined`, `reduce`, `min`, `max`.
- Chuỗi: `uppercased`, `lowercased`, `hasPrefix`, `hasSuffix`, `contains`, `count`, `isEmpty`, `replacingOccurrences`.
- Hàm có sẵn: `Int()`, `Double()`, `String()`, `min`, `max`, `abs`, `sqrt`, `round`, `print`.

## Chưa hỗ trợ

- Generic, protocol thật sự, `extension` (được bỏ qua), tuple, dictionary, `Optional` chaining đầy đủ, `try/catch`.
- `@ObservedObject`, `@EnvironmentObject`, `ObservableObject`, Combine, `async/await`.
- Animation (`withAnimation`, `.animation`), `sheet`, `alert`, điều hướng thật, `TabView` nhiều tab, gesture ngoài `onTapGesture`.
- Thư viện ngoài SwiftUI (Foundation nâng cao, MapKit...).

## Lỗi thường gặp

- **Dòng lỗi đỏ ở giữa màn hình:** lỗi cú pháp hoặc code vượt quá phần được hỗ trợ. Thông báo ghi tên file và số dòng.
- **Chữ đỏ ở cuối màn hình:** lỗi khi chạy một action (ví dụ chỉ số mảng ngoài phạm vi). Giao diện vẫn giữ nguyên, bạn sửa code rồi bấm Tải lại.
- **Cảnh báo xám ở cuối màn hình:** modifier hoặc view chưa hỗ trợ bị bỏ qua.
- **"Chạy quá lâu":** vòng lặp quá nhiều bước, thường do `while` không kết thúc.
- **Bố cục khác Xcode:** Preview tự tính bố cục bằng UIKit nên có thể lệch nhẹ, nhất là với `Spacer` lồng nhau và `frame`.
