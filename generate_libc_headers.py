#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.12"
# ///

# Generate libc_headers.zig by checking which headers Zig bundles for each target.
# Darwin and DragonFly are hardcoded since Zig does not bundle their complete SDK headers.
#
# Usage:
#   python3 generate_libc_headers.py [zig-lib-dir]
#   python3 generate_libc_headers.py | zig fmt --stdin > libc_headers.zig
#
# If zig-lib-dir is omitted, it is derived from `zig env`.

import subprocess
import sys
from pathlib import Path

# Headers to track. Add any header a C package commonly probes for.
HEADERS: list[str] = [
    "arpa/inet.h",
    "atomic.h",
    "copyfile.h",
    "crtdefs.h",
    "execinfo.h",
    "fcntl.h",
    "getopt.h",
    "ifaddrs.h",
    "inttypes.h",
    "linux/tcp.h",
    "memory.h",
    "net/if.h",
    "netdb.h",
    "netinet/in.h",
    "netinet/tcp.h",
    "netinet/udp.h",
    "poll.h",
    "pwd.h",
    "stdint.h",
    "stdlib.h",
    "string.h",
    "strings.h",
    "sys/epoll.h",
    "sys/event.h",
    "sys/eventfd.h",
    "sys/filio.h",
    "sys/ioctl.h",
    "sys/personality.h",
    "sys/prctl.h",
    "sys/procctl.h",
    "sys/resource.h",
    "sys/select.h",
    "sys/signalfd.h",
    "sys/sockio.h",
    "sys/stat.h",
    "sys/types.h",
    "sys/ucred.h",
    "sys/un.h",
    "termios.h",
    "unistd.h",
    "uuid.h",
    "uuid/uuid.h",
    "xlocale.h",
]

# Version-gated headers: present on the OS but only from a given release.
# {os_key: {header: (major, minor, patch, man_url)}}
VERSION_GATES: dict[str, dict[str, tuple[int, int, int, str]]] = {
    "freebsd": {
        "sys/procctl.h": (
            10, 1, 0,
            "https://man.freebsd.org/cgi/man.cgi?query=procctl&sektion=2",
        ),
    },
}

# Linux kernel headers in any-linux-any/ (not in per-ABI generic-glibc/ or musl/include/).
LINUX_EXTRA_HEADERS: frozenset[str] = frozenset({
    "linux/tcp.h",
})

# Darwin: Zig does not bundle the macOS SDK — hardcoded from known SDK contents.
DARWIN_HEADERS: frozenset[str] = frozenset({
    "arpa/inet.h", "copyfile.h", "execinfo.h", "fcntl.h", "getopt.h", "ifaddrs.h",
    "inttypes.h", "memory.h", "net/if.h", "netdb.h", "netinet/in.h", "netinet/tcp.h",
    "netinet/udp.h", "poll.h", "pwd.h", "stdint.h", "stdlib.h", "string.h", "strings.h",
    "sys/event.h", "sys/filio.h", "sys/ioctl.h", "sys/resource.h", "sys/select.h",
    "sys/sockio.h", "sys/stat.h", "sys/types.h", "sys/ucred.h", "sys/un.h", "termios.h",
    "unistd.h", "uuid/uuid.h", "xlocale.h",
})

# DragonFly: Zig has no bundled headers — hardcoded.
DRAGONFLY_HEADERS: frozenset[str] = frozenset({
    "arpa/inet.h", "execinfo.h", "fcntl.h", "getopt.h", "ifaddrs.h", "inttypes.h",
    "memory.h", "net/if.h", "netdb.h", "netinet/in.h", "netinet/tcp.h", "netinet/udp.h",
    "poll.h", "pwd.h", "stdint.h", "stdlib.h", "string.h", "strings.h", "sys/event.h",
    "sys/filio.h", "sys/ioctl.h", "sys/resource.h", "sys/select.h", "sys/sockio.h",
    "sys/stat.h", "sys/types.h", "sys/ucred.h", "sys/un.h", "termios.h", "unistd.h",
    "uuid.h",
})

# Windows (mingw64): scanned from Zig's bundled any-windows-any headers.
WINDOWS_HEADERS: frozenset[str] = frozenset({
    "crtdefs.h", "fcntl.h", "getopt.h", "inttypes.h", "memory.h", "stdint.h", "stdlib.h",
    "string.h", "strings.h", "sys/stat.h", "sys/types.h", "unistd.h",
})

OS_DISPLAY: dict[str, str] = {
    "glibc":     "glibc",
    "musl":      "musl",
    "freebsd":   "FreeBSD",
    "netbsd":    "NetBSD",
    "openbsd":   "OpenBSD",
    "darwin":    "macOS",
    "dragonfly": "DragonFly",
    "windows":   "Windows (mingw64)",
}


def get_zig_lib_dir() -> Path:
    result = subprocess.run(["zig", "env"], capture_output=True, text=True, check=True)
    for line in result.stdout.splitlines():
        if ".lib_dir" in line:
            return Path(line.split('"')[1])
    raise RuntimeError("lib_dir not found in `zig env` output")


def scan(directory: Path) -> frozenset[str]:
    return frozenset(h for h in HEADERS if (directory / h).exists())


def field(header: str) -> str:
    return header.replace("/", "_").replace(".", "_")


def emit_linux(
    glibc: frozenset[str],
    musl: frozenset[str],
    always_present: frozenset[str],
) -> list[str]:
    lines = ["fn detectLinux(target: std.Target) LibcHeaders {", "    return .{"]
    for h in sorted(HEADERS):
        if h in always_present:
            continue
        f = field(h)
        in_g, in_m = h in glibc, h in musl
        if in_g and in_m:
            lines.append(f"        .{f} = true,")
        elif in_g:
            lines.append(f"        .{f} = !target.abi.isMusl(),")
        elif in_m:
            lines.append(f"        .{f} = target.abi.isMusl(),")
    lines += ["    };", "}"]
    return lines


