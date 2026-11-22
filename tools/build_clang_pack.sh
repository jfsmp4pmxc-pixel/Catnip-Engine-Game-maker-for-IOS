#!/bin/bash
# Build gói Clang++ cho Catnip (chạy trên macOS có Xcode + cmake + ninja + python3).
#   OUT=<thư mục>          nơi đặt kết quả (mặc định ./clang-pack)
#   LLVM_REF=llvmorg-20.1.8
#   SDL3_HEADERS=<thư mục chứa SDL3/*.h>  (tuỳ chọn; ví dụ từ love-apple-dependencies)
# Kết quả: $OUT/catnip-clang-ios-arm64.tar.z (tar GNU nén deflate thô, app tải về và giải nén).
set -euo pipefail

OUT="${OUT:-$PWD/clang-pack}"
LLVM_REF="${LLVM_REF:-llvmorg-20.1.8}"
SRC="$OUT/llvm-project"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
mkdir -p "$OUT"
LAUNCHER=""
if command -v ccache >/dev/null 2>&1; then LAUNCHER="-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"; fi

if [ ! -d "$SRC" ]; then
  git init -q "$SRC"
  git -C "$SRC" remote add origin https://github.com/llvm/llvm-project
  git -C "$SRC" fetch -q --depth 1 origin "$LLVM_REF"
  git -C "$SRC" checkout -q FETCH_HEAD
fi

# 1) Công cụ sinh mã chạy trên máy build (host).
cmake -G Ninja -S "$SRC/llvm" -B "$OUT/build-host" $LAUNCHER \
  -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_TARGETS_TO_BUILD="AArch64" -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF
ninja -C "$OUT/build-host" llvm-tblgen llvm-min-tblgen clang-tblgen

# 2) LLVM + Clang cho iOS arm64.
cmake -G Ninja -S "$SRC/llvm" -B "$OUT/build-ios" $LAUNCHER \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_CROSSCOMPILING=ON -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DLLVM_HOST_TRIPLE=arm64-apple-ios15.0 \
  -DCMAKE_INSTALL_PREFIX="$OUT/install" \
  -DLLVM_ENABLE_PROJECTS="clang" -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_TARGETS_TO_BUILD="AArch64" -DLLVM_DEFAULT_TARGET_TRIPLE="arm64-apple-ios15.0" \
  -DLLVM_NATIVE_TOOL_DIR="$OUT/build-host/bin" \
  -DLLVM_TABLEGEN="$OUT/build-host/bin/llvm-tblgen" -DCLANG_TABLEGEN="$OUT/build-host/bin/clang-tblgen" \
  -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON -DCLANG_LINK_CLANG_DYLIB=ON \
  -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_UTILS=OFF \
  -DLLVM_BUILD_TOOLS=OFF -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF -DLLVM_ENABLE_PLUGINS=OFF -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
  -DCLANG_ENABLE_ARCMT=OFF -DCLANG_PLUGIN_SUPPORT=OFF \
  -DHAVE_LIBRT=OFF -DLLVM_ENABLE_LIBEDIT=OFF -DLLVM_ENABLE_LIBPFM=OFF -DLLVM_ENABLE_CURL=OFF -DLLVM_ENABLE_HTTPLIB=OFF \
  -DCMAKE_MACOSX_BUNDLE=OFF -DCLANG_INCLUDE_TESTS=OFF -DCLANG_BUILD_TOOLS=OFF \
  -DCLANG_TOOL_CLANG_REPL_BUILD=OFF -DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF -DCLANG_TOOL_LIBCLANG_BUILD=OFF \
  -DCLANG_TOOL_CLANG_REFACTOR_BUILD=OFF -DCLANG_TOOL_AMDGPU_ARCH_BUILD=OFF -DCLANG_TOOL_NVPTX_ARCH_BUILD=OFF \
  -DCLANG_TOOL_CLANG_FORMAT_BUILD=OFF -DCLANG_TOOL_CLANG_SCAN_DEPS_BUILD=OFF -DCLANG_TOOL_CLANG_OFFLOAD_BUNDLER_BUILD=OFF \
  -DCLANG_TOOL_CLANG_LINKER_WRAPPER_BUILD=OFF -DCLANG_TOOL_CLANG_NVLINK_WRAPPER_BUILD=OFF \
  -DCLANG_TOOL_CLANG_FUZZER_BUILD=OFF -DCLANG_TOOL_DIAGTOOL_BUILD=OFF
