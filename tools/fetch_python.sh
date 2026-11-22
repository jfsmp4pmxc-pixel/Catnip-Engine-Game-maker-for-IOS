#!/usr/bin/env bash
# Tải gói CPython cho iOS (BeeWare Python-Apple-support) vào $OUT (mặc định python-support/).
# Cần: gh (có GH_TOKEN), tar. Biến: PY_VERSION (mặc định 3.13).
set -euo pipefail
OUT="${OUT:-$PWD/python-support}"
VER="${PY_VERSION:-3.13}"
mkdir -p "$OUT"
echo "== Tìm gói Python-${VER}-iOS-support mới nhất"
URL=$(gh api "repos/beeware/Python-Apple-support/releases?per_page=30" \
  --jq "[.[] | .assets[] | select(.name | test(\"^Python-${VER}-iOS-support.*\\\\.tar\\\\.gz\$\"))][0].browser_download_url")
if [ -z "$URL" ] || [ "$URL" = "null" ]; then
  echo "❌ Không tìm thấy asset Python-${VER}-iOS-support*.tar.gz. Các asset iOS hiện có:"
  gh api "repos/beeware/Python-Apple-support/releases?per_page=5" --jq '.[] | .tag_name as $t | .assets[] | select(.name|test("iOS")) | "\($t) \(.name)"'
  exit 1
fi
echo "URL: $URL"
curl -fsSL "$URL" -o "$OUT/support.tar.gz"
tar -xzf "$OUT/support.tar.gz" -C "$OUT"
rm -f "$OUT/support.tar.gz"
test -d "$OUT/Python.xcframework" || { echo "❌ Thiếu Python.xcframework sau khi giải nén:"; ls -la "$OUT"; exit 1; }
echo "== Cấu trúc Python.xcframework"
find "$OUT/Python.xcframework" -maxdepth 3 | head -40
