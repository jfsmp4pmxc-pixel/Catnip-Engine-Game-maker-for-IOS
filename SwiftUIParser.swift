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

// SwiftUIParser.swift
// Bộ đọc cú pháp Swift (tập con đủ cho SwiftUI) cho loại dự án "UI": tách từ (lexer) + dựng cây cú pháp (parser).
// Hỗ trợ: struct/class/enum, @State/@Binding..., func, var/let, if/guard/for/while/switch, closure, chuỗi nội suy,
// range, toán tử, gọi hàm có nhãn và trailing closure. Không phải Swift đầy đủ: không có generic, protocol, tuple...

import Foundation

struct SwiftSyntaxError: LocalizedError {
    let line: Int
    let message: String
    var errorDescription: String? { "Dòng \(line): \(message)" }
}

// MARK: - Cây cú pháp

enum StrPart { case lit(String); case expr(Expr) }

struct Arg { let label: String?; let value: Expr }

final class ClosureDef {
    let params: [String]
    let body: [Stmt]
    init(params: [String], body: [Stmt]) { self.params = params; self.body = body }
}

indirect enum Expr {
    case int(Int)
    case double(Double)
    case bool(Bool)
    case nilLit
    case str([StrPart])
    case ident(String)
    case implicitMember(String)
    case member(Expr, String)
    case call(Expr, [Arg], [(String?, ClosureDef)])
    case index(Expr, Expr)
    case array([Expr])
    case unary(String, Expr)
    case binary(String, Expr, Expr)
    case ternary(Expr, Expr, Expr)
    case closure(ClosureDef)
    case keyPath
}

enum Cond { case expr(Expr); case bind(String, Expr) }

indirect enum Stmt {
    case expr(Expr)
    case decl(String, Expr?)
    case assign(String, Expr, Expr)
    case ifS([Cond], [Stmt], [Stmt]?)
    case guardS([Cond], [Stmt])
    case forS(String, Expr, [Stmt])
    case whileS(Expr, [Stmt])
    case ret(Expr?)
    case brk
    case cont
    case switchS(Expr, [([Expr], [Stmt])], [Stmt]?)
}

struct PropDef {
    let name: String
    let isState: Bool
    let defaultExpr: Expr?
    let computed: [Stmt]?
    let returnsView: Bool
}

struct ParamDef { let label: String?; let name: String; let defaultExpr: Expr? }

final class FuncDef {
    let name: String
    let params: [ParamDef]
    let body: [Stmt]
    init(name: String, params: [ParamDef], body: [Stmt]) { self.name = name; self.params = params; self.body = body }
}

final class StructDef {
    let name: String
    var conforms: [String] = []
    var isClass = false
    var props: [PropDef] = []
    var methods: [String: FuncDef] = [:]
    init(name: String) { self.name = name }
    var isView: Bool { conforms.contains("View") }
    var isApp: Bool { conforms.contains("App") }
}

final class EnumDef {
    let name: String
    var cases: [String] = []
    init(name: String) { self.name = name }
}

final class Program {
    var structs: [String: StructDef] = [:]
    var structOrder: [String] = []
    var enums: [String: EnumDef] = [:]
    var funcs: [String: FuncDef] = [:]
    var globals: [(String, Expr)] = []
    var previewBody: ClosureDef?
}

// MARK: - Từ vựng

struct Tok {
    enum Kind { case ident, int, double, string, op, eof }
    var kind: Kind
    var text: String
    var parts: [(isExpr: Bool, text: String)] = []
    var nl: Bool          // có xuống dòng ngay trước token
    var sp: Bool          // có khoảng trắng ngay trước token
    var line: Int
}

enum SwiftLexer {
    private static let ops3 = ["...", "..<"]
    private static let ops2 = ["==", "!=", "<=", ">=", "&&", "||", "??", "+=", "-=", "*=", "/=", "->", "%="]

