# libc-query

Compile-time detection of libc symbol and header availability for Zig cross-compilation targets.

Covers **glibc**, **musl**, **macOS**, **FreeBSD**, **OpenBSD**, **NetBSD**, and **DragonFly**.

## What is tracked

**`libc_features`** — optional libc functions:
`accept4`, `arc4random`, `arc4random_buf`, `arc4random_uniform`, `asprintf`, `backtrace_symbols`,
`clock_gettime`, `copy_file_range`, `copyfile`, `elf_aux_info`, `explicit_bzero`, `fdatasync`,
`freezero`, `fseeko`, `ftruncate`, `getauxval`, `getdelim`, `getentropy`, `getifaddrs`, `getline`,
`getopt`, `getpagesize`, `getpeereid`, `getprogname`, `getrandom`, `inet_aton`, `inet_pton`,
`localeconv_l`, `mbstowcs_l`, `memmem`, `memset_s`, `mkdtemp`, `posix_fadvise`, `posix_fallocate`,
`ppoll`, `preadv`, `pwritev`, `readpassphrase`, `reallocarray`, `recallocarray`, `setproctitle`,
`strcasecmp`, `strchrnul`, `strerror_r`, `strlcat`, `strlcpy`, `strncasecmp`, `strndup`, `strnlen`,
`strsep`, `strsignal`, `strtonum`, `sync_file_range`, `syncfs`, `syslog`, `timingsafe_bcmp`,
`timingsafe_memcmp`, `uselocale`, `vasprintf`, `wcstombs_l`.

**`libc_headers`** — system headers: standard POSIX/C99 headers (always `true` on supported targets)
plus OS-specific ones such as `sys/epoll.h`, `sys/event.h`, `sys/ucred.h`, `execinfo.h`,
`xlocale.h`, `copyfile.h`, and others.

**`libc_types`** — struct field presence: `struct_sockaddr_sa_len` (BSDs and macOS),
`struct_tm_tm_zone` (all supported targets).

**`libc_constants`** — constant/declaration availability: `f_fullfsync` (macOS only).

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

const features   = libcquery.libc_features.detect(target.result);
const headers    = libcquery.libc_headers.detect(target.result);
const types      = libcquery.libc_types.detect(target.result);
const constants  = libcquery.libc_constants.detect(target.result);

if (features.strlcpy)                  { ... }
if (headers.sys_epoll_h)               { ... }
if (types.struct_sockaddr_sa_len)      { ... }
if (constants.f_fullfsync)             { ... }
```

Each `detect()` takes a `std.Target` and returns a struct of `bool` fields. Fields default to
`false` for unknown targets (except POSIX-ubiquitous ones which default to `true`).

## Regenerating generated files

`glibc_abi.zig` and `libc_headers.zig` are generated from Zig's bundled libc data:

```sh
python3 generate_glibc_abi.py | zig fmt --stdin > glibc_abi.zig
python3 generate_libc_headers.py | zig fmt --stdin > libc_headers.zig
```

Requires `zig` on `PATH`. Run after upgrading the Zig toolchain.