def emit_fn(
    name: str,
    os_key: str,
    os_headers: frozenset[str],
    always_present: frozenset[str],
) -> list[str]:
    gates = VERSION_GATES.get(os_key, {})
    needs_target = bool(gates)
    param = "target: std.Target" if needs_target else ""
    lines = [f"fn {name}({param}) LibcHeaders {{", "    return .{"]
    for h in sorted(HEADERS):
        f = field(h)
        if h in gates:
            major, minor, patch, url = gates[h]
            lines.append(
                f"        .{f} = gte(target.os, .{os_key},"
                f" .{{ .major = {major}, .minor = {minor}, .patch = {patch} }}),"
                f" // {url}"
            )
        elif h in os_headers and h not in always_present:
            lines.append(f"        .{f} = true,")
        elif h not in os_headers and h in always_present:
            lines.append(f"        .{f} = false,")
    lines += ["    };", "}"]
    return lines


def main() -> None:
    lib_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else get_zig_lib_dir()
    inc = lib_dir / "libc" / "include"

    target_headers: dict[str, frozenset[str]] = {
        "glibc":     scan(inc / "generic-glibc") | LINUX_EXTRA_HEADERS,
        "musl":      scan(lib_dir / "libc" / "musl" / "include") | LINUX_EXTRA_HEADERS,
        "freebsd":   scan(inc / "generic-freebsd"),
        "netbsd":    scan(inc / "generic-netbsd"),
        "openbsd":   scan(inc / "generic-openbsd"),
        "darwin":    DARWIN_HEADERS,
        "dragonfly": DRAGONFLY_HEADERS,
        "windows":   WINDOWS_HEADERS,
    }

    always_present = frozenset(
        h for h in HEADERS if all(h in hs for hs in target_headers.values())
    )
    os_specific = frozenset(HEADERS) - always_present

    print("// Generated by generate_libc_headers.py — do not edit.")
    print("// Regenerate with: python3 generate_libc_headers.py | zig fmt --stdin > libc_headers.zig")
    print("//")
    print("// Headers that are universally available on all supported POSIX targets default")
    print("// to true and are listed once. Headers whose presence varies by OS default to")
    print("// false and are set explicitly in each per-OS detection function.")
    print()
    print('const std = @import("std");')
    print()

    # Struct
    print("pub const LibcHeaders = struct {")
    print("    // Availability reference:")
    print("    //")
    os_order = list(OS_DISPLAY.keys())
    for h in sorted(HEADERS):
        present_in = [OS_DISPLAY[o] for o in os_order if h in target_headers[o]]
        gates = VERSION_GATES.get
        note: str
        if len(present_in) == len(os_order):
            note = "all supported targets"
        elif present_in:
            note = ", ".join(present_in)
            # Annotate version gates
            for os_key, g in VERSION_GATES.items():
                if h in g:
                    major, minor, patch, _ = g[h]
                    note = note.replace(
                        OS_DISPLAY[os_key],
                        f"{OS_DISPLAY[os_key]} {major}.{minor}+",
                    )
        else:
            note = "none"
        print(f"    // {h + ':':<22} {note}")

    print()
    print("    // Always present")
    for h in sorted(always_present):
        print(f"    {field(h)}: bool = true,")
    print()
    print("    // OS-specific")
    for h in sorted(os_specific):
        print(f"    {field(h)}: bool = false,")
    print("};")
    print()

    # detect() dispatcher
    print("pub fn detect(target: std.Target) LibcHeaders {")
    print("    return switch (target.os.tag) {")
    print("        .linux => detectLinux(target),")
    print("        .macos, .ios, .tvos, .watchos, .visionos => detectDarwin(),")
    print("        .freebsd => detectFreeBSD(target),")
    print("        .openbsd => detectOpenBSD(),")
    print("        .netbsd => detectNetBSD(),")
    print("        .dragonfly => detectDragonFly(),")
    print("        .windows => detectWindows(),")
    print("        else => .{")
    for h in sorted(always_present):
        print(f"            .{field(h)} = false,")
    print("        },")
    print("    };")
    print("}")
    print()

    print("// ── Linux ─────────────────────────────────────────────────────────────────────")
    print()
    for line in emit_linux(target_headers["glibc"], target_headers["musl"], always_present):
        print(line)
    print()

    print("// ── Darwin ────────────────────────────────────────────────────────────────────")
    print()
    for line in emit_fn("detectDarwin", "darwin", DARWIN_HEADERS, always_present):
        print(line)
    print()

    print("// ── BSDs ──────────────────────────────────────────────────────────────────────")
    print()
    if any(VERSION_GATES.values()):
        print("fn gte(os: std.Target.Os, comptime tag: std.Target.Os.Tag, ver: std.SemanticVersion) bool {")
        print("    return os.isAtLeast(tag, ver) orelse false;")
        print("}")
        print()

    for fn_name, os_key, os_hdrs in [
        ("detectFreeBSD",  "freebsd",  target_headers["freebsd"]),
        ("detectOpenBSD",  "openbsd",  target_headers["openbsd"]),
        ("detectNetBSD",   "netbsd",   target_headers["netbsd"]),
        ("detectDragonFly","dragonfly", DRAGONFLY_HEADERS),
    ]:
        for line in emit_fn(fn_name, os_key, os_hdrs, always_present):
            print(line)
        print()

    print("// ── Windows (mingw64) ─────────────────────────────────────────────────────────")
    print()
    for line in emit_fn("detectWindows", "windows", WINDOWS_HEADERS, always_present):
        print(line)
    print()


if __name__ == "__main__":
    main()
