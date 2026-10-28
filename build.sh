#!/bin/bash
# build.sh — Build VNTOOL.dylib + tự động ghi hash toàn file
# Chạy: chmod +x build.sh && ./build.sh

set -e

# ─── Cấu hình ───
OUTPUT_NAME="VNTOOL.dylib"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "════════════════════════════════════════"
echo "  🔨 BUILD VNTOOL"
echo "════════════════════════════════════════"
echo ""

# ─── Bước 1: Build ───
echo "[1/3] Đang build..."
make clean > /dev/null 2>&1
make 2>&1 | tail -5

# Tìm file dylib output
DY=$(find .theos/obj -name "*.dylib" -type f | head -1)
if [ -z "$DY" ]; then
    echo "❌ Không tìm thấy file .dylib sau khi build"
    exit 1
fi
echo "    ✓ Built: $DY"

# ─── Bước 2: Copy ra ngoài ───
echo ""
echo "[2/3] Copy ra $OUTPUT_NAME..."
cp "$DY" "./$OUTPUT_NAME"
SIZE=$(stat -c%s "./$OUTPUT_NAME" 2>/dev/null || stat -f%z "./$OUTPUT_NAME")
echo "    ✓ Size: $SIZE bytes"

# ─── Bước 3: Ghi hash vào file ───
echo ""
echo "[3/3] Ghi hash toàn file..."
if [ ! -f "tools/gen_hash.py" ]; then
    echo "❌ Không tìm thấy tools/gen_hash.py"
    exit 1
fi
python3 tools/gen_hash.py "./$OUTPUT_NAME"

# ─── Xong ───
echo ""
echo "════════════════════════════════════════"
echo "  ✅ XONG: ./$OUTPUT_NAME"
echo "════════════════════════════════════════"
echo ""
echo "Bước tiếp theo — cài lên iPhone:"
echo "  scp ./$OUTPUT_NAME root@<IP>:/Library/MobileSubstrate/DynamicLibraries/"
echo "  ssh root@<IP> killall -9 PUBG"
echo ""