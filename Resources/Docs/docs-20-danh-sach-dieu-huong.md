# Danh sách, điều hướng, tab, sheet và alert

## List và Section

```swift
struct ContentView: View {
    @State private var fruits = ["Cam", "Táo", "Xoài"]

    var body: some View {
        List {
            Section("Trái cây") {
                ForEach(fruits, id: \.self) { f in
                    Text(f)
                }
            }
            Section("Khác") {
                Text("Rau")
            }
        }
    }
}
```

`Form` giống `List`, dùng cho trang cài đặt. Preview vẽ dạng nhóm bo góc quen thuộc.

## NavigationView và chuyển trang

```swift
NavigationView {
    List {
        NavigationLink("Chi tiết A", destination: DetailView(title: "A"))
        NavigationLink("Chi tiết B", destination: DetailView(title: "B"))
    }
    .navigationTitle("Danh mục")
}
```

- Bấm hàng để sang trang mới; có nút **‹ Quay lại**.
- Trang đích được dựng lại mỗi lần, nên phản ứng với `@State`.
- `@Environment(\.dismiss) var dismiss` rồi gọi `dismiss()` để quay lại hoặc đóng sheet.

```swift
struct DetailView: View {
    var title: String
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack {
            Text("Trang \(title)").font(.title)
            Button("Đóng") { dismiss() }
        }
        .navigationTitle(title)
    }
}
```

## toolbar

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button("Thêm") { count += 1 }
    }
}
```

Nút toolbar hiện ở góc trên bên phải của `NavigationView`.

## TabView

```swift
TabView {
    Text("Trang chủ").tabItem { Label("Nhà", systemImage: "house") }
    Text("Cài đặt").tabItem { Label("Cài đặt", systemImage: "gear") }
}
```

Thanh tab hiện ở dưới; bấm để đổi tab.

## sheet

```swift
@State private var showSheet = false

Button("Mở") { showSheet = true }
    .sheet(isPresented: $showSheet) {
        Text("Nội dung sheet")
    }
```

Sheet hiện dạng thẻ nổi trên nền mờ, có nút **Xong**. `fullScreenCover` và `popover` hiện giống vậy.

## alert và confirmationDialog

```swift
.alert("Xoá?", isPresented: $showAlert) {
    Button("Xoá") { items.removeAll() }
    Button("Huỷ") { }
} message: {
    Text("Không hoàn tác được")
}
```

Bấm một nút trong hộp thoại là tự đóng.

## Lưới, Menu, DisclosureGroup, Link

```swift
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
    ForEach(0..<6) { i in
        RoundedRectangle(cornerRadius: 10).fill(Color.blue).frame(height: 60)
    }
}

Menu("Tuỳ chọn") {
    Button("Sao chép") { }
    Button("Xoá") { }
}

DisclosureGroup("Xem thêm") { Text("Nội dung ẩn") }

Link("Mở trang web", destination: URL(string: "https://example.com")!)
```

- `GridItem(.adaptive(minimum: 80))` được quy ra số cột gần đúng.
- `Menu` bung danh sách khi bấm; mỗi `Button` thành một mục.
- `ProgressView(value: 0.5)` và `Gauge(value: 0.5)` vẽ thanh tiến trình.