    static func lex(_ src: String) throws -> [Tok] {
        let c = Array(src)
        var i = 0, line = 1
        var toks: [Tok] = []
        var nl = false, sp = false
        func isIdStart(_ ch: Character) -> Bool { ch.isLetter || ch == "_" }
        func isIdChar(_ ch: Character) -> Bool { ch.isLetter || ch.isNumber || ch == "_" }

        while i < c.count {
            let ch = c[i]
            if ch == "\n" { line += 1; nl = true; sp = true; i += 1; continue }
            if ch == " " || ch == "\t" || ch == "\r" { sp = true; i += 1; continue }
            if ch == "/" && i + 1 < c.count && c[i + 1] == "/" {
                while i < c.count && c[i] != "\n" { i += 1 }
                continue
            }
            if ch == "/" && i + 1 < c.count && c[i + 1] == "*" {
                i += 2
                while i + 1 < c.count && !(c[i] == "*" && c[i + 1] == "/") { if c[i] == "\n" { line += 1; nl = true }; i += 1 }
                i += 2
                sp = true
                continue
            }
            let startLine = line
            func push(_ kind: Tok.Kind, _ text: String, parts: [(isExpr: Bool, text: String)] = []) {
                toks.append(Tok(kind: kind, text: text, parts: parts, nl: nl, sp: sp, line: startLine))
                nl = false; sp = false
            }
            if isIdStart(ch) || (ch == "$" && i + 1 < c.count && isIdChar(c[i + 1])) {
                var j = i + 1
                while j < c.count && isIdChar(c[j]) { j += 1 }
                push(.ident, String(c[i..<j]))
                i = j
                continue
            }
            if ch.isNumber {
                var j = i
                while j < c.count && (c[j].isNumber || c[j] == "_") { j += 1 }
                var isDouble = false
                if j + 1 < c.count && c[j] == "." && c[j + 1].isNumber {
                    isDouble = true
                    j += 1
                    while j < c.count && (c[j].isNumber || c[j] == "_") { j += 1 }
                }
                if j < c.count && (c[j] == "e" || c[j] == "E"), j + 1 < c.count, (c[j + 1].isNumber || c[j + 1] == "-" || c[j + 1] == "+") {
                    isDouble = true
                    j += 2
                    while j < c.count && c[j].isNumber { j += 1 }
                }
                let text = String(c[i..<j]).replacingOccurrences(of: "_", with: "")
                push(isDouble ? .double : .int, text)
                i = j
                continue
            }
            if ch == "\"" {
                var parts: [(isExpr: Bool, text: String)] = []
                var buf = ""
                let multi = i + 2 < c.count && c[i + 1] == "\"" && c[i + 2] == "\""
                i += multi ? 3 : 1
                var closed = false
                while i < c.count {
                    let d = c[i]
                    if multi {
                        if d == "\"" && i + 2 < c.count && c[i + 1] == "\"" && c[i + 2] == "\"" { i += 3; closed = true; break }
                    } else {
                        if d == "\"" { i += 1; closed = true; break }
                        if d == "\n" { break }
                    }
                    if d == "\\" && i + 1 < c.count {
                        let e = c[i + 1]
                        if e == "(" {
                            var depth = 1
                            var j = i + 2
                            var inner = ""
                            while j < c.count && depth > 0 {
                                if c[j] == "(" { depth += 1 }
                                if c[j] == ")" { depth -= 1; if depth == 0 { break } }
                                inner.append(c[j]); j += 1
                            }
                            if !buf.isEmpty { parts.append((false, buf)); buf = "" }
                            parts.append((true, inner))
                            i = j + 1
                            continue
                        }
                        switch e {
                        case "n": buf.append("\n")
                        case "t": buf.append("\t")
                        case "r": buf.append("\r")
                        case "0": buf.append("\0")
                        default: buf.append(e)
                        }
                        i += 2
                        continue
                    }
                    if d == "\n" { line += 1 }
                    buf.append(d)
                    i += 1
                }
                if !closed { throw SwiftSyntaxError(line: startLine, message: "chuỗi chưa đóng dấu \"") }
                if multi {
                    // Bỏ dòng đầu rỗng và thụt lề chung của chuỗi nhiều dòng.
                    var lines = buf.components(separatedBy: "\n")
                    if let f = lines.first, f.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeFirst() }
                    if let l = lines.last, l.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeLast() }
                    let indent = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        .map { $0.prefix(while: { $0 == " " || $0 == "\t" }).count }.min() ?? 0
                    buf = lines.map { String($0.dropFirst(min(indent, $0.count))) }.joined(separator: "\n")
                    if parts.isEmpty { parts = [] }
                }
                if !buf.isEmpty || parts.isEmpty { parts.append((false, buf)) }
                push(.string, "", parts: parts)
                continue
            }
            // Toán tử
            let rest3 = i + 2 < c.count ? String(c[i..<i + 3]) : ""
            let rest2 = i + 1 < c.count ? String(c[i..<i + 2]) : ""
            if ops3.contains(rest3) { push(.op, rest3); i += 3; continue }
            if ops2.contains(rest2) { push(.op, rest2); i += 2; continue }
            if "+-*/%<>=!?:.,;(){}[]@#&|\\^~".contains(ch) { push(.op, String(ch)); i += 1; continue }
            throw SwiftSyntaxError(line: line, message: "ký tự lạ \"\(ch)\"")
        }
        toks.append(Tok(kind: .eof, text: "", nl: true, sp: true, line: line))
        return toks
    }
}

