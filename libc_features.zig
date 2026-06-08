//! Detect which optional libc extensions are available for a given target.
//!
//! All listed functions are beyond ISO C — POSIX extensions, BSD extensions,
//! or glibc-specific additions.
//!
//! For glibc targets, availability is derived from glibc_abi.zig (generated
//! from Zig's bundled abilists — run generate_glibc_abi.py to regenerate).
//! For BSD targets a version-threshold table is used.
//!
//! Usage from build.zig:
//!   const features = @import("libc_features.zig").detect(target.result);
//!   if (features.strlcat) { ... }

const std = @import("std");
const glibc_abi = @import("glibc_abi.zig");

pub const LibcFeatures = struct {
    // Availability reference:
    // accept4:           glibc 2.10, musl, FreeBSD 10.0, NetBSD 8.0, DragonFly 4.6
    // arc4random:        OpenBSD 2.1, FreeBSD 2.2.6, NetBSD 10.0, glibc 2.36, musl
    // arc4random_buf:    OpenBSD 2.1, FreeBSD 8.0, NetBSD 10.0, glibc 2.36, musl
    // arc4random_uniform:OpenBSD 4.2, FreeBSD 8.0, NetBSD 10.0, glibc 2.36, musl
    // asprintf:          glibc, OpenBSD 2.3, FreeBSD 2.2, Windows (mingw64)
    // backtrace_symbols: glibc (ancient), macOS
    // clock_gettime:     POSIX.1 (ubiquitous on POSIX targets; macOS 10.12+; not Windows)
    // copy_file_range:   glibc 2.27, FreeBSD 13.0
    // copyfile:          macOS only
    // elf_aux_info:      FreeBSD 12.0, OpenBSD 7.6
    // eventfd:           glibc 2.8, musl (Linux only; kernel 2.6.22)
    // explicit_bzero:    glibc 2.25, FreeBSD 11.0, OpenBSD 5.5, NetBSD 7.0, DragonFly 5.0 (not macOS)
    // fdatasync:         POSIX.1 (all POSIX targets; not Windows)
    // freezero:          OpenBSD 6.2, DragonFly 5.5
    // fseeko:            POSIX.1 (ubiquitous)
    // ftruncate:         4.2BSD, POSIX.1, Windows (mingw64)
    // getauxval:         glibc 2.16, musl (Linux only)
    // getdelim, getline: POSIX.1, FreeBSD 8.0, OpenBSD 5.2, NetBSD 6.0
    // gethostbyname_r:   glibc, musl, FreeBSD 6.2, DragonFly 2.1 (not macOS/OpenBSD/NetBSD/Windows)
    // getentropy:        OpenBSD 5.6, FreeBSD 12.0, NetBSD 10.0, glibc 2.25
    // getifaddrs:        glibc 2.3, FreeBSD (ancient), OpenBSD (ancient), NetBSD (ancient), macOS, musl
    // getopt:            POSIX.1 (ubiquitous)
    // getpagesize:       4.2BSD, SUSv1
    // getpass_r:         NetBSD 7.0
    // getpeereid:        OpenBSD (ancient), FreeBSD 4.6, NetBSD 3.0, macOS, DragonFly
    // getprogname:       NetBSD 1.6, FreeBSD 4.4, OpenBSD 5.4
    // getrandom:         glibc 2.25, FreeBSD 12.0
    // inet_aton:         all POSIX targets; not Windows (use inet_pton instead)
    // inet_ntop:         POSIX.1 (ubiquitous; Windows via ws2tcpip.h)
    // inet_pton:         POSIX.1 (ubiquitous; Windows via ws2tcpip.h)
    // localeconv_l, mbstowcs_l, wcstombs_l: xlocale extension; macOS 10.4, FreeBSD 10.3, DragonFly (not glibc/musl/OpenBSD/NetBSD/Windows)
    // memmem:            glibc (ancient), FreeBSD (ancient), OpenBSD (ancient), macOS 10.7
    // memrchr:           glibc, musl, FreeBSD 6.4, OpenBSD 4.3, NetBSD, DragonFly (not macOS/Windows)
    // memset_s:          C11 Annex K; macOS 10.9, FreeBSD 11.1, DragonFly 5.8 (not glibc/musl/OpenBSD/NetBSD/Windows)
    // mkdtemp:           glibc (ancient), BSDs (ancient), macOS, musl
    // pipe2:             glibc 2.9, musl, FreeBSD 10.0, OpenBSD 5.7, NetBSD 6.0, DragonFly (not macOS/Windows)
    // posix_fadvise:     glibc (ancient), FreeBSD 6.0, NetBSD 4.0, DragonFly, musl; NOT macOS/OpenBSD/Windows
    // posix_fallocate:   glibc (ancient), FreeBSD 11.0, NetBSD 7.0, musl; NOT macOS/OpenBSD/Windows
    // ppoll:             glibc 2.4, musl (Linux only)
    // preadv, pwritev:   POSIX.1-2008 (all POSIX targets; glibc 2.10, FreeBSD 6.0, OpenBSD 2.7, NetBSD 1.4, DragonFly 1.5; not Windows)
    // readpassphrase:    OpenBSD (ancient), FreeBSD (ancient), NetBSD (ancient), macOS, DragonFly
    // reallocarray:      glibc 2.26, OpenBSD 5.6, FreeBSD 11.0, NetBSD 8, DragonFly 5.5
    // recallocarray:     OpenBSD 6.1, DragonFly 5.5
    // sendmmsg:          glibc 2.14, musl (kernel 3.0), FreeBSD 11.0, NetBSD 7.0, OpenBSD 7.2
    // setproctitle:      FreeBSD (ancient), OpenBSD (ancient), NetBSD (ancient), DragonFly
    // strcasecmp:        POSIX.1 (ubiquitous)
    // strerror_r:        POSIX.1 (all POSIX targets; not Windows — mingw only provides a pthread.h macro)
    // strlcat, strlcpy:  OpenBSD 2.4, FreeBSD 3.3, NetBSD 1.4.3, glibc 2.38, musl
    // strchrnul:         glibc 2.1.1, musl, FreeBSD 10.0, NetBSD 8.0, DragonFly 3.5, macOS 15.4
    // strncasecmp:       POSIX.1 (ubiquitous)
    // strndup:           glibc 2.2.5, FreeBSD 7.2, NetBSD 4.0, OpenBSD 4.8
    // strnlen:           POSIX.1, Windows (mingw64)
    // strsep:            4.4BSD, glibc (with _GNU_SOURCE)
    // strsignal:         POSIX.1 (all POSIX targets; not Windows)
    // strtonum:          OpenBSD 3.6, NetBSD 8
    // sync_file_range:   glibc 2.4, musl (Linux only)
    // syncfs:            glibc 2.14, musl (Linux only)
    // syslog:            POSIX.1 (all POSIX targets; not Windows)
    // timingsafe_bcmp:   OpenBSD 4.9, FreeBSD 11.1, DragonFly 5.6
    // timingsafe_memcmp: OpenBSD 5.6, FreeBSD 11.1, DragonFly 5.6
    // uselocale:         glibc 2.3, musl, macOS 10.4, FreeBSD 9.1, OpenBSD 6.2, DragonFly (not NetBSD/Windows)
    // vasprintf:         glibc (ancient), OpenBSD 2.3, FreeBSD (ancient), NetBSD (ancient), Windows (mingw64)

    accept4: bool = false,
    arc4random: bool = false,
    arc4random_buf: bool = false,
    arc4random_uniform: bool = false,
    asprintf: bool = false,
    backtrace_symbols: bool = false,
    clock_gettime: bool = true,
    copy_file_range: bool = false,
    copyfile: bool = false,
    elf_aux_info: bool = false,
    eventfd: bool = false,
    explicit_bzero: bool = false,
    fdatasync: bool = true,
    freezero: bool = false,
    fseeko: bool = true,
    ftruncate: bool = false,
    getauxval: bool = false,
    getdelim: bool = false,
    getentropy: bool = false,
    getifaddrs: bool = false,
    getline: bool = false,
    getopt: bool = true,
    getpagesize: bool = false,
    getpass_r: bool = false,
    getpeereid: bool = false,
    getprogname: bool = false,
    gethostbyname_r: bool = false,
    getrandom: bool = false,
    inet_aton: bool = true,
    inet_ntop: bool = true,
    inet_pton: bool = true,
    localeconv_l: bool = false,
    mbstowcs_l: bool = false,
    memmem: bool = false,
    memrchr: bool = false,
    memset_s: bool = false,
    mkdtemp: bool = false,
    posix_fadvise: bool = false,
    posix_fallocate: bool = false,
    pipe2: bool = false,
    ppoll: bool = false,
    preadv: bool = true,
    pwritev: bool = true,
    readpassphrase: bool = false,
    reallocarray: bool = false,
    recallocarray: bool = false,
    sendmmsg: bool = false,
    setproctitle: bool = false,
    strcasecmp: bool = true,
    strchrnul: bool = false,
    strerror_r: bool = true,
    strlcat: bool = false,
    strlcpy: bool = false,
    strncasecmp: bool = true,
    strndup: bool = false,
    strnlen: bool = false,
    strsep: bool = false,
    strsignal: bool = true,
    strtonum: bool = false,
    sync_file_range: bool = false,
    syncfs: bool = false,
    syslog: bool = true,
    timingsafe_bcmp: bool = false,
    timingsafe_memcmp: bool = false,
    uselocale: bool = false,
    vasprintf: bool = false,
    wcstombs_l: bool = false,
};

