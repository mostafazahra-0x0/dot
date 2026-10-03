#!/usr/bin/env python3
"""caelestia-scheme-to-noctalia.py — convert a Caelestia color scheme to a
Noctalia --theme-json palette so noctalia-managed apps match Caelestia's
active color scheme exactly (not just the wallpaper).

Usage:
  caelestia-scheme-to-noctalia.py \
    --scheme-json ~/.local/state/caelestia/scheme.json \
    --wallpaper <path> [--noct-scheme m3-content] \
    -o /tmp/noctalia-theme.json

Env (set by caelestia theme/wallpaper postHooks, preferred when present):
  SCHEME_NAME SCHEME_FLAVOUR SCHEME_MODE SCHEME_VARIANT SCHEME_COLOURS(json)

Output JSON: {"dark": {token: "#hex", ...}, "light": {...}} ready for:
  noctalia theme --theme-json out.json --default-mode <mode> -r in:out

Strategy:
  - Base maps come from `noctalia theme <wallpaper> --both` (keeps sane values
    for tokens with no Caelestia equivalent, e.g. source_color).
  - The ACTIVE mode map is overridden with converted Caelestia colours.
  - The INACTIVE mode map: static dual-mode flavour's opposite txt file when
    available, else the wallpaper-derived base (or active duplicate).
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

# Caelestia key -> Noctalia token
DIRECT = {
    "background": "background",
    "onBackground": "on_background",
    "surface": "surface",
    "surfaceDim": "surface_dim",
    "surfaceBright": "surface_bright",
    "surfaceContainerLowest": "surface_container_lowest",
    "surfaceContainerLow": "surface_container_low",
    "surfaceContainer": "surface_container",
    "surfaceContainerHigh": "surface_container_high",
    "surfaceContainerHighest": "surface_container_highest",
    "surfaceVariant": "surface_variant",
    "onSurface": "on_surface",
    "onSurfaceVariant": "on_surface_variant",
    "outline": "outline",
    "outlineVariant": "outline_variant",
    "shadow": "shadow",
    "scrim": "scrim",
    "surfaceTint": "surface_tint",
    "inverseSurface": "inverse_surface",
    "inverseOnSurface": "inverse_on_surface",
    "inversePrimary": "inverse_primary",
    "primary": "primary",
    "onPrimary": "on_primary",
    "primaryContainer": "primary_container",
    "onPrimaryContainer": "on_primary_container",
    "primaryFixed": "primary_fixed",
    "primaryFixedDim": "primary_fixed_dim",
    "onPrimaryFixed": "on_primary_fixed",
    "onPrimaryFixedVariant": "on_primary_fixed_variant",
    "secondary": "secondary",
    "onSecondary": "on_secondary",
    "secondaryContainer": "secondary_container",
    "onSecondaryContainer": "on_secondary_container",
    "secondaryFixed": "secondary_fixed",
    "secondaryFixedDim": "secondary_fixed_dim",
    "onSecondaryFixed": "on_secondary_fixed",
    "onSecondaryFixedVariant": "on_secondary_fixed_variant",
    "tertiary": "tertiary",
    "onTertiary": "on_tertiary",
    "tertiaryContainer": "tertiary_container",
    "onTertiaryContainer": "on_tertiary_container",
    "tertiaryFixed": "tertiary_fixed",
    "tertiaryFixedDim": "tertiary_fixed_dim",
    "onTertiaryFixed": "on_tertiary_fixed",
    "onTertiaryFixedVariant": "on_tertiary_fixed_variant",
    "error": "error",
    "onError": "on_error",
    "errorContainer": "error_container",
    "onErrorContainer": "on_error_container",
}

TERM = {
    "term0": "terminal_normal_black",
    "term1": "terminal_normal_red",
    "term2": "terminal_normal_green",
    "term3": "terminal_normal_yellow",
    "term4": "terminal_normal_blue",
    "term5": "terminal_normal_magenta",
    "term6": "terminal_normal_cyan",
    "term7": "terminal_normal_white",
    "term8": "terminal_bright_black",
    "term9": "terminal_bright_red",
    "term10": "terminal_bright_green",
    "term11": "terminal_bright_yellow",
    "term12": "terminal_bright_blue",
    "term13": "terminal_bright_magenta",
    "term14": "terminal_bright_cyan",
    "term15": "terminal_bright_white",
}


def hx(v: str) -> str:
    v = v.strip().lstrip("#")
    if len(v) > 6:
        v = v[:6]
    return "#" + v


def convert(colours: dict) -> dict:
    out: dict = {}
    for ck, nt in DIRECT.items():
        if ck in colours and colours[ck]:
            out[nt] = hx(str(colours[ck]))
    for ck, nt in TERM.items():
        if ck in colours and colours[ck]:
            out[nt] = hx(str(colours[ck]))
    # terminal chrome (mirrors noctalia's own derivation + caelestia's
    # apply_terms which uses secondary as cursor)
    if "surface" in colours:
        out["terminal_background"] = hx(str(colours["surface"]))
        out["terminal_cursor_text"] = hx(str(colours["surface"]))
    if "onSurface" in colours:
        out["terminal_foreground"] = hx(str(colours["onSurface"]))
    if "secondary" in colours:
        out["terminal_cursor"] = hx(str(colours["secondary"]))
    if "onSurfaceVariant" in colours:
        out["terminal_selection_fg"] = hx(str(colours["onSurfaceVariant"]))
    if "surfaceVariant" in colours:
        out["terminal_selection_bg"] = hx(str(colours["surfaceVariant"]))
    return out


def read_txt(path: Path) -> dict:
    cols: dict = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        k, _, v = line.partition(" ")
        if k and v:
            cols[k.strip()] = v.strip()
    return cols


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scheme-json", default="")
    ap.add_argument("--wallpaper", default="")
    ap.add_argument("--noct-scheme", default="m3-content")
    ap.add_argument("-o", "--output", required=True)
    args = ap.parse_args()

    env = os.environ
    state = Path(env.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    scheme_file = Path(args.scheme_json or (state / "caelestia/scheme.json"))

    name = env.get("SCHEME_NAME", "")
    flavour = env.get("SCHEME_FLAVOUR", "")
    mode = env.get("SCHEME_MODE", "")
    colours = None
    if env.get("SCHEME_COLOURS"):
        try:
            colours = json.loads(env["SCHEME_COLOURS"])
        except json.JSONDecodeError:
            colours = None
    file_scheme = {}
    if scheme_file.is_file():
        try:
            file_scheme = json.loads(scheme_file.read_text())
        except json.JSONDecodeError:
            pass
    name = name or file_scheme.get("name", "")
    flavour = flavour or file_scheme.get("flavour", "")
    mode = mode or file_scheme.get("mode", "dark")
    if colours is None:
        colours = file_scheme.get("colours", {})
    if mode not in ("dark", "light"):
        mode = "dark"
    if not colours:
        print("caelestia-scheme-to-noctalia: no scheme colours found", file=sys.stderr)
        return 1

    wallpaper = args.wallpaper or env.get("WALLPAPER_PATH", "")
    if not wallpaper:
        cw = state / "caelestia/wallpaper/path.txt"
        if cw.is_file():
            wallpaper = cw.read_text().strip()

    # Base maps keep every token sane (source_color, unmapped roles).
    base = {"dark": {}, "light": {}}
    if wallpaper and Path(wallpaper).is_file():
        try:
            p = subprocess.run(
                ["noctalia", "theme", wallpaper, "--scheme", args.noct_scheme, "--both"],
                capture_output=True, text=True, timeout=120,
            )
            if p.returncode == 0:
                base = json.loads(p.stdout)
        except Exception as e:
            print(f"caelestia-scheme-to-noctalia: base palette failed: {e}", file=sys.stderr)

    other = "light" if mode == "dark" else "dark"
    opp_colours = None
    if name and flavour and name != "dynamic":
        opp = Path(f"/usr/lib/python3.14/site-packages/caelestia/data/schemes/{name}/{flavour}/{other}.txt")
        if opp.is_file():
            try:
                opp_colours = read_txt(opp)
            except OSError:
                pass

    dark_map = dict(base.get("dark", {}))
    light_map = dict(base.get("light", {}))
    dark_map.update(convert(opp_colours) if (other == "dark" and opp_colours) else (convert(colours) if mode == "dark" else {}))
    light_map.update(convert(opp_colours) if (other == "light" and opp_colours) else (convert(colours) if mode == "light" else {}))
    # Single-mode flavour with no wallpaper base: duplicate active map so the
    # inactive side is never empty.
    if not dark_map and light_map:
        dark_map = dict(light_map)
    if not light_map and dark_map:
        light_map = dict(dark_map)

    out = {"dark": dark_map, "light": light_map}
    Path(args.output).write_text(json.dumps(out))
    n = len(convert(colours))
    print(f"caelestia-scheme-to-noctalia: scheme={name} {flavour} {mode} tokens={n} -> {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
