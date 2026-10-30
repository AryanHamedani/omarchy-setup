# Oh My Zsh, with Omarchy's bash setup (mise, starship, zoxide, fzf, aliases) carried over.

export ZSH="$HOME/.oh-my-zsh"

# Empty theme: the prompt is starship, which follows the Omarchy theme.
ZSH_THEME=""

plugins=(
  git sudo extract copypath history-substring-search
  docker docker-compose kubectl kubectx helm
  python uv golang gh direnv
)

# Extra completions (zsh-completions package) before compinit runs.
# ~/.local/share/zsh/site-functions holds generated ones (glab, jira, k9s, mise, sentry-cli).
fpath=(~/.local/share/zsh/site-functions /usr/share/zsh/site-functions $fpath)

source "$ZSH/oh-my-zsh.sh"

# History
HISTSIZE=32768
SAVEHIST=32768
setopt HIST_IGNORE_SPACE HIST_IGNORE_ALL_DUPS SHARE_HISTORY

# Omarchy defaults: editor, browser, bat man pages, locale
source "$OMARCHY_PATH/default/bash/envs"

# Tools
command -v mise &>/dev/null && eval "$(mise activate zsh)"
[[ $TERM != dumb ]] && command -v starship &>/dev/null && eval "$(starship init zsh)"
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
if command -v fzf &>/dev/null; then
  source <(fzf --zsh)
fi
# Atuin takes over CTRL+R (after fzf); Up keeps searching by what's already typed.
command -v atuin &>/dev/null && eval "$(atuin init zsh --disable-up-arrow)"
if command -v try &>/dev/null; then
  try() {
    unfunction try
    eval "$(SHELL=/bin/zsh command try init ~/Work/tries)"
    try "$@"
  }
fi

# Omarchy aliases and functions (ls→eza, cd→zoxide, g, d, n, cx, tmux/ssh/worktree helpers)
source "$OMARCHY_PATH/default/bash/aliases"
for f in "$OMARCHY_PATH"/default/bash/fns/*; do
  [[ ${f:t} == worktrees ]] || source "$f"
done
unset f

# Omarchy's worktree helpers are named ga/gd, which clash with Oh My Zsh's
# git add/diff aliases. Keep the aliases; expose the helpers as gwa/gwd.
unalias ga gd 2>/dev/null
source "$OMARCHY_PATH/default/bash/fns/worktrees"
functions[gwa]=$functions[ga] functions[gwd]=$functions[gd]
unfunction ga gd
alias ga='git add' gd='git diff'

# Plugins from Arch packages; syntax highlighting must stay last.
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Up/Down search history by what's already typed
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Your own aliases and functions go below.

# Work shortcuts
alias dj='uv run python manage.py'   # Django: dj runserver, dj shell_plus, dj migrate
alias pt='uv run pytest'
alias lg='lazygit' lzd='lazydocker'


# Claude with the Telegram channel (bot token: vault set TELEGRAM_BOT_TOKEN)
alias claude-tg='claude --channels plugin:telegram@claude-plugins-official'

# Claude Code shortcuts
alias cw='claude -w'          # new git worktree session: cw feature-x
alias cbg='claude --bg'       # background session: cbg "task"
alias ca='claude agents'      # list background sessions (claude attach <id> to join)
