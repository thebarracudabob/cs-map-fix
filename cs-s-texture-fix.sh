#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 Barracuda Bob
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Counter-Strike: Source Custom Map Texture Fix
# Fixes pink/black checkerboard textures caused by:
#   - Case-sensitivity mismatches (Windows maps on Linux)
#   - Backslash paths in VMT files (Windows -> Linux)
#   - Special characters in filenames (!, brackets, etc.)
#
# Usage: ./cs-s-texture-fix.sh [/path/to/cstrike]
# If no path given, auto-detects CS:S installation.
# Works on any Linux distribution with bash, unzip, and coreutils.

set -euo pipefail

check_deps() {
  for cmd in unzip find sed realpath; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Error: '$cmd' not found. Install it with your package manager." >&2
      exit 1
    fi
  done
}

# ---- Auto-detect CS:S installation ----
find_css() {
  local dir lib candidate line vdf

  # Check common locations
  for dir in \
    "$HOME/.local/share/Steam/steamapps/common/Counter-Strike Source/cstrike" \
    "$HOME/.steam/steam/steamapps/common/Counter-Strike Source/cstrike" \
    "/usr/share/steam/steamapps/common/Counter-Strike Source/cstrike"; do
    [ -d "$dir" ] && [ -f "$dir/gameinfo.txt" ] && { echo "$dir"; return 0; }
  done

  # Scan Steam library folders from libraryfolders.vdf
  for vdf in \
    "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf" \
    "$HOME/.steam/steam/steamapps/libraryfolders.vdf"; do
    if [ -f "$vdf" ]; then
      while IFS= read -r line; do
        case "$line" in
          *'"path"'*)
            lib=$(echo "$line" | sed 's/.*"path"[[:space:]]*"\(.*\)"/\1/')
            candidate="$lib/steamapps/common/Counter-Strike Source/cstrike"
            [ -d "$candidate" ] && [ -f "$candidate/gameinfo.txt" ] && { echo "$candidate"; return 0; }
            ;;
        esac
      done < "$vdf"
    fi
  done

  return 1
}

