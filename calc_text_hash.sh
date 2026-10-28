#!/bin/bash
set -e

DYLIB="${1:-.theos/obj/arm64/Tanhdzcute.dylib}"
MM="${2:-Esp/AntiAll.mm}"

if [ ! -f "$DYLIB" ]; then
    echo "[hash] Không thấy $DYLIB"
    exit 1
fi

# Parse Mach-O trực tiếp bằng Python (không phụ thuộc otool/llvm-objdump)
RESULT=$(python3 - "$DYLIB" <<'PY'
import sys, struct, hashlib

path = sys.argv[1]
data = open(path, "rb").read()

magic = struct.unpack_from("<I", data, 0)[0]
if magic != 0xFEEDFACF:
    print("ERR magic=0x%X" % magic)
    sys.exit(1)

ncmds = struct.unpack_from("<I", data, 16)[0]
off = 32  # sizeof(mach_header_64)

text_off = None
text_size = None

for _ in range(ncmds):
    cmd, cmdsize = struct.unpack_from("<II", data, off)
    if cmd == 0x19:  # LC_SEGMENT_64
        segname = data[off+8:off+24].rstrip(b'\0').decode('latin1')
        nsects = struct.unpack_from("<I", data, off+64)[0]
        sect_off = off + 72
        for _ in range(nsects):
            sectname = data[sect_off:sect_off+16].rstrip(b'\0').decode('latin1')
            segn     = data[sect_off+16:sect_off+32].rstrip(b'\0').decode('latin1')
            addr, size = struct.unpack_from("<QQ", data, sect_off+32)
            offset     = struct.unpack_from("<I", data, sect_off+48)[0]
            if segn == "__TEXT" and sectname == "__text":
                text_off = offset
                text_size = size
            sect_off += 80
    off += cmdsize

if text_off is None or text_size is None:
    print("ERR no __text")
    sys.exit(1)

chunk = data[text_off:text_off+text_size]
h = hashlib.sha256(chunk).digest()
print("OFF=%d SIZE=%d" % (text_off, text_size))
print("HASH=" + ",".join("0x%02X" % b for b in h))
PY
)

echo "$RESULT"

HASH=$(echo "$RESULT" | grep "^HASH=" | cut -d= -f2)
if [ -z "$HASH" ]; then
    echo "[hash] Không tính được hash"
    exit 1
fi

# Cập nhật kTextHash trong AntiAll.mm
python3 - "$MM" "$HASH" <<'PY'
import sys, re
mm, hash_str = sys.argv[1], sys.argv[2]
src = open(mm, "r").read()

pat = re.compile(r"(kTextHash\[32\]\s*=\s*\{)([^}]*)(\};)", re.S)
def repl(m):
    parts = hash_str.split(",")
    lines = []
    for i in range(0, 32, 8):
        lines.append("    " + ",".join(parts[i:i+8]) + ("," if i < 24 else ""))
    body = "\n" + "\n".join(lines) + "\n"
    return m.group(1) + body + m.group(3)

new = pat.sub(repl, src, count=1)
if new == src:
    print("[hash] Không match kTextHash")
    sys.exit(1)
open(mm, "w").write(new)
print("[hash] Đã cập nhật %s" % mm)
PY