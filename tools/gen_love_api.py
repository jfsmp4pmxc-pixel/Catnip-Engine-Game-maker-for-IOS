#!/usr/bin/env python3
"""Sinh LoveAPI.swift từ mã nguồn LÖVE: đọc các bảng luaL_Reg trong src/modules/*/wrap_*.cpp.

Dùng:  python3 tools/gen_love_api.py <thư mục gốc của love> > LoveAPI.swift
"""
import os, re, sys

root = sys.argv[1]
mods = os.path.join(root, "src", "modules")
entry = re.compile(r'\{\s*"([A-Za-z_][A-Za-z0-9_]*)"\s*,\s*[A-Za-z_][A-Za-z0-9_]*\s*\}')
table = re.compile(r'luaL_Reg\s+(\w+)\s*\[\]\s*=\s*\{(.*?)\n\};', re.S)

functions = {}   # module -> set(names)
types = {}       # type -> set(methods)

for mod in sorted(os.listdir(mods)):
    d = os.path.join(mods, mod)
    if not os.path.isdir(d) or mod == "love":
        continue
    for fn in sorted(os.listdir(d)):
        if not (fn.startswith("wrap_") and fn.endswith(".cpp")):
            continue
        src = open(os.path.join(d, fn), encoding="utf-8", errors="replace").read()
        for name, body in table.findall(src):
            names = set(entry.findall(body))
            m = re.fullmatch(r'w_(\w+?)_functions', name)
            names = {n for n in names if not (n.startswith("_") or n.endswith("_i"))}
            if name == "functions":
                functions.setdefault(mod, set()).update(names)
            elif m:
                types.setdefault(m.group(1), set()).update(names)

def arr(items):
    return "[" + ", ".join('"%s"' % x for x in sorted(items)) + "]"

out = []
out.append("// Tự sinh bởi tools/gen_love_api.py từ mã nguồn LÖVE (zlib license). Đừng sửa tay.\n")
out.append("import Foundation\n")
out.append("enum LoveAPI {")
out.append("    /// Hàm của từng module: love.<module>.<hàm>")
out.append("    static let modules: [String: [String]] = [")
for m in sorted(functions):
    out.append('        "%s": %s,' % (m, arr(functions[m])))
out.append("    ]\n")
out.append("    /// Phương thức của từng kiểu đối tượng (dùng sau dấu ':').")
out.append("    static let types: [String: [String]] = [")
for t in sorted(types):
    out.append('        "%s": %s,' % (t, arr(types[t])))
out.append("    ]\n}")
print("\n".join(out))
