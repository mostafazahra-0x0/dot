export LC_TIME=en_US.UTF-8
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(
    git
    zsh-completions
    zsh-autosuggestions
    zsh-syntax-highlighting
    history-substring-search
)
source $ZSH/oh-my-zsh.sh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
if [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
  source /usr/share/doc/fzf/examples/completion.zsh
fi
if command -v fzf >/dev/null; then
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
fi
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export PATH="$PATH:/opt/nvim-linux64/bin"
export PATH=/home/mostafazahra101/.opencode/bin:$PATH
alias ls='eza --icons --group-directories-first'
alias ll='eza -lh --icons --grid --group-directories-first'
alias lt='eza --tree --icons'
alias lg="eza -la --git"
alias la="eza -la"
alias cat='bat'
alias k='kilo'
alias ge='gemini'
alias co='codex'
alias bt='btop'
alias y='yazi'
alias tokens='bunx tokscale'
alias ob='obsidian'
alias cc='claude'
alias oc='opencode'
alias v='nvim'
alias mkd='mkdir'
alias tch='touch'
alias ser='serie'
alias ff='fastfetch'
alias cavamic="cava -p ~/.config/cava/mic_config"
export PATH="$HOME/.cargo/bin:$PATH"

# OpenClaw Completion
source "/home/mostafazahra101/.openclaw/completions/openclaw.zsh"

# bun completions
[ -s "/home/mostafazahra101/.bun/_bun" ] && source "/home/mostafazahra101/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Neuron CLI
export PATH="$HOME/.local/bin:$PATH"


# Added by Antigravity CLI installer
export PATH="/home/mostafazahra101/.local/bin:$PATH"

# >>> hitch shell integration >>>
function _hitch_prompt_segment() {
  [[ -n "${HITCH_SESSION:-}" ]] && print -n "%F{2}#${HITCH_SESSION}%f "
}

function _hitch_precmd() {
  [[ -n "${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS:-}" ]] && return
  [[ -z "${HITCH_SESSION:-}" ]] && return
  local _hitch_prefix="%F{2}#${HITCH_SESSION}%f "
  [[ "$PROMPT" == "${_hitch_prefix}"* ]] && return
  PROMPT="${_hitch_prefix}${PROMPT}"
}

if [[ -z "${HITCH_PROMPT_INSTALLED:-}" && -z "${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS:-}" ]]; then
  HITCH_PROMPT_INSTALLED=1
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _hitch_precmd
fi

function _hitch_run() {
    local _hitch_command="$1"
    shift
    local _hitch_bin="${commands[$_hitch_command]:-}"
    if [[ -z "${_hitch_bin:-}" ]]; then
      print -u2 "$_hitch_command: command not found"
      return 127
    fi
    if [[ -z "${HITCH_SESSION:-}" && ( "$#" -eq 0 || "$1" == "on" || "$1" == "start" ) ]]; then
      fc -W 2>/dev/null
    fi

    local _hitch_cwd_file=""
    if [[ -z "${HITCH_SESSION:-}" ]]; then
      _hitch_cwd_file="${TMPDIR:-/tmp}/hitch-cwd-$$-$RANDOM"
      HITCH_CWD_SYNC_FILE="$_hitch_cwd_file" "$_hitch_bin" "$@"
    else
      "$_hitch_bin" "$@"
    fi
    local code=$?
    if [[ -n "$_hitch_cwd_file" && -s "$_hitch_cwd_file" ]]; then
      local _hitch_cwd
      _hitch_cwd="$(cat "$_hitch_cwd_file" 2>/dev/null)"
      if [[ -d "$_hitch_cwd" ]]; then
        cd "$_hitch_cwd"
      fi
    fi
    [[ -n "$_hitch_cwd_file" ]] && rm -f "$_hitch_cwd_file"
    if [[ "$code" -eq 42 ]]; then
      exit
    fi
    return "$code"
}

function hitch() {
  _hitch_run hitch "$@"
}

alias unhitch='hitch off'

function hitch-dev() {
  _hitch_run hitch-dev "$@"
}
# <<< hitch shell integration <<<
eval "$(starship init zsh)"
