//
//  Catnip Engine: game maker for IOS
//
//  Copyright (C) 2026 jfsmp4pmxc-pixel <ihhjnkk@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program. If not, see <https://www.gnu.org/licenses/>.
//

// SwiftUIInterp.swift
// Trình thông dịch tập con Swift/SwiftUI cho loại dự án "UI": chạy cây cú pháp từ SwiftUIParser, dựng cây VNode
// (mô tả giao diện). UIPreview.swift vẽ VNode bằng UIKit. @State lưu trong `store`, đổi là dựng lại.

import UIKit

struct RunError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Giá trị

final class Binding {
    let get: () -> V
    let set: (V) -> Void
    init(get: @escaping () -> V, set: @escaping (V) -> Void) { self.get = get; self.set = set }
}

final class Obj {
    let def: StructDef
    var fields: [String: V] = [:]
    init(def: StructDef) { self.def = def }
}

final class Closure {
    let def: ClosureDef
    let scope: Scope
    init(def: ClosureDef, scope: Scope) { self.def = def; self.scope = scope }
}

final class VNode {
    var kind: String
    var args: [String: V] = [:]
    var children: [VNode] = []
    var mods: [(String, [V])] = []
    init(_ kind: String) { self.kind = kind }
    func copy() -> VNode {
        let n = VNode(kind)
        n.args = args; n.children = children; n.mods = mods
        return n
    }
}

indirect enum V {
    case int(Int)
    case double(Double)
    case bool(Bool)
    case str(String)
    case null
    case array([V])
    case view(VNode)
    case closure(Closure)
    case enumCase(String?, String, [V])
    case color(UIColor)
    case binding(Binding)
    case obj(Obj)
    case range(Double, Double, Bool, Bool)   // lo, hi, closed, isInt
    case type(String)

    var asDouble: Double? {
        switch self {
        case .int(let i): return Double(i)
        case .double(let d): return d
        default: return nil
        }
    }
    var asInt: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int(d)
        default: return nil
        }
    }
    var asBool: Bool? { if case .bool(let b) = self { return b }; return nil }
    var asString: String? { if case .str(let s) = self { return s }; return nil }
}

final class Scope {
    var vars: [String: V] = [:]
    let parent: Scope?
    var selfObj: Obj?
    init(parent: Scope?, selfObj: Obj? = nil) {
        self.parent = parent
        self.selfObj = selfObj ?? parent?.selfObj
    }
    func lookup(_ n: String) -> V? {
        if let v = vars[n] { return v }
        return parent?.lookup(n)
    }
    @discardableResult func assign(_ n: String, _ v: V) -> Bool {
        if vars[n] != nil { vars[n] = v; return true }
        return parent?.assign(n, v) ?? false
    }
}

enum Flow { case none, ret(V), brk, cont }

// MARK: - Tiện ích giá trị

func describe(_ v: V) -> String {
    switch v {
    case .int(let i): return String(i)
    case .double(let d): return d == d.rounded() && abs(d) < 1e15 ? String(format: "%.1f", d) : String(d)
    case .bool(let b): return b ? "true" : "false"
    case .str(let s): return s
    case .null: return "nil"
    case .array(let a): return "[" + a.map { v -> String in if case .str(let s) = v { return "\"\(s)\"" }; return describe(v) }.joined(separator: ", ") + "]"
    case .enumCase(_, let c, _): return c
    case .binding(let b): return describe(b.get())
    case .view: return "(View)"
    case .closure: return "(closure)"
    case .color: return "Color"
    case .obj(let o): return o.def.name
    case .range(let a, let b, let closed, let isInt):
        return isInt ? "\(Int(a))\(closed ? "..." : "..<")\(Int(b))" : "\(a)\(closed ? "..." : "..<")\(b)"
    case .type(let n): return n
    }
}

func valuesEqual(_ a: V, _ b: V) -> Bool {
    switch (a, b) {
    case (.int(let x), .int(let y)): return x == y
    case (.str(let x), .str(let y)): return x == y
    case (.bool(let x), .bool(let y)): return x == y
    case (.null, .null): return true
    case (.enumCase(let t1, let c1, _), .enumCase(let t2, let c2, _)):
        return c1 == c2 && (t1 == nil || t2 == nil || t1 == t2)
    case (.array(let x), .array(let y)):
        return x.count == y.count && zip(x, y).allSatisfy { valuesEqual($0, $1) }
    default:
        if let x = a.asDouble, let y = b.asDouble { return x == y }
        return false
    }
}

func truthy(_ v: V) -> Bool {
    if case .bool(let b) = v { return b }
    if case .binding(let b) = v { return truthy(b.get()) }
    return false
}

// MARK: - Màu và font

enum PVColors {
    static func named(_ n: String) -> UIColor? {
        switch n {
        case "red": return .systemRed
        case "blue": return .systemBlue
        case "green": return .systemGreen
        case "orange": return .systemOrange
        case "yellow": return .systemYellow
        case "pink": return .systemPink
        case "purple": return .systemPurple
        case "gray", "grey": return .systemGray
        case "black": return .black
        case "white": return .white
        case "clear": return .clear
        case "primary": return .label
        case "secondary": return .secondaryLabel
        case "accentColor": return .systemBlue
        case "indigo": return .systemIndigo
        case "teal": return .systemTeal
        case "cyan": return .systemCyan
        case "mint": return .systemMint
        case "brown": return .systemBrown
        default: return nil
        }
    }

