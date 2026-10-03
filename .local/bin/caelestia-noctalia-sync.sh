#!/usr/bin/env bash
# caelestia-noctalia-sync.sh — keep noctalia-managed app colors in sync
# when running Caelestia (or any non-noctalia shell).
#
# Noctalia re-renders builtin + community templates on wallpaper changes.
# Caelestia's own engine (caelestia wallpaper -> apply_colours) only covers
# Caelestia's set (gtk.css, btop caelestia.theme, fuzzel, zed caelestia.json...).
# It does NOT update noctalia's outputs:
#   kitty/themes/noctalia.conf, ghostty, alacritty, foot, wezterm, starship,
#   gtk noctalia.css, kcolorscheme, qt, obsidian snippets/noctalia.css, ...
#
# This script re-renders the *enabled* noctalia templates for Caelestia's
# ACTIVE color scheme via `caelestia-scheme-to-noctalia.py` + `noctalia theme
# --theme-json -r in:out`, then runs each template's post_hook (kitty reload,
# gtk import, obsidian snippet enable...). App colors therefore match the
# color scheme exactly — static schemes (gruvbox, rosepine…) included.
# If scheme conversion fails it falls back to the wallpaper-derived palette.
# Works even when the noctalia daemon is NOT running (the Caelestia case).
#
# Usage: caelestia-noctalia-sync.sh [wallpaper]
# Env:   WALLPAPER_PATH (set by caelestia wallpaper postHook)
#        SCHEME_MODE    (set by caelestia theme/wallpaper postHook — Caelestia's
#                       current light/dark mode; takes precedence)
#        MODE_OVERRIDE  (manual override for testing: dark|light)

set -u

WALLPAPER="${1:-${WALLPAPER_PATH:-}}"
CAEL_WALL_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/wallpaper/path.txt"
NOCT_SETTINGS="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"
NOCT_CONFIG="$HOME/.config/noctalia/config.toml"
BUILTIN_TOML="/usr/share/noctalia/assets/templates/builtin.toml"
BUILTIN_DIR="/usr/share/noctalia/assets/templates"
COMMUNITY_BASE="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/community-templates"

if [[ -z "$WALLPAPER" && -f "$CAEL_WALL_FILE" ]]; then
  WALLPAPER="$(cat "$CAEL_WALL_FILE")"
fi
if [[ -z "$WALLPAPER" ]]; then
  WALLPAPER="$(python3 - "$NOCT_SETTINGS" <<'PY' 2>/dev/null || true
import sys, tomllib
try:
    d = tomllib.load(open(sys.argv[1],'rb'))
    print(d.get('wallpaper',{}).get('default',{}).get('path',''))
except Exception:
    pass
PY
)"
fi

if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
  echo "caelestia-noctalia-sync: no valid wallpaper (got: '$WALLPAPER')" >&2
  exit 0
fi

# Read prefs: config.toml is the base, settings.toml overlays it
# (settings.toml is GUI-managed and lacks enable_* flags).
eval "$(python3 - "$NOCT_SETTINGS" "$NOCT_CONFIG" <<'PY'
import tomllib
def load(p):
    try:
        return tomllib.load(open(p,'rb'))
    except Exception:
        return {}
s, c = load(__import__('sys').argv[1]), load(__import__('sys').argv[2])
ct, st = c.get('theme', {}), s.get('theme', {})
ctt, stt = ct.get('templates', {}), st.get('templates', {})
def pick(key, default=None):
    return st.get(key, ct.get(key, default))
def pick_tt(key, default=None):
    if key in stt:
        return stt[key]
    return ctt.get(key, default)