ninja -C "$OUT/build-ios" LLVM clang-cpp clang-resource-headers

# 3) libcatnipclang.dylib (API C cho app).
CLANG_INC="$SRC/clang/include"
BUILD_CLANG_INC="$OUT/build-ios/tools/clang/include"
LLVM_INC="$SRC/llvm/include"
BUILD_LLVM_INC="$OUT/build-ios/include"
mkdir -p "$OUT/pack/lib"
xcrun --sdk iphoneos clang++ -arch arm64 -miphoneos-version-min=15.0 -isysroot "$SDK" \
  -std=c++17 -fno-rtti -fvisibility-inlines-hidden -dynamiclib -O2 \
  -I"$CLANG_INC" -I"$BUILD_CLANG_INC" -I"$LLVM_INC" -I"$BUILD_LLVM_INC" \
  "$(dirname "$0")/catnip_clang_api.cpp" \
  -L"$OUT/build-ios/lib" -lclang-cpp -lLLVM \
  -Wl,-rpath,@loader_path -install_name @rpath/libcatnipclang.dylib \
  -o "$OUT/pack/lib/libcatnipclang.dylib"
cp -L "$OUT/build-ios/lib/"libLLVM*.dylib "$OUT/build-ios/lib/"libclang-cpp*.dylib "$OUT/pack/lib/"
xcrun strip -x "$OUT/pack/lib/"*.dylib || true
python3 - "$OUT/pack/lib" <<'PY'
import sys, os, struct
for fn in os.listdir(sys.argv[1]):
    if not fn.endswith(".dylib"): continue
    path = os.path.join(sys.argv[1], fn)
    d = bytearray(open(path, "rb").read())
    nc = struct.unpack_from("<I", d, 16)[0]; o = 32
    for _ in range(nc):
        c, s = struct.unpack_from("<2I", d, o)
        if c == 0xC:
            off = struct.unpack_from("<I", d, o + 8)[0]
            name = bytes(d[o + off:o + s]).split(b"\0")[0]
            if name.startswith(b"/System/Library/Frameworks/CoreServices"):
                struct.pack_into("<I", d, o, 0x80000018); print("weak:", fn, name.decode())
        o += s
    open(path, "wb").write(d)
PY
for f in "$OUT/pack/lib/"*.dylib; do
  codesign --force --sign - "$f"
  codesign --verify --verbose=1 "$f"
done
ls -lh "$OUT/pack/lib"

# 4) Header: sysroot iOS, resource headers clang (nếu có), SDL3.
mkdir -p "$OUT/pack/sysroot/usr" "$OUT/pack/include" "$OUT/pack/resource/lib"
if [ -d "$OUT/build-ios/lib/clang" ]; then
  cp -R "$OUT/build-ios/lib/clang" "$OUT/pack/resource/lib/clang"
  echo ">> Copied clang resource dir vào pack/resource/lib/clang"
else
  echo ">> WARN: $OUT/build-ios/lib/clang không tồn tại — bỏ qua resource dir"
fi
cp -R "$SDK/usr/include" "$OUT/pack/sysroot/usr/include"

# ---- FIX: nhúng compiler-builtin headers vào sysroot ----
# App gọi clang++ CHỈ với -isysroot (không -resource-dir), nên:
#   (a) <stdarg.h> — chỉ trong clang resource dir — không tìm thấy → lỗi _va_list.h.
#   (b) <stddef.h> SDK include <sys/_types/_wint_t.h> cần __darwin_wint_t
#       trong khi arm/_types.h chưa parse xong → "__darwin_wint_t unknown type".
# Giải pháp: copy builtin headers vào sysroot/usr/include/ + override stddef.h.
SYS_INC="$OUT/pack/sysroot/usr/include"

# Tìm clang builtin include dir: ưu tiên build-ios → install → source.
CLANG_BUILTIN_INC=""
for d in "$OUT/build-ios" "$OUT/install"; do
  [ -d "$d" ] || continue
  CANDIDATE="$(find "$d" -maxdepth 7 -type d -path '*/lib/clang/*/include' -print -quit 2>/dev/null || true)"
  if [ -n "$CANDIDATE" ] && [ -f "$CANDIDATE/stdarg.h" ] && [ -f "$CANDIDATE/stddef.h" ]; then
    CLANG_BUILTIN_INC="$CANDIDATE"
    echo ">> Clang builtin include: $CLANG_BUILTIN_INC (từ $d)"
    break
  fi
