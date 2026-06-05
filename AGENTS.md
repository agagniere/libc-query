# AGENTS.md

This file provides guidance to LLMs when working with code in this repository.

## Purpose

This library provides compile-time detection of optional libc symbol availability for a given Zig cross-compilation target. It covers glibc, musl, Darwin, FreeBSD, OpenBSD, NetBSD, and DragonFly.

## Regenerating generated files

Both `glibc_abi.zig` and `libc_headers.zig` are generated — do not edit them directly.

```sh
python3 generate_glibc_abi.py | zig fmt --stdin > glibc_abi.zig
python3 generate_libc_headers.py | zig fmt --stdin > libc_headers.zig
```

Both scripts derive data from the Zig toolchain's bundled headers (`zig env` locates the lib dir automatically). You can also pass an explicit lib dir as the first argument.

## Architecture

There are three files to edit and one generated file:

- **`libc_features.zig`** — detects function availability. `detect(target: std.Target) LibcFeatures` dispatches to per-OS detection functions. Edit this to add new symbols or new OS support.
- **`libc_headers.zig`** — generated header availability table. Do not edit directly; regenerate with `python3 generate_libc_headers.py | zig fmt --stdin > libc_headers.zig`.
- **`generate_glibc_abi.py`** — add symbol names to the `SYMBOLS` list to track them through glibc's `abilists`, then regenerate `glibc_abi.zig`.
- **`glibc_abi.zig`** — generated lookup table, one `pub fn symbol(arch, abi) ?std.SemanticVersion` per tracked symbol.

## Key design facts

**Per-arch glibc versions are intentional.** The version for a symbol on a given arch reflects when that symbol became available *on that arch*, which is the later of (a) when the function was added to glibc and (b) when the arch port entered glibc. Newer ports like loongarch64 (2.36) or riscv32 (2.33) get higher version floors for all symbols — this is correct.

**The glibc baseline is 2.17.** Symbols hardcoded as always-true in `detectGlibc` (e.g. `asprintf`, `ftruncate`, `getdelim`) are present in every glibc version Zig supports.

**`abilists` format.** The parser in `generate_glibc_abi.py` handles a custom binary format: libs count → version tuples → target name strings → function entries with ULEB128-encoded target bitmasks and version indices. A symbol can span multiple consecutive entries (same name across different target sets) before an `is_terminal` flag signals the end; all versions are accumulated before taking the minimum.