import shlex
mode = pick('mode', 'dark')
scheme = pick('wallpaper_scheme', pick('wallpaperScheme', 'm3-content'))
eb = pick_tt('enable_builtin_templates', True)
ec = pick_tt('enable_community_templates', True)
bi = pick_tt('builtin_ids', []) or []
ci = pick_tt('community_ids', []) or []
print(f"NOCT_MODE={shlex.quote(str(mode))}")
print(f"NOCT_SCHEME={shlex.quote(str(scheme))}")
print(f"CAEL_MODE={shlex.quote(str(__import__('json').load(open(__import__('os').path.expandvars('$XDG_STATE_HOME/caelestia/scheme.json'))) .get('mode','') if __import__('os').path.exists(__import__('os').path.expandvars('$XDG_STATE_HOME/caelestia/scheme.json')) else ''))}")
print(f"CAEL_WALL={shlex.quote(open(__import__('os').path.expandvars('$XDG_STATE_HOME/caelestia/wallpaper/path.txt')).read().strip() if __import__('os').path.exists(__import__('os').path.expandvars('$XDG_STATE_HOME/caelestia/wallpaper/path.txt')) else '')}")
print(f"ENABLE_BUILTIN={shlex.quote(str(bool(eb)).lower())}")
print(f"ENABLE_COMMUNITY={shlex.quote(str(bool(ec)).lower())}")
print(f"BUILTIN_IDS={shlex.quote(','.join(bi))}")
print(f"COMMUNITY_IDS={shlex.quote(','.join(ci))}")
PY
)"

# Effective render mode: Caelestia's mode wins when this sync is for
# Caelestia's wallpaper (otherwise noctalia apps would stay light while the
# Caelestia shell is dark, and the obsidian .theme-dark block — which uses
# {{colors.*.default.*}} — would get light colors).
# Precedence: MODE_OVERRIDE > SCHEME_MODE (caelestia hook env) >
# caelestia scheme.json (when wallpaper is Caelestia's) > noctalia settings.
EFFECTIVE_MODE="$NOCT_MODE"
MODE_SOURCE="noctalia-settings"
if [[ "${MODE_OVERRIDE:-}" == "dark" || "${MODE_OVERRIDE:-}" == "light" ]]; then
  EFFECTIVE_MODE="$MODE_OVERRIDE"
  MODE_SOURCE="MODE_OVERRIDE"
elif [[ "${SCHEME_MODE:-}" == "dark" || "${SCHEME_MODE:-}" == "light" ]]; then
  EFFECTIVE_MODE="$SCHEME_MODE"
  MODE_SOURCE="SCHEME_MODE"
elif [[ -n "${CAEL_MODE:-}" && ( "${CAEL_MODE:-}" == "dark" || "${CAEL_MODE:-}" == "light" ) && "$WALLPAPER" == "${CAEL_WALL:-}" ]]; then
  EFFECTIVE_MODE="$CAEL_MODE"
  MODE_SOURCE="caelestia-scheme"
fi

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

expand_path() {
  local p="$1"
  p="${p//\$XDG_CONFIG_HOME/$XDG_CONFIG_HOME}"
  p="${p//\$XDG_CACHE_HOME/$XDG_CACHE_HOME}"
  p="${p//\$XDG_DATA_HOME/$XDG_DATA_HOME}"
  p="${p//\$XDG_STATE_HOME/$XDG_STATE_HOME}"
  p="${p//\$HOME/$HOME}"
  if [[ "$p" == "~"* ]]; then
    p="$HOME${p:1}"
  fi
  printf '%s' "$p"
}

resolve_hook() {
  local hook="$1" config_dir="$2"
  hook="${hook//\{\{ config_dir \}\}/$config_dir}"
  hook="${hook//\{\{config_dir\}\}/$config_dir}"
  hook="${hook//\{\{ mode \}\}/$EFFECTIVE_MODE}"
  hook="${hook//\{\{mode\}\}/$EFFECTIVE_MODE}"
  printf '%s' "$hook"
}