// MARK: - Bộ đọc

final class SwiftParser {
    private var t: [Tok]
    private var p = 0
    private var allowTrailing = true

    init(tokens: [Tok]) { t = tokens }

    // MARK: Tiện ích

    private var cur: Tok { t[p] }
    private func peek(_ n: Int = 1) -> Tok { t[min(p + n, t.count - 1)] }
    private func fail(_ msg: String) -> SwiftSyntaxError { SwiftSyntaxError(line: cur.line, message: msg) }
    private func isOp(_ s: String) -> Bool { cur.kind == .op && cur.text == s }
    private func isId(_ s: String) -> Bool { cur.kind == .ident && cur.text == s }
    @discardableResult private func next() -> Tok { let x = t[p]; if p < t.count - 1 { p += 1 }; return x }
    private func accept(_ s: String) -> Bool { if isOp(s) { next(); return true }; return false }
    private func acceptId(_ s: String) -> Bool { if isId(s) { next(); return true }; return false }
    private func expect(_ s: String) throws {
        guard isOp(s) else { throw fail("cần \"\(s)\" nhưng gặp \"\(cur.kind == .eof ? "hết file" : cur.text)\"") }
        next()
    }
    private func ident() throws -> String {
        guard cur.kind == .ident else { throw fail("cần một tên") }
        return next().text
    }

    // MARK: Chương trình

    func parseProgram() throws -> Program {
        let prog = Program()
        while cur.kind != .eof {
            if accept(";") { continue }
            try parseTopLevel(prog)
        }
        return prog
    }

    private func skipAttributes() throws -> [String] {
        var names: [String] = []
        while isOp("@") {
            next()
            names.append(try ident())
            if isOp("(") && !cur.nl { try skipBalanced("(", ")") }
        }
        return names
    }

    private static let modifiers: Set<String> = ["private", "public", "internal", "fileprivate", "open", "static", "final",
                                                 "mutating", "nonmutating", "lazy", "weak", "unowned", "override", "indirect",
                                                 "required", "convenience", "class"]

