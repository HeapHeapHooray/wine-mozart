#!/usr/bin/env bash
# =============================================================================
# build.sh — Build the wine-mozart runner
#
# Clones the base patches from https://github.com/HeapHeapHooray/wine-d2d1-msi
# in real time, clones the base Wine repository (giang17/wine), applies base
# patches, applies custom patches from patches/, and builds the runner package.
#
# Output: dist/wine-mozart-11.0-x86_64.tar.xz
# =============================================================================
set -euo pipefail

PKG_NAME="wine-mozart"
WINE_VERSION="11.0"
PKG_BASENAME="${PKG_NAME}-${WINE_VERSION}"

GIANG17_REPO="${GIANG17_REPO:-https://github.com/giang17/wine.git}"
GIANG17_BRANCH="${GIANG17_BRANCH:-d2d1-dcomp-11.0}"
GIANG17_COMMIT="${GIANG17_COMMIT:-496ddf7abf6fc92644ea0cbb8f128d0336c51e25}"

D2D1_MSI_REPO="${D2D1_MSI_REPO:-https://github.com/HeapHeapHooray/wine-d2d1-msi.git}"
D2D1_MSI_BRANCH="${D2D1_MSI_BRANCH:-main}"

cd "$(dirname "$0")"
REPO_ROOT="$PWD"
WORKDIR="$PWD/.work"
D2D1_MSI_DIR="$WORKDIR/wine-d2d1-msi"
SRC="$WORKDIR/wine"
BUILD="$WORKDIR/build"
STAGE="$WORKDIR/stage"
DIST="$REPO_ROOT/dist"

MODE="all"
JOBS="$(nproc)"
LOAD=""

while [ $# -gt 0 ]; do
    case "$1" in
        -j)
            if [ -n "${2:-}" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
                JOBS="$2"
                shift 2
            else
                echo "Error: -j requires a positive integer argument" >&2
                exit 1
            fi
            ;;
        -j[0-9]*)
            JOBS="${1#-j}"
            shift
            ;;
        --jobs=*)
            JOBS="${1#--jobs=}"
            shift
            ;;
        --jobs)
            if [ -n "${2:-}" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
                JOBS="$2"
                shift 2
            else
                echo "Error: --jobs requires a positive integer argument" >&2
                exit 1
            fi
            ;;
        -l)
            if [ -n "${2:-}" ] && [[ "$2" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                LOAD="$2"
                shift 2
            else
                echo "Error: -l requires a numeric argument" >&2
                exit 1
            fi
            ;;
        -l[0-9]*)
            LOAD="${1#-l}"
            shift
            ;;
        --load-average=*|--max-load=*)
            LOAD="${1#*=}"
            shift
            ;;
        --load-average|--max-load)
            if [ -n "${2:-}" ] && [[ "$2" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                LOAD="$2"
                shift 2
            else
                echo "Error: -l requires a numeric argument" >&2
                exit 1
            fi
            ;;
        --fetch-patches)
            MODE="fetch-patches"
            shift
            ;;
        --fetch-wine)
            MODE="fetch-wine"
            shift
            ;;
        --apply-patches)
            MODE="apply-patches"
            shift
            ;;
        --prepare|--patch-only)
            MODE="prepare"
            shift
            ;;
        --configure)
            MODE="configure"
            shift
            ;;
        --build|--compile)
            MODE="build"
            shift
            ;;
        --package)
            MODE="package"
            shift
            ;;
        --clean)
            echo "Cleaning build and stage directories..."
            rm -rf "$BUILD" "$STAGE"
            echo "Clean complete."
            exit 0
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Execution modes:"
            echo "  (default)                 Run all stages in sequence"
            echo "  --fetch-patches           Clone/update base patches (wine-d2d1-msi)"
            echo "  --fetch-wine              Clone/update base Wine tree (giang17)"
            echo "  --apply-patches           Apply base and custom patches to base Wine tree"
            echo "  --prepare, --patch-only   Run fetch-patches, fetch-wine, and apply-patches"
            echo "  --configure               Run configure in build directory"
            echo "  --build, --compile        Run make compilation"
            echo "  --package                 Stage installation and create dist tarball"
            echo "  --clean                   Remove build and stage artifacts"
            echo "  -h, --help                Show this help message"
            echo ""
            echo "Build tuning:"
            echo "  -j, --jobs <N>            Number of parallel build jobs (default: $(nproc))"
            echo "  -l, --load-average <N>    Maximum system load average for make"
            echo ""
            echo "Environment overrides:"
            echo "  GIANG17_REPO              Base Wine repository URL"
            echo "  GIANG17_BRANCH            Base Wine branch"
            echo "  GIANG17_COMMIT            Base Wine commit"
            echo "  D2D1_MSI_REPO             Git repository URL for base patches"
            echo "  D2D1_MSI_BRANCH           Git branch for base patches (default: main)"
            echo "  INSTALL_DEPS=yes|no       Non-interactive dependency installation control"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1
            ;;
    esac
