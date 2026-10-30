#!/bin/bash
# Set up a fresh Omarchy install the way I use it. Run in a terminal (sudo asks for a password).
#
#   ./install.sh               every step, in order
#   ./install.sh configs desk  only the named steps
#
# Steps: packages shell configs plugins tools kubevpn claudecode services desk
# Re-running is safe: installed packages are skipped and a config that differs is backed up
# to <file>.bak-<timestamp> before it is replaced.
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)

step() { printf '\n==> %s\n' "$*"; }

packages() {
  step "Packages (official repos, then AUR)"
  omarchy pkg add $(<"$REPO/packages/pacman.txt")
  omarchy pkg aur add $(<"$REPO/packages/aur.txt")
}

shell() {
  step "zsh with Oh My Zsh (the prompt stays starship)"
  [[ -d ~/.oh-my-zsh ]] || git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
  [[ $(getent passwd "$USER" | cut -d: -f7) == /usr/bin/zsh ]] || chsh -s /usr/bin/zsh
}

configs() {
  step "Config files into ~ (differing files are backed up first)"
  local src dst
  while IFS= read -r -d '' src; do
    dst="$HOME/${src#"$REPO/home/"}"
    if [[ -e $dst ]] && cmp -s "$src" "$dst"; then continue; fi
    [[ -e $dst ]] && cp -a "$dst" "$dst.bak-$STAMP" && echo "  backed up ${dst/#$HOME/~}"
    install -D -m "$(stat -c %a "$src")" "$src" "$dst"
    echo "  ${dst/#$HOME/~}"
  done < <(find "$REPO/home" -type f -print0)

  gsettings set org.gnome.desktop.interface font-name 'Inter 11'
  gsettings set org.gnome.desktop.interface document-font-name 'Inter 11'
  gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11'
  fc-cache -f
  if hyprctl version &>/dev/null; then
    hyprctl reload >/dev/null
    hyprctl configerrors
  fi
}

# My two bar plugins, from their own repos. Each installer pulls its own
# dependencies (windscribe-cli, the Vazirmatn font) and is safe to rerun.
# `bash <(curl …)` rather than `curl | bash` keeps the terminal on stdin for
# Windscribe's sign-in prompt.
plugins() {
  step "Omarchy plugins: Jalali calendar and Windscribe"
  bash <(curl -fsSL https://raw.githubusercontent.com/AryanHamedani/jalali-calendar/main/install.sh) --replace-clock
  bash <(curl -fsSL https://raw.githubusercontent.com/AryanHamedani/windscribe-panel/main/install.sh)
}

tools() {
  step "Dev tools from ~/.config/mise/config.toml"
  mise install
  local d=~/.local/share/zsh/site-functions
  mkdir -p "$d"
  glab completion -s zsh >"$d/_glab"
  jira completion zsh >"$d/_jira"
  k9s completion zsh >"$d/_k9s"
  mise completion zsh >"$d/_mise"
  sentry-cli completions zsh >"$d/_sentry-cli" 2>/dev/null
}

# kubectl, k9s and helm for one cluster through an isolated OpenVPN container
# (https://github.com/AryanHamedani/kubectl-vpn). The VPN profile, credentials and
# cluster are never in this repo; its installer asks for them locally.
kubevpn() {
  step "kubectl-vpn: one cluster through an isolated OpenVPN container"
  local dir=~/Work/personal/AryanHamedani/kubectl-vpn
  [[ -d $dir ]] || git clone https://github.com/AryanHamedani/kubectl-vpn.git "$dir"
  git -C "$dir" pull --ff-only
  echo "  Select the cluster's context, then run once:"
  echo "    python3 $dir/install.py --profile /path/to/vpn.ovpn"
}

# Hooks and agents arrive with `configs`. Settings are merged, never replaced, so
# plugins and MCP servers that only exist on this machine stay.
claudecode() {
  step "Claude Code: marketplaces, plugins and settings"
  claude --version >/dev/null # Omarchy's launcher installs it on first use
  claude plugin marketplace add DietrichGebert/ponytail
  claude plugin marketplace add openai/codex-plugin-cc
  local have plugin
  have=$(claude plugin list --json | jq -r '.[].id')
  # Reinstalling takes seconds per plugin, so only the missing ones.
  while read -r plugin; do
    grep -qxF "$plugin" <<<"$have" || claude plugin install "$plugin"
  done <"$REPO/packages/claude-plugins.txt"
  [[ -e ~/.claude/settings.json ]] && cp -a ~/.claude/settings.json ~/.claude/settings.json.bak-"$STAMP"
  python3 "$REPO/claude/merge-settings.py" "$REPO/claude/settings.json"
}

services() {
  step "User services and Tailscale"
  systemctl --user daemon-reload
  systemctl --user enable --now voxtype.service
  sudo systemctl enable --now tailscaled
  echo "  Sign in to Tailscale once: sudo tailscale up --operator=$USER"
}

desk() {
  step "Desk PC over RDP: hypr-rdp (see README)"
  # shellcheck source=/dev/null
  [[ -r ~/.config/vault/env ]] && source ~/.config/vault/env
  if [[ -z ${LAPTOP_RDP_PASSWORD:-} ]]; then
    echo "  First pick the password the PC will use:"
    echo "    vault set LAPTOP_RDP_PASSWORD \"Password the desk PC uses to RDP into this laptop\""
    echo "  then run: ./install.sh desk"
    return 1
  fi

  omarchy pkg aur add hypr-rdp

  # On AC a shut, locked laptop stays reachable; on battery it suspends as usual.
  sudo install -D -m 644 "$REPO/system/etc/systemd/logind.conf.d/30-rdp-lid.conf" \
    /etc/systemd/logind.conf.d/30-rdp-lid.conf
  sudo systemctl kill -s HUP systemd-logind

  sudo ufw allow from 192.168.1.0/24 to any port 3389 proto tcp comment 'desk-rdp'
  sudo ufw allow in on tailscale0 to any port 3389 proto tcp comment 'desk-rdp-tailscale'

  systemctl --user daemon-reload
  systemctl --user enable --now hypr-rdp.service
  systemctl --user --no-pager status hypr-rdp.service | head -3
}

all=(packages shell configs plugins tools kubevpn claudecode services desk)
steps=("$@")
((${#steps[@]})) || steps=("${all[@]}")
for name in "${steps[@]}"; do
  [[ " ${all[*]} " == *" $name "* ]] || { echo "Unknown step: $name (steps: ${all[*]})" >&2; exit 1; }
  "$name"
done
echo
echo "Done. Log out and back in for the shell change."
