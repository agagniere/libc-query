const std = @import("std");

pub const libc_features = @import("libc_features.zig");
pub const libc_headers = @import("libc_headers.zig");

pub fn build(b: *std.Build) void {
    _ = b;
}