pub fn detect(target: std.Target) LibcFeatures {
    return switch (target.os.tag) {
        .linux => detectLinux(target),
        .macos, .ios, .tvos, .watchos, .visionos => detectDarwin(target),
        .freebsd => detectFreeBSD(target),
        .openbsd => detectOpenBSD(target),
        .netbsd => detectNetBSD(target),
        .dragonfly => detectDragonFly(target),
        .windows => detectWindows(),
        else => .{},
    };
}

// ── Linux ─────────────────────────────────────────────────────────────────────

fn detectLinux(target: std.Target) LibcFeatures {
    if (target.abi.isMusl()) return detectMusl();
    if (!target.isGnuLibC()) return .{};
    return detectGlibc(target);
}

fn detectGlibc(target: std.Target) LibcFeatures {
    const glibc = target.os.versionRange().gnuLibCVersion() orelse return .{};
    const arch = target.cpu.arch;
    const abi = target.abi;

    const has = struct {
        fn check(intro: ?std.SemanticVersion, ver: std.SemanticVersion) bool {
            return if (intro) |v| ver.order(v) != .lt else false;
        }
    }.check;

    return .{
        // Always present in any glibc Zig supports (≥ 2.17)
        .asprintf = true,
        .eventfd = true, // since glibc 2.8 / kernel 2.6.22
        .gethostbyname_r = true,
        .memrchr = true,
        .pipe2 = true, // since glibc 2.9
        .sendmmsg = true, // since glibc 2.14 / kernel 3.0
        .uselocale = true, // since glibc 2.3
        .ftruncate = true,
        .getdelim = true,
        .getline = true,
        .getpagesize = true,
        .strnlen = true,
        .strsep = true,
        // Version-sensitive — queried from abilists via glibc_abi.zig
        .accept4 = has(glibc_abi.accept4(arch, abi), glibc),
        .arc4random = has(glibc_abi.arc4random(arch, abi), glibc),
        .arc4random_buf = has(glibc_abi.arc4random_buf(arch, abi), glibc),
        .arc4random_uniform = has(glibc_abi.arc4random_uniform(arch, abi), glibc),
        .backtrace_symbols = has(glibc_abi.backtrace_symbols(arch, abi), glibc),
        .copy_file_range = has(glibc_abi.copy_file_range(arch, abi), glibc),
        .explicit_bzero = has(glibc_abi.explicit_bzero(arch, abi), glibc),
        .getauxval = has(glibc_abi.getauxval(arch, abi), glibc),
        .getentropy = has(glibc_abi.getentropy(arch, abi), glibc),
        .getifaddrs = has(glibc_abi.getifaddrs(arch, abi), glibc),
        .getrandom = has(glibc_abi.getrandom(arch, abi), glibc),
        .memmem = has(glibc_abi.memmem(arch, abi), glibc),
        .mkdtemp = has(glibc_abi.mkdtemp(arch, abi), glibc),
        .posix_fadvise = has(glibc_abi.posix_fadvise(arch, abi), glibc),
        .posix_fallocate = has(glibc_abi.posix_fallocate(arch, abi), glibc),
        .ppoll = has(glibc_abi.ppoll(arch, abi), glibc),
        .reallocarray = has(glibc_abi.reallocarray(arch, abi), glibc),
        .strchrnul = has(glibc_abi.strchrnul(arch, abi), glibc),
        .strlcat = has(glibc_abi.strlcat(arch, abi), glibc),
        .strlcpy = has(glibc_abi.strlcpy(arch, abi), glibc),
        .strndup = has(glibc_abi.strndup(arch, abi), glibc),
        .sync_file_range = has(glibc_abi.sync_file_range(arch, abi), glibc),
        .syncfs = has(glibc_abi.syncfs(arch, abi), glibc),
        .vasprintf = has(glibc_abi.vasprintf(arch, abi), glibc),
    };
}