render_entry() {
  local input="$1" output="$2" hook="$3" dynamic="$4"
  # Skip outputs for apps that aren't installed: if the parent dir does not
  # exist yet (and this isn't a dynamic output like obsidian which discovers
  # vaults itself), don't create junk — mirrors noctalia's
  # "skipping template ... (client not installed)".
  if [[ "$dynamic" != "1" && ! -d "$(dirname "$output")" && ! -f "$output" ]]; then
    echo "  skip (client not installed): $output"
    return 0
  fi
  mkdir -p "$(dirname "$output")"
  if [[ -n "${THEME_JSON_FILE:-}" && -f "${THEME_JSON_FILE:-}" ]]; then
    # App colors match Caelestia's active color scheme exactly.
    if ! noctalia theme --theme-json "$THEME_JSON_FILE" --default-mode "$EFFECTIVE_MODE" \
        -r "$input:$output" >/dev/null 2>&1; then
      echo "  warn: render failed: $input -> $output" >&2
      return 0
    fi
  else
    # Fallback: wallpaper-derived noctalia palette.
    if ! noctalia theme "$WALLPAPER" --scheme "$NOCT_SCHEME" --default-mode "$EFFECTIVE_MODE" \
        -r "$input:$output" >/dev/null 2>&1; then
      echo "  warn: render failed: $input -> $output" >&2
      return 0
    fi
  fi
  echo "  rendered: $output"
  if [[ -n "$hook" ]]; then
    bash -c "$hook" >/dev/null 2>&1 || true
  fi
}

# Emit one line per template entry:
# ENTRY_ID \x1f INPUT_JSON \x1f OUTPUTS_JSON \x1f POST_HOOK \x1f IS_DYNAMIC
# INPUT_JSON: {"path":..., "dynamic":...} OUTPUTS_JSON: ["..."] or {"dynamic":...}
emit_entries() {
  local manifest="$1" tdir="$2" want_ids="$3" builtin="$4"
  python3 - "$manifest" "$tdir" "$want_ids" "$builtin" <<'PY' 2>/dev/null
import sys, tomllib, json
manifest, tdir, want, builtin = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == '1'
want_set = set(filter(None, want.split(','))) if want else None
try:
    d = tomllib.load(open(manifest, 'rb'))
except Exception as e:
    print(f"WARN cannot parse {manifest}: {e}", file=sys.stderr)
    sys.exit(0)
for entry_id, entry in (d.get('templates', {}) or {}).items():
    if builtin and want_set is not None and entry_id not in want_set:
        continue
    inp = entry.get('input_path', '')
    inp_dyn = entry.get('input_path_dynamic', '')
    inp_modes = entry.get('input_path_modes', '')
    out = entry.get('output_path', '')
    out_dyn = entry.get('output_path_dynamic', '')
    hook = entry.get('post_hook', '')
    # normalize outputs to list (tomllib already gives list for arrays)
    outs = out if isinstance(out, list) else ([out] if out else [])
    rec = {
        'id': entry_id,
        'input': inp, 'input_dyn': inp_dyn, 'input_modes': inp_modes,
        'outputs': outs, 'output_dyn': out_dyn, 'hook': hook,
    }
    print(json.dumps(rec, separators=(',', ':')))
PY
}

echo "caelestia-noctalia-sync: wallpaper=$WALLPAPER scheme=$NOCT_SCHEME noctalia_mode=$NOCT_MODE effective_mode=$EFFECTIVE_MODE ($MODE_SOURCE)"

# Build a Noctalia palette from Caelestia's ACTIVE color scheme so app colors
# match the scheme exactly (static schemes like gruvbox/rosepine included).
# Falls back to wallpaper-derived rendering if conversion fails.
THEME_JSON_FILE=""
TJ_CANDIDATE="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/noctalia-theme.json"
if [[ -x "$HOME/.local/bin/caelestia-scheme-to-noctalia.py" ]]; then
  if "$HOME/.local/bin/caelestia-scheme-to-noctalia.py" \
      --wallpaper "$WALLPAPER" --noct-scheme "$NOCT_SCHEME" \
      -o "$TJ_CANDIDATE" >/dev/null 2>&1; then
    if python3 -c "import json; d=json.load(open('$TJ_CANDIDATE')); assert d.get('dark') and d.get('light')" 2>/dev/null; then
      THEME_JSON_FILE="$TJ_CANDIDATE"
      echo "caelestia-noctalia-sync: matching Caelestia color scheme via $THEME_JSON_FILE"
    fi
  fi
fi
if [[ -z "$THEME_JSON_FILE" ]]; then
  echo "caelestia-noctalia-sync: converter unavailable, using wallpaper palette"
fi

