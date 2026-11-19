# Trạng thái và nhập liệu

## @State: giá trị có thể đổi

```swift
struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Đã bấm: \(count)")
            Button("Tăng") { count += 1 }
        }
    }
}
```

Khi `count` đổi, giao diện tự vẽ lại. `\(count)` chèn giá trị vào chuỗi.

## Button

```swift
Button("Xoá") { items.removeAll() }

Button(action: { count += 1 }) {
    HStack { Image(systemName: "plus"); Text("Thêm") }
}

Button { count -= 1 } label: { Text("Giảm") }
```

## Binding với `$`

Điều khiển nhập liệu cần **binding** tới một `@State`, viết bằng `$`:

| View | Ví dụ |
|---|---|
| `TextField` | `TextField("Tên", text: $name)` |
| `SecureField` | `SecureField("Mật khẩu", text: $pass)` |
| `TextEditor` | `TextEditor(text: $note)` |
| `Toggle` | `Toggle("Bật", isOn: $on)` |
| `Slider` | `Slider(value: $volume, in: 0...100)` |
| `Stepper` | `Stepper("SL", value: $qty, in: 1...10)` |
| `Picker` | `Picker("Cỡ", selection: $size) { Text("S").tag("S"); Text("M").tag("M") }` |

```swift
struct ContentView: View {
    @State private var name = ""
    @State private var on = true
    @State private var volume = 30.0

    var body: some View {
        VStack(spacing: 12) {
            TextField("Tên bạn", text: $name)
            Toggle("Thông báo", isOn: $on)
            Slider(value: $volume, in: 0...100)
            Text("Xin chào \(name), âm lượng \(Int(volume))")
        }
        .padding()
    }
}
```

`Picker` được vẽ dạng thanh chọn (segmented).

## Truyền trạng thái cho view con: @Binding

```swift
struct Counter: View {
    @Binding var value: Int
    var body: some View {
        Button("Giá trị: \(value)") { value += 1 }
    }
}

struct ContentView: View {
    @State private var n = 0
    var body: some View {
        VStack { Counter(value: $n); Text("Ngoài thấy \(n)") }
    }
}
```

## Điều kiện và vòng lặp trong giao diện

```swift
if on { Text("Đang bật") } else { Text("Đang tắt") }

ForEach(0..<3) { i in Text("Dòng \(i)") }
```

## Hiển thị chọn lọc

- `.disabled(true)` làm mờ và khoá tương tác.
- `.opacity(0.5)`, `.hidden()` để ẩn.
- `.onTapGesture { count += 1 }` biến mọi view thành vùng bấm.
- `.onAppear { ... }` chạy một lần khi Preview mở.

## withAnimation

```swift
Button("Đổi") { withAnimation { on.toggle() } }
```

Preview làm mờ chuyển cảnh khi có `withAnimation`. Animation chi tiết (`.animation`, `.transition`) chưa hỗ trợ và bị bỏ qua.
