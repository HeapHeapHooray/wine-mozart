#!/usr/bin/env bash
# =============================================================================
# build.sh — Build the wine-mozart runner
#
# Clones the base patches from https://github.com/HeapHeapHooray/wine-d2d1-msi
# in real time, reads the base Wine repo constants from its build.sh,
# clones the base Wine repo in real time, applies the base patches,
# applies wine-mozart's own custom patches from patches/, and builds it.
#
# Output: dist/wine-mozart-11.0-x86_64.tar.xz
# =============================================================================
set -euo pipefail

PKG_NAME="wine-mozart"
WINE_VERSION="11.0"
PKG_BASENAME="${PKG_NAME}-${WINE_VERSION}"

GIANG17_REPO="${GIANG17_REPO:-https://github.com/giang17/wine.git}"
GIANG17_BRANCH="${GIANG17_BRANCH:-d2d1-dcomp-11.0}"
GIANG17_COMMIT="${GIANG17_COMMIT:-46c43a2db62ceeac1b33b31bccdebda65ef7f770}"

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

MODE="build"
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
        --patch-only|--prepare)
            MODE="patch-only"
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
            echo "Options:"
            echo "  -j, --jobs <N>            Number of parallel build jobs (default: $(nproc))"
            echo "  -l, --load-average <N>    Maximum system load average for make"
            echo "  --prepare, --patch-only   Clone in real time and apply patches without compiling"
            echo "  --clean                   Remove build and stage artifacts"
            echo "  -h, --help                Show this help message"
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

# --- 0. Build dependencies (optional, asks first) ---------------------------
need_deps() {
    ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1 || \
    ! command -v bison >/dev/null 2>&1 || \
    ! command -v flex  >/dev/null 2>&1
}

if need_deps; then
    echo "Some Wine build dependencies are missing (mingw-w64, bison, flex, ...)."
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
                libxinerama-dev libvulkan-dev libgl-dev libegl-dev
            ;;
        *) echo "Continuing anyway — the build may fail if deps are missing." ;;
    esac
fi

# --- 1. Clone base patches from wine-d2d1-msi in real time ------------------
echo "========================================================================"
echo " Step 1: Cloning base patches from $D2D1_MSI_REPO in real time"
echo "========================================================================"
if [ ! -d "$D2D1_MSI_DIR/.git" ]; then
    rm -rf "$D2D1_MSI_DIR"
    echo "Cloning fresh $D2D1_MSI_REPO ($D2D1_MSI_BRANCH)..."
    git clone --depth 1 -b "$D2D1_MSI_BRANCH" "$D2D1_MSI_REPO" "$D2D1_MSI_DIR"
else
    echo "Fetching latest base patches from $D2D1_MSI_REPO in real time..."
    git -C "$D2D1_MSI_DIR" fetch --depth 1 origin "$D2D1_MSI_BRANCH"
    git -C "$D2D1_MSI_DIR" checkout -q FETCH_HEAD
fi

# --- 2. Clone / fetch base Wine repository in real time ----------------------
echo "========================================================================"
echo " Step 2: Fetching base Wine repository ($GIANG17_REPO @ $GIANG17_COMMIT)"
echo "========================================================================"
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

# --- 3. Apply base patches from wine-d2d1-msi -------------------------------
echo "========================================================================"
echo " Step 3: Applying base patches from wine-d2d1-msi"
echo "========================================================================"
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

# --- 4. Apply wine-mozart custom patches (from patches/) ---------------------
echo "========================================================================"
echo " Step 4: Applying wine-mozart custom patches"
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

if [ "$MODE" = "patch-only" ]; then
    echo ""
    echo "========================================================================"
    echo " Preparation and patch application complete! (--patch-only specified)"
    echo " Source tree is ready at: $SRC"
    echo "========================================================================"
    exit 0
fi

# --- 5. Configure + build (new-WoW64, no lib32 deps) ------------------------
echo "========================================================================"
echo " Step 5: Configuring and building Wine"
echo "========================================================================"
mkdir -p "$BUILD"
cd "$BUILD"

echo "Running configure..."
"$SRC/configure" --prefix="/opt/$PKG_BASENAME" --enable-archs=i386,x86_64

MAKE_ARGS=(-j"$JOBS")
if [ -n "$LOAD" ]; then
    MAKE_ARGS+=(-l"$LOAD")
fi

echo "Compiling with: make ${MAKE_ARGS[*]}..."
make "${MAKE_ARGS[@]}"

# --- 6. Stage + package the runner ------------------------------------------
echo "========================================================================"
echo " Step 6: Staging and packaging the runner"
echo "========================================================================"
STAGE="$WORKDIR/stage"
rm -rf "$STAGE"
make DESTDIR="$STAGE" install

RUNNER_DIR="$WORKDIR/${PKG_BASENAME}-x86_64"
rm -rf "$RUNNER_DIR"
mkdir -p "$RUNNER_DIR"
cp -a "$STAGE/opt/$PKG_BASENAME/." "$RUNNER_DIR/"

export XZ_OPT="${XZ_OPT:--T$JOBS}"
ARCHIVE_PATH="$DIST/${PKG_BASENAME}-x86_64.tar.xz"
echo "Creating archive $ARCHIVE_PATH..."
tar cJvf "$ARCHIVE_PATH" -C "$WORKDIR" "${PKG_BASENAME}-x86_64"

echo ""
echo "========================================================================"
echo " Build successful!"
echo " Package: $ARCHIVE_PATH"
echo ""
echo " Install (cheapwine):"
echo "   tar -xJf $ARCHIVE_PATH -C ~/.local/share/cheapwine/runners/"
echo ""
echo " Install (Bottles):"
echo "   tar -xJf $ARCHIVE_PATH -C ~/.local/share/bottles/runners/"
echo "========================================================================"
