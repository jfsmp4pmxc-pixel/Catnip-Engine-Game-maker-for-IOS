# SwiftUI cơ bản

## View và `body`

Mọi màn hình là một `struct` theo `View`, với thuộc tính `body` trả về giao diện:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Xin chào Catnip")
    }
}
```

Giao diện là **mô tả**: bạn không tạo nút rồi thêm vào màn hình; bạn viết cái bạn muốn thấy, SwiftUI lo phần còn lại.

## Text và Image

```swift
VStack(spacing: 12) {
    Text("Tiêu đề").font(.title).bold()
    Text("Dòng phụ").foregroundColor(.secondary)
    Image(systemName: "star.fill").font(.largeTitle).foregroundColor(.yellow)
}
```

- `Image(systemName:)` dùng biểu tượng SF Symbols của Apple.
- Cỡ chữ: `.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.subheadline`, `.body`, `.callout`, `.footnote`, `.caption`, hoặc `.system(size: 20, weight: .bold)`.
- Ghép chữ: `Text("A").bold() + Text(" B")`.

## Stack: xếp view

| View | Xếp |
|---|---|
| `VStack` | theo chiều dọc |
| `HStack` | theo chiều ngang |
| `ZStack` | chồng lên nhau |
| `Spacer()` | khoảng trống co giãn |
| `Divider()` | đường kẻ |

```swift
HStack {
    Image(systemName: "person.circle")
    Text("Mai")
    Spacer()
    Text("Online").foregroundColor(.green)
}
.padding()
```

Tham số hay dùng: `VStack(alignment: .leading, spacing: 8)`, `HStack(alignment: .top)`.

`ScrollView { ... }` cho nội dung dài (dọc mặc định, `ScrollView(.horizontal)` cho ngang).

## Modifier

Modifier là hàm gọi nối sau view, **thứ tự quan trọng**:

```swift
Text("Nút")
    .padding()              // đệm trước
    .background(Color.blue) // rồi tô nền cả vùng đệm
    .foregroundColor(.white)
    .cornerRadius(12)
```

Đổi thứ tự `padding` và `background` sẽ cho kết quả khác.

Nhóm modifier thường dùng:

- **Chữ:** `font`, `bold`, `italic`, `foregroundColor`, `multilineTextAlignment`, `lineLimit`.
- **Khoảng cách:** `padding()`, `padding(.horizontal, 20)`, `padding(.top)`.
- **Kích thước:** `frame(width: 100, height: 50)`, `frame(maxWidth: .infinity)`.
- **Nền, viền:** `background`, `overlay`, `cornerRadius`, `border`, `shadow`, `clipShape(Circle())`.
- **Hiệu ứng tĩnh:** `opacity`, `offset(x:y:)`, `scaleEffect`, `rotationEffect(.degrees(15))`.

## Màu và hình

- Màu: `.red .blue .green .orange .yellow .pink .purple .gray .black .white .clear .primary .secondary .indigo .teal .cyan .mint .brown`, `Color(red: 0.2, green: 0.4, blue: 0.9)`, `Color.blue.opacity(0.3)`.
- Hình: `Rectangle()`, `RoundedRectangle(cornerRadius: 12)`, `Circle()`, `Capsule()`, `Ellipse()`.
- Tô: `Circle().fill(Color.orange).frame(width: 60, height: 60)`.
- Dải màu: `LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)`.

```swift
ZStack {
    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        .ignoresSafeArea()
    Text("Xin chào").font(.largeTitle).foregroundColor(.white)
}
```

## Tách view nhỏ

Chia giao diện thành struct riêng cho dễ đọc:

```swift
struct Avatar: View {
    var name: String
    var body: some View {
        Text(String(name.prefix(1)))
            .font(.title)
            .frame(width: 48, height: 48)
            .background(Color.blue.opacity(0.2))
            .clipShape(Circle())
    }
}

struct ContentView: View {
    var body: some View {
        HStack { Avatar(name: "Mai"); Avatar(name: "Nam") }
    }
}
```

Tham số khi tạo view là các thuộc tính, truyền theo tên: `Avatar(name: "Mai")`.