done

mkdir -p "$WORKDIR" "$DIST" "$REPO_ROOT/patches"

# --- 0. Build dependencies --------------------------------------------------
step_deps() {
    need_deps() {
        ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1 || \
        ! command -v bison >/dev/null 2>&1 || \
        ! command -v flex  >/dev/null 2>&1 || \
        ! pkg-config --exists gstreamer-1.0 gstreamer-video-1.0 gstreamer-audio-1.0 gstreamer-tag-1.0 >/dev/null 2>&1
    }

    if need_deps; then
        echo "Some Wine build dependencies are missing (mingw-w64, bison, flex, gstreamer, ...)."
        if [ -t 0 ]; then
            read -r -p "Install them now with apt (uses sudo)? [y/N] " ans
        else
            ans="${INSTALL_DEPS:-no}"
        fi
        case "$ans" in
            y|Y|yes)
                sudo apt-get update
                sudo apt-get install -y --no-install-recommends \
                    build-essential mingw-w64 bison flex autoconf perl gettext \
                    libfreetype-dev libfontconfig-dev libpng-dev libjpeg-dev \
                    libgif-dev libgnutls28-dev libasound2-dev libpulse-dev \
                    libxcomposite-dev libxcursor-dev libxrandr-dev libxi-dev \
                    libxinerama-dev libvulkan-dev libgl-dev libegl-dev \
                    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
                ;;
            *) echo "Continuing anyway — the build may fail if deps are missing." ;;
        esac
    fi
}

# --- 1. Clone base patches from wine-d2d1-msi in real time ------------------
step_fetch_patches() {
    echo "========================================================================"
    echo " 🧩 Cloning base patches from $D2D1_MSI_REPO in real time"
    echo "========================================================================"
    mkdir -p "$WORKDIR" "$DIST" "$REPO_ROOT/patches"
    if [ ! -d "$D2D1_MSI_DIR/.git" ]; then
        rm -rf "$D2D1_MSI_DIR"
        echo "Cloning fresh $D2D1_MSI_REPO ($D2D1_MSI_BRANCH)..."
        git clone --depth 1 -b "$D2D1_MSI_BRANCH" "$D2D1_MSI_REPO" "$D2D1_MSI_DIR"
    else
        echo "Fetching latest base patches from $D2D1_MSI_REPO in real time..."
        git -C "$D2D1_MSI_DIR" fetch --depth 1 origin "$D2D1_MSI_BRANCH"
        git -C "$D2D1_MSI_DIR" checkout -q FETCH_HEAD
    fi
}

# --- 2. Clone / fetch base Wine repository in real time ----------------------
step_fetch_wine() {
    echo "========================================================================"
    echo " 🍷 Fetching base Wine repository ($GIANG17_REPO @ $GIANG17_COMMIT)"
    echo "========================================================================"
    mkdir -p "$WORKDIR"
    if [ ! -d "$SRC/.git" ]; then
        echo "Cloning base Wine repository in real time..."
        git clone --no-checkout "$GIANG17_REPO" "$SRC"
    fi

    cd "$SRC"
    echo "Fetching and checking out commit $GIANG17_COMMIT in real time..."
    git fetch --depth 1 origin "$GIANG17_COMMIT" 2>/dev/null || git fetch origin "$GIANG17_BRANCH"
    git checkout -q "$GIANG17_COMMIT"
    git restore .
    git clean -fd
}

