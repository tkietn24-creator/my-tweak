#!/bin/bash
# Chạy script này TRÊN MÁY BUILD (có toolchain) để xem breakdown size

echo "=== 1. Check IMGUI folder contents (tìm imgui_demo.cpp) ==="
ls -la IMGUI/*.cpp IMGUI/*.mm 2>/dev/null

echo ""
echo "=== 2. Size của static lib Dobby ==="
ls -la Other/libdobby_fixed.a 2>/dev/null
size Other/libdobby_fixed.a 2>/dev/null

echo ""
echo "=== 3. Sau khi build xong, breakdown symbol theo size ==="
echo "Chạy: nm -S --size-sort -C .theos/obj/debug/*.dylib | tail -30"
echo "hoặc: nm -S --size-sort -C YourTweak.dylib | tail -30"

echo ""
echo "=== 4. So sánh trước/sau strip ==="
echo "ls -la YourTweak.dylib"
echo "strip -x -S YourTweak.dylib"
echo "ls -la YourTweak.dylib"

echo ""
echo "=== 5. lipo info (kiểm tra có dư arch không) ==="
echo "lipo -info YourTweak.dylib"