fn detectMusl() LibcFeatures {
    return .{
        .accept4 = true,
        .arc4random = true,
        .arc4random_buf = true,
        .arc4random_uniform = true,
        .asprintf = true,
        .copy_file_range = true,
        .explicit_bzero = true,
        .ftruncate = true,
        .getauxval = true,
        .getdelim = true,
        .getentropy = true,
        .getifaddrs = true,
        .getline = true,
        .getpagesize = true,
        .getrandom = true,
        .memmem = true,
        .mkdtemp = true,
        .posix_fadvise = true,
        .posix_fallocate = true,
        .ppoll = true,
        .reallocarray = true,
        .strchrnul = true,
        .strlcat = true,
        .strlcpy = true,
        .strndup = true,
        .strnlen = true,
        .strsep = true,
        .eventfd = true,
        .gethostbyname_r = true,
        .memrchr = true,
        .pipe2 = true,
        .sendmmsg = true,
        .sync_file_range = true,
        .syncfs = true,
        .uselocale = true,
        .vasprintf = true,
    };
}

// ── Darwin ────────────────────────────────────────────────────────────────────

fn detectDarwin(target: std.Target) LibcFeatures {
    const os = target.os;
    return .{
        .arc4random = true,
        .arc4random_buf = gte(os, .macos, .{ .major = 10, .minor = 7, .patch = 0 }), // https://keith.github.io/xcode-man-pages/arc4random.3.html
        .arc4random_uniform = gte(os, .macos, .{ .major = 10, .minor = 7, .patch = 0 }), // https://keith.github.io/xcode-man-pages/arc4random.3.html
        .asprintf = true,
        .backtrace_symbols = gte(os, .macos, .{ .major = 10, .minor = 5, .patch = 0 }), // https://keith.github.io/xcode-man-pages/backtrace.3.html
        .copyfile = gte(os, .macos, .{ .major = 10, .minor = 5, .patch = 0 }), // https://keith.github.io/xcode-man-pages/copyfile.3.html
        .ftruncate = true,
        .getdelim = gte(os, .macos, .{ .major = 10, .minor = 7, .patch = 0 }),
        .getentropy = gte(os, .macos, .{ .major = 10, .minor = 12, .patch = 0 }), // https://keith.github.io/xcode-man-pages/getentropy.2.html
        .getifaddrs = true,
        .getline = gte(os, .macos, .{ .major = 10, .minor = 7, .patch = 0 }), // https://keith.github.io/xcode-man-pages/getline.3.html
        .localeconv_l = gte(os, .macos, .{ .major = 10, .minor = 4, .patch = 0 }), // https://keith.github.io/xcode-man-pages/localeconv_l.3.html
        .mbstowcs_l = gte(os, .macos, .{ .major = 10, .minor = 4, .patch = 0 }), // https://keith.github.io/xcode-man-pages/mbstowcs_l.3.html
        .getpagesize = true,
        .getpeereid = true,
        .getprogname = true,
        .memmem = gte(os, .macos, .{ .major = 10, .minor = 7, .patch = 0 }), // https://keith.github.io/xcode-man-pages/memmem.3.html
        .memset_s = gte(os, .macos, .{ .major = 10, .minor = 9, .patch = 0 }), // https://keith.github.io/xcode-man-pages/memset_s.3.html
        .mkdtemp = true,
        .readpassphrase = true,
        .strchrnul = gte(os, .macos, .{ .major = 15, .minor = 4, .patch = 0 }), // https://keith.github.io/xcode-man-pages/strchr.3.html
        .strlcat = true,
        .strlcpy = true,
        .strndup = gte(os, .macos, .{ .major = 10, .minor = 7, .patch = 0 }), // https://keith.github.io/xcode-man-pages/strdup.3.html
        .strnlen = gte(os, .macos, .{ .major = 10, .minor = 7, .patch = 0 }), // https://keith.github.io/xcode-man-pages/strlen.3.html
        .strsep = true,
        .strtonum = gte(os, .macos, .{ .major = 11, .minor = 0, .patch = 0 }), // https://keith.github.io/xcode-man-pages/strtonum.3.html
        .uselocale = gte(os, .macos, .{ .major = 10, .minor = 4, .patch = 0 }), // https://keith.github.io/xcode-man-pages/uselocale.3.html
        .vasprintf = true,
        .wcstombs_l = gte(os, .macos, .{ .major = 10, .minor = 4, .patch = 0 }), // https://keith.github.io/xcode-man-pages/wcstombs_l.3.html
    };
}

