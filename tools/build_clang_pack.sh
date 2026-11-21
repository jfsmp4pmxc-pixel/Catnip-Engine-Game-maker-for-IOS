#!/bin/bash
# Build gói Clang++ cho Catnip (chạy trên macOS có Xcode + cmake + ninja + python3).
#   OUT=<thư mục>          nơi đặt kết quả (mặc định ./clang-pack)
#   LLVM_REF=llvmorg-20.1.8
#   SDL3_HEADERS=<thư mục chứa SDL3/*.h>  (tuỳ chọn; ví dụ từ love-apple-dependencies)
# Kết quả: $OUT/catnip-clang-ios-arm64.tar.z (tar GNU nén deflate thô, app tải về và giải nén).
# Chưa kiểm chứng: LLVM cho iOS tốn nhiều giờ; nếu lỗi thì sửa theo log.
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

# Lưu ý: dùng CMAKE_SYSTEM_NAME=Darwin (không phải iOS) vì LLVM chọn cờ linker theo tên 'Darwin';
# nếu để iOS, nó dùng cờ kiểu Linux (--whole-archive, -z defs...) và liên kết hỏng.
# 2) LLVM + Clang cho iOS arm64 (thư viện động libLLVM + libclang-cpp).
cmake -G Ninja -S "$SRC/llvm" -B "$OUT/build-ios" $LAUNCHER \
  -DCMAKE_BUILD_TYPE=MinSizeRel \
  -DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_CROSSCOMPILING=ON -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DLLVM_HOST_TRIPLE=arm64-apple-ios15.0 \
  -DCMAKE_INSTALL_PREFIX="$OUT/install" \
  -DLLVM_ENABLE_PROJECTS="clang" \
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
ls -lh "$OUT/pack/lib"

# 4) Header: resource của clang, sysroot iOS (usr/include có cả libc++), SDL3.
mkdir -p "$OUT/pack/sysroot/usr" "$OUT/pack/include"
mkdir -p "$OUT/pack/resource/lib"
cp -R "$OUT/build-ios/lib/clang" "$OUT/pack/resource/lib/clang"
cp -R "$SDK/usr/include" "$OUT/pack/sysroot/usr/include"
if [ -n "${SDL3_HEADERS:-}" ] && [ -d "$SDL3_HEADERS" ]; then cp -R "$SDL3_HEADERS" "$OUT/pack/include/SDL3"; fi

# 5) Đóng gói: tar GNU + deflate thô (Compression framework của app giải được).
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
