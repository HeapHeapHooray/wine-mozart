# wine-mozart — plain-Wine runner for audio production

A standalone **Wine 11.0** runner designed for music production software on Linux.

`wine-mozart` builds on top of giang17's Wine repository directly, fetches the base patch series from [HeapHeapHooray/wine-d2d1-msi](https://github.com/HeapHeapHooray/wine-d2d1-msi) in real time, applies them, and layers custom patches from this repository.

---

## Architecture & How It Works

1. **Real-time Base Patch Retrieval**:
   `build.sh` clones or updates [HeapHeapHooray/wine-d2d1-msi](https://github.com/HeapHeapHooray/wine-d2d1-msi) in real time into `.work/wine-d2d1-msi` to borrow its patch series.

2. **Base Wine Tree Management**:
   The base Wine repository (`GIANG17_REPO`) and pinned commit (`GIANG17_COMMIT`) are configured directly in `wine-mozart`'s `build.sh` (defaulting to giang17's Wine `d2d1-dcomp-11.0` @ `46c43a2db62ceeac1b33b31bccdebda65ef7f770`).

3. **Base Patch Application**:
   Applies the base patches from `wine-d2d1-msi` in numerical order:
   - `0007-msi-rewrite-all-tables-on-long-strref.mypatch` — Wine MSI string-table corruption fix (Option A, Native Instruments InstallAware installers).
   - `0008-wined3d-only-map-host-visible-bo.mypatch` — wined3d Vulkan host-visible buffer mapping fix for Kontakt 8 D3D backend.
   - `0009-mscoree-implement-CLRRuntimeInfo_GetProcAddress-and-IManagedInstaller.mypatch` — VS/WiX managed installer Custom Actions (`IManagedInstaller`).
   - `0010-wbemprox-implement-Win32_Service-Create-and-fix-wmic.mypatch` — `wbemprox` implementation of `Win32_Service.Create` and `wmic.exe` formatting.
   - `0011-wminet_utils-implement-COM-delegate-forwarding-and-_f-exports.mypatch` — `wminet_utils.dll` COM forwarding and `_f` export aliases for Mono `System.Management.dll`.
   - `0012-opengl-support-child-window-and-egl-pfd-draw-to-window.mypatch` — OpenGL child window context creation, EGL `PFD_DRAW_TO_WINDOW` flags, and cursor handling.
   - `0013-configure-fallback-soname-libgl-and-libegl.mypatch` — Linux runtime fallback for `SONAME_LIBGL` and `SONAME_LIBEGL`.
   - `0014-crypt32-preserve-pkcs-attributes-order.mypatch` — Preserves input attribute order in `CRYPT_AsnEncodePKCSAttributes` for FL Studio Authenticode verification.

4. **Custom Mozart Patch Application**:
   Applies any custom patches found in `patches/*.mypatch` or `patches/*.patch` in natural version order (`sort -V`).

5. **Build & Package**:
   Configures Wine with `--prefix="/opt/wine-mozart-11.0" --enable-archs=i386,x86_64` (new-WoW64 architecture, no 32-bit Linux host libraries required), compiles using specified `-j` and `-l` options, and packages the result into `dist/wine-mozart-11.0-x86_64.tar.xz`.

---

## Quick Start

### Build Requirements
- Linux x86_64
- Standard C cross-compiler toolchain: `mingw-w64`, `bison`, `flex`, `autoconf`, `perl`, `gettext`
- Vulkan and X11 development headers: `libvulkan-dev`, `libfreetype-dev`, etc.
- If dependencies are missing, `build.sh` prompts to install them automatically with `apt`.

### Building

```bash
# Full build and package (uses all CPU cores by default):
./build.sh

# Build with custom parallelism and load limits:
./build.sh -j 8 -l 16

# Or prepare only (clones in real time and applies all patches without compiling):
./build.sh --prepare
```

### Adding Custom Patches

To add custom patches to `wine-mozart`:

1. Drop your `.mypatch` or `.patch` file into the `patches/` folder:
   ```bash
   cp my-fix.patch patches/0015-my-fix.mypatch
   ```
2. Run `./build.sh` (or `./build.sh --prepare` to test patch application).

---

## Installing the Runner

Once built, the archive is located at `dist/wine-mozart-11.0-x86_64.tar.xz`.

### cheapwine
```bash
tar -xJf dist/wine-mozart-11.0-x86_64.tar.xz -C ~/.local/share/cheapwine/runners/
```

Initialize a prefix using the runner:
```bash
cheapwine init --runner="wine-mozart-11.0"
```

### Bottles
```bash
tar -xJf dist/wine-mozart-11.0-x86_64.tar.xz -C ~/.local/share/bottles/runners/
```