done
if [ -z "$CLANG_BUILTIN_INC" ] && [ -f "$SRC/clang/lib/Headers/stdarg.h" ] && [ -f "$SRC/clang/lib/Headers/stddef.h" ]; then
  CLANG_BUILTIN_INC="$SRC/clang/lib/Headers"
  echo ">> Clang builtin include: $CLANG_BUILTIN_INC (fallback source)"
fi
if [ -z "$CLANG_BUILTIN_INC" ]; then
  echo "ERROR: Không tìm thấy clang builtin headers ở build dir hoặc source." >&2
  echo "Debug — các file stdarg.h/stddef.h có trong \$OUT:" >&2
  find "$OUT" \( -name 'stdarg.h' -o -name 'stddef.h' \) 2>/dev/null | head -30 >&2 || true
  exit 1
fi

# Copy các builtin header SDK còn thiếu
added=0
for f in "$CLANG_BUILTIN_INC"/*.h; do
  base="$(basename "$f")"
  if [ ! -e "$SYS_INC/$base" ]; then
    cp -f "$f" "$SYS_INC/$base"
    added=$((added + 1))
  fi
done
echo ">> Đã thêm $added builtin headers vào sysroot"

# Ghi đè stddef.h — cắt vòng lặp phụ thuộc _wint_t.h
cp -f "$CLANG_BUILTIN_INC/stddef.h" "$SYS_INC/stddef.h"
echo ">> Đã override stddef.h (bản clang, không include _wint_t.h)"

# Sanity check
test -f "$SYS_INC/stdarg.h"   || { echo "ERROR: stdarg.h chưa có trong sysroot" >&2; exit 1; }
test -f "$SYS_INC/stddef.h"   || { echo "ERROR: stddef.h chưa có trong sysroot" >&2; exit 1; }

if [ -n "${SDL3_HEADERS:-}" ] && [ -d "$SDL3_HEADERS" ]; then cp -R "$SDL3_HEADERS" "$OUT/pack/include/SDL3"; fi

# 5) Đóng gói.
python3 - "$OUT/pack" "$OUT/catnip-clang-ios-arm64.tar.z" <<'PY'
import sys, tarfile, zlib, io, os
src, dst = sys.argv[1], sys.argv[2]
class Sink(io.RawIOBase):
    def __init__(self, f):
        self.f = f; self.c = zlib.compressobj(9, zlib.DEFLATED, -15)
    def writable(self): return True
    def write(self, b):
        self.f.write(self.c.compress(bytes(b))); return len(b)
    def close(self):
        self.f.write(self.c.flush()); super().close()
with open(dst, "wb") as f:
    sink = Sink(f)
    with tarfile.open(fileobj=sink, mode="w|", format=tarfile.GNU_FORMAT) as t:
        t.add(src, arcname=".", recursive=True)
    sink.close()
print("size:", os.path.getsize(dst))
PY
ls -lh "$OUT/catnip-clang-ios-arm64.tar.z"

# 6) Verify.
python3 - "$OUT/catnip-clang-ios-arm64.tar.z" <<'PY'
import sys, zlib, io, tarfile
data = zlib.decompressobj(-15).decompress(open(sys.argv[1], "rb").read())
t = tarfile.open(fileobj=io.BytesIO(data))
names = [m.name.lstrip("./") for m in t.getmembers() if m.isfile()]
print("files:", len(names))
for n in sorted(x for x in names if x.startswith("lib/")): print("  ", n)
need = ["lib/libcatnipclang.dylib", "lib/libclang-cpp.dylib", "lib/libLLVM.dylib"]
missing = [n for n in need if n not in names]
if missing: sys.exit("Gói thiếu: " + ", ".join(missing))
if not any(n.startswith("sysroot/usr/include/c++/v1/") for n in names): sys.exit("Gói thiếu libc++ headers")
if "sysroot/usr/include/stdarg.h" not in names:
    sys.exit("Gói thiếu sysroot/usr/include/stdarg.h → app sẽ không compile được")
if "sysroot/usr/include/stddef.h" not in names:
    sys.exit("Gói thiếu sysroot/usr/include/stddef.h")
for m in t.getmembers():
    if m.name.lstrip("./") == "sysroot/usr/include/stddef.h":
        c = t.extractfile(m).read().decode("utf-8","replace")
        if "_wint_t.h" in c:
            sys.exit("stddef.h vẫn là bản SDK (có _wint_t.h) → chưa override đúng")
        print(">> stddef.h OK (bản clang)")
        break
print("OK: gói hợp lệ")
PY