    private func skipModifiers() {
        while cur.kind == .ident, SwiftParser.modifiers.contains(cur.text) {
            // "class Foo" là khai báo class, không phải bổ từ.
            if cur.text == "class" && peek().kind == .ident && !["func", "var", "let"].contains(peek().text) { break }
            next()
            if isOp("(") && !cur.nl { try? skipBalanced("(", ")") }   // private(set)
        }
    }

    private func skipBalanced(_ open: String, _ close: String) throws {
        try expect(open)
        var depth = 1
        while depth > 0 {
            if cur.kind == .eof { throw fail("thiếu \"\(close)\"") }
            if isOp(open) { depth += 1 } else if isOp(close) { depth -= 1 }
            next()
        }
    }

    private func parseTopLevel(_ prog: Program) throws {
        let attrs = try skipAttributes()
        _ = attrs
        skipModifiers()
        if acceptId("import") {
            _ = try ident()
            while accept(".") { _ = try ident() }
        } else if isId("struct") || isId("class") {
            let def = try parseStruct()
            prog.structs[def.name] = def
            prog.structOrder.append(def.name)
        } else if isId("enum") {
            let e = try parseEnum()
            prog.enums[e.name] = e
        } else if isId("func") {
            let f = try parseFunc()
            prog.funcs[f.0.name] = f.0
        } else if isId("let") || isId("var") {
            next()
            let name = try ident()
            _ = try skipType()
            if accept("=") { prog.globals.append((name, try parseExpr())) }
        } else if isOp("#") {
            next()
            let name = try ident()
            if name == "Preview" {
                if isOp("(") { try skipBalanced("(", ")") }
                try expect("{")
                let body = try parseBlockBody()
                prog.previewBody = ClosureDef(params: [], body: body)
            }
        } else if isId("extension") || isId("protocol") || isId("typealias") {
            // Bỏ qua cả khối.
            while cur.kind != .eof && !isOp("{") && !cur.nl { next() }
            if isOp("{") { try skipBalanced("{", "}") }
        } else {
            // Câu lệnh rời ở cấp cao nhất: đọc và bỏ qua.
            _ = try parseStmt()
        }
    }

    /// Bỏ qua một kiểu (có thể có generic, mảng, closure...). Trả về các tên đã gặp.
    private func skipType() throws -> [String] {
        var names: [String] = []
        guard accept(":") else { return names }
        var depth = 0
        var first = true
        while cur.kind != .eof {
            if !first && cur.nl && depth == 0 && !(isOp("->")) { break }
            if depth == 0 {
                if isOp("=") || isOp("{") || isOp(",") || isOp(")") || isOp("]") || isOp(";") { break }
            }
            if isOp("(") || isOp("[") || isOp("<") { depth += 1 }
            else if isOp(")") || isOp("]") || isOp(">") { depth -= 1 }
            if cur.kind == .ident { names.append(cur.text) }
            next()
            first = false
        }
        return names
    }

