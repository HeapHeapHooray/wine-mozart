# wine-mozart — The Official Wine Runner for mozart.sh

**wine-mozart** is the official Wine runner of the **mozart.sh** project, which aims to make music production on Linux simple, reliable, and accessible.

Engineered specifically for pro-audio workloads, digital audio workstations (DAWs), VST/VST3/CLAP plugins, and proprietary audio software installers, `wine-mozart` builds on top of `giang17/wine` with Direct2D 1.3 / DirectComposition support, dynamically integrates real-time patches from [HeapHeapHooray/wine-d2d1-msi](https://github.com/HeapHeapHooray/wine-d2d1-msi), and layers custom Mozart-specific optimizations to deliver an out-of-the-box Windows audio environment on Linux.

---

## Architecture & How It Works

1. **Real-time Base Patch Retrieval**:
   `build.sh` clones or updates [HeapHeapHooray/wine-d2d1-msi](https://github.com/HeapHeapHooray/wine-d2d1-msi) in real time into `.work/wine-d2d1-msi` to borrow its patch series.

2. **Base Wine Tree Management**:
   The base Wine repository (`GIANG17_REPO`) and pinned commit (`GIANG17_COMMIT`) are configured directly in `wine-mozart`'s `build.sh` (defaulting to giang17's Wine `d2d1-dcomp-11.0` @ `46c43a2db62ceeac1b33b31bccdebda65ef7f770`).

3. **Base Patch Application**:
   Discovers and applies all base patches (`*.mypatch` and `*.patch`) dynamically fetched from `wine-d2d1-msi` in natural version order (`sort -V`).

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
   cp my-fix.patch patches/my-fix.mypatch
   ```
2. Run `./build.sh` (or `./build.sh --prepare` to test patch application).

---

## Installing the Runner

Once built, the archive is located at `dist/wine-mozart-11.0-x86_64.tar.xz`.

### mozart.sh / cheapwine
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