    static func color(_ v: V) -> UIColor? {
        switch v {
        case .color(let c): return c
        case .enumCase(_, let n, _): return named(n)
        case .view(let n):
            if n.kind == "ColorFill", case .color(let c)? = n.args["color"] { return c }
            return nil
        case .binding(let b): return color(b.get())
        default: return nil
        }
    }

    static func font(_ v: V) -> UIFont? {
        guard case .enumCase(_, let n, let a) = v else { return nil }
        switch n {
        case "largeTitle": return .preferredFont(forTextStyle: .largeTitle)
        case "title": return .preferredFont(forTextStyle: .title1)
        case "title2": return .preferredFont(forTextStyle: .title2)
        case "title3": return .preferredFont(forTextStyle: .title3)
        case "headline": return .preferredFont(forTextStyle: .headline)
        case "subheadline": return .preferredFont(forTextStyle: .subheadline)
        case "body": return .preferredFont(forTextStyle: .body)
        case "callout": return .preferredFont(forTextStyle: .callout)
        case "footnote": return .preferredFont(forTextStyle: .footnote)
        case "caption": return .preferredFont(forTextStyle: .caption1)
        case "caption2": return .preferredFont(forTextStyle: .caption2)
        case "system":
            // .system(size: 20, weight: .bold)
            let size = a.first?.asDouble ?? 17
            var w = UIFont.Weight.regular
            if a.count > 1 { w = weight(a[1]) ?? .regular }
            return .systemFont(ofSize: CGFloat(size), weight: w)
        default: return nil
        }
    }

    static func weight(_ v: V) -> UIFont.Weight? {
        guard case .enumCase(_, let n, _) = v else { return nil }
        switch n {
        case "ultraLight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return nil
        }
    }
}

// MARK: - Trình thông dịch

final class Interp {
    let prog: Program
    var store: [String: V] = [:]
    var globals: [String: V] = [:]
    var warnings: [String] = []
    var onChange: (() -> Void)?
    var printed: [String] = []
    private var steps = 0
    private var coll: [[VNode]] = []
    private var appeared: Set<String> = []

    init(prog: Program) { self.prog = prog }

    func fail(_ m: String) -> RunError { RunError(message: m) }
    func warn(_ m: String) { if !warnings.contains(m) { warnings.append(m) } }

    func resetRun() { steps = 0; warnings = [] }

    // MARK: Điểm vào

    func buildRoot() throws -> VNode {
        resetRun()
        if globals.isEmpty {
            let top = Scope(parent: nil)
            for (n, e) in prog.globals { globals[n] = try eval(e, top) }
        }
        let scope = Scope(parent: nil)
        if let pb = prog.previewBody {
            let nodes = try nodesOf(try runBody(pb.body, scope))
            return group(nodes)
        }
        var rootName: String?
        if prog.structs["ContentView"]?.isView == true { rootName = "ContentView" }
        if rootName == nil, let app = prog.structOrder.compactMap({ prog.structs[$0] }).first(where: { $0.isApp }) {
            // Tìm "XxxView()" đầu tiên trong body của App: đơn giản nhất là lấy View đầu tiên khác App.
            _ = app
        }
        if rootName == nil { rootName = prog.structOrder.first(where: { prog.structs[$0]?.isView == true }) }
        guard let name = rootName, let def = prog.structs[name] else {
            throw fail("Không thấy struct nào có dạng `struct TênView: View`. Thêm ContentView.swift hoặc khối #Preview { ... }.")
        }
        return try viewNode(try instantiate(def, [], scope))
    }

    private func group(_ nodes: [VNode]) -> VNode {
        if nodes.count == 1 { return nodes[0] }
        let g = VNode("Group")
        g.children = nodes
        return g
    }

    private func viewNode(_ v: V) throws -> VNode {
        if case .view(let n) = v { return n }
        throw fail("Giá trị này không phải View")
    }

    // MARK: Struct

    func fieldKey(_ obj: Obj, _ name: String) -> String { obj.def.name + "." + name }

    func readField(_ obj: Obj, _ name: String) throws -> V? {
        guard let p = obj.def.props.first(where: { $0.name == name }) else { return nil }
        if let body = p.computed {
            let sc = Scope(parent: nil, selfObj: obj)
            return try runBody(body, sc)
        }
        if p.isState { return store[fieldKey(obj, name)] ?? .null }
        let v = obj.fields[name] ?? .null
        if case .binding(let b) = v { return b.get() }
        return v
    }

    func writeField(_ obj: Obj, _ name: String, _ v: V) throws {
        guard let p = obj.def.props.first(where: { $0.name == name }) else { throw fail("Không có thuộc tính \(name)") }
        if p.isState { store[fieldKey(obj, name)] = v; return }
        if case .binding(let b)? = obj.fields[name] { b.set(v); return }
        obj.fields[name] = v
    }

    func bindingFor(_ obj: Obj, _ name: String) -> Binding? {
        guard let p = obj.def.props.first(where: { $0.name == name }) else { return nil }
        if !p.isState, case .binding(let b)? = obj.fields[name] { return b }
        return Binding(get: { [unowned self] in ((try? self.readField(obj, name)) ?? nil) ?? .null },
                       set: { [unowned self] v in try? self.writeField(obj, name, v); self.onChange?() })
    }