    private func parseStruct() throws -> StructDef {
        let isClass = isId("class")
        next()
        let def = StructDef(name: try ident())
        def.isClass = isClass
        if isOp("<") { // generic: bỏ qua
            var depth = 0
            repeat { if isOp("<") { depth += 1 } else if isOp(">") { depth -= 1 }; next() } while depth > 0 && cur.kind != .eof
        }
        if accept(":") {
            repeat { def.conforms.append(try ident()) } while accept(",")
        }
        try expect("{")
        while !isOp("}") {
            if cur.kind == .eof { throw fail("thiếu \"}\" kết thúc struct \(def.name)") }
            if accept(";") { continue }
            let attrs = try skipAttributes()
            skipModifiers()
            if isId("var") || isId("let") {
                next()
                let name = try ident()
                let typeNames = try skipType()
                let returnsView = typeNames.contains("View")
                let isState = attrs.contains { ["State", "StateObject", "AppStorage", "SceneStorage", "Namespace"].contains($0) }
                var dflt: Expr?
                var computed: [Stmt]?
                if accept("=") {
                    dflt = try parseExpr()
                } else if isOp("{") {
                    next()
                    // get/set tường minh: chỉ nhận phần get.
                    if isId("get") && peek().kind == .op && peek().text == "{" {
                        next(); next()
                        computed = try parseBlockBody()
                        while !isOp("}") && cur.kind != .eof { next() }
                        try expect("}")
                    } else {
                        computed = try parseBlockBody()
                    }
                }
                def.props.append(PropDef(name: name, isState: isState, defaultExpr: dflt, computed: computed, returnsView: returnsView))
            } else if isId("func") {
                let f = try parseFunc()
                def.methods[f.0.name] = f.0
                if f.1 { /* trả về View: gọi sẽ tự gom view */ }
            } else if isId("init") {
                next()
                if isOp("(") { try skipBalanced("(", ")") }
                if isOp("{") { try skipBalanced("{", "}") }
            } else if isId("struct") || isId("class") || isId("enum") {
                // Kiểu lồng nhau: đọc rồi bỏ.
                if isId("enum") { _ = try parseEnum() } else { _ = try parseStruct() }
            } else if isId("typealias") {
                while !cur.nl && cur.kind != .eof { next() }
            } else {
                throw fail("chưa hỗ trợ khai báo \"\(cur.text)\" trong struct")
            }
        }
        try expect("}")
        return def
    }

    private func parseEnum() throws -> EnumDef {
        next()
        let e = EnumDef(name: try ident())
        if accept(":") { repeat { _ = try ident() } while accept(",") }
        try expect("{")
        while !isOp("}") {
            if cur.kind == .eof { throw fail("thiếu } kết thúc enum") }
            if acceptId("case") {
                repeat {
                    e.cases.append(try ident())
                    if accept("=") { _ = try parseExpr() }
                    if isOp("(") { try skipBalanced("(", ")") }
                } while accept(",")
            } else if isOp("@") || isId("func") || isId("var") || isId("let") || cur.kind == .ident && SwiftParser.modifiers.contains(cur.text) {
                // Phương thức/thuộc tính của enum: bỏ qua.
                var depth = 0
                repeat {
                    if isOp("{") { depth += 1 } else if isOp("}") { depth -= 1 }
                    next()
                } while (depth > 0 || (!isOp("}") && !isId("case") && !(cur.nl && depth == 0 && (isId("func") || isId("var") || isId("let") || isOp("@") || (cur.kind == .ident && SwiftParser.modifiers.contains(cur.text)))))) && cur.kind != .eof
            } else {
                next()
            }
        }
        try expect("}")
        return e
    }

    private func parseFunc() throws -> (FuncDef, Bool) {
        next() // func
        let name = cur.kind == .ident ? next().text : next().text
        if isOp("<") { var d = 0; repeat { if isOp("<") { d += 1 } else if isOp(">") { d -= 1 }; next() } while d > 0 && cur.kind != .eof }
        try expect("(")
        var params: [ParamDef] = []
        while !isOp(")") {
            let a = try ident()
            var label: String? = a
            var pname = a
            if cur.kind == .ident { pname = next().text; label = (a == "_") ? nil : a }
            else if a == "_" { label = nil }
            _ = try skipType()
            var dflt: Expr?
            if accept("=") { dflt = try parseExpr() }
            params.append(ParamDef(label: label, name: pname, defaultExpr: dflt))
            if !accept(",") { break }
        }
        try expect(")")
        _ = acceptId("throws")
        var returnsView = false
        if accept("->") {
            var depth = 0
            while cur.kind != .eof && !(depth == 0 && isOp("{")) {
                if cur.kind == .ident && cur.text == "View" { returnsView = true }
                if isOp("(") || isOp("[") || isOp("<") { depth += 1 } else if isOp(")") || isOp("]") || isOp(">") { depth -= 1 }
                next()
            }
        }
        try expect("{")
        let body = try parseBlockBody()
        return (FuncDef(name: name, params: params, body: body), returnsView)
    }

