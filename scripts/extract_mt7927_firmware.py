#!/usr/bin/env python3
import os
import struct
import sys

BLOBS = [
    "BT_RAM_CODE_MT6639_2_1_hdr.bin",
    "WIFI_MT6639_PATCH_MCU_2_1_hdr.bin",
    "WIFI_RAM_CODE_MT6639_2_1.bin",
]

def extract_blob(data: bytes, name: str, outdir: str) -> None:
    key = name.encode()
    idx = data.find(key)
    if idx < 0:
        raise RuntimeError(f"Blob not found: {name}")

    pos = idx + len(key)
    while pos < len(data) and data[pos] == 0:
        pos += 1

    if pos + 14 < len(data) and all(48 <= b <= 57 for b in data[pos:pos + 14]):
        pos += 14

    pos = (pos + 3) & ~3
    off = struct.unpack_from("<I", data, pos)[0]
    size = struct.unpack_from("<I", data, pos + 4)[0]
    blob = data[off:off + size]

    if len(blob) != size:
        raise RuntimeError(f"Size mismatch for {name}: expected {size}, got {len(blob)}")

    os.makedirs(outdir, exist_ok=True)
    out = os.path.join(outdir, name)
    with open(out, "wb") as f:
        f.write(blob)
    print(f"extracted {name} -> {out}")

def main() -> int:
    if len(sys.argv) != 3:
        print("usage: extract_mt7927_firmware.py <mtkwlan.dat> <output_dir>")
        return 1

    dat_path, outdir = sys.argv[1], sys.argv[2]
    with open(dat_path, "rb") as f:
        data = f.read()

    for name in BLOBS:
        extract_blob(data, name, outdir)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
