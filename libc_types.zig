//! Detect which optional types and struct fields are present in libc for a given target.
//!
//! Covers typedef availability (HAVE_<TYPE>) and struct field presence (HAVE_STRUCT_*).
//!
//! Usage from build.zig:
//!   const types = @import("libc_types.zig").detect(target.result);
//!   if (types.struct_tm_tm_zone) { ... }

const std = @import("std");

pub const LibcTypes = struct {
    // Availability reference:
    //
    // sa_family_t:             POSIX.1-2001 (all POSIX targets including WASI; not Windows)
    // socklen_t:               POSIX.1-2001 (all supported targets including WASI; Windows via ws2tcpip.h)
    // struct sockaddr.sa_len:  BSDs, macOS (not Linux/Windows/WASI — explicit length passed separately)
    // struct sockaddr_storage: RFC 3493, POSIX.1-2001 (all named targets; Windows via winsock2.h; WASI)
    // struct timeval:          4.2BSD, POSIX.1 (all named targets; Windows via sys/time.h or winsock2.h;
    //                          note: Windows uses long fields, not time_t/suseconds_t)
    // struct tm.tm_zone:       BSD/glibc extension (all POSIX targets; not Windows/WASI;
    //                          requires _GNU_SOURCE or _BSD_SOURCE on glibc/musl)
    // suseconds_t:             POSIX.1-2001 (all POSIX targets including WASI; not Windows)

    sa_family_t: bool = true,
    socklen_t: bool = true,
    struct_sockaddr_sa_len: bool = false,
    struct_sockaddr_storage: bool = true,
    struct_timeval: bool = true,
    /// struct tm { tm_zone }
    struct_tm_tm_zone: bool = true,
    suseconds_t: bool = true,
};

pub fn detect(target: std.Target) LibcTypes {
    return switch (target.os.tag) {
        .macos,
        .ios,
        .tvos,
        .watchos,
        .visionos,
        .freebsd,
        .openbsd,
        .netbsd,
        .dragonfly,
        => .{ .struct_sockaddr_sa_len = true },
        .linux => .{},
        // WASI has sa_family_t, socklen_t, suseconds_t typedefs; struct tm uses __tm_zone (not tm_zone)
        .wasi => .{ .struct_tm_tm_zone = false },
        .windows => .{ .sa_family_t = false, .struct_tm_tm_zone = false, .suseconds_t = false },
        else => .{ .sa_family_t = false, .socklen_t = false, .struct_tm_tm_zone = false, .suseconds_t = false },
    };
}