# --- 3. Apply base and custom patches ---------------------------------------
step_apply_patches() {
    echo "========================================================================"
    echo " 🩹 Applying base patches from wine-d2d1-msi"
    echo "========================================================================"
    if [ ! -d "$D2D1_MSI_DIR/patches" ]; then
        echo "ERROR: Base patch directory not found at $D2D1_MSI_DIR/patches" >&2
        echo "Run '$0 --fetch-patches' first." >&2
        exit 1
    fi
    if [ ! -d "$SRC/.git" ]; then
        echo "ERROR: Base Wine source directory not found at $SRC" >&2
        echo "Run '$0 --fetch-wine' first." >&2
        exit 1
    fi

    cd "$SRC"
    git restore .
    git clean -fd

    shopt -s nullglob
    base_patches=("$D2D1_MSI_DIR"/patches/*.mypatch "$D2D1_MSI_DIR"/patches/*.patch)
    shopt -u nullglob

    if [ ${#base_patches[@]} -eq 0 ]; then
        echo "ERROR: No base patches found in $D2D1_MSI_DIR/patches!" >&2
        exit 1
    fi

    IFS=$'\n' sorted_base=($(sort -V <<<"${base_patches[*]}")); unset IFS
    for p in "${sorted_base[@]}"; do
        echo "Applying base patch: $(basename "$p")"
        git apply --stat "$p"
        git apply "$p"
    done

    echo "========================================================================"
    echo " 🩹 Applying wine-mozart custom patches"
    echo "========================================================================"
    shopt -s nullglob
    mozart_patches=("$REPO_ROOT"/patches/*.mypatch "$REPO_ROOT"/patches/*.patch)
    shopt -u nullglob

    if [ ${#mozart_patches[@]} -eq 0 ]; then
        echo "No custom wine-mozart patches found in patches/ (none added yet)."
    else
        echo "Found ${#mozart_patches[@]} custom wine-mozart patch(es):"
        IFS=$'\n' sorted_mozart=($(sort -V <<<"${mozart_patches[*]}")); unset IFS
        for p in "${sorted_mozart[@]}"; do
            echo "Applying custom wine-mozart patch: $(basename "$p")"
            git apply --stat "$p"
            git apply "$p"
        done
    fi
}

# --- 4. Configure Wine ------------------------------------------------------
step_configure() {
    echo "========================================================================"
    echo " ⚙️ Configuring Wine (new-WoW64, no lib32 deps)"
    echo "========================================================================"
    if [ ! -f "$SRC/configure" ]; then
        echo "ERROR: configure script not found in $SRC" >&2
        exit 1
    fi
    mkdir -p "$BUILD"
    cd "$BUILD"
    echo "Running configure..."
    "$SRC/configure" --prefix="/opt/$PKG_BASENAME" --enable-archs=i386,x86_64
}

# --- 5. Compile Wine --------------------------------------------------------
step_build() {
    echo "========================================================================"
    echo " 🔨 Compiling Wine runner"
    echo "========================================================================"
    if [ ! -f "$BUILD/Makefile" ]; then
        echo "ERROR: Makefile not found in $BUILD. Run '$0 --configure' first." >&2
        exit 1
    fi
    cd "$BUILD"
    # Remove any zero-byte files that may have been left behind by an interrupted build
    find "$BUILD" -type f -size 0 -delete 2>/dev/null || true

    MAKE_ARGS=(-j"$JOBS")
    if [ -n "$LOAD" ]; then
        MAKE_ARGS+=(-l"$LOAD")
    fi
    echo "Compiling with: make ${MAKE_ARGS[*]}..."
    make "${MAKE_ARGS[@]}"
}

# --- 6. Stage and package runner archive ------------------------------------
step_package() {
    echo "========================================================================"
    echo " 📦 Staging and packaging the runner"
    echo "========================================================================"
    STAGE="$WORKDIR/stage"
    RUNNER_DIR="$WORKDIR/${PKG_BASENAME}-x86_64"

    if [ ! -d "$STAGE/opt/$PKG_BASENAME" ]; then
        if [ ! -f "$BUILD/Makefile" ]; then
            echo "ERROR: Neither pre-staged directory nor build directory found." >&2
            echo "Run build first or provide $STAGE/opt/$PKG_BASENAME." >&2
            exit 1
        fi
        rm -rf "$STAGE"
        make -C "$BUILD" DESTDIR="$STAGE" -j"$JOBS" install
    else
        echo "Using existing staged runner in $STAGE/opt/$PKG_BASENAME"
    fi

    rm -rf "$RUNNER_DIR"
    mkdir -p "$RUNNER_DIR"
    cp -a "$STAGE/opt/$PKG_BASENAME/." "$RUNNER_DIR/"

    mkdir -p "$DIST"
    export XZ_OPT="${XZ_OPT:--T$JOBS}"
    ARCHIVE_PATH="$DIST/${PKG_BASENAME}-x86_64.tar.xz"
    echo "Creating archive $ARCHIVE_PATH..."
    tar cJvf "$ARCHIVE_PATH" -C "$WORKDIR" "${PKG_BASENAME}-x86_64"
    sha256sum "$ARCHIVE_PATH" > "${ARCHIVE_PATH}.sha256"

    echo ""
    echo "========================================================================"
    echo " 🎉 Build successful!"
    echo " Package: $ARCHIVE_PATH"
    echo ""
    echo " Install (cheapwine):"
    echo "   tar -xJf $ARCHIVE_PATH -C ~/.local/share/cheapwine/runners/"
    echo ""
    echo " Install (Bottles):"
    echo "   tar -xJf $ARCHIVE_PATH -C ~/.local/share/bottles/runners/"
    echo "========================================================================"
}

# --- Dispatch based on selected mode ----------------------------------------
case "$MODE" in
    fetch-patches)
        step_fetch_patches
        ;;
    fetch-wine)
        step_fetch_wine
        ;;
    apply-patches)
        step_apply_patches
        ;;
    prepare)
        step_fetch_patches
        step_fetch_wine
        step_apply_patches
        ;;
    configure)
        step_configure
        ;;
    build)
        step_build
        ;;
    package)
        step_package
        ;;
    all)
        step_deps
        step_fetch_patches
        step_fetch_wine
        step_apply_patches
        step_configure
        step_build
        step_package
        ;;
esac
