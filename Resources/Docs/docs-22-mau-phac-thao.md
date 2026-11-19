# Mẫu phác thảo và bảng tra cứu

## Mẫu 1: màn hình đăng nhập

```swift
import SwiftUI

struct ContentView: View {
    @State private var email = ""
    @State private var pass = ""
    @State private var nho = true

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pawprint.fill").font(.system(size: 56)).foregroundColor(.orange)
            Text("Đăng nhập").font(.largeTitle).bold()
            TextField("Email", text: $email)
            SecureField("Mật khẩu", text: $pass)
            Toggle("Ghi nhớ tôi", isOn: $nho)
            Button("Vào") { }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .padding(24)
    }
}
```

## Mẫu 2: danh sách việc cần làm

```swift
import SwiftUI

struct Viec {
    var ten: String
    var xong: Bool
}

struct ContentView: View {
    @State private var ds = [Viec(ten: "Học SwiftUI", xong: false), Viec(ten: "Pha cà phê", xong: true)]
    @State private var moi = ""

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Việc mới", text: $moi)
                    Button("Thêm") {
                        if !moi.isEmpty { ds.append(Viec(ten: moi, xong: false)); moi = "" }
                    }
                }
                .padding()
                List {
                    ForEach(0..<ds.count) { i in
                        HStack {
                            Image(systemName: ds[i].xong ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(ds[i].xong ? .green : .gray)
                            Text(ds[i].ten)
                            Spacer()
                        }
                        .onTapGesture { ds[i].xong.toggle() }
                    }
                }
            }
            .navigationTitle("Việc hôm nay")
        }
    }
}
```

## Mẫu 3: thẻ sản phẩm có tab

```swift
import SwiftUI

struct Card: View {
    var ten: String
    var gia: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.2)).frame(height: 80)
            Text(ten).font(.headline)
            Text(gia).foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 3)
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(0..<6) { i in Card(ten: "Món \(i + 1)", gia: "\(10 + i) k") }
                }
                .padding()
            }
            .tabItem { Label("Cửa hàng", systemImage: "bag") }

            Text("Giỏ hàng trống")
                .tabItem { Label("Giỏ", systemImage: "cart") }
        }
    }
}
```

## Bảng tra cứu nhanh

| Muốn | Dùng |
|---|---|
| Xếp dọc / ngang / chồng | `VStack` `HStack` `ZStack` |
| Co giãn | `Spacer()`, `.frame(maxWidth: .infinity)` |
| Cuộn | `ScrollView`, `List` |
| Lưới | `LazyVGrid(columns:)` |
| Nhập chữ | `TextField`, `SecureField`, `TextEditor` |
| Bật tắt, thanh trượt | `Toggle`, `Slider`, `Stepper` |
| Chọn | `Picker` (segmented), `Menu` |
| Chuyển trang | `NavigationView` + `NavigationLink` |
| Tab | `TabView` + `.tabItem` |
| Hộp thoại | `.sheet`, `.alert`, `.confirmationDialog` |
| Tiến trình | `ProgressView(value:)`, `Gauge` |
| Nền màu / dải màu | `Color`, `LinearGradient` |
| Chế độ tối | `.preferredColorScheme(.dark)` |

## Modifier bị bỏ qua (an toàn)

Các modifier sau được chấp nhận nhưng chưa có tác dụng, để code SwiftUI thật chép vào vẫn chạy: `animation`, `transition`, `contextMenu`, `swipeActions`, `refreshable`, `onChange`, `onSubmit`, `focused`, `searchable`, `blur`, `mask`, `fixedSize`, `zIndex`, `listRowBackground`, `aspectRatio`, `lineSpacing`, `underline`, `strikethrough`, `badge`, `accessibility...`, `buttonStyle`, `pickerStyle`, `listStyle`, `resizable`, `scaledToFit`.

Modifier không có trong cả hai danh sách sẽ bị bỏ qua kèm **cảnh báo** ở dòng cuối Preview.

## Mẹo

- Dữ liệu mẫu để ở đầu file (`let mau = [...]`) cho dễ sửa.
- Chia view lớn thành struct nhỏ; Preview vẽ lại nhanh.
- Chưa chắc một tính năng có hỗ trợ không: thử luôn. Nếu chưa có, Preview hiện khung xám hoặc cảnh báo chứ không dừng.