    // MARK: Câu lệnh

    /// Đọc các câu lệnh tới dấu "}" (đã nuốt "{" trước đó) và nuốt luôn "}".
    private func parseBlockBody() throws -> [Stmt] {
        var out: [Stmt] = []
        let savedTrailing = allowTrailing
        allowTrailing = true
        defer { allowTrailing = savedTrailing }
        while !isOp("}") {
            if cur.kind == .eof { throw fail("thiếu \"}\"") }
            if accept(";") { continue }
            out.append(try parseStmt())
        }
        try expect("}")
        return out
    }

    private func parseBlock() throws -> [Stmt] {
        try expect("{")
        return try parseBlockBody()
    }

    private func parseConds() throws -> [Cond] {
        var conds: [Cond] = []
        let saved = allowTrailing
        allowTrailing = false
        defer { allowTrailing = saved }
        repeat {
            if isId("let") || isId("var") {
                next()
                let name = try ident()
                if accept("=") { conds.append(.bind(name, try parseExpr())) }
                else { conds.append(.bind(name, .ident(name))) }   // if let x  (Swift 5.7)
            } else {
                conds.append(.expr(try parseExpr()))
            }
        } while accept(",")
        return conds
    }

    private func parseStmt() throws -> Stmt {
        if cur.kind == .ident {
            switch cur.text {
            case "let", "var":
                next()
                let name = try ident()
                _ = try skipType()
                if accept("=") { return .decl(name, try parseExpr()) }
                return .decl(name, nil)
            case "if":
                return try parseIf()
            case "guard":
                next()
                let conds = try parseConds()
                guard acceptId("else") else { throw fail("guard cần else") }
                return .guardS(conds, try parseBlock())
            case "for":
                next()
                let name = try ident()
                guard acceptId("in") else { throw fail("for cần \"in\"") }
                let saved = allowTrailing
                allowTrailing = false
                let seq = try parseExpr()
                allowTrailing = saved
                return .forS(name, seq, try parseBlock())
            case "while":
                next()
                let saved = allowTrailing
                allowTrailing = false
                let c = try parseExpr()
                allowTrailing = saved
                return .whileS(c, try parseBlock())
            case "return":
                next()
                if cur.nl || isOp("}") || cur.kind == .eof { return .ret(nil) }
                return .ret(try parseExpr())
            case "break": next(); return .brk
            case "continue": next(); return .cont
            case "switch": return try parseSwitch()
            case "try", "await":
                next()
                return try parseStmt()
            default: break
            }
        }
        let lhs = try parseExpr()
        if cur.kind == .op, !cur.nl, ["=", "+=", "-=", "*=", "/=", "%="].contains(cur.text) {
            let op = next().text
            return .assign(op, lhs, try parseExpr())
        }
        return .expr(lhs)
    }

    private func parseIf() throws -> Stmt {
        next()
        let conds = try parseConds()
        let then = try parseBlock()
        var els: [Stmt]?
        if isId("else") {
            next()
            if isId("if") { els = [try parseIf()] } else { els = try parseBlock() }
        }
        return .ifS(conds, then, els)
    }

    private func parseSwitch() throws -> Stmt {
        next()
        let saved = allowTrailing
        allowTrailing = false
        let subject = try parseExpr()
        allowTrailing = saved
        try expect("{")
        var cases: [([Expr], [Stmt])] = []
        var dflt: [Stmt]?
        while !isOp("}") {
            if cur.kind == .eof { throw fail("thiếu \"}\" của switch") }
            if acceptId("case") {
                var pats: [Expr] = []
                repeat { pats.append(try parseExpr()) } while accept(",")
                try expect(":")
                cases.append((pats, try parseCaseBody()))
            } else if acceptId("default") {
                try expect(":")
                dflt = try parseCaseBody()
            } else {
                throw fail("switch cần case hoặc default")
            }
        }
        try expect("}")
        return .switchS(subject, cases, dflt)
    }

