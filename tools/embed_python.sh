#!/usr/bin/env bash
# Chép thư viện chuẩn Python vào bản .app: <app>/python/lib/python3.X (+ lib-dynload của thiết bị).
# Dùng: tools/embed_python.sh <đường dẫn Catnip.app> [thư mục python-support]
set -euo pipefail
APP="$1"
SUP="${2:-$PWD/python-support}"
XC="$SUP/Python.xcframework"
test -d "$XC" || { echo "❌ Không có $XC"; exit 1; }

# Thư viện chuẩn: thư mục lib/python3.X có os.py (chung cho mọi slice).
OSPY=$(find "$XC" -path '*/lib/python3*/os.py' -not -path '*simulator*' | sed -n 1p)
[ -n "$OSPY" ] || OSPY=$(find "$XC" -path '*/lib/python3*/os.py' | sed -n 1p)
[ -n "$OSPY" ] || { echo "❌ Không thấy os.py trong xcframework"; find "$XC" -maxdepth 4; exit 1; }
STD=$(dirname "$OSPY"); NAME=$(basename "$STD")
DEST="$APP/python/lib/$NAME"
echo "== stdlib: $STD -> $DEST"
mkdir -p "$DEST"
rsync -a --exclude '__pycache__' --exclude 'test' --exclude 'tests' --exclude 'idlelib' --exclude 'tkinter' \
  --exclude 'turtledemo' --exclude 'turtle.py' --exclude 'ensurepip' --exclude 'lib2to3' --exclude 'site-packages' "$STD/" "$DEST/"
mkdir -p "$DEST/site-packages"

# Module nhị phân (lib-dynload) của thiết bị (không lấy simulator).
DYN=$(find "$XC" -type d -name lib-dynload -not -path '*simulator*' | sed -n 1p)
if [ -n "$DYN" ]; then
  echo "== lib-dynload: $DYN"
  mkdir -p "$DEST/lib-dynload"
  rsync -a "$DYN/" "$DEST/lib-dynload/"
else
  echo "⚠️ Không thấy lib-dynload cho thiết bị (một số module chuẩn có thể thiếu)"
fi
du -sh "$APP/python"
ls "$DEST/lib-dynload" 2>/dev/null | sed -n 1,20p || true

# Thư viện bên thứ ba (wheel iOS arm64 của BeeWare) → site-packages. Biến PYTHON_PACKAGES, ví dụ "numpy pillow".
if [ -n "${PYTHON_PACKAGES:-}" ]; then
  PYVER="${NAME#python}"   # 3.13
  PYTAG="${PYVER/./}"
  WH="$(mktemp -d)"
  echo "== pip download: $PYTHON_PACKAGES (cp$PYTAG, ios_13_0_arm64_iphoneos)"
  # shellcheck disable=SC2086
  python3 -m pip download $PYTHON_PACKAGES -d "$WH" \
    --platform ios_13_0_arm64_iphoneos --python-version "$PYVER" --implementation cp --abi "cp$PYTAG" \
    --only-binary=:all: --extra-index-url https://pypi.anaconda.org/beeware/simple \
    || { echo "❌ Không tải được wheel iOS cho: $PYTHON_PACKAGES"; exit 1; }
  for w in "$WH"/*.whl; do
    echo "  + $(basename "$w")"
    unzip -q -o "$w" -d "$DEST/site-packages"
  done
  # Dọn bớt: test, __pycache__, dist-info không cần
  find "$DEST/site-packages" -type d \( -name tests -o -name test -o -name __pycache__ \) -prune -exec rm -rf {} + 2>/dev/null || true
  # Ký ad-hoc các .so/.dylib (iOS không nạp mã nhị phân chưa ký)
  find "$DEST/site-packages" \( -name '*.so' -o -name '*.dylib' \) -print0 | while IFS= read -r -d '' f; do
    codesign --force --sign - "$f" 2>/dev/null || echo "⚠️ không ký được $f"
  done
  du -sh "$DEST/site-packages"
fi