    func instantiate(_ def: StructDef, _ args: [(String?, V)], _ scope: Scope) throws -> V {
        let obj = Obj(def: def)
        let stored = def.props.filter { $0.computed == nil }
        var given: [String: V] = [:]
        var posIdx = 0
        for (label, v) in args {
            if let l = label { given[l] = v }
            else {
                guard posIdx < stored.count else { break }
                given[stored[posIdx].name] = v
                posIdx += 1
            }
        }
        let sc = Scope(parent: nil, selfObj: obj)
        for p in stored {
            if p.isState {
                if store[fieldKey(obj, p.name)] == nil {
                    store[fieldKey(obj, p.name)] = try p.defaultExpr.map { try eval($0, sc) } ?? .null
                }
            } else if let g = given[p.name] {
                obj.fields[p.name] = g
            } else if let d = p.defaultExpr {
                obj.fields[p.name] = try eval(d, sc)
            }
        }
        if def.isView {
            guard let body = def.props.first(where: { $0.name == "body" })?.computed else {
                throw fail("\(def.name) thiếu `var body: some View { ... }`")
            }
            let v = try runBody(body, Scope(parent: nil, selfObj: obj))
            let nodes = try nodesOf(v)
            let g = VNode("Group")
            g.children = nodes
            return .view(g)
        }
        return .obj(obj)
    }

    // MARK: Chạy khối lệnh

    func nodesOf(_ v: V) throws -> [VNode] {
        switch v {
        case .view(let n):
            if n.kind == "Group" && n.mods.isEmpty { return n.children }
            return [n]
        case .color: return [try asNode(v)]
        case .array(let a): return try a.flatMap { try nodesOf($0) }
        default: return []
        }
    }

    private func asNode(_ v: V) throws -> VNode {
        if case .view(let n) = v { return n }
        if case .color(let c) = v {
            let n = VNode("ColorFill")
            n.args["color"] = .color(c)
            return n
        }
        throw fail("Không phải View")
    }

    func runBody(_ stmts: [Stmt], _ scope: Scope) throws -> V {
        if stmts.count == 1, case .expr(let e) = stmts[0] { return try eval(e, scope) }
        coll.append([])
        var flow: Flow = .none
        do { flow = try exec(stmts, scope) } catch { _ = coll.popLast(); throw error }
        let nodes = coll.popLast() ?? []
        if case .ret(let v) = flow { return v }
        if nodes.isEmpty { return .null }
        let g = VNode("Group")
        g.children = nodes
        return .view(g)
    }

    func exec(_ stmts: [Stmt], _ scope: Scope) throws -> Flow {
        for s in stmts {
            let f = try exec(s, scope)
            if case .none = f { continue }
            return f
        }
        return .none
    }

    private func tick() throws {
        steps += 1
        if steps > 3_000_000 { throw fail("Chạy quá lâu (vòng lặp vô hạn?)") }
    }

    private func evalConds(_ conds: [Cond], _ scope: Scope) throws -> Bool {
        for c in conds {
            switch c {
            case .expr(let e): if !truthy(try eval(e, scope)) { return false }
            case .bind(let n, let e):
                let v = try eval(e, scope)
                if case .null = v { return false }
                scope.vars[n] = v
            }
        }
        return true
    }

    func exec(_ s: Stmt, _ scope: Scope) throws -> Flow {
        try tick()
        switch s {
        case .expr(let e):
            let v = try eval(e, scope)
            if !coll.isEmpty {
                switch v {
                case .view, .color:
                    coll[coll.count - 1].append(contentsOf: try nodesOf(v))
                default: break
                }
            }
            return .none
        case .decl(let n, let e):
            scope.vars[n] = try e.map { try eval($0, scope) } ?? .null
            return .none
        case .assign(let op, let lhs, let rhs):
            var nv = try eval(rhs, scope)
            if op != "=" {
                let cur = try eval(lhs, scope)
                nv = try binary(String(op.dropLast()), cur, nv)
            }
            try assignTo(lhs, nv, scope)
            return .none
        case .ifS(let conds, let then, let els):
            let inner = Scope(parent: scope)
            if try evalConds(conds, inner) { return try exec(then, inner) }
            if let e = els { return try exec(e, Scope(parent: scope)) }
            return .none
        case .guardS(let conds, let els):
            if try evalConds(conds, scope) { return .none }
            let f = try exec(els, Scope(parent: scope))
            return f
        case .forS(let name, let seq, let body):
            for item in try iterate(try eval(seq, scope)) {
                let inner = Scope(parent: scope)
                inner.vars[name] = item
                let f = try exec(body, inner)
                switch f {
                case .brk: return .none
                case .ret: return f
                default: break
                }
            }
            return .none
        case .whileS(let cond, let body):
            while truthy(try eval(cond, scope)) {
                try tick()
                let f = try exec(body, Scope(parent: scope))
                switch f {
                case .brk: return .none
                case .ret: return f
                default: break
                }
            }
            return .none
        case .ret(let e):
            return .ret(try e.map { try eval($0, scope) } ?? .null)
        case .brk: return .brk
        case .cont: return .cont
        case .switchS(let subj, let cases, let dflt):
            let v = try eval(subj, scope)
            for (pats, body) in cases {
                for p in pats {
                    let pv = try eval(p, scope)
                    var hit = valuesEqual(v, pv)
                    if case .range(let lo, let hi, let closed, _) = pv, let d = v.asDouble { hit = d >= lo && (closed ? d <= hi : d < hi) }
                    if hit {
                        let f = try exec(body, Scope(parent: scope))
                        if case .brk = f { return .none }
                        return f
                    }
                }
            }
            if let d = dflt {
                let f = try exec(d, Scope(parent: scope))
                if case .brk = f { return .none }
                return f
            }
            return .none
        }
    }

