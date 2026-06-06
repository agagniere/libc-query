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
    // F_FULLFSYNC: macOS only — fcntl(2) command that flushes to physical media,
    //              stronger guarantee than F_FULLFSYNC on Linux (which has no equivalent)

    f_fullfsync: bool = false,
};

pub fn detect(target: std.Target) LibcConstants {
    return switch (target.os.tag) {
        .macos, .ios, .tvos, .watchos, .visionos => .{ .f_fullfsync = true },
        else => .{},
    };
}
