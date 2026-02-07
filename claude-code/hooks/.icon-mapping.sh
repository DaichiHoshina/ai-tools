#!/usr/bin/env bash
# Unicode Symbol Icon Mapping (Simple, works everywhere)
# Usage: source ~/.claude/hooks/.icon-mapping.sh

# Status icons
ICON_SUCCESS=$'\u2713'      # ✓ check mark (success)
ICON_WARNING=$'\u25b2'      # ▲ triangle (warning)
ICON_ERROR=$'\u2715'        # ✕ multiplication x (error)
ICON_CRITICAL=$'\u25c9'     # ◉ fisheye (critical)
ICON_INFO=$'\u25cf'         # ● circle (info)

# Action icons
ICON_LOADING=$'\u21bb'      # ↻ clockwise arrow (loading/refresh)
ICON_FORBIDDEN=$'\u2297'    # ⊗ circled times (forbidden)
ICON_IDLE=$'\u263e'         # ☾ moon (idle/sleep)
ICON_PIN=$'\u2691'          # ⚑ flag (pin/note)

# Status prefixes
PREFIX_SUCCESS="${ICON_SUCCESS} "
PREFIX_WARNING="${ICON_WARNING} "
PREFIX_ERROR="${ICON_ERROR} "
PREFIX_CRITICAL="${ICON_CRITICAL} "
PREFIX_INFO="${ICON_INFO} "
PREFIX_LOADING="${ICON_LOADING} "
PREFIX_FORBIDDEN="${ICON_FORBIDDEN} "
PREFIX_IDLE="${ICON_IDLE} "
PREFIX_PIN="${ICON_PIN} "