    func iterate(_ v: V) throws -> [V] {
        switch v {
        case .array(let a): return a
        case .range(let lo, let hi, let closed, _):
            let l = Int(lo), h = Int(hi)
            let end = closed ? h : h - 1
            if end < l { return [] }
            if end - l > 100_000 { throw fail("Khoảng lặp quá lớn") }
            return (l...end).map { .int($0) }
        case .str(let s): return s.map { .str(String($0)) }
        case .binding(let b): return try iterate(b.get())
        default: throw fail("Không lặp được qua giá trị này")
        }
    }

    // MARK: Gán

    func assignTo(_ lhs: Expr, _ v: V, _ scope: Scope) throws {
        switch lhs {
        case .ident(let n):
            if scope.assign(n, v) { return }
            if let o = scope.selfObj, o.def.props.contains(where: { $0.name == n }) { try writeField(o, n, v); return }
            if globals[n] != nil { globals[n] = v; return }
            throw fail("Không gán được cho \"\(n)\"")
        case .member(let base, let name):
            if case .ident("self") = base, let o = scope.selfObj { try writeField(o, name, v); return }
            if case .obj(let o) = try eval(base, scope) { try writeField(o, name, v); return }
            throw fail("Không gán được cho .\(name)")
        case .index(let base, let idx):
            guard case .array(var arr) = try eval(base, scope), let i = try eval(idx, scope).asInt, i >= 0, i < arr.count else {
                throw fail("Chỉ số mảng không hợp lệ")
            }
            arr[i] = v
            try assignTo(base, .array(arr), scope)
        default:
            throw fail("Vế trái của phép gán không hợp lệ")
        }
    }

    // MARK: Biểu thức

    func eval(_ e: Expr, _ scope: Scope) throws -> V {
        try tick()
        switch e {
        case .int(let i): return .int(i)
        case .double(let d): return .double(d)
        case .bool(let b): return .bool(b)
        case .nilLit: return .null
        case .keyPath: return .null
        case .str(let parts):
            var out = ""
            for p in parts {
                switch p {
                case .lit(let s): out += s
                case .expr(let x): out += describe(try eval(x, scope))
                }
            }
            return .str(out)
        case .ident(let n): return try evalIdent(n, scope)
        case .implicitMember(let n): return .enumCase(nil, n, [])
        case .array(let items): return .array(try items.map { try eval($0, scope) })
        case .closure(let def): return .closure(Closure(def: def, scope: scope))
        case .unary(let op, let x):
            let v = try derefValue(try eval(x, scope))
            if op == "!" { return .bool(!truthy(v)) }
            if case .int(let i) = v { return .int(-i) }
            if case .double(let d) = v { return .double(-d) }
            throw fail("Không đổi dấu được giá trị này")
        case .binary(let op, let a, let b):
            if op == "&&" { return .bool(truthy(try eval(a, scope)) && truthy(try eval(b, scope))) }
            if op == "||" { return .bool(truthy(try eval(a, scope)) || truthy(try eval(b, scope))) }
            if op == "??" {
                let l = try derefValue(try eval(a, scope))
                if case .null = l { return try eval(b, scope) }
                return l
            }
            return try binary(op, try derefValue(try eval(a, scope)), try derefValue(try eval(b, scope)))
        case .ternary(let c, let a, let b):
            return truthy(try eval(c, scope)) ? try eval(a, scope) : try eval(b, scope)
        case .index(let base, let idx):
            let b = try derefValue(try eval(base, scope))
            let i = try derefValue(try eval(idx, scope))
            if case .array(let arr) = b, let k = i.asInt {
                guard k >= 0 && k < arr.count else { throw fail("Chỉ số \(k) ngoài mảng (\(arr.count) phần tử)") }
                return arr[k]
            }
            throw fail("Không dùng [ ] được với giá trị này")
        case .member(let base, let name):
            return try evalMember(base, name, scope)
        case .call(let callee, let args, let trailing):
            return try evalCall(callee, args, trailing, scope)
        }
    }

    func derefValue(_ v: V) -> V {
        if case .binding(let b) = v { return b.get() }
        return v
    }

    private func evalIdent(_ n: String, _ scope: Scope) throws -> V {
        if n == "self", let o = scope.selfObj { return .obj(o) }
        if n.hasPrefix("$") {
            let name = String(n.dropFirst())
            if scope.lookup(name) != nil {
                return .binding(Binding(get: { scope.lookup(name) ?? .null }, set: { [weak self] nv in scope.assign(name, nv); self?.onChange?() }))
            }
            if let o = scope.selfObj, let b = bindingFor(o, name) { return .binding(b) }
            throw fail("Không tìm thấy \"\(name)\" để tạo binding $\(name)")
        }
        if let v = scope.lookup(n) { return v }
        if let o = scope.selfObj {
            if let v = try readField(o, n) { return v }
            if o.def.methods[n] != nil { return .closure(methodClosure(o, n)) }
        }
        if let v = globals[n] { return v }
        if prog.structs[n] != nil || prog.enums[n] != nil { return .type(n) }
        if ["Color", "Font", "Alignment", "Edge", "Axis", "Angle"].contains(n) { return .type(n) }
        throw fail("Không tìm thấy tên \"\(n)\"")
    }