    private func parseCaseBody() throws -> [Stmt] {
        var out: [Stmt] = []
        while !isOp("}") && !isId("case") && !isId("default") {
            if cur.kind == .eof { throw fail("thiếu \"}\" của switch") }
            if accept(";") { continue }
            out.append(try parseStmt())
        }
        return out
    }

    // MARK: Biểu thức

    func parseExpr() throws -> Expr { try parseTernary() }

    private func parseTernary() throws -> Expr {
        let c = try parseBinary(1)
        if isOp("?") && cur.sp && !cur.nl {
            next()
            let saved = allowTrailing
            allowTrailing = true
            let a = try parseTernary()
            allowTrailing = saved
            try expect(":")
            let b = try parseTernary()
            return .ternary(c, a, b)
        }
        return c
    }

    private static let prec: [String: Int] = [
        "||": 1, "&&": 2,
        "==": 3, "!=": 3, "<": 3, ">": 3, "<=": 3, ">=": 3,
        "??": 4, "...": 5, "..<": 5,
        "+": 6, "-": 6, "*": 7, "/": 7, "%": 7,
    ]

    private func parseBinary(_ minPrec: Int) throws -> Expr {
        var lhs = try parseUnary()
        while cur.kind == .op, let pr = SwiftParser.prec[cur.text], pr >= minPrec, !cur.nl {
            let op = next().text
            let rhs = try parseBinary(op == "??" ? pr : pr + 1)
            lhs = .binary(op, lhs, rhs)
        }
        return lhs
    }

    private func parseUnary() throws -> Expr {
        if isOp("!") { next(); return .unary("!", try parseUnary()) }
        if isOp("-") { next(); return .unary("-", try parseUnary()) }
        if isOp("+") { next(); return try parseUnary() }
        if isId("try") || isId("await") { next(); return try parseUnary() }
        return try parsePostfix()
    }

    private func parseCallArgs() throws -> [Arg] {
        try expect("(")
        var args: [Arg] = []
        let saved = allowTrailing
        allowTrailing = true
        defer { allowTrailing = saved }
        while !isOp(")") {
            if cur.kind == .ident && peek().kind == .op && peek().text == ":" && !(peek(2).kind == .op && peek(2).text == ":") {
                let label = next().text
                next()
                args.append(Arg(label: label == "_" ? nil : label, value: try parseExpr()))
            } else {
                args.append(Arg(label: nil, value: try parseExpr()))
            }
            if !accept(",") { break }
        }
        try expect(")")
        return args
    }

    private func parsePostfix() throws -> Expr {
        var e = try parsePrimary()
        while true {
            if isOp(".") {
                if cur.nl && !(peek().kind == .ident) { break }
                next()
                if cur.kind == .int { e = .member(e, next().text); continue }
                e = .member(e, try ident())
                continue
            }
            if isOp("?") && !cur.sp && !cur.nl && peek().kind == .op && peek().text == "." { next(); continue }
            if isOp("!") && !cur.sp && !cur.nl { next(); continue }
            if isOp("(") && !cur.nl {
                let args = try parseCallArgs()
                var trailing: [(String?, ClosureDef)] = []
                try parseTrailing(&trailing)
                e = .call(e, args, trailing)
                continue
            }
            if isOp("[") && !cur.nl && !cur.sp {
                next()
                let saved = allowTrailing
                allowTrailing = true
                let idx = try parseExpr()
                allowTrailing = saved
                try expect("]")
                e = .index(e, idx)
                continue
            }
            if isOp("{") && !cur.nl && allowTrailing {
                switch e {
                case .ident, .member, .implicitMember, .call:
                    var trailing: [(String?, ClosureDef)] = []
                    try parseTrailing(&trailing)
                    e = .call(e, [], trailing)
                    continue
                default: break
                }
            }
            break
        }
        return e
    }

