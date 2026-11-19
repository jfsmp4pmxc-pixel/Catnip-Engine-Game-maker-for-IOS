# Swift cho giao diện

Phần Swift mà Preview hiểu được. Nếu bạn đã biết Swift thì đây là danh sách giới hạn.

## Biến, kiểu, chuỗi

```swift
let ten = "Mai"
var tuoi = 20
let diem = 8.5
let ok = true
let loiChao = "Chào \(ten), \(tuoi) tuổi"
let nhieuDong = """
    Dòng 1
    Dòng 2
    """
```

Kiểu khai báo (`let x: Int = 5`) được chấp nhận và bỏ qua. Đổi kiểu: `Int("12")`, `Double(5)`, `String(7)`, `String(format: "%.1f", 3.14159)`.

## Điều khiển luồng

```swift
if tuoi >= 18 { ... } else if tuoi >= 13 { ... } else { ... }
let nhan = tuoi >= 18 ? "Lớn" : "Nhỏ"

for i in 0..<5 { ... }
for ten in danhSach { ... }
while dem < 10 { dem += 1 }

switch loai {
case .a: ...
case .b, .c: ...
default: ...
}

guard let x = giaTri else { return }
if let y = giaTri { ... }
```

## Mảng

```swift
var ds = [3, 1, 2]
ds.append(4)
ds.remove(at: 0)
ds.insert(9, at: 0)
ds.count; ds.isEmpty; ds.first; ds.last
ds.map { $0 * 2 }
ds.filter { $0 > 1 }
ds.sorted()
ds.sorted { $0 > $1 }
ds.reduce(0) { $0 + $1 }
ds.contains(3)
ds.firstIndex(of: 3)
ds.joined(separator: ", ")      // với mảng chuỗi
Array(repeating: 0, count: 5)
```

Cũng có: `forEach`, `reversed`, `compactMap`, `flatMap`, `allSatisfy`, `prefix`, `suffix`, `dropFirst`, `dropLast`, `shuffled`, `randomElement`, `enumerated`, `min`, `max`, `sort`.

## Từ điển và tuple

```swift
var tuoiCua = ["Mai": 20, "Nam": 22]
tuoiCua["Lan"] = 19
tuoiCua["Nam"] = nil          // xoá
print(tuoiCua.count, tuoiCua.keys, tuoiCua.values)
for (ten, tuoi) in tuoiCua { ... }

let toaDo = (x: 10, y: 20)
print(toaDo.x, toaDo.y, toaDo.0)

for (i, ten) in danhSach.enumerated() { ... }
```

## struct, class và thuộc tính

```swift
struct SanPham: Identifiable {
    var id = UUID()
    var ten: String
    var gia: Double
    var giaVND: String { "\(Int(gia)) đ" }   // thuộc tính tính toán
    func mota() -> String { "\(ten): \(giaVND)" }
}

let sp = SanPham(ten: "Bút", gia: 5000)
```

- Khởi tạo theo từng thuộc tính (memberwise) và `init(...)` tự viết đều dùng được.
- `static let mau = [...]` dùng được: `SanPham.mau`.
- `extension SanPham { ... }` được gộp vào kiểu gốc.
- `struct` trong Preview được **chia sẻ tham chiếu** như class, nên `ds[0].ten = "B"` đổi thật. Đừng dựa vào việc sao chép giá trị.

## enum

```swift
enum Mau: String {
    case do_ = "Đỏ", xanh = "Xanh"
    var chu: String { rawValue }
    func dep() -> Bool { self == .xanh }
}

enum Hinh {
    case tron(Double)
    case vuong(Double, Double)
}

switch hinh {
case .tron(let r): print(r)
case .vuong(let w, let h): print(w * h)
}

Mau.allCases
```

## Closure

```swift
let nhan2 = { (x: Int) in x * 2 }
let ds2 = [1, 2, 3].map { x in x + 1 }
let ds3 = [1, 2, 3].map { $0 * 3 }
```

## Hàm

```swift
func tong(_ a: Int, _ b: Int) -> Int { a + b }
func chao(ten: String, long: Bool = false) -> String { ... }
chao(ten: "Mai")
```

Hàm trả về view không cần ghi `return` nếu chỉ có một biểu thức.

## ObservableObject (model dùng chung)

```swift
class Gio: ObservableObject {
    @Published var sl = 0
    func them() { sl += 1 }
}

struct ContentView: View {
    @StateObject private var gio = Gio()
    var body: some View {
        Button("SL: \(gio.sl)") { gio.them() }
    }
}
```

Đổi thuộc tính của class làm giao diện vẽ lại. `@ObservedObject` và `@EnvironmentObject` (kèm `.environmentObject(...)`) dùng được ở mức cơ bản.

## Chưa hỗ trợ

Generic, protocol tự định nghĩa có ràng buộc, `async/await`, `try/catch`, `@Observable` (macro mới), `Date` nâng cao, `Codable`, giá trị tuỳ chọn lồng sâu (`??` và `?.` đơn giản vẫn dùng được).
