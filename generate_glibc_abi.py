#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.12"
# ///

# Generate glibc_abi.zig by querying symbol introduction versions
# from the abilists file shipped with the Zig toolchain.
#
# Usage:
#   python3 generate_glibc_abi.py [zig-lib-dir]
#   python3 generate_glibc_abi.py | zig fmt --stdin > glibc_abi.zig
#
# If zig-lib-dir is omitted, it is derived from `zig env`.

import struct
import subprocess
import sys
from pathlib import Path

# Symbols to track. Add any function here that C packages commonly check
# for availability; the script will look it up in the abilists and emit the
# glibc introduction version (or null if it is not in glibc at all).
SYMBOLS: list[str] = [
    # Entropy & randomness
    "arc4random",
    "arc4random_buf",
    "arc4random_uniform",
    "getentropy",
    "getrandom",
    # Memory
    "explicit_bzero",
    "reallocarray",
    # Strings
    "memmem",
    "strlcat",
    "strlcpy",
    "strchrnul",
    "strndup",
    "vasprintf",
    # File I/O
    "copy_file_range",
    "mkdtemp",
    "posix_fadvise",
    "posix_fallocate",
    "ppoll",
    "sync_file_range",
    "syncfs",
    # Networking
    "accept4",
    "getifaddrs",
    # System
    "getauxval",
    # Debugging
    "backtrace_symbols",
]


def get_zig_lib_dir() -> Path:
    result = subprocess.run(["zig", "env"], capture_output=True, text=True, check=True)
    for line in result.stdout.splitlines():
        if ".lib_dir" in line:
            return Path(line.split('"')[1])
    raise RuntimeError("lib_dir not found in `zig env` output")


def read_uleb128(data: bytes, i: int) -> tuple[int, int]:
    v, shift = 0, 0
    while True:
        b = data[i]
        i += 1
        v |= (b & 0x7F) << shift
        if not (b & 0x80):
            break
        shift += 7
    return v, i


def parse_abilists(path: Path) -> dict[str, dict[str, tuple[int, int, int]]]:
    """Parse the abilists binary file.

    Returns {symbol: {target_name: (major, minor, patch)}}.
    """
    data = path.read_bytes()
    i = 0

    # Skip libs section (count byte + null-terminated names)
    libs_len = data[i]
    i += 1
    for _ in range(libs_len):
        end = data.index(0, i)
        i = end + 1

    # Read versions array (count byte + 3-byte tuples)
    vers_len = data[i]
    i += 1
    versions: list[tuple[int, int, int]] = []
    for _ in range(vers_len):
        versions.append((data[i], data[i + 1], data[i + 2]))
        i += 3

    # Read target names (count byte + null-terminated "arch-linux-abi" strings)
    targets_len = data[i]
    i += 1
    targets: list[str] = []
    for _ in range(targets_len):
        end = data.index(0, i)
        targets.append(data[i:end].decode())
        i = end + 1

    # Parse function inclusions.
    #
    # Each symbol can span multiple consecutive entries (same name, different
    # target bitmasks); the last entry is marked with is_terminal. Versions
    # must be accumulated across *all* entries before picking the minimum.
    fn_count = struct.unpack_from("<H", data, i)[0]
    i += 2

    result: dict[str, dict[str, tuple[int, int, int]]] = {sym: {} for sym in SYMBOLS}
    current_sym: str | None = None
    target_vers: dict[int, list[tuple[int, int, int]]] = {}

    for _ in range(fn_count):
        # Symbol name only appears in the byte stream for the first entry.
        if current_sym is None:
            end = data.index(0, i)
            current_sym = data[i:end].decode()
            i = end + 1
            target_vers = {}

        targets_mask, i = read_uleb128(data, i)
        lib_byte = data[i]
        i += 1
        is_terminal = bool(lib_byte & 0x80)

        # Version bytes: lower 7 bits = version index, MSB = is-last flag.
        entry_vers: list[tuple[int, int, int]] = []
        while True:
            vb = data[i]
            i += 1
            entry_vers.append(versions[vb & 0x7F])
            if vb & 0x80:
                break

        for ti in range(len(targets)):
            if (targets_mask >> ti) & 1:
                target_vers.setdefault(ti, []).extend(entry_vers)

        if is_terminal:
            if current_sym in result:
                for ti, vers in target_vers.items():
                    result[current_sym][targets[ti]] = min(vers)
            current_sym = None

    return result