    private func parseTrailing(_ out: inout [(String?, ClosureDef)]) throws {
        guard isOp("{") && !cur.nl && allowTrailing else { return }
        out.append((nil, try parseClosureLiteral()))
        // Closure có nhãn tiếp theo:  } label: { ... }
        while cur.kind == .ident && peek().kind == .op && peek().text == ":" && peek(2).kind == .op && peek(2).text == "{" {
            let label = next().text
            next()
            out.append((label, try parseClosureLiteral()))
        }
    }

    private func parseClosureLiteral() throws -> ClosureDef {
        try expect("{")
        var params: [String] = []
        // Danh sách tham số: { a, b in ...} hoặc { (a, b) in ... }
        var q = p
        var found = false
        var names: [String] = []
        if t[q].kind == .op && t[q].text == "[" { // [weak self] in
            while q < t.count && !(t[q].kind == .op && t[q].text == "]") { q += 1 }
            q += 1
        }
        let paren = t[q].kind == .op && t[q].text == "("
        if paren { q += 1 }
        while q < t.count, t[q].kind == .ident || (t[q].kind == .op && t[q].text == ",") {
            if t[q].kind == .ident && t[q].text == "in" { break }
            if t[q].kind == .ident { names.append(t[q].text) }
            q += 1
        }
        if paren, q < t.count, t[q].kind == .op, t[q].text == ")" { q += 1 }
        if q < t.count, t[q].kind == .ident, t[q].text == "in" { found = true }
        if found {
            params = names.filter { $0 != "self" || false }
            p = q + 1
        }
        let body = try parseBlockBody()
        return ClosureDef(params: params, body: body)
    }

    private func parsePrimary() throws -> Expr {
        let tk = cur
        switch tk.kind {
        case .int:
            next()
            guard let v = Int(tk.text) else { throw fail("số nguyên quá lớn") }
            return .int(v)
        case .double:
            next()
            return .double(Double(tk.text) ?? 0)
        case .string:
            next()
            var parts: [StrPart] = []
            for part in tk.parts {
                if part.isExpr {
                    let sub = SwiftParser(tokens: try SwiftLexer.lex(part.text))
                    do { parts.append(.expr(try sub.parseExpr())) }
                    catch let e as SwiftSyntaxError { throw SwiftSyntaxError(line: tk.line, message: "trong chuỗi nội suy: " + e.message) }
                } else {
                    parts.append(.lit(part.text))
                }
            }
            return .str(parts)
        case .ident:
            next()
            switch tk.text {
            case "true": return .bool(true)
            case "false": return .bool(false)
            case "nil": return .nilLit
            default: return .ident(tk.text)
            }
        case .op:
            if tk.text == "." {
                next()
                return .implicitMember(try ident())
            }
            if tk.text == "(" {
                next()
                let saved = allowTrailing
                allowTrailing = true
                let e = try parseExpr()
                allowTrailing = saved
                if isOp(",") { throw fail("tuple chưa được hỗ trợ") }
                try expect(")")
                return e
            }
            if tk.text == "[" {
                next()
                var items: [Expr] = []
                let saved = allowTrailing
                allowTrailing = true
                defer { allowTrailing = saved }
                if isOp(":") { throw fail("dictionary chưa được hỗ trợ") }
                while !isOp("]") {
                    items.append(try parseExpr())
                    if isOp(":") { throw fail("dictionary chưa được hỗ trợ") }
                    if !accept(",") { break }
                }
                try expect("]")
                return .array(items)
            }
            if tk.text == "{" {
                return .closure(try parseClosureLiteral())
            }
            if tk.text == "\\" {
                next()
                while accept(".") { _ = try ident() }
                return .keyPath
            }
            throw fail("không hiểu \"\(tk.text)\" ở đây")
        case .eof:
            throw fail("file kết thúc đột ngột")
        }
    }
}
