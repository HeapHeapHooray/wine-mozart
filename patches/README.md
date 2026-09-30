# wine-mozart custom patches

Place custom patches (`.mypatch` or `.patch` files) in this directory.

`build.sh` automatically discovers all `*.mypatch` and `*.patch` files in this directory
and applies them in version/alphabetical order (`sort -V`) after the base patches
from `HeapHeapHooray/wine-d2d1-msi` (0007-0014) have been applied.

Suggested naming convention for custom patches:
- `0015-feature-name.mypatch`
- `0016-another-fix.mypatch`
