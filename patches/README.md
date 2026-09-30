# wine-mozart custom patches

Place custom patches (`.mypatch` or `.patch` files) in this directory.

`build.sh` automatically discovers all `*.mypatch` and `*.patch` files in this directory
and applies them in version/alphabetical order (`sort -V`) after the base patches
cloned from `HeapHeapHooray/wine-d2d1-msi` have been applied.

Suggested naming convention for custom patches:
- `01-feature-name.mypatch`
- `02-another-fix.mypatch`
