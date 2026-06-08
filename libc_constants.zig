//! Detect which optional libc constants and macros are declared for a given target.
//!
//! These are probed by autoconf as HAVE_DECL_* or HAVE_<CONSTANT>.
//!
//! Usage from build.zig:
//!   const constants = @import("libc_constants.zig").detect(target.result);
//!   if (constants.f_fullfsync) { ... }

const std = @import("std");

pub const LibcConstants = struct {
    // Availability reference:
    //
    // CLOCK_MONOTONIC:     POSIX.1-2001 (all POSIX targets including WASI; not Windows)
    // CLOCK_MONOTONIC_RAW: Linux (glibc/musl); macOS 10.12+, iOS 10.0+, tvOS 10.0+, watchOS 3.0+
    // F_FULLFSYNC:         macOS only — fcntl(2) command that flushes to physical media,
    //                      stronger guarantee than fsync(2)
    // MSG_NOSIGNAL:        Linux, FreeBSD, NetBSD, OpenBSD, DragonFly; macOS 14.0+; not Windows
    // O_NONBLOCK:          all POSIX targets; not Windows (use FIONBIO or overlapped I/O instead)

    clock_monotonic: bool = true,
    clock_monotonic_raw: bool = false,
    f_fullfsync: bool = false,
    msg_nosignal: bool = false,
    o_nonblock: bool = true,
};

fn gte(os: std.Target.Os, comptime tag: std.Target.Os.Tag, ver: std.SemanticVersion) bool {
    return os.isAtLeast(tag, ver) orelse false;
}

pub fn detect(target: std.Target) LibcConstants {
    return switch (target.os.tag) {
        .macos, .ios, .tvos, .watchos, .visionos => .{
            .clock_monotonic_raw = true,
            .f_fullfsync = true,
            // MSG_NOSIGNAL added in macOS 14.0 (Sonoma); returns false for non-macOS Darwin
            .msg_nosignal = gte(target.os, .macos, .{ .major = 14, .minor = 0, .patch = 0 }),
        },
        .linux => .{ .clock_monotonic_raw = true, .msg_nosignal = true },
        .freebsd, .netbsd, .openbsd, .dragonfly => .{ .msg_nosignal = true },
        .windows => .{ .clock_monotonic = false, .o_nonblock = false },
        else => .{},
    };
}
