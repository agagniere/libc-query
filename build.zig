const std = @import("std");

pub const libc_constants = @import("libc_constants.zig");
pub const libc_features = @import("libc_features.zig");
pub const libc_headers = @import("libc_headers.zig");
pub const libc_types = @import("libc_types.zig");

pub fn build(b: *std.Build) void {
    _ = b;
}
