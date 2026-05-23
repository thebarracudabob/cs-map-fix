# Counter-Strike: Source Custom Map Texture Fix

Date: 2026-05-16

## Problem

Custom maps downloaded from game servers showed pink/black checkerboard textures on Linux.

## Root Cause

The BSP files for custom maps embed textures in a ZIP archive (pakfile). Map authors compile maps on Windows where the filesystem is **case-insensitive**. The `.vmt` material files reference textures with one case (e.g., `$basetexture "band/plainwall"`) but the actual `.vtf` texture files are stored with different case (e.g., `BAND/plainwall.vtf`).

On Windows, `band/` and `BAND/` are the same directory. On Linux, they're different — the texture lookup fails and the engine shows the classic pink/black checkerboard.

Some maps also use Windows backslash paths (`nippertextures\westwood\texture`) which don't work on Linux.

## Maps Fixed

All 14 custom maps in `cstrike/download/maps/` were extracted and fixed:

| Map | Case-Sensitivity Fixes | Notes |
|-----|----------------------|-------|
| `de_westwood_07_ofc` | 104 | Heavy use of `AERISWEET/`, `BAND/`, `NIPPERTEXTURES/` directories with mixed-case mismatches + backslash paths |
| `de_nighthawk_fga` | 32 | `Models/Props/`, `SK3TCH/`, `overviews/` case issues |
| `de_scud_pro` | 21 | `models/ill_hanger/`, duplicated path segments in zip |
| `gg_lego_2floor_dm` | 23 | `Custom_textures/` case mismatches |
| `gg_mario_vs_wario_v2` | 11 | `SIMPSONS/`, `skybox/` case issues |
| `de_foggy_island` | 10 | `OFC/`, `TOOLS/`, `signs/` mismatches |
| `de_red_roofs` | 9 | `ELEVATORBG/`, `NIPPERTEXTURES/`, backslash paths |
| `gg_wolfenstein_3d` | 11 | `FY_GROSSE/`, `CUSTOMS/` mismatches |
| `de_piranesi_x3` | 2 | Radar overview textures |
| `fy_iceworld` | 0 | Uses stock textures only |
| `fy_iceworld_grind_v2` | 0 | Uses stock textures only |
| `gg_64bottles_v2_noecho` | 0 | Uses stock textures only |
| `gg_fy_funtimes` | 0 | Uses stock textures only |

## What Was Done

1. Extracted embedded ZIP archives from all 14 BSP files to `cstrike/custom/<mapname>/`
2. Scanned every `.vmt` file for `$basetexture` / `$baseTexture` references
3. Created symlinks from the exact path the VMT expects to the actual VTF file, when: case mismatch existed, or backslash paths needed conversion to forward slashes
4. Cleaned up corrupted directory entries (duplicated path segments, literal backslash characters in directory names)

## Remaining Unresolved (28)

All are **stock CS:S or HL2 textures** shipped in the game's `.vpk` archives (e.g., `de_dust/groundsand03`, `de_chateau/rockf`, `cs_havana/woodm`). The game finds these automatically from its VPK files. Three VMTs are corrupted with null bytes/backspace characters embedded by the map author — these don't work on any platform.

## Files

- `cs-s-texture-fix.sh` — The fix script
- `cs-s-texture-fix-conversation.md` — This conversation summary
