#!/bin/bash
# Build lõi iSH (Linux x86 usermode emulator) thành thư viện tĩnh cho iOS, và tải rootfs Alpine.
# Dùng trong CI (macOS). Kết quả nằm ở $OUT (mặc định ish-core/):
#   ish-core/lib/{libish.a,libish_emu.a,libfakefs.a,libarchive.a}
#   ish-core/Resources/           root.tar.gz (rootfs Alpine của iSH) + repositories.txt (kho apk, cùng cách iSH tạo)
#   ish-core/ish/                 mã nguồn iSH (cần header để biên dịch cầu nối)
# iSH: GPL-3.0 (kèm LICENSE.IOS), https://github.com/ish-app/ish
set -euo pipefail

ISH_REF="${ISH_REF:?cần ISH_REF}"
OUT="${OUT:-$PWD/ish-core}"
SRC="$OUT/ish"
BUILD="$OUT/build"
mkdir -p "$OUT/lib"

echo "::group::Fetch iSH $ISH_REF"
rm -rf "$SRC"
git init -q "$SRC"
git -C "$SRC" remote add origin https://github.com/ish-app/ish
git -C "$SRC" fetch -q --depth 1 origin "$ISH_REF"
git -C "$SRC" checkout -q FETCH_HEAD
# Chỉ cần libarchive (đọc rootfs .tar.gz). Không lấy linux kernel hay hterm.
git -C "$SRC" submodule update --init --depth 1 deps/libarchive
echo "::endgroup::"

echo "::group::Install build tools"
brew install llvm lld ninja meson libarchive || true
echo "::endgroup::"

COMMON=(-configuration Release -sdk iphoneos -arch arm64
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="")

echo "::group::Build libish / libish_emu / libfakefs"
xcodebuild -project "$SRC/iSH.xcodeproj" \
    -target libish -target libish_emu -target libfakefs \
    "${COMMON[@]}" SYMROOT="$BUILD/ish" build 2>&1 | tee "$OUT/ish-build.log" | tail -n 40
echo "::endgroup::"

echo "::group::Build libarchive"
xcodebuild -project "$SRC/deps/libarchive.xcodeproj" \
    -target libarchive \
    "${COMMON[@]}" SYMROOT="$BUILD/archive" build 2>&1 | tee "$OUT/archive-build.log" | tail -n 40
echo "::endgroup::"

echo "::group::Collect libraries"
for name in libish.a libish_emu.a libfakefs.a libarchive.a; do
    found=$(find "$BUILD" -name "$name" -not -path "*/Intermediates*" | head -n 1)
    if [ -z "$found" ]; then
        echo "❌ Không tìm thấy $name"; find "$BUILD" -name "*.a" | head -n 40; exit 1
    fi
    cp "$found" "$OUT/lib/$name"
    echo "✅ $name  ($(du -h "$OUT/lib/$name" | cut -f1))"
    lipo -info "$OUT/lib/$name" || true
done
echo "::endgroup::"

echo "::group::Rootfs + apk repositories"
ROOTFS_URL=$(sed -n 's/^ROOTFS_URL *= *//p' "$SRC/app/iSH.xcconfig" | head -n 1)
test -n "$ROOTFS_URL"
echo "ROOTFS_URL=$ROOTFS_URL"
curl -fL --retry 3 "https://$ROOTFS_URL" -o "$OUT/root.tar.gz"
ls -lh "$OUT/root.tar.gz"
# Giống app/gen_apk_repositories.py nhưng ghi ra file cố định.
SRCROOT="$SRC" BUILT_PRODUCTS_DIR="$OUT" CONTENTS_FOLDER_PATH="." python3 "$SRC/app/gen_apk_repositories.py"
cat "$OUT/repositories.txt"
echo "::endgroup::"

# Tài nguyên đóng vào app (Catnip tìm theo tên: root.tar.gz, repositories.txt)
mkdir -p "$OUT/Resources"
cp "$OUT/root.tar.gz" "$OUT/repositories.txt" "$OUT/Resources/"

# Giữ lại giấy phép
cp "$SRC/LICENSE.md" "$SRC/LICENSE.IOS" "$OUT/" 2>/dev/null || true
echo "✅ Xong: $OUT"