# User-managed opt-outs: template ids listed in
# ~/.config/caelestia/noctalia-sync-skip (one per line) are never rendered,
# so hand-maintained app configs (e.g. a cleared starship.toml) stay untouched.
SYNC_SKIP_FILE="$HOME/.config/caelestia/noctalia-sync-skip"
SYNC_SKIP_IDS=","
if [[ -f "$SYNC_SKIP_FILE" ]]; then
  while IFS= read -r skip_line || [[ -n "$skip_line" ]]; do
    skip_line="${skip_line%%#*}"
    skip_line="$(printf '%s' "$skip_line" | tr -d '[:space:]')"
    [[ -n "$skip_line" ]] && SYNC_SKIP_IDS+="$skip_line,"
  done < "$SYNC_SKIP_FILE"
fi
is_skipped() { [[ "$SYNC_SKIP_IDS" == *",$1,"* ]]; }

# --- Builtin templates ---
if [[ "$ENABLE_BUILTIN" == "true" && -f "$BUILTIN_TOML" ]]; then
  while IFS= read -r rec; do
    [[ -z "$rec" ]] && continue
    eval "$(python3 - "$rec" "$BUILTIN_DIR" "$EFFECTIVE_MODE" <<'PY'
import sys, json, os
rec = json.loads(sys.argv[1]); tdir = sys.argv[2]; mode = sys.argv[3]
def sub(s):
    return s.replace('{{ config_dir }}', tdir).replace('{{config_dir}}', tdir).replace('{{ mode }}', mode).replace('{{mode}}', mode)
inp, inp_dyn, inp_modes = rec['input'], rec['input_dyn'], rec['input_modes']
inp_dyn = sub(inp_dyn) if inp_dyn else ''
# resolve input
resolved_in = ''
if inp_dyn:
    pass  # resolved in bash (needs shell exec)
elif inp:
    p = inp[2:] if inp.startswith('./') else inp
    resolved_in = p if os.path.isabs(p) else os.path.join(tdir, p)
elif isinstance(inp_modes, dict) and inp_modes:
    f = inp_modes.get(mode, inp_modes.get('dark', ''))
    if f:
        resolved_in = f if os.path.isabs(f) else os.path.join(tdir, f)
