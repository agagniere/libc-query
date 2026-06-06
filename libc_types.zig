//! Detect which optional struct fields are present in libc for a given target.
//!
//! These are non-standard extensions to standard C types — their presence
//! varies by OS and is probed by autoconf as HAVE_STRUCT_*.
//!
//! Usage from build.zig:
//!   const types = @import("libc_types.zig").detect(target.result);
//!   if (types.struct_tm_tm_zone) { ... }

const std = @import("std");

pub const LibcTypes = struct {
    // Availability reference:
    //
    // struct sockaddr.sa_len: BSDs, macOS (not Linux — Linux uses sa_family + explicit length)
    // struct tm.tm_zone:      BSD/glibc extension (ubiquitous on supported targets;
    //                         requires _GNU_SOURCE or _BSD_SOURCE on glibc/musl)

    struct_sockaddr_sa_len: bool = false,
    struct_tm_tm_zone: bool = true,
};

pub fn detect(target: std.Target) LibcTypes {
    return switch (target.os.tag) {
        .macos, .ios, .tvos, .watchos, .visionos,
        .freebsd, .openbsd, .netbsd, .dragonfly,
        => .{ .struct_sockaddr_sa_len = true },
        .linux => .{},
        else => .{ .struct_tm_tm_zone = false },
    };
}