    private func methodClosure(_ o: Obj, _ name: String) -> Closure {
        // Dùng khi truyền hàm làm giá trị (action: doSomething).
        let def = ClosureDef(params: [], body: [.expr(.call(.member(.ident("self"), name), [], []))])
        return Closure(def: def, scope: Scope(parent: nil, selfObj: o))
    }

    private func evalMember(_ base: Expr, _ name: String, _ scope: Scope) throws -> V {
        if case .ident(let tn) = base, scope.lookup(tn) == nil, scope.selfObj.map({ o in !o.def.props.contains { $0.name == tn } }) ?? true, globals[tn] == nil {
            if let en = prog.enums[tn] {
                if name == "allCases" { return .array(en.cases.map { .enumCase(tn, $0, []) }) }
                if en.cases.contains(name) { return .enumCase(tn, name, []) }
                throw fail("enum \(tn) không có case \(name)")
            }
            if tn == "Color" {
                if let c = PVColors.named(name) { return .color(c) }
                throw fail("Color.\(name) chưa hỗ trợ")
            }
            if ["Font", "Alignment", "Edge", "Axis", "Angle", "Weight", "TextAlignment", "HorizontalAlignment", "VerticalAlignment"].contains(tn) {
                return .enumCase(tn, name, [])
            }
        }
        let b = derefValue(try eval(base, scope))
        switch b {
        case .obj(let o):
            if let v = try readField(o, name) { return v }
            if o.def.methods[name] != nil { return .closure(methodClosure(o, name)) }
            throw fail("\(o.def.name) không có thuộc tính \(name)")
        case .array(let a):
            switch name {
            case "count": return .int(a.count)
            case "isEmpty": return .bool(a.isEmpty)
            case "first": return a.first ?? .null
            case "last": return a.last ?? .null
            default: break
            }
        case .str(let s):
            switch name {
            case "count": return .int(s.count)
            case "isEmpty": return .bool(s.isEmpty)
            default: break
            }
        case .enumCase(_, let c, _):
            if name == "rawValue" { return .str(c) }
        case .double(let d):
            if name == "description" { return .str(describe(.double(d))) }
        case .int(let i):
            if name == "description" { return .str(String(i)) }
        case .binding(let bd):
            if name == "wrappedValue" { return bd.get() }
        case .view(let node):
            // Truy cập thuộc tính của view không có ý nghĩa: trả nguyên view.
            _ = node
        default: break
        }
        throw fail("Chưa hỗ trợ truy cập .\(name)")
    }

    // MARK: Toán tử

    func binary(_ op: String, _ a: V, _ b: V) throws -> V {
        switch op {
        case "==": return .bool(valuesEqual(a, b))
        case "!=": return .bool(!valuesEqual(a, b))
        case "...", "..<":
            if case .int(let x) = a, case .int(let y) = b { return .range(Double(x), Double(y), op == "...", true) }
            if let x = a.asDouble, let y = b.asDouble { return .range(x, y, op == "...", false) }
            throw fail("Khoảng không hợp lệ")
        case "+":
            if case .str(let x) = a, case .str(let y) = b { return .str(x + y) }
            if case .array(let x) = a, case .array(let y) = b { return .array(x + y) }
        default: break
        }
        if case .int(let x) = a, case .int(let y) = b {
            switch op {
            case "+": return .int(x &+ y)
            case "-": return .int(x &- y)
            case "*": return .int(x &* y)
            case "/": if y == 0 { throw fail("Chia cho 0") }; return .int(x / y)
            case "%": if y == 0 { throw fail("Chia cho 0") }; return .int(x % y)
            case "<": return .bool(x < y)
            case ">": return .bool(x > y)
            case "<=": return .bool(x <= y)
            case ">=": return .bool(x >= y)
            default: break
            }
        }
        if let x = a.asDouble, let y = b.asDouble {
            switch op {
            case "+": return .double(x + y)
            case "-": return .double(x - y)
            case "*": return .double(x * y)
            case "/": return .double(x / y)
            case "%": return .double(fmod(x, y))
            case "<": return .bool(x < y)
            case ">": return .bool(x > y)
            case "<=": return .bool(x <= y)
            case ">=": return .bool(x >= y)
            default: break
            }
        }
        if case .str(let x) = a, case .str(let y) = b {
            switch op {
            case "<": return .bool(x < y)
            case ">": return .bool(x > y)
            case "<=": return .bool(x <= y)
            case ">=": return .bool(x >= y)
            default: break
            }
        }
        throw fail("Không tính được \(describe(a)) \(op) \(describe(b))")
    }

    // MARK: Gọi

    func callClosure(_ c: Closure, _ args: [V]) throws -> V {
        let sc = Scope(parent: c.scope)
        if c.def.params.isEmpty {
            for (i, a) in args.enumerated() { sc.vars["$\(i)"] = a }
        } else {
            for (i, p) in c.def.params.enumerated() where i < args.count { sc.vars[p] = args[i] }
        }
        return try runBody(c.def.body, sc)
    }

    /// Chạy closure nội dung (ViewBuilder) và lấy ra các node con.
    func content(_ v: V?, _ args: [V] = []) throws -> [VNode] {
        guard let v = v, case .closure(let c) = v else { return [] }
        return try nodesOf(try callClosure(c, args))
    }

