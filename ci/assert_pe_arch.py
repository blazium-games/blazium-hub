#!/usr/bin/env python3
"""Assert a Windows PE binary matches the expected Hub arch label (x86_32 / x86_64)."""

from __future__ import annotations

import struct
import sys
from pathlib import Path

IMAGE_FILE_MACHINE_I386 = 0x014C
IMAGE_FILE_MACHINE_AMD64 = 0x8664


def pe_machine(path: Path) -> int:
    data = path.read_bytes()
    if data[:2] != b"MZ":
        raise SystemExit(f"{path}: not a PE (missing MZ)")
    (e_lfanew,) = struct.unpack_from("<I", data, 0x3C)
    if data[e_lfanew : e_lfanew + 4] != b"PE\0\0":
        raise SystemExit(f"{path}: missing PE signature")
    (machine,) = struct.unpack_from("<H", data, e_lfanew + 4)
    return machine


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <path.exe> <x86_32|x86_64>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    want = sys.argv[2].strip()
    if not path.is_file():
        print(f"{path}: missing", file=sys.stderr)
        return 1
    machine = pe_machine(path)
    expected = {
        "x86_32": IMAGE_FILE_MACHINE_I386,
        "x86_64": IMAGE_FILE_MACHINE_AMD64,
    }.get(want)
    if expected is None:
        print(f"unknown arch label {want!r}", file=sys.stderr)
        return 2
    label = {IMAGE_FILE_MACHINE_I386: "x86_32", IMAGE_FILE_MACHINE_AMD64: "x86_64"}.get(
        machine, f"0x{machine:04x}"
    )
    print(f"{path}: PE machine={label} (0x{machine:04x}), expected {want}")
    if machine != expected:
        print(f"PE architecture mismatch: got {label}, want {want}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
