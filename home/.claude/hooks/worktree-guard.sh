#!/usr/bin/env bash
# PreToolUse (Edit/Write): under ~/Work, the first edit per session to a repo's main checkout is
# bounced once with a reminder to use a worktree (see ~/Work/CLAUDE.md). Retrying goes through,
# so Claude decides; gitignored files (local-only config) are never bounced.
input=$(cat)
file=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
[[ $file == "$HOME/Work/"* ]] || exit 0

dir=$(dirname "$file")
while [[ ! -d $dir ]]; do dir=$(dirname "$dir"); done
git_dir=$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null) || exit 0
[[ $git_dir == "$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir)" ]] || exit 0
git -C "$dir" check-ignore -q "$file" && exit 0

repo=$(git -C "$dir" rev-parse --show-toplevel)
marker=${XDG_RUNTIME_DIR:-/tmp}/claude-worktree-guard/$(jq -r .session_id <<<"$input")-$(md5sum <<<"$repo" | cut -c1-12)
[[ -e $marker ]] && exit 0
mkdir -p "${marker%/*}" && touch "$marker"

echo "Reminder: $file is in the main checkout of $repo. Task work belongs in a worktree:
  git -C $repo worktree add $repo/.claude/worktrees/<slug> -b <type>/<task> origin/HEAD
If editing the main checkout is right here (Aryan asked for it, or it isn't branch work),
retry the same edit: it will go through, and you won't be stopped again for this repo." >&2
exit 2