    /// Chạy action (nút bấm...) rồi báo đổi để dựng lại.
    func runAction(_ v: V?) throws {
        guard let v = v, case .closure(let c) = v else { return }
        _ = try callClosure(c, [])
    }

    func callMethod(_ o: Obj, _ m: FuncDef, _ args: [(String?, V)]) throws -> V {
        let sc = Scope(parent: nil, selfObj: o)
        var pos = 0
        for p in m.params {
            if let l = p.label, let hit = args.first(where: { $0.0 == l }) { sc.vars[p.name] = hit.1; continue }
            if p.label == nil {
                let unl = args.filter { $0.0 == nil }
                if pos < unl.count { sc.vars[p.name] = unl[pos].1; pos += 1; continue }
            }
            if let d = p.defaultExpr { sc.vars[p.name] = try eval(d, sc) } else { sc.vars[p.name] = .null }
        }
        return try runBody(m.body, sc)
    }

    func callFunc(_ f: FuncDef, _ args: [(String?, V)]) throws -> V {
        let sc = Scope(parent: nil)
        var pos = 0
        for p in f.params {
            if let l = p.label, let hit = args.first(where: { $0.0 == l }) { sc.vars[p.name] = hit.1; continue }
            if p.label == nil {
                let unl = args.filter { $0.0 == nil }
                if pos < unl.count { sc.vars[p.name] = unl[pos].1; pos += 1; continue }
            }
            if let d = p.defaultExpr { sc.vars[p.name] = try eval(d, sc) } else { sc.vars[p.name] = .null }
        }
        return try runBody(f.body, sc)
    }

    private func evalCall(_ callee: Expr, _ args: [Arg], _ trailing: [(String?, ClosureDef)], _ scope: Scope) throws -> V {
        var a: [(String?, V)] = try args.map { ($0.label, try eval($0.value, scope)) }
        let t: [(String?, V)] = trailing.map { ($0.0, .closure(Closure(def: $0.1, scope: scope))) }

        switch callee {
        case .ident(let name):
            if let v = scope.lookup(name), case .closure(let c) = v { return try callClosure(c, a.map { $0.1 } + t.map { $0.1 }) }
            if let o = scope.selfObj, let m = o.def.methods[name] { return try callMethod(o, m, a + t) }
            if let f = prog.funcs[name] { return try callFunc(f, a + t) }
            if let d = prog.structs[name] {
                var all = a
                if let tc = t.first { all.append((tc.0 ?? "content", tc.1)) }
                return try instantiate(d, all, scope)
            }
            return try builtin(name, a, t, scope)
        case .member(let base, let name):
            if case .ident(let tn) = base, scope.lookup(tn) == nil, scope.selfObj.map({ o in !o.def.props.contains { $0.name == tn } && o.def.methods[tn] == nil }) ?? true {
                if tn == "Color" || tn == "Font" || prog.enums[tn] != nil || ["Alignment"].contains(tn) {
                    if tn == "Color" { throw fail("Color.\(name)(...) chưa hỗ trợ") }
                    return .enumCase(tn, name, a.map { $0.1 })
                }
            }
            if case .ident("self") = base, let o = scope.selfObj, let m = o.def.methods[name] { return try callMethod(o, m, a + t) }
            let b = derefValue(try eval(base, scope))
            return try callOn(b, name, &a, t, base, scope)
        case .implicitMember(let name):
            return .enumCase(nil, name, a.map { $0.1 })
        default:
            let f = try eval(callee, scope)
            if case .closure(let c) = f { return try callClosure(c, a.map { $0.1 }) }
            throw fail("Giá trị này không gọi được như hàm")
        }
    }
}

// MARK: - Phương thức trên giá trị và hàm dựng sẵn

extension Interp {
    private func cl(_ v: V?) -> Closure? { if case .closure(let c)? = v { return c }; return nil }

