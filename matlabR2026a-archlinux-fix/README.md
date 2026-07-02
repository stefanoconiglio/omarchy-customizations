# MATLAB R2026a/R2026b Installer Fix for Arch Linux

The MATLAB installer (`./install`) segfaults immediately on Arch Linux. This repo contains a fix.

## The bug

MATLAB's installer bundles FLEXlm/FLEXnet for license activation. That library runs the x86 `CPUID` instruction to fingerprint the CPU and reads back the vendor string — `"GenuineIntel"` on Intel CPUs — which comes back split across three 32-bit registers:

| Register | Value        | ASCII |
|----------|--------------|-------|
| EBX      | `0x756e6547` | Genu  |
| EDX      | `0x49656e69` | ineI  |
| ECX      | `0x6c65746e` | ntel  |

A bug in the FLEXlm code then takes those raw 32-bit integers and uses them as **64-bit memory pointers** — attempting to dereference addresses like `0x6c65746e`. Those addresses are not mapped, so the process gets a SIGSEGV before any installer UI appears.

This is not a gnutls issue (a separate known fix for R2025 on Arch). It is not fixed by downgrading gnutls.

## The fix

`matlab_fix.so` is an `LD_PRELOAD` library that does two things at startup, before the buggy code runs:

1. **Maps zero pages at all three CPUID vendor-string addresses** (`0x75600000`, `0x49600000`, `0x6c600000`). When the buggy code tries to dereference those values as pointers, it hits real mapped memory (filled with zeros) instead of segfaulting.

2. **Installs a SIGSEGV handler** for downstream null-pointer crashes. Code that reads the zeros planted in step 1 and then tries to dereference *those* as pointers faults at low addresses (e.g. `0x0`, `0xb`). The handler decodes the faulting x86-64 instruction, advances the instruction pointer past it, and zeroes likely destination registers so execution continues.

Together these two layers get the licensing code through its CPU fingerprinting section without crashing, and the installer GUI comes up normally.

## Building

Requires `gcc`. No other dependencies.

```bash
gcc -shared -fPIC -o matlab_fix.so matlab_fix.c -nostartfiles
```

A pre-compiled x86-64 Linux binary (`matlab_fix.so`) is also included in this repo.

## Usage

```bash
# From your MATLAB installer directory:
LD_PRELOAD=/path/to/matlab_fix.so ./install
```

## Tested on

- Arch Linux (Omarchy), kernel 7.0.9-arch2-1, Intel CPU
- MATLAB R2026b Prerelease installer
- MATLAB R2026a installer

## Why this is needed

Arch Linux is a rolling-release distro and is not officially supported by MathWorks. This particular crash is caused by a bug inside MATLAB's bundled FLEXlm library, not by Arch's system libraries, so there is no distro-side fix. The workaround (distrobox/podman) of running MATLAB inside a supported container works but is heavy. This single shared library is the minimal fix.
