# libc-query

Compile-time detection of libc symbol and header availability for Zig cross-compilation targets.

Covers **glibc**, **musl**, **macOS**, **FreeBSD**, **OpenBSD**, **NetBSD**, **DragonFly**, **Windows (mingw64)**, and **WASI** (preview 1 and preview 2).

## What is tracked

**`libc_features`** — optional libc functions:
`accept4`, `alarm`, `arc4random`, `arc4random_buf`, `arc4random_uniform`, `asprintf`,
`backtrace_symbols`, `clock_gettime`, `copy_file_range`, `copyfile`, `elf_aux_info`, `eventfd`,
`explicit_bzero`, `fcntl`, `fdatasync`, `fnmatch`, `freeaddrinfo`, `freezero`, `fseeko`,
`fsetxattr`, `ftruncate`, `getaddrinfo`, `getaddrinfo_threadsafe`, `getauxval`, `getdelim`,
`getentropy`, `geteuid`, `gethostbyname_r`, `gethostname`, `getifaddrs`, `getline`, `getopt`,
`getpagesize`, `getpass_r`, `getpeereid`, `getpeername`, `getppid`, `getprogname`, `getpwuid`,
`getpwuid_r`, `getrandom`, `getrlimit`, `getsockname`, `gettimeofday`, `gmtime_r`,
`if_nametoindex`, `inet_aton`, `inet_ntop`, `inet_pton`, `localtime_r`, `localeconv_l`,
`mbstowcs_l`, `memmem`, `memrchr`, `memset_s`, `mkdtemp`, `opendir`, `pipe`, `pipe2`, `poll`,
`posix_fadvise`, `posix_fallocate`, `ppoll`, `preadv`, `pwritev`, `readpassphrase`, `reallocarray`,
`recallocarray`, `recv`, `sched_yield`, `select`, `send`, `sendmmsg`, `sendmsg`, `setlocale`,
`setmode`, `setproctitle`, `setrlimit`, `sigaction`, `siginterrupt`, `sigsetjmp`, `signal`,
`snprintf`, `socket`, `socketpair`, `strcasecmp`, `strchrnul`, `strdup`, `strerror_r`, `strlcat`,
`strlcpy`, `strncasecmp`, `strndup`, `strnlen`, `strsep`, `strsignal`, `strtonum`,
`sync_file_range`, `syncfs`, `syslog`, `timingsafe_bcmp`, `timingsafe_memcmp`, `uselocale`,
`utimes`, `vasprintf`, `wcstombs_l`.

**`libc_headers`** — system headers: headers always present on all supported targets (e.g. `stdlib.h`,
`string.h`, `fcntl.h`) plus OS-specific ones such as `sys/epoll.h`, `sys/event.h`, `sys/ucred.h`,
`netinet/tcp.h`, `sys/ioctl.h`, `sys/resource.h`, `linux/tcp.h` (Linux only), `crtdefs.h` (Windows
only), and others.

**`libc_types`** — struct field and typedef presence: `sa_family_t`, `socklen_t`, `suseconds_t`
(all POSIX targets including WASI), `struct_sockaddr_sa_len` (BSDs and macOS),
`struct_sockaddr_storage` and `struct_timeval` (all named targets including WASI and Windows),
`struct_tm_tm_zone` (all POSIX targets except WASI, which uses `__tm_zone`).

**`libc_constants`** — constant/declaration availability: `clock_monotonic` (all POSIX targets
including WASI), `clock_monotonic_raw` (Linux and Darwin), `f_fullfsync` (macOS only),
`msg_nosignal` (Linux, BSDs, DragonFly, macOS 14.0+), `o_nonblock` (all POSIX targets
including WASI).

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