    func callOn(_ b: V, _ name: String, _ a: inout [(String?, V)], _ t: [(String?, V)], _ baseExpr: Expr, _ scope: Scope) throws -> V {
        switch b {
        case .view(let node):
            let n = node.copy()
            // Giữ nhãn đối số (frame(width:), offset(x:)...) bằng enumCase "label:<nhãn>".
            let packed: [V] = a.map { $0.0 != nil ? V.enumCase(nil, "label:" + $0.0!, [$0.1]) : $0.1 } + t.map { $0.1 }
            n.mods.append((name, packed))
            return .view(n)
        case .color(let c):
            if name == "opacity", let x = a.first?.1.asDouble { return .color(c.withAlphaComponent(CGFloat(x))) }
            return .view(try modNode(VNode("ColorFill"), c, name, a, t))
        case .obj(let o):
            if let m = o.def.methods[name] { return try callMethod(o, m, a + t) }
            throw fail("\(o.def.name) không có hàm \(name)")
        case .closure(let c):
            return try callClosure(c, a.map { $0.1 })
        case .bool(let x):
            if name == "toggle" { try assignTo(baseExpr, .bool(!x), scope); return .null }
        case .array(var arr):
            let f = cl(t.first?.1) ?? cl(a.first?.1)
            switch name {
            case "append":
                if let v = a.first?.1 { arr.append(v) }
                try assignTo(baseExpr, .array(arr), scope); return .null
            case "removeAll": try assignTo(baseExpr, .array([]), scope); return .null
            case "removeLast":
                guard !arr.isEmpty else { throw fail("removeLast trên mảng rỗng") }
                let r = arr.removeLast(); try assignTo(baseExpr, .array(arr), scope); return r
            case "remove":
                guard let i = a.first?.1.asInt, i >= 0, i < arr.count else { throw fail("remove(at:) ngoài mảng") }
                let r = arr.remove(at: i); try assignTo(baseExpr, .array(arr), scope); return r
            case "insert":
                guard a.count >= 2, let i = a[1].1.asInt, i >= 0, i <= arr.count else { throw fail("insert(_:at:) không hợp lệ") }
                arr.insert(a[0].1, at: i); try assignTo(baseExpr, .array(arr), scope); return .null
            case "contains":
                if let f = f { return .bool(try arr.contains { truthy(try callClosure(f, [$0])) }) }
                return .bool(arr.contains { valuesEqual($0, a.first?.1 ?? .null) })
            case "map": if let f = f { return .array(try arr.map { try callClosure(f, [$0]) }) }
            case "filter": if let f = f { return .array(try arr.filter { truthy(try callClosure(f, [$0])) }) }
            case "forEach": if let f = f { for x in arr { _ = try callClosure(f, [x]) }; return .null }
            case "sorted":
                if let f = f { return .array(try arr.sorted { truthy(try callClosure(f, [$0, $1])) }) }
                return .array(try arr.sorted { truthy(try binary("<", $0, $1)) })
            case "reversed": return .array(arr.reversed())
            case "joined":
                let sep = a.first?.1.asString ?? ""
                return .str(arr.map { describe($0) }.joined(separator: sep))
            case "reduce":
                if let f = f, let initial = a.first?.1 { var acc = initial; for x in arr { acc = try callClosure(f, [acc, x]) }; return acc }
            case "min", "max":
                guard var best = arr.first else { return .null }
                for x in arr.dropFirst() where truthy(try binary(name == "min" ? "<" : ">", x, best)) { best = x }
                return best
            default: break
            }
        case .str(let s):
            switch name {
            case "uppercased": return .str(s.uppercased())
            case "lowercased": return .str(s.lowercased())
            case "hasPrefix": return .bool(s.hasPrefix(a.first?.1.asString ?? "\u{0}"))
            case "hasSuffix": return .bool(s.hasSuffix(a.first?.1.asString ?? "\u{0}"))
            case "contains": return .bool(s.contains(a.first?.1.asString ?? "\u{0}"))
            case "replacingOccurrences":
                if a.count >= 2, let x = a[0].1.asString, let y = a[1].1.asString { return .str(s.replacingOccurrences(of: x, with: y)) }
            default: break
            }
        case .type(let tn):
            if tn == "Color" { throw fail("Color.\(name) chưa hỗ trợ") }
        default: break
        }
        throw fail("Chưa hỗ trợ hàm .\(name)(...) trên \(describe(b))")
    }

    // MARK: Tiện ích dựng node

    private func labeled(_ a: [(String?, V)], _ l: String) -> V? { a.first(where: { $0.0 == l })?.1 }
    private func unlabeled(_ a: [(String?, V)]) -> [V] { a.filter { $0.0 == nil }.map { $0.1 } }

    private func modNode(_ n: VNode, _ c: UIColor, _ name: String, _ a: [(String?, V)], _ t: [(String?, V)]) throws -> VNode {
        n.args["color"] = .color(c)
        n.mods.append((name, a.map { $0.0 != nil ? V.enumCase(nil, "label:" + $0.0!, [$0.1]) : $0.1 } + t.map { $0.1 }))
        return n
    }

    private func stack(_ kind: String, _ a: [(String?, V)], _ t: [(String?, V)]) throws -> V {
        let n = VNode(kind)
        if let s = labeled(a, "spacing") { n.args["spacing"] = s }
        if let al = labeled(a, "alignment") { n.args["alignment"] = al }
        n.children = try content(t.first?.1)
        return .view(n)
    }

