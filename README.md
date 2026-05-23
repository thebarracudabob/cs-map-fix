# CS:S Custom Map Texture Fix

Fixes pink/black checkerboard textures on custom Counter-Strike: Source maps running on Linux.

## The Problem

Custom maps compiled on Windows embed texture files inside the `.bsp` (pakfile). Windows is **case-insensitive** — map authors write `$basetexture "band/plainwall"` in the material file but store the texture as `BAND/plainwall.vtf`. On Linux the case mismatch causes the texture lookup to fail, showing the classic pink/black checkerboard.

Some maps also use Windows backslash paths (`nippertextures\westwood\texture`) which don't work on Linux.

## What It Does

1. **Scans** `cstrike/download/maps/` for installed `.bsp` files
2. **Extracts** each map's embedded pakfile into `cstrike/custom/<mapname>/`
3. **Fixes backslash paths** in `.vmt` material files (Windows → Linux)
4. **Creates symlinks** from the exact path each `.vmt` expects to the actual `.vtf` file (case mismatch workaround)
5. **Handles special characters** — brackets, spaces, and other symbols in filenames that break `find -iname`

Maps that use only stock VPK textures (no embedded `.vmt` files) are skipped automatically.

## Usage

```bash
# Auto-detect CS:S installation
./cs-s-texture-fix.sh

# Or specify a custom path
./cs-s-texture-fix.sh /path/to/cstrike
```

Run it once after installing new custom maps. The extracted fixes live in `cstrike/custom/` and persist across game updates.

## Requirements

- `bash`
- `unzip`
- `find`, `sed`, `realpath` (part of coreutils)

## Install

```bash
# Clone the repo
git clone https://github.com/thebarracudabob/cs-map-fix.git
cd cs-map-fix

# Make executable
chmod +x cs-s-texture-fix.sh

# Run it
./cs-s-texture-fix.sh
```

## License

SPDX-FileCopyrightText: 2025 Barracuda Bob  
SPDX-License-Identifier: GPL-3.0-or-later
