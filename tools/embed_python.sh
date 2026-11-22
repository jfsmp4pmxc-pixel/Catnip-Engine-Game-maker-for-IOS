#!/usr/bin/env bash
# Chép thư viện chuẩn Python vào bản .app: <app>/python/lib/python3.X (+ lib-dynload của thiết bị).
# Dùng: tools/embed_python.sh <đường dẫn Catnip.app> [thư mục python-support]
set -euo pipefail
APP="$1"
SUP="${2:-$PWD/python-support}"
XC="$SUP/Python.xcframework"
test -d "$XC" || { echo "❌ Không có $XC"; exit 1; }

# Thư viện chuẩn: thư mục lib/python3.X có os.py (chung cho mọi slice).
OSPY=$(find "$XC" -path '*/lib/python3*/os.py' -not -path '*simulator*' | head -1)
[ -n "$OSPY" ] || OSPY=$(find "$XC" -path '*/lib/python3*/os.py' | head -1)
[ -n "$OSPY" ] || { echo "❌ Không thấy os.py trong xcframework"; find "$XC" -maxdepth 4; exit 1; }
STD=$(dirname "$OSPY"); NAME=$(basename "$STD")
DEST="$APP/python/lib/$NAME"
echo "== stdlib: $STD -> $DEST"
mkdir -p "$DEST"
rsync -a --exclude '__pycache__' --exclude 'test' --exclude 'tests' --exclude 'idlelib' --exclude 'tkinter' \
  --exclude 'turtledemo' --exclude 'turtle.py' --exclude 'ensurepip' --exclude 'lib2to3' --exclude 'site-packages' "$STD/" "$DEST/"
mkdir -p "$DEST/site-packages"

# Module nhị phân (lib-dynload) của thiết bị (không lấy simulator).
DYN=$(find "$XC" -type d -name lib-dynload -not -path '*simulator*' | head -1)
if [ -n "$DYN" ]; then
  echo "== lib-dynload: $DYN"
  mkdir -p "$DEST/lib-dynload"
  rsync -a "$DYN/" "$DEST/lib-dynload/"
else
  echo "⚠️ Không thấy lib-dynload cho thiết bị (một số module chuẩn có thể thiếu)"
fi
du -sh "$APP/python"
ls "$DEST/lib-dynload" 2>/dev/null | head -20 || true