    func builtin(_ name: String, _ a: [(String?, V)], _ t: [(String?, V)], _ scope: Scope) throws -> V {
        let un = unlabeled(a)
        switch name {
        // --- Hàm thường
        case "Int":
            if let v = un.first {
                if case .str(let s) = v { return Int(s).map { .int($0) } ?? .null }
                if let i = v.asInt { return .int(i) }
            }
            return .null
        case "Double":
            if let v = un.first {
                if case .str(let s) = v { return Double(s).map { .double($0) } ?? .null }
                if let d = v.asDouble { return .double(d) }
            }
            return .null
        case "String": return .str(un.first.map { describe(derefValue($0)) } ?? "")
        case "Bool": return .bool(truthy(un.first ?? .null))
        case "min", "max":
            guard un.count >= 2 else { throw fail("\(name) cần 2 giá trị") }
            let less = truthy(try binary("<", derefValue(un[0]), derefValue(un[1])))
            return (name == "min") == less ? un[0] : un[1]
        case "abs":
            if case .int(let i)? = un.first { return .int(abs(i)) }
            if let d = un.first?.asDouble { return .double(abs(d)) }
        case "sqrt": if let d = un.first?.asDouble { return .double(sqrt(d)) }
        case "round": if let d = un.first?.asDouble { return .double(d.rounded()) }
        case "print": printed.append(un.map { describe($0) }.joined(separator: " ")); return .null
        case "Color":
            if let r = labeled(a, "red")?.asDouble, let g = labeled(a, "green")?.asDouble, let b = labeled(a, "blue")?.asDouble {
                return .color(UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(labeled(a, "opacity")?.asDouble ?? 1)))
            }
            if let w = un.first?.asDouble { return .color(UIColor(white: CGFloat(w), alpha: CGFloat(labeled(a, "opacity")?.asDouble ?? 1))) }
            throw fail("Color(...) cần red/green/blue")
        // --- Chứa
        case "VStack", "HStack", "ZStack", "LazyVStack", "LazyHStack":
            return try stack(name.replacingOccurrences(of: "Lazy", with: ""), a, t)
        case "Group", "NavigationView", "NavigationStack", "TabView", "Form", "List":
            let n = VNode(name == "NavigationStack" ? "NavigationView" : name)
            if name == "List" || name == "Form" { n.kind = "List" }
            n.children = try content(t.first?.1)
            if name == "List", let data = un.first, let f = t.first?.1 {
                n.children = try iterate(derefValue(data)).flatMap { try content(f, [$0]) }
            }
            return .view(n)
        case "ScrollView":
            let n = VNode("ScrollView")
            if case .enumCase(_, "horizontal", _)? = un.first { n.args["axis"] = .str("h") }
            n.children = try content(t.first?.1)
            return .view(n)
        case "Section":
            let n = VNode("Section")
            if let h = un.first, case .str = h { n.args["header"] = h }
            else if let h = labeled(a, "header"), case .closure = h { n.args["headerNodes"] = h }
            n.children = try content(t.last?.1)
            return .view(n)
        case "ForEach":
            guard let data = un.first, let f = t.first?.1 else { throw fail("ForEach cần dữ liệu và closure") }
            let n = VNode("Group")
            for item in try iterate(derefValue(data)) { n.children += try content(f, [item]) }
            return .view(n)
        // --- Lá
        case "Text":
            let n = VNode("Text")
            n.args["text"] = .str(un.first.map { describe(derefValue($0)) } ?? labeled(a, "verbatim").map { describe($0) } ?? "")
            return .view(n)
        case "Spacer": return .view(VNode("Spacer"))
        case "Divider": return .view(VNode("Divider"))
        case "EmptyView": return .view(VNode("Group"))
        case "Image":
            let n = VNode("Image")
            n.args["systemName"] = labeled(a, "systemName") ?? .str("photo")
            return .view(n)
        case "Label":
            let n = VNode("HStack")
            n.args["spacing"] = .int(6)
            let i = VNode("Image"); i.args["systemName"] = labeled(a, "systemImage") ?? .str("circle")
            let x = VNode("Text"); x.args["text"] = .str(un.first.map { describe($0) } ?? "")
            n.children = [i, x]
            return .view(n)
        case "Rectangle", "Circle", "Capsule", "Ellipse", "RoundedRectangle":
            let n = VNode("Shape")
            n.args["shape"] = .str(name)
            if let r = labeled(a, "cornerRadius") { n.args["radius"] = r }
            return .view(n)
        case "Button":
            let n = VNode("Button")
            var action: V?
            var label: V?
            if case .closure? = labeled(a, "action") { action = labeled(a, "action") }
            if let title = un.first, case .str(let s) = title {
                let x = VNode("Text"); x.args["text"] = .str(s); n.children = [x]
                action = action ?? t.first?.1
            } else if action != nil {
                label = t.first?.1
            } else {
                action = t.first?.1
                label = t.count > 1 ? t[1].1 : nil
            }
            if let l = label { n.children = try content(l) }
            if n.children.isEmpty { let x = VNode("Text"); x.args["text"] = .str("Button"); n.children = [x] }
            n.args["action"] = action ?? .null
            return .view(n)
        case "TextField", "SecureField":
            let n = VNode(name)
            n.args["placeholder"] = un.first ?? .str("")
            n.args["binding"] = labeled(a, "text") ?? .null
            return .view(n)
        case "Toggle":
            let n = VNode("Toggle")
            n.args["binding"] = labeled(a, "isOn") ?? .null
            if let s = un.first { n.args["title"] = s } else { n.children = try content(t.first?.1) }
            return .view(n)
        case "Slider":
            let n = VNode("Slider")
            n.args["binding"] = labeled(a, "value") ?? .null
            n.args["range"] = labeled(a, "in") ?? .range(0, 1, true, false)
            if let st = labeled(a, "step") { n.args["step"] = st }
            return .view(n)
        case "Stepper":
            let n = VNode("Stepper")
            n.args["title"] = un.first ?? .str("")
            n.args["binding"] = labeled(a, "value") ?? .null
            n.args["range"] = labeled(a, "in") ?? .null
            n.args["step"] = labeled(a, "step") ?? .int(1)
            return .view(n)
        case "Picker":
            let n = VNode("Picker")
            n.args["binding"] = labeled(a, "selection") ?? .null
            n.children = try content(t.first?.1)
            return .view(n)
        case "ProgressView":
            let n = VNode("Progress")
            if let v = labeled(a, "value") { n.args["value"] = v }
            n.args["total"] = labeled(a, "total") ?? .double(1)
            return .view(n)
        case "NavigationLink":
            let n = VNode("VStack")
            if let s = un.first, case .str(let txt) = s { let x = VNode("Text"); x.args["text"] = .str(txt); n.children = [x] }
            else { n.children = try content(t.last?.1) }
            warn("NavigationLink chưa chuyển trang, chỉ hiện nhãn")
            return .view(n)
        default: break
        }
        throw fail("Chưa hỗ trợ \"\(name)\" trong Preview")
    }
}
