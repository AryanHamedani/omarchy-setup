# omarchy-setup

My changes on top of a stock [Omarchy](https://omarchy.org/) install, and a script that applies
them. Omarchy stays Omarchy: everything lives in `~/.config` and other user files, nothing under
`/usr/share/omarchy` is touched, and the only system files are one logind drop-in and two
firewall rules for remote desktop.

## Use

On a fresh Omarchy install, in a terminal:

```bash
git clone https://github.com/AryanHamedani/omarchy-setup ~/omarchy-setup
cd ~/omarchy-setup
./install.sh                 # every step
./install.sh configs desk    # or only some
```

| Step | What it does |
|---|---|
| `packages` | Installs [`packages/pacman.txt`](packages/pacman.txt) and [`packages/aur.txt`](packages/aur.txt) with `omarchy pkg add` / `omarchy pkg aur add` |
| `shell` | Oh My Zsh, and zsh as the login shell |
| `configs` | Copies [`home/`](home) into `~`. A file that differs is first backed up to `<file>.bak-<timestamp>` |
| `tools` | `mise install` for the dev tools in [`mise/config.toml`](home/.config/mise/config.toml) |
| `services` | voxtype and the weekly Windscribe refresh as user services, plus Tailscale |
| `desk` | Remote desktop from my Windows PC into this laptop (below) |

Every step can be run again safely. After the first run: log out and back in, run
`sudo tailscale up --operator=$USER` and `windscribe-cli login` once.

## What's in it

- **Hyprland**: US + Persian keyboard layouts (both Alt keys switch), 1.25 scale, and a lid
  binding that does nothing while the desk PC is connected.
- **Omarchy shell**: bar layout and two plugins of mine: a Jalali (Persian) calendar with
  Iranian holidays, and a Windscribe VPN indicator.
- **Terminals**: Ghostty, plus WezTerm for Persian/right-to-left text (Ghostty can't do BiDi).
- **Shell**: zsh + Oh My Zsh with Omarchy's own aliases and functions carried over, starship,
  atuin, direnv. Omarchy's `ga`/`gd` worktree helpers become `gwa`/`gwd`, so `ga`/`gd` stay
  `git add`/`git diff`.
- **Fonts**: Inter for the interface, JetBrains Mono for code, Vazirmatn for Persian.
- **Tokens**: [`vault`](home/.local/bin/vault) keeps API tokens as exported variables in
  `~/.config/vault/env` (mode 600, never in this repo). `~/.zshenv` loads them in every zsh.
  `vault set NAME "description"`, `vault list`.
- **Git**: delta for diffs, rebase on pull, zdiff3 conflicts.
- **Windscribe**: a weekly job keeps Iranian networks out of the VPN tunnel
  ([`windscribe-refresh-iran`](home/.local/bin/windscribe-refresh-iran)).
- **`winpc`**: remote desktop from this laptop into the Windows PC.

## Desk: the Windows PC works on this laptop over RDP

I lock the laptop, put it on its stand (lid closed) and work on it from the PC with Remote
Desktop Connection, served by [hypr-rdp](https://github.com/MuNeNICK/hypr-rdp):

- The PC sees the laptop screen itself at 1920x1080, with the same workspaces, windows and shortcuts.
- While the PC is connected, the laptop stays awake with its lid shut and its panel dimmed.
- When the PC disconnects with the lid shut, the laptop locks. On AC power it stays awake and
  reachable; on battery it suspends as usual.

`install.sh desk` needs the RDP password in the vault first:
`vault set LAPTOP_RDP_PASSWORD "Password the desk PC uses to RDP into this laptop"`.

The session doesn't resize to a portrait monitor. hypr-rdp can give the PC its own screen that
does, but with the lid shut Hyprland won't turn that screen on until the lid opens, so sessions
started on a closed laptop fail.

## Not included

Secrets (the vault file, keys, VPN profiles), work-only tools and configs, and anything
Omarchy already ships by default.

## License

MIT.