# ---- Main ----
main() {
  check_deps

  local CSDIR
  if [ -n "${1:-}" ]; then
    CSDIR="$1"
  else
    CSDIR=$(find_css) || true
  fi

  if [ -z "$CSDIR" ] || [ ! -d "$CSDIR" ]; then
    echo "Error: CS:S installation not found."
    echo ""
    echo "Usage: $0 [/path/to/cstrike]"
    echo ""
    echo "The cstrike directory is usually found at:"
    echo "  ~/.local/share/Steam/steamapps/common/Counter-Strike Source/cstrike"
    exit 1
  fi

  echo "Counter-Strike: Source found at: $CSDIR"

  local CUSTOM="$CSDIR/custom"
  mkdir -p "$CUSTOM"

  # Collect map directories
  local MAPDIRS=()
  if [ -d "$CSDIR/download/maps" ]; then
    MAPDIRS+=("$CSDIR/download/maps")
  fi

  # ---- Step 1: Extract BSP pakfiles ----
  echo ""
  echo "=== Step 1: Extract BSP pakfiles ==="
  local map_count=0 skipped_count=0 mapname target vmt_count
  for mapdir in "${MAPDIRS[@]}"; do
    for bsp in "$mapdir"/*.bsp; do
      [ -f "$bsp" ] || continue
      mapname=$(basename "$bsp" .bsp)
      target="$CUSTOM/$mapname"

      # Check if BSP has embedded VMT files worth fixing
      vmt_count=$(unzip -l "$bsp" 2>/dev/null | grep -c '\.vmt$' || true)
      if [ "$vmt_count" -eq 0 ]; then
        if [ -d "$target" ]; then
          rm -rf "$target"
          echo "    Removing stale: $mapname (no embedded VMTs, uses VPK textures)"
        fi
        skipped_count=$((skipped_count + 1))
        continue
      fi

      if [ -d "$target" ]; then
        continue
      fi
      echo "    Extracting: $mapname ($vmt_count VMT files)"
      mkdir -p "$target"
      unzip -o "$bsp" -d "$target" > /dev/null 2>&1
      map_count=$((map_count + 1))
    done
  done

  if [ "$map_count" -eq 0 ] && [ "$skipped_count" -eq 0 ]; then
    echo "  No maps found."
  else
    echo "  Extracted $map_count new map(s), skipped $skipped_count (VPK-only)."
  fi

  # ---- Step 2: Convert Windows backslash paths to forward slashes ----
  echo ""
  echo "=== Step 2: Convert Windows backslash paths to forward slashes ==="
  local backslash_fixed=0
  while IFS= read -r -d '' vmt; do
    local text
    text=$(grep -i 'basetexture\|baseTexture' "$vmt" 2>/dev/null || true)
    if echo "$text" | grep -q '\\' 2>/dev/null; then
      sed -i '/basetexture/s/\\/\//g; /baseTexture/s/\\/\//g' "$vmt"
      local rel="${vmt#$CUSTOM/}"
      echo "  $rel"
      backslash_fixed=$((backslash_fixed + 1))
    fi
  done < <(find "$CUSTOM" -name '*.vmt' -print0 2>/dev/null)
  echo "  Fixed: $backslash_fixed VMT(s) with backslash paths"

  # ---- Step 3: Fix case mismatches ----
  echo ""
  echo "=== Step 3: Fix case mismatches (symlink VMT-referenced VTFs to actual files) ==="
  local fixed_total=0

  # Clean up corrupted Windows artifacts
  find "$CUSTOM" -name '*\\*' -type d 2>/dev/null | while IFS= read -r d; do rm -rf "$d"; done 2>/dev/null
  find "$CUSTOM" -xtype l 2>/dev/null | while IFS= read -r l; do rm -f "$l"; done 2>/dev/null

  while IFS= read -r -d '' vmt; do
    local tex tex_fwd mapdir expected tex_name actual rel
    tex=$(grep -i '^\s*"\$basetexture"\s' "$vmt" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    [ -z "$tex" ] && tex=$(grep -i '^\s*"\$baseTexture"\s' "$vmt" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    [ -z "$tex" ] && continue

    tex_fwd=$(echo "$tex" | tr '\\' '/')
    mapdir="${vmt%materials/*}"
    expected="${mapdir}materials/${tex_fwd}.vtf"

    [ -f "$expected" ] || [ -L "$expected" ] && continue

    tex_name=$(basename "$tex_fwd").vtf
    actual=$(find "$mapdir/materials" -iname "$tex_name" 2>/dev/null | head -1)

    if [ -n "$actual" ]; then
      mkdir -p "$(dirname "$expected")"
      ln -sf "$(realpath --relative-to="$(dirname "$expected")" "$actual")" "$expected"
      rel="${vmt#$CUSTOM/}"
      echo "  $rel"
      fixed_total=$((fixed_total + 1))
    fi
  done < <(find "$CUSTOM" -name '*.vmt' -print0 2>/dev/null)

  # Fix bracket-named textures (find can't match literal brackets with -iname)
  while IFS= read -r -d '' vmt; do
    local tex tex_fwd mapdir expected dir tex_name glob_pattern actual rel
    tex=$(grep -i '^\s*"\$basetexture"\s' "$vmt" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    [ -z "$tex" ] && tex=$(grep -i '^\s*"\$baseTexture"\s' "$vmt" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    [ -z "$tex" ] && continue

    case "$tex" in *'['*']'*|*' '*)
      tex_fwd=$(echo "$tex" | tr '\\' '/')
      mapdir="${vmt%materials/*}"
      expected="${mapdir}materials/${tex_fwd}.vtf"
      [ -f "$expected" ] || [ -L "$expected" ] && continue

      dir=$(dirname "$expected")
      tex_name=$(basename "$tex_fwd").vtf
      glob_pattern=$(echo "$tex_name" | sed 's/\[/\\[/g; s/\]/\\]/g')
      actual=$(find "$mapdir/materials" -type f -name "$glob_pattern" 2>/dev/null | head -1)

      if [ -n "$actual" ]; then
        mkdir -p "$dir"
        ln -sf "$(realpath --relative-to="$dir" "$actual")" "$expected"
        rel="${vmt#$CUSTOM/}"
        echo "  $rel"
        fixed_total=$((fixed_total + 1))
      fi
    ;;
    esac
  done < <(find "$CUSTOM" -name '*.vmt' -print0 2>/dev/null)

  echo ""
  echo "=== Done ==="
  echo "  Maps extracted: $map_count"
  echo "  Maps skipped (no VMTs, VPK-only): $skipped_count"
  echo "  Backslash fixes: $backslash_fixed"
  echo "  Case fixes: $fixed_total"
  echo ""
  echo "Launch or restart CS:S and connect to your server. Textures should now load correctly."
  echo ""
  echo "Tip: Re-run this script after downloading new maps from servers."
}

main "$@"