import shlex
print(f"E_ID={shlex.quote(rec['id'])}")
print(f"E_IN={shlex.quote(resolved_in)}")
print(f"E_IN_DYN={shlex.quote(inp_dyn)}")
print(f"E_OUT_DYN={shlex.quote(sub(rec['output_dyn']) if rec['output_dyn'] else '')}")
outs = [os.path.expandvars(o) for o in rec['outputs']]
print(f"E_OUTS={shlex.quote(chr(31).join(outs))}")
print(f"E_HOOK={shlex.quote(sub(rec['hook']) if rec['hook'] else '')}")
PY
)"
    # dynamic input needs shell execution
    if [[ -z "$E_IN" && -n "$E_IN_DYN" ]]; then
      E_IN="$(bash -c "$E_IN_DYN" 2>/dev/null | head -n 1)"
      if [[ "$E_IN" == ./* ]]; then E_IN="$BUILTIN_DIR/${E_IN#./}"; fi
      if [[ "$E_IN" != /* && -n "$E_IN" ]]; then E_IN="$BUILTIN_DIR/$E_IN"; fi
    fi
    [[ -z "$E_IN" || ! -f "$E_IN" ]] && continue
    if is_skipped "$E_ID"; then
      echo "  skip (user opt-out): $E_ID"
      continue
    fi
    outs=()
    is_dyn=0
    if [[ -n "$E_OUT_DYN" ]]; then
      is_dyn=1
      while IFS= read -r line; do
        [[ -n "$line" ]] && outs+=("$(expand_path "$line")")
      done < <(bash -c "$E_OUT_DYN" 2>/dev/null)
    elif [[ -n "$E_OUTS" ]]; then
      IFS=$'\x1f' read -ra outs <<<"$E_OUTS"
    fi
    [[ ${#outs[@]} -eq 0 ]] && continue
    for out in "${outs[@]}"; do
      [[ -z "$out" ]] && continue
      render_entry "$E_IN" "$(expand_path "$out")" "$E_HOOK" "$is_dyn"
    done
  done < <(emit_entries "$BUILTIN_TOML" "$BUILTIN_DIR" "$BUILTIN_IDS" 1)
fi

# --- Community templates ---
if [[ "$ENABLE_COMMUNITY" == "true" ]]; then
  IFS=',' read -ra CIDS <<<"$COMMUNITY_IDS"
  for cid in "${CIDS[@]}"; do
    [[ -z "$cid" ]] && continue
    if is_skipped "$cid"; then
      echo "  skip (user opt-out): $cid"
      continue
    fi
    manifest="$COMMUNITY_BASE/$cid/template.toml"
    tdir="$COMMUNITY_BASE/$cid"
    [[ -f "$manifest" ]] || continue
    while IFS= read -r rec; do
      [[ -z "$rec" ]] && continue
      eval "$(python3 - "$rec" "$tdir" "$EFFECTIVE_MODE" <<'PY'
import sys, json, os
rec = json.loads(sys.argv[1]); tdir = sys.argv[2]; mode = sys.argv[3]
def sub(s):
    return s.replace('{{ config_dir }}', tdir).replace('{{config_dir}}', tdir).replace('{{ mode }}', mode).replace('{{mode}}', mode)
inp, inp_dyn, inp_modes = rec['input'], rec['input_dyn'], rec['input_modes']
inp_dyn = sub(inp_dyn) if inp_dyn else ''
resolved_in = ''
if inp_dyn:
    pass
elif inp:
    resolved_in = os.path.join(tdir, inp)
elif isinstance(inp_modes, dict) and inp_modes:
    f = inp_modes.get(mode, inp_modes.get('dark', ''))
    if f:
        resolved_in = os.path.join(tdir, f)
import shlex
print(f"E_ID={shlex.quote(rec['id'])}")
print(f"E_IN={shlex.quote(resolved_in)}")
print(f"E_IN_DYN={shlex.quote(inp_dyn)}")
print(f"E_OUT_DYN={shlex.quote(sub(rec['output_dyn']) if rec['output_dyn'] else '')}")
outs = rec['outputs']
print(f"E_OUTS={shlex.quote(chr(31).join(outs))}")
print(f"E_HOOK={shlex.quote(sub(rec['hook']) if rec['hook'] else '')}")
PY
)"
      if [[ -z "$E_IN" && -n "$E_IN_DYN" ]]; then
        E_IN="$(bash -c "$E_IN_DYN" 2>/dev/null | head -n 1)"
      fi
      [[ -z "$E_IN" || ! -f "$E_IN" ]] && continue
      outs=()
      is_dyn=0
      if [[ -n "$E_OUT_DYN" ]]; then
        is_dyn=1
        while IFS= read -r line; do
          [[ -n "$line" ]] && outs+=("$(expand_path "$line")")
        done < <(bash -c "$E_OUT_DYN" 2>/dev/null)
      elif [[ -n "$E_OUTS" ]]; then
        IFS=$'\x1f' read -ra outs <<<"$E_OUTS"
      fi
      [[ ${#outs[@]} -eq 0 ]] && continue
      for out in "${outs[@]}"; do
        [[ -z "$out" ]] && continue
        render_entry "$E_IN" "$(expand_path "$out")" "$E_HOOK" "$is_dyn"
      done
    done < <(emit_entries "$manifest" "$tdir" "" 0)
  done
fi

echo "caelestia-noctalia-sync: done"

# Completion signal. This script runs detached (nohup ... &) from Caelestia's
# postHook and takes ~10s, so without this the change looks like it never
# applied and users manually re-toggle light/dark to "fix" it.
# Only notifies when Caelestia is the active shell to avoid spam under
# Noctalia/ii/DMS. Opt out with CAELESTIA_SYNC_NOTIFY=0.
if [[ "${CAELESTIA_SYNC_NOTIFY:-1}" == "1" ]] && command -v notify-send >/dev/null 2>&1; then
  _active_shell="$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/shell-switch/last" 2>/dev/null || true)"
  if [[ "$_active_shell" == "ca" ]] || pgrep -f "qs -c caelestia" >/dev/null 2>&1; then
    notify-send "Caelestia" "App colors synced ($EFFECTIVE_MODE mode)" >/dev/null 2>&1 || true
  fi
  unset _active_shell
fi