// ── BSDs ──────────────────────────────────────────────────────────────────────

fn gte(os: std.Target.Os, comptime tag: std.Target.Os.Tag, ver: std.SemanticVersion) bool {
    return os.isAtLeast(tag, ver) orelse false;
}

fn detectFreeBSD(target: std.Target) LibcFeatures {
    const os = target.os;
    return .{
        .accept4 = gte(os, .freebsd, .{ .major = 10, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=accept4&sektion=2
        .arc4random = true, // https://man.freebsd.org/cgi/man.cgi?query=arc4random&sektion=3
        .arc4random_buf = gte(os, .freebsd, .{ .major = 8, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=arc4random&sektion=3
        .arc4random_uniform = gte(os, .freebsd, .{ .major = 8, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=arc4random&sektion=3
        .asprintf = true,
        .copy_file_range = gte(os, .freebsd, .{ .major = 13, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=copy_file_range&sektion=2
        .elf_aux_info = gte(os, .freebsd, .{ .major = 12, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=elf_aux_info&sektion=3
        .explicit_bzero = gte(os, .freebsd, .{ .major = 11, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=explicit_bzero&sektion=3
        .gethostbyname_r = gte(os, .freebsd, .{ .major = 6, .minor = 2, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=gethostbyname_r&sektion=3
        .ftruncate = true,
        .getdelim = gte(os, .freebsd, .{ .major = 8, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=getdelim&sektion=3
        .getentropy = gte(os, .freebsd, .{ .major = 12, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=getentropy&sektion=3
        .getifaddrs = true,
        .getline = gte(os, .freebsd, .{ .major = 8, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=getdelim&sektion=3
        .getpagesize = true,
        .localeconv_l = gte(os, .freebsd, .{ .major = 10, .minor = 3, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=localeconv_l&sektion=3
        .mbstowcs_l = gte(os, .freebsd, .{ .major = 10, .minor = 3, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=mbstowcs_l&sektion=3
        .getpeereid = gte(os, .freebsd, .{ .major = 4, .minor = 6, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=getpeereid&sektion=3
        .getprogname = gte(os, .freebsd, .{ .major = 4, .minor = 4, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=getprogname&sektion=3
        .getrandom = gte(os, .freebsd, .{ .major = 12, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=getrandom&sektion=2
        .memmem = true,
        .memrchr = gte(os, .freebsd, .{ .major = 6, .minor = 4, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=memrchr&sektion=3
        .memset_s = gte(os, .freebsd, .{ .major = 11, .minor = 1, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=memset_s&sektion=3
        .mkdtemp = true,
        .pipe2 = gte(os, .freebsd, .{ .major = 10, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=pipe2&sektion=2
        .sendmmsg = gte(os, .freebsd, .{ .major = 11, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=sendmmsg&sektion=2
        .posix_fadvise = gte(os, .freebsd, .{ .major = 9, .minor = 1, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=posix_fadvise&sektion=2
        .posix_fallocate = gte(os, .freebsd, .{ .major = 9, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=posix_fallocate&sektion=2
        .readpassphrase = true,
        .reallocarray = gte(os, .freebsd, .{ .major = 11, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=reallocarray&sektion=3
        .setproctitle = true,
        .strchrnul = gte(os, .freebsd, .{ .major = 10, .minor = 0, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=strchrnul&sektion=3
        .strlcat = gte(os, .freebsd, .{ .major = 3, .minor = 3, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=strlcpy&sektion=3
        .strlcpy = gte(os, .freebsd, .{ .major = 3, .minor = 3, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=strlcpy&sektion=3
        .strndup = gte(os, .freebsd, .{ .major = 7, .minor = 2, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=strndup&sektion=3
        .strnlen = true,
        .strsep = true,
        .timingsafe_bcmp = gte(os, .freebsd, .{ .major = 11, .minor = 1, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=timingsafe_bcmp&sektion=3
        .timingsafe_memcmp = gte(os, .freebsd, .{ .major = 11, .minor = 1, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=timingsafe_bcmp&sektion=3
        .uselocale = gte(os, .freebsd, .{ .major = 9, .minor = 1, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=uselocale&sektion=3
        .vasprintf = true,
        .wcstombs_l = gte(os, .freebsd, .{ .major = 10, .minor = 3, .patch = 0 }), // https://man.freebsd.org/cgi/man.cgi?query=wcstombs_l&sektion=3
    };
}

fn detectOpenBSD(target: std.Target) LibcFeatures {
    const os = target.os;
    return .{
        .arc4random = true, // https://man.openbsd.org/arc4random.3
        .arc4random_buf = true, // https://man.openbsd.org/arc4random.3
        .arc4random_uniform = gte(os, .openbsd, .{ .major = 4, .minor = 2, .patch = 0 }), // https://man.openbsd.org/arc4random.3
        .asprintf = gte(os, .openbsd, .{ .major = 2, .minor = 3, .patch = 0 }), // https://man.openbsd.org/asprintf.3
        .elf_aux_info = gte(os, .openbsd, .{ .major = 7, .minor = 6, .patch = 0 }), // https://man.openbsd.org/elf_aux_info.3
        .explicit_bzero = gte(os, .openbsd, .{ .major = 5, .minor = 5, .patch = 0 }), // https://man.openbsd.org/explicit_bzero.3
        .freezero = gte(os, .openbsd, .{ .major = 6, .minor = 2, .patch = 0 }), // https://man.openbsd.org/freezero.3
        .ftruncate = true,
        .getdelim = gte(os, .openbsd, .{ .major = 5, .minor = 2, .patch = 0 }), // https://man.openbsd.org/getline.3
        .getentropy = gte(os, .openbsd, .{ .major = 5, .minor = 6, .patch = 0 }), // https://man.openbsd.org/getentropy.2
        .getifaddrs = true,
        .getline = gte(os, .openbsd, .{ .major = 5, .minor = 2, .patch = 0 }), // https://man.openbsd.org/getline.3
        .getpagesize = true,
        .getpeereid = true,
        .getprogname = gte(os, .openbsd, .{ .major = 5, .minor = 4, .patch = 0 }), // https://man.openbsd.org/getprogname.3
        .memmem = true,
        .memrchr = gte(os, .openbsd, .{ .major = 4, .minor = 3, .patch = 0 }), // https://man.openbsd.org/memrchr.3
        .mkdtemp = true,
        .pipe2 = gte(os, .openbsd, .{ .major = 5, .minor = 7, .patch = 0 }), // https://man.openbsd.org/pipe2.2
        .readpassphrase = true,
        .reallocarray = gte(os, .openbsd, .{ .major = 5, .minor = 6, .patch = 0 }), // https://man.openbsd.org/reallocarray.3
        .recallocarray = gte(os, .openbsd, .{ .major = 6, .minor = 1, .patch = 0 }), // https://man.openbsd.org/reallocarray.3
        .setproctitle = true,
        .strlcat = true, // https://man.openbsd.org/strlcpy.3
        .strlcpy = true, // https://man.openbsd.org/strlcpy.3
        .strndup = gte(os, .openbsd, .{ .major = 4, .minor = 8, .patch = 0 }), // https://man.openbsd.org/strndup.3
        .strnlen = true,
        .strsep = true,
        .strtonum = gte(os, .openbsd, .{ .major = 3, .minor = 6, .patch = 0 }), // https://man.openbsd.org/strtonum.3
        .sendmmsg = gte(os, .openbsd, .{ .major = 7, .minor = 2, .patch = 0 }), // https://man.openbsd.org/sendmmsg.2
        .timingsafe_bcmp = gte(os, .openbsd, .{ .major = 4, .minor = 9, .patch = 0 }), // https://man.openbsd.org/timingsafe_bcmp.3
        .timingsafe_memcmp = gte(os, .openbsd, .{ .major = 5, .minor = 6, .patch = 0 }), // https://man.openbsd.org/timingsafe_bcmp.3
        .uselocale = gte(os, .openbsd, .{ .major = 6, .minor = 2, .patch = 0 }), // https://man.openbsd.org/uselocale.3
        .vasprintf = gte(os, .openbsd, .{ .major = 2, .minor = 3, .patch = 0 }), // https://man.openbsd.org/asprintf.3
    };
}

fn detectNetBSD(target: std.Target) LibcFeatures {
    const os = target.os;
    return .{
        .accept4 = gte(os, .netbsd, .{ .major = 8, .minor = 0, .patch = 0 }), // https://man.netbsd.org/accept4.2
        .arc4random = gte(os, .netbsd, .{ .major = 10, .minor = 0, .patch = 0 }), // https://man.netbsd.org/arc4random.3
        .arc4random_buf = gte(os, .netbsd, .{ .major = 10, .minor = 0, .patch = 0 }), // https://man.netbsd.org/arc4random.3
        .arc4random_uniform = gte(os, .netbsd, .{ .major = 10, .minor = 0, .patch = 0 }), // https://man.netbsd.org/arc4random.3
        .asprintf = true,
        .explicit_bzero = gte(os, .netbsd, .{ .major = 7, .minor = 0, .patch = 0 }), // https://man.netbsd.org/explicit_bzero.3
        .ftruncate = true,
        .getdelim = gte(os, .netbsd, .{ .major = 6, .minor = 0, .patch = 0 }), // https://man.netbsd.org/getline.3
        .getentropy = gte(os, .netbsd, .{ .major = 10, .minor = 0, .patch = 0 }), // https://man.netbsd.org/getentropy.2
        .getifaddrs = true,
        .getline = gte(os, .netbsd, .{ .major = 6, .minor = 0, .patch = 0 }), // https://man.netbsd.org/getline.3
        .getpagesize = true,
        .getpeereid = gte(os, .netbsd, .{ .major = 5, .minor = 0, .patch = 0 }), // https://man.netbsd.org/getpeereid.3
        .getprogname = true, // https://man.netbsd.org/getprogname.3
        .getpass_r = gte(os, .netbsd, .{ .major = 7, .minor = 0, .patch = 0 }), // https://man.netbsd.org/getpass_r.3
        .memmem = true,
        .memrchr = true, // https://man.netbsd.org/memrchr.3
        .mkdtemp = true,
        .pipe2 = gte(os, .netbsd, .{ .major = 6, .minor = 0, .patch = 0 }), // https://man.netbsd.org/pipe2.2
        .sendmmsg = gte(os, .netbsd, .{ .major = 7, .minor = 0, .patch = 0 }), // https://man.netbsd.org/sendmmsg.2
        .posix_fadvise = gte(os, .netbsd, .{ .major = 4, .minor = 0, .patch = 0 }), // https://man.netbsd.org/posix_fadvise.2
        .posix_fallocate = gte(os, .netbsd, .{ .major = 7, .minor = 0, .patch = 0 }), // https://man.netbsd.org/posix_fallocate.3
        .readpassphrase = true,
        .reallocarray = gte(os, .netbsd, .{ .major = 8, .minor = 0, .patch = 0 }), // https://man.netbsd.org/reallocarray.3
        .setproctitle = true,
        .strlcat = true, // https://man.netbsd.org/strlcpy.3
        .strlcpy = true, // https://man.netbsd.org/strlcpy.3
        .strndup = gte(os, .netbsd, .{ .major = 4, .minor = 0, .patch = 0 }), // https://man.netbsd.org/strndup.3
        .strnlen = true,
        .strsep = true,
        .strchrnul = gte(os, .netbsd, .{ .major = 8, .minor = 0, .patch = 0 }), // https://man.netbsd.org/strchrnul.3
        .strtonum = gte(os, .netbsd, .{ .major = 8, .minor = 0, .patch = 0 }), // https://man.netbsd.org/strtonum.3
        .vasprintf = true,
    };
}

fn detectDragonFly(target: std.Target) LibcFeatures {
    const os = target.os;
    return .{
        .accept4 = gte(os, .dragonfly, .{ .major = 4, .minor = 3, .patch = 0 }), // https://leaf.dragonflybsd.org/cgi/web-man?command=accept4
        .arc4random = true,
        .arc4random_buf = true,
        .arc4random_uniform = true,
        .asprintf = true,
        .explicit_bzero = gte(os, .dragonfly, .{ .major = 5, .minor = 5, .patch = 0 }), // https://leaf.dragonflybsd.org/cgi/web-man?command=explicit_bzero
        .freezero = gte(os, .dragonfly, .{ .major = 5, .minor = 5, .patch = 0 }), // https://leaf.dragonflybsd.org/cgi/web-man?command=freezero
        .ftruncate = true,
        .getdelim = true,
        .getentropy = true,
        .getifaddrs = true,
        .getline = true,
        .getpagesize = true,
        .getpeereid = true,
        .getprogname = true,
        .localeconv_l = true, // https://leaf.dragonflybsd.org/cgi/web-man?command=localeconv_l
        .mbstowcs_l = true, // https://leaf.dragonflybsd.org/cgi/web-man?command=mbstowcs_l
        .gethostbyname_r = gte(os, .dragonfly, .{ .major = 2, .minor = 1, .patch = 0 }), // https://leaf.dragonflybsd.org/cgi/web-man?command=gethostbyname_r
        .memmem = true,
        .memrchr = true, // https://leaf.dragonflybsd.org/cgi/web-man?command=memrchr
        .memset_s = gte(os, .dragonfly, .{ .major = 5, .minor = 8, .patch = 0 }), // https://leaf.dragonflybsd.org/cgi/web-man?command=memset_s
        .mkdtemp = true,
        .posix_fadvise = true,
        .readpassphrase = true,
        .reallocarray = gte(os, .dragonfly, .{ .major = 5, .minor = 5, .patch = 0 }), // https://leaf.dragonflybsd.org/cgi/web-man?command=reallocarray
        .recallocarray = gte(os, .dragonfly, .{ .major = 5, .minor = 5, .patch = 0 }), // https://leaf.dragonflybsd.org/cgi/web-man?command=recallocarray
        .setproctitle = true,
        .strchrnul = gte(os, .dragonfly, .{ .major = 3, .minor = 5, .patch = 0 }), // https://leaf.dragonflybsd.org/cgi/web-man?command=strchrnul
        .strlcat = true,
        .strlcpy = true,
        .strndup = true,
        .strnlen = true,
        .strsep = true,
        .timingsafe_bcmp = gte(os, .dragonfly, .{ .major = 5, .minor = 6, .patch = 0 }), // https://leaf.dragonflybsd.org/cgi/web-man?command=timingsafe_bcmp
        .timingsafe_memcmp = gte(os, .dragonfly, .{ .major = 5, .minor = 6, .patch = 0 }), // https://leaf.dragonflybsd.org/cgi/web-man?command=timingsafe_bcmp
        .pipe2 = true, // https://leaf.dragonflybsd.org/cgi/web-man?command=pipe2
        .uselocale = true, // https://leaf.dragonflybsd.org/cgi/web-man?command=uselocale
        .vasprintf = true,
        .wcstombs_l = true, // https://leaf.dragonflybsd.org/cgi/web-man?command=wcstombs_l
    };
}

// ── Windows (mingw64) ─────────────────────────────────────────────────────────

fn detectWindows() LibcFeatures {
    return .{
        // Defaults false that are present on Windows via mingw64
        .asprintf = true,
        .ftruncate = true,
        .strnlen = true,
        .vasprintf = true,
        // Defaults true that are absent on Windows
        .clock_gettime = false, // only in pthread_time.h (winpthreads), not in time.h
        .fdatasync = false,
        .inet_aton = false,
        .preadv = false,
        .pwritev = false,
        .strerror_r = false, // mingw pthread.h only provides a wrapper macro
        .strsignal = false,
        .syslog = false,
    };
}
