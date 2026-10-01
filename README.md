# wine-mozart — The Official Wine Runner for mozart.sh

**wine-mozart** is the official Wine runner of the **mozart.sh** project, which aims to make music production on Linux simple, reliable, and accessible.

Engineered specifically for pro-audio workloads, digital audio workstations (DAWs), VST/VST3/CLAP plugins, and proprietary audio software installers, `wine-mozart` builds on top of `giang17/wine` with Direct2D 1.3 / DirectComposition support, dynamically integrates real-time patches from [HeapHeapHooray/wine-d2d1-msi](https://github.com/HeapHeapHooray/wine-d2d1-msi), and layers custom Mozart-specific optimizations to deliver an out-of-the-box Windows audio environment on Linux.

---

## Compatible Software, DAWs & Instruments

> [!IMPORTANT]
> Fully-working software is only guaranteed by using this runner with the installers of the **mozart.sh** project.

`wine-mozart` resolves Wine engine regressions, Direct2D/DirectComposition GUI rendering bottlenecks, Authenticode signature checks, and MSI string-pool corruption to make demanding audio production software run effortlessly on Linux:

- **DAWs & Hosts**:
  - **FL Studio (late-2026)**: Fixes Authenticode signature verification (`TRUST_E_CERT_SIGNATURE` / `0x80096004`) in `FL64.exe` verifying `FLEngine_x64.dll`, along with full Direct2D/DirectComposition plugin hosting support.
- **Samplers & Instrument Ecosystems**:
  - **Native Access & Kontakt 8**: Solves Wine MSI string-table database corruption during in-place InstallAware installations, and fixes `wined3d` Vulkan host-visible buffer mapping for Kontakt 8's Direct3D rendering backend.
  - **EastWest Installation Center & OPUS (including 1.6.5)**: Clean execution for library installations and high-resolution engine rendering.
  - **Heavyocity Portal**: Resolves managed installer Custom Action failures (InstallUtil / WiX error 1603) via `mscoree` CLRRuntimeInfo and `IManagedInstaller` COM fallback.
- **Synths, Modern GUIs & Plugins**:
  - **Direct2D 1.3 & DirectComposition GUIs**: Eliminates black/blank window bugs in JUCE 8, VSTGUI, and SynthEdit plugin interfaces (e.g. Pianoteq 9, Serum 2, Korg Trinity / Prophecy, EZkeys 2, Garritan CFX).
  - **OpenGL & EGL Hybrid Plugins**: Supports OpenGL child window context creation, safe cross-connection cursors, and EGL window rendering (e.g. Copycat VST3/CLAP, IK Multimedia Pianoverse).
  - **WMI & Service-Based Installers**: Supports Windows service creation and Mono P/Invoke delegate forwarding for modern instrument installers (e.g. Crow Hill App, Westwood ROOTS, Pocket Strings, Vaults).

---

## Architecture & How It Works

1. **Real-time Base Patch Retrieval**:
   `build.sh` clones or updates [HeapHeapHooray/wine-d2d1-msi](https://github.com/HeapHeapHooray/wine-d2d1-msi) in real time into `.work/wine-d2d1-msi` to borrow its patch series.

2. **Base Wine Tree Management**:
   The base Wine repository (`GIANG17_REPO`) and pinned commit (`GIANG17_COMMIT`) are configured directly in `wine-mozart`'s `build.sh` (defaulting to giang17's Wine `d2d1-dcomp-11.0` @ `496ddf7abf6fc92644ea0cbb8f128d0336c51e25`).

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

## Installing & Using the Runner

### Automatic Installation via cheapwine (Recommended)

`cheapwine` natively supports automatic downloading and installation of `wine-mozart` releases:

```bash
cheapwine init --runner "wine-mozart"
```

Running this command will automatically fetch, download, and unpack the latest `wine-mozart` release into your local runners directory without requiring manual downloads.

### Manual Installation (Local Builds or Releases)

If you are using a local build (`dist/wine-mozart-11.0-x86_64.tar.xz`) or manual release archive:

#### cheapwine
```bash
tar -xJf dist/wine-mozart-11.0-x86_64.tar.xz -C ~/.local/share/cheapwine/runners/
cheapwine init --runner "wine-mozart"
```

#### Bottles
```bash
tar -xJf dist/wine-mozart-11.0-x86_64.tar.xz -C ~/.local/share/bottles/runners/
```