def arch_abi_from_target(target: str) -> tuple[str, str]:
    parts = target.split("-")
    return parts[0], parts[2]


def generate_fn(sym: str, target_versions: dict[str, tuple[int, int, int]]) -> list[str]:
    lines: list[str] = []
    lines.append(
        f"pub fn {sym}(arch: std.Target.Cpu.Arch, abi: std.Target.Abi) ?std.SemanticVersion {{"
    )

    if not target_versions:
        lines += ["    _ = arch;", "    _ = abi;", "    return null;", "}"]
        return lines

    arch_abi_vers: dict[tuple[str, str], tuple[int, int, int]] = {
        arch_abi_from_target(t): v for t, v in target_versions.items()
    }

    all_vers = list(arch_abi_vers.values())

    if len(set(all_vers)) == 1:
        v = all_vers[0]
        lines += [
            "    _ = arch;",
            "    _ = abi;",
            f"    return .{{ .major = {v[0]}, .minor = {v[1]}, .patch = {v[2]} }};",
            "}",
        ]
        return lines

    # Group by arch; check whether ABI distinctions are needed.
    arch_to_abi_vers: dict[str, dict[str, tuple[int, int, int]]] = {}
    for (arch, abi), ver in arch_abi_vers.items():
        arch_to_abi_vers.setdefault(arch, {})[abi] = ver

    need_abi_switch = any(
        len(set(abi_map.values())) > 1 for abi_map in arch_to_abi_vers.values()
    )

    if not need_abi_switch:
        lines.append("    _ = abi;")
        # Group arches that share the same single version.
        ver_to_arches: dict[tuple[int, int, int], list[str]] = {}
        for arch, abi_map in arch_to_abi_vers.items():
            (ver,) = set(abi_map.values())
            ver_to_arches.setdefault(ver, []).append(arch)

        lines.append("    return switch (arch) {")
        for ver, arches in sorted(ver_to_arches.items()):
            tag_list = ", ".join(f".{a}" for a in sorted(arches))
            lines.append(
                f"        {tag_list} => .{{ .major = {ver[0]}, .minor = {ver[1]}, .patch = {ver[2]} }},"
            )
        lines += ["        else => null,", "    };", "}"]
    else:
        lines.append("    return switch (arch) {")
        for arch, abi_map in sorted(arch_to_abi_vers.items()):
            vers_set = set(abi_map.values())
            if len(vers_set) == 1:
                (v,) = vers_set
                lines.append(
                    f"        .{arch} => .{{ .major = {v[0]}, .minor = {v[1]}, .patch = {v[2]} }},"
                )
            else:
                lines.append(f"        .{arch} => switch (abi) {{")
                for a, v in sorted(abi_map.items()):
                    lines.append(
                        f"            .{a} => .{{ .major = {v[0]}, .minor = {v[1]}, .patch = {v[2]} }},"
                    )
                lines += ["            else => null,", "        },"]
        lines += ["        else => null,", "    };", "}"]

    return lines


def main() -> None:
    lib_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else get_zig_lib_dir()
    symbol_data = parse_abilists(lib_dir / "libc" / "glibc" / "abilists")

    print("// Generated by generate_glibc_abi.py — do not edit.")
    print("// Regenerate with: python3 generate_glibc_abi.py | zig fmt --stdin > glibc_abi.zig")
    print("//")
    print("// Each function returns the minimum glibc version that introduced the symbol")
    print("// for a given (arch, abi) target, or null if not available in glibc.")
    print()
    print('const std = @import("std");')
    print()

    for sym in sorted(SYMBOLS):
        for line in generate_fn(sym, symbol_data[sym]):
            print(line)
        print()


if __name__ == "__main__":
    main()
