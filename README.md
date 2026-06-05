# libc-query

Compile-time detection of libc symbol and header availability for Zig cross-compilation targets.

Covers **glibc**, **musl**, **macOS**, **FreeBSD**, **OpenBSD**, **NetBSD**, and **DragonFly**.

## What is tracked

**`libc_features`** — optional libc functions: `accept4`, `arc4random`, `arc4random_buf`, `arc4random_uniform`, `backtrace_symbols`, `copy_file_range`, `explicit_bzero`, `getauxval`, `getentropy`, `getifaddrs`, `getrandom`, `memmem`, `mkdtemp`, `posix_fadvise`, `posix_fallocate`, `ppoll`, `reallocarray`, `strlcat`, `strlcpy`, `strndup`, `sync_file_range`, `syncfs`, `vasprintf`.

**`libc_headers`** — system headers: standard POSIX/C99 headers (always `true` on supported targets) plus OS-specific ones such as `sys/epoll.h`, `sys/event.h`, `sys/ucred.h`, `execinfo.h`, `xlocale.h`, `copyfile.h`, and others.

For glibc, function availability is per-architecture and derived from Zig's bundled `abilists` file.

## Usage

Add this repo as a dependency to your `build.zig.zon`:

```shell
zig fetch --save git+https://github.com/agagniere/libc-query
```

Then in your `build.zig`:

```zig
const libcquery = @import("libcquery");

// Then, in your build function:

const features = libcquery.libc_features.detect(target.result);
const headers  = libcquery.libc_headers.detect(target.result);

if (features.strlcpy) { ... }
if (headers.sys_epoll_h) { ... }
```

`detect()` takes a `std.Target` and returns a struct of `bool` fields — one per tracked symbol or header. Fields default to `false` for unknown targets.

## Regenerating generated files

Both `glibc_abi.zig` and `libc_headers.zig` are generated from Zig's bundled libc data:

```sh
python3 generate_glibc_abi.py | zig fmt --stdin > glibc_abi.zig
python3 generate_libc_headers.py | zig fmt --stdin > libc_headers.zig
```

Requires `zig` on `PATH`. Run after upgrading the Zig toolchain